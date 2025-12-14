import SwiftUI
import Combine
import os

@MainActor
class FilerManager: ObservableObject {
    // MARK: - UI State
    @Published var filers: [Filer] = []
    @Published var mountPaths: [UUID: String] = [:] // Maps Filer ID -> Local Path
    @Published var busyFilers: Set<UUID> = []       // Loading indicators
    @Published var launchAtLogin: Bool = MountService.isLoginItemEnabled()
    @Published var preferredTerminal: String
    
    // Error Handling
    @Published var lastError: String? = nil
    @Published var showError: Bool = false
    
    // MARK: - Dependencies
    private let storage = PersistenceService()
    private let eventMonitor = EventMonitorService()
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Mounty", category: "Manager")
    
    // Available Terminals for Settings
    let terminalOptions = [
        ("Terminal", "com.apple.Terminal"),
        ("iTerm2", "com.googlecode.iterm2"),
        ("Hyper", "co.zeit.hyper"),
        ("Warp", "dev.warp.Warp-Stable")
    ]
    
    init() {
        self.filers = storage.loadFilers()
        self.preferredTerminal = storage.loadTerminalBundleID()
        
        setupPipelines()
        
        // Initial async refresh
        Task { await refreshState() }
    }
    
    // MARK: - Event Driven Pipelines
    
    private func setupPipelines() {
        // 1. Network Change (VPN/WiFi) -> Trigger Automount & Zombie Check
        eventMonitor.networkChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.logger.debug("Network Event: Running logic")
                Task { await self?.runAutomount() }
                Task { await self?.refreshState() }
            }
            .store(in: &cancellables)
        
        // 2. FileSystem Change (Mount/Unmount) -> Refresh UI
        eventMonitor.fileSystemChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                Task { await self?.refreshState() }
            }
            .store(in: &cancellables)
        
        // 3. Heartbeat (60s) -> Cleanup Zombies missed by OS notifications
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refreshState() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Logic: Automount
    
    private func runAutomount() async {
        for filer in filers where filer.isAutomountEnabled {
            // Pre-condition: Not mounted, Not busy
            if mountPaths[filer.id] == nil && !busyFilers.contains(filer.id) {
                
                busyFilers.insert(filer.id)
                
                // Network Reachability Check (avoids Finder error popups)
                let isReachable = await ReachabilityService.isServerReachable(address: filer.serverAddress)
                
                if isReachable && mountPaths[filer.id] == nil {
                    guard let url = URL(string: filer.serverAddress) else { continue }
                    logger.info("Automounting \(filer.name)")
                    
                    if let path = await MountService.mount(url: url) {
                         self.mountPaths[filer.id] = path
                    } else {
                        logger.warning("Automount failed for \(filer.name)")
                    }
                }
                
                busyFilers.remove(filer.id)
            }
        }
    }
    
    // MARK: - Logic: Refresh State
    
    func refreshState() async {
        let currentFilers = self.filers
        
        // Offload heavy matching/checking to background thread
        let newPaths = await Task.detached {
            return await FilerManager.detectMounts(filers: currentFilers)
        }.value
        
        if self.mountPaths != newPaths {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.mountPaths = newPaths
            }
        }
    }
    
    /// Pure logic static function to be safe in Task.detached
    nonisolated private static func detectMounts(filers: [Filer]) async -> [UUID: String] {
        let systemMounts = SystemMountService.getSystemMounts()
        var results: [UUID: String] = [:]
        
        // Parallel liveness checks
        await withTaskGroup(of: (UUID, String?).self) { group in
            for filer in filers {
                group.addTask {
                    if let path = SystemMountService.findMountPath(for: filer, in: systemMounts) {
                        // Crucial Zombie Check
                        if ReachabilityService.isMountPointAlive(path: path) {
                            return (filer.id, path)
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
    
    // MARK: - User Actions
    
    func mount(_ filer: Filer) {
        guard let url = URL(string: filer.serverAddress) else { return }
        busyFilers.insert(filer.id)
        
        Task {
            if let path = await MountService.mount(url: url) {
                self.mountPaths[filer.id] = path
                logger.info("Mounted \(filer.name) successfully")
            } else {
                self.lastError = "Could not connect to \(filer.name). Please check server address and keychain credentials."
                self.showError = true
            }
            self.busyFilers.remove(filer.id)
            await self.refreshState()
        }
    }
    
    func unmount(_ filer: Filer) {
        disableAutomount(for: filer)
        guard let path = mountPaths[filer.id] else { return }
        
        // Optimistic UI update
        mountPaths.removeValue(forKey: filer.id)
        busyFilers.insert(filer.id)
        
        Task {
            await MountService.unmount(path: path)
            self.busyFilers.remove(filer.id)
            await self.refreshState()
        }
    }
    
    func openInFinder(_ filer: Filer) {
        if let path = mountPaths[filer.id] { MountService.openInFinder(path: path) }
    }
    
    func openInTerminal(_ filer: Filer) {
        if let path = mountPaths[filer.id] {
            MountService.openInTerminal(path: path, with: preferredTerminal)
        }
    }
    
    // MARK: - CRUD & Preferences
    
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
            // Trigger check immediately if enabled
            if filers[idx].isAutomountEnabled {
                Task { await runAutomount() }
            }
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
