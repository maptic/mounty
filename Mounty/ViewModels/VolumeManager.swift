import Combine
import Network
import SwiftUI
import os

/// ViewModel: Orchestrates detection logic, automounting, and state management.
@MainActor
class VolumeManager: ObservableObject {

    // MARK: - UI State
    @Published var volumes: [Volume] = []
    @Published var mountPaths: [UUID: String] = [:]
    @Published var busyVolumes: Set<UUID> = []

    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .name
    @Published var sortDirection: SortDirection = .ascending
    @Published var showSearch = false

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

    // Logger is an instance property, safely isolated by @MainActor.
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
        self.volumes = storage.loadVolumes()
        self.preferredTerminal = storage.loadTerminalBundleID()

        setupPipelines()
        refreshInstalledTerminals()

        Task {
            await refreshState()
            await runAutomount()
        }
    }

    // MARK: - Computed Properties

    var filteredAndSortedVolumes: [Volume] {
        let filtered = volumes.filter {
            searchText.isEmpty
                ? true : $0.name.localizedCaseInsensitiveContains(searchText)
        }

        let sorted = filtered.sorted {
            let comparisonResult: ComparisonResult
            switch sortOrder {
            case .name:
                comparisonResult = $0.name.localizedStandardCompare($1.name)
            case .dateAdded:
                comparisonResult = $0.dateAdded.compare($1.dateAdded)
            }
            return sortDirection == .ascending
                ? (comparisonResult == .orderedAscending)
                : (comparisonResult == .orderedDescending)
        }
        return sorted
    }

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case dateAdded = "Date Added"
    }

    enum SortDirection {
        case ascending, descending
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
                    self.logger.info(
                        "Global Network Changed: \(self.isNetworkUp ? "UP" : "DOWN")"
                    )
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
                // Using 'self?' ensures safe access inside the closure
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

        // 4. Heartbeat (less frequent now)
        Timer.publish(every: 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in Task { await self?.refreshState() } }
            .store(in: &cancellables)
    }

    // MARK: - Logic

    private func runAutomount() async {
        guard isNetworkUp else { return }

        for volume in volumes where volume.isAutomountEnabled {
            if mountPaths[volume.id] == nil && !busyVolumes.contains(volume.id)
            {
                busyVolumes.insert(volume.id)
                let isReachable = await ReachabilityService.isServerReachable(
                    address: volume.serverAddress
                )
                if isReachable && mountPaths[volume.id] == nil {
                    guard let url = URL(string: volume.serverAddress) else {
                        continue
                    }
                    logger.info(
                        "Automounting volume: \(volume.name, privacy: .public)"
                    )
                    if let path = await MountService.mount(url: url) {
                        self.mountPaths[volume.id] = path
                    }
                }
                busyVolumes.remove(volume.id)
            }
        }
    }

    func refreshState() async {
        let currentVolumes = self.volumes
        let networkAvailable = self.isNetworkUp

        let newPaths = await Task.detached {
            return await VolumeManager.detectMounts(
                volumes: currentVolumes,
                isNetworkUp: networkAvailable
            )
        }.value

        if self.mountPaths != newPaths {
            withAnimation(.easeInOut) { self.mountPaths = newPaths }
        }
    }

    nonisolated private static func detectMounts(
        volumes: [Volume],
        isNetworkUp: Bool
    ) async -> [UUID: String] {
        if !isNetworkUp { return [:] }

        let systemMounts = SystemMountService.getSystemMounts()
        var results: [UUID: String] = [:]

        await withTaskGroup(of: (UUID, String?).self) { group in
            for volume in volumes {
                group.addTask {
                    if let path = SystemMountService.findMountPath(
                        for: volume,
                        in: systemMounts
                    ) {
                        if await ReachabilityService.isServerReachable(
                            address: volume.serverAddress
                        ) {
                            if ReachabilityService.isMountPointAlive(path: path)
                            {
                                return (volume.id, path)
                            }
                        }
                    }
                    return (volume.id, nil)
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

    func mount(_ volume: Volume) {
        guard let url = URL(string: volume.serverAddress) else { return }
        busyVolumes.insert(volume.id)

        Task {
            if let path = await MountService.mount(url: url) {
                self.mountPaths[volume.id] = path
                logger.info(
                    "Manually mounted volume: \(volume.name, privacy: .public)"
                )
            } else {
                self.lastError = "Connection failed."
                self.showError = true
            }
            self.busyVolumes.remove(volume.id)
            await self.refreshState()
        }
    }

    func unmount(_ volume: Volume) {
        disableAutomount(for: volume)
        guard let path = mountPaths[volume.id] else { return }

        mountPaths.removeValue(forKey: volume.id)
        busyVolumes.insert(volume.id)

        Task {
            await MountService.unmount(path: path)
            self.busyVolumes.remove(volume.id)
            await self.refreshState()
        }
    }

    func openInFinder(_ volume: Volume) {
        if let path = mountPaths[volume.id] {
            MountService.openInFinder(path: path)
        }
    }

    func openInTerminal(_ volume: Volume) {
        if let path = mountPaths[volume.id] {
            MountService.openInTerminal(path: path, with: preferredTerminal)
        }
    }

    // MARK: - Persistence

    func addVolume(_ volume: Volume) {
        volumes.append(volume)
        storage.saveVolumes(volumes)
        Task { await refreshState() }
    }

    func removeVolume(_ id: UUID) {
        volumes.removeAll { $0.id == id }
        storage.saveVolumes(volumes)
        Task { await refreshState() }
    }

    func clearAllVolumes() {
        volumes.removeAll()
        storage.saveVolumes(volumes)
        Task { await refreshState() }
    }

    func importVolumes(from data: Data) throws {
        let importedVolumes = try JSONDecoder().decode(
            [Volume].self,
            from: data
        )
        for volume in importedVolumes {
            if !volumes.contains(where: {
                $0.serverAddress == volume.serverAddress
            }) {
                volumes.append(volume)
            }
        }
        storage.saveVolumes(volumes)
    }

    func toggleAutomount(_ id: UUID) {
        if let idx = volumes.firstIndex(where: { $0.id == id }) {
            volumes[idx].isAutomountEnabled.toggle()
            storage.saveVolumes(volumes)
            if volumes[idx].isAutomountEnabled { Task { await runAutomount() } }
        }
    }

    private func disableAutomount(for volume: Volume) {
        if let idx = volumes.firstIndex(where: { $0.id == volume.id }) {
            volumes[idx].isAutomountEnabled = false
            storage.saveVolumes(volumes)
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
