import Combine
import Network
import SwiftUI
import os

/// ViewModel: Orchestrates detection, automounting, and state management.
@MainActor
class FilerManager: ObservableObject {

    // MARK: - UI State
    @Published var filers: [Filer] = []
    @Published var mountPaths: [UUID: String] = [:]
    @Published var busyFilers: Set<UUID> = []
    @Published var launchAtLogin: Bool = MountService.isLoginItemEnabled()
    @Published var preferredTerminal: String
    @Published var availableTerminals: [(name: String, id: String)] = []

    @Published var lastError: String? = nil
    @Published var showError: Bool = false

    private var isNetworkUp: Bool = true

    // Dependencies
    private let storage = PersistenceService()
    private let eventMonitor = EventMonitorService()
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Mounty",
        category: "Manager"
    )

    private let knownTerminals = [
        ("Terminal", "com.apple.Terminal"),
        ("iTerm2", "com.googlecode.iterm2"),
        ("Hyper", "co.zeit.hyper"),
        ("Warp", "dev.warp.Warp-Stable"),
        ("Alacritty", "org.alacritty"),
        ("Kitty", "net.kovidgoyal.kitty"),
    ]

    init() {
        self.filers = storage.loadFilers()
        self.preferredTerminal = storage.loadTerminalBundleID()

        setupPipelines()
        refreshInstalledTerminals()

        // Initial Refresh (Serialized)
        Task {
            await refreshState()
            await runAutomount()
        }
    }

    // MARK: - Event Pipelines

    private func setupPipelines() {
        // 1. Global Network Gate
        eventMonitor.networkStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }
                let wasUp = self.isNetworkUp
                self.isNetworkUp = (status == .satisfied)

                if self.isNetworkUp != wasUp {
                    logger.info(
                        "Global Network Changed: \(self.isNetworkUp ? "UP" : "DOWN")"
                    )
                    // Serialize logic to prevent race condition
                    Task {
                        await self.refreshState()
                        if self.isNetworkUp { await self.runAutomount() }
                    }
                }
            }
            .store(in: &cancellables)

        // 2. Interface Changes (VPN Toggle)
        eventMonitor.interfacesChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.logger.info(
                    "Interface topology changed. Retrying connections."
                )
                Task {
                    await self?.refreshState()
                    await self?.runAutomount()
                }
            }
            .store(in: &cancellables)

        // 3. FileSystem Changes
        eventMonitor.fileSystemChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in Task { await self?.refreshState() } }
            .store(in: &cancellables)

        // 4. Heartbeat (5s)
        Timer.publish(every: 5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.refreshState() } }
            .store(in: &cancellables)
    }

    // MARK: - Logic: Automount

    private func runAutomount() async {
        guard isNetworkUp else { return }

        for filer in filers where filer.isAutomountEnabled {
            if mountPaths[filer.id] == nil && !busyFilers.contains(filer.id) {
                busyFilers.insert(filer.id)

                // TCP Pre-check
                let isReachable = await ReachabilityService.isServerReachable(
                    address: filer.serverAddress
                )

                // Re-verify mount status after TCP check to prevent race
                if isReachable && mountPaths[filer.id] == nil {
                    guard let url = URL(string: filer.serverAddress) else {
                        continue
                    }
                    logger.info("Automounting \(filer.name)")

                    if let path = await MountService.mount(url: url) {
                        self.mountPaths[filer.id] = path
                    }
                }
                busyFilers.remove(filer.id)
            }
        }
    }

    func refreshState() async {
        let currentFilers = self.filers
        let networkAvailable = self.isNetworkUp

        // Offload heavy checks to background
        let newPaths = await Task.detached {
            return await FilerManager.detectMounts(
                filers: currentFilers,
                isNetworkUp: networkAvailable
            )
        }.value

        if self.mountPaths != newPaths {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.mountPaths = newPaths
            }
        }
    }

    /// Detects active mounts using Two-Factor Liveness Check (TCP + I/O).
    nonisolated private static func detectMounts(
        filers: [Filer],
        isNetworkUp: Bool
    ) async -> [UUID: String] {
        if !isNetworkUp { return [:] }

        let systemMounts = SystemMountService.getSystemMounts()
        var results: [UUID: String] = [:]

        await withTaskGroup(of: (UUID, String?).self) { group in
            for filer in filers {
                group.addTask {
                    if let path = SystemMountService.findMountPath(
                        for: filer,
                        in: systemMounts
                    ) {

                        // 1. TCP Check (Fastest fail for dropped routes)
                        if await ReachabilityService.isServerReachable(
                            address: filer.serverAddress
                        ) {
                            // 2. I/O Check (Catches hung Kernels)
                            if ReachabilityService.isMountPointAlive(path: path)
                            {
                                return (filer.id, path)
                            }
                        }
                    }
                    return (filer.id, nil)
                }
            }
            for await (id, path) in group {
                if let validPath = path { results[id] = validPath }
            }
        }
        return results
    }

    // MARK: - Actions

    private func refreshInstalledTerminals() {
        self.availableTerminals = knownTerminals.filter { (_, bundleID) in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
                != nil
        }
        if !availableTerminals.contains(where: { $0.id == preferredTerminal }) {
            preferredTerminal = "com.apple.Terminal"
        }
    }

    func mount(_ filer: Filer) {
        guard let url = URL(string: filer.serverAddress) else { return }
        busyFilers.insert(filer.id)

        Task {
            if let path = await MountService.mount(url: url) {
                self.mountPaths[filer.id] = path
                logger.info("Manually mounted \(filer.name)")
            } else {
                self.lastError =
                    "Connection failed. Verify address and keychain credentials."
                self.showError = true
            }
            self.busyFilers.remove(filer.id)
            await self.refreshState()
        }
    }

    func unmount(_ filer: Filer) {
        disableAutomount(for: filer)
        guard let path = mountPaths[filer.id] else { return }

        mountPaths.removeValue(forKey: filer.id)
        busyFilers.insert(filer.id)

        Task {
            await MountService.unmount(path: path)
            self.busyFilers.remove(filer.id)
            await self.refreshState()
        }
    }

    func openInFinder(_ filer: Filer) {
        if let path = mountPaths[filer.id] {
            MountService.openInFinder(path: path)
        }
    }

    func openInTerminal(_ filer: Filer) {
        if let path = mountPaths[filer.id] {
            MountService.openInTerminal(path: path, with: preferredTerminal)
        }
    }

    // MARK: - Persistence

    func addFiler(_ filer: Filer) {
        filers.append(filer)
        storage.saveFilers(filers)
        Task { await refreshState() }
    }

    func removeFiler(_ id: UUID) {
        filers.removeAll { $0.id == id }
        storage.saveFilers(filers)
        Task { await refreshState() }
    }

    func removeAllFilers() {
        filers.removeAll()
        storage.saveFilers(filers)
        Task { await refreshState() }
    }

    func toggleAutomount(_ id: UUID) {
        if let idx = filers.firstIndex(where: { $0.id == id }) {
            filers[idx].isAutomountEnabled.toggle()
            storage.saveFilers(filers)
            if filers[idx].isAutomountEnabled { Task { await runAutomount() } }
        }
    }

    private func disableAutomount(for filer: Filer) {
        if let idx = filers.firstIndex(where: { $0.id == filer.id }) {
            filers[idx].isAutomountEnabled = false
            storage.saveFilers(filers)
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        MountService.toggleLoginItem(enabled: enabled)
        launchAtLogin = MountService.isLoginItemEnabled()
    }

    func setPreferredTerminal(_ bundleID: String) {
        preferredTerminal = bundleID
        storage.saveTerminalBundleID(bundleID)
    }
}
