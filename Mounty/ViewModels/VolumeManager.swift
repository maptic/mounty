import Combine
import Network
import SwiftUI
import UniformTypeIdentifiers
import os

/// ViewModel: Orchestrates detection logic, automounting, state management, and data persistence.
@MainActor
class VolumeManager: ObservableObject {

    // MARK: - UI State
    @Published var volumes: [Volume] = []
    @Published var mountPaths: [UUID: String] = [:]
    @Published var busyVolumes: Set<UUID> = []

    // UI Controls
    @Published var searchText = ""
    @Published var sortOrder: SortOrder = .name
    @Published var sortDirection: SortDirection = .ascending
    @Published var showSearch = false

    // Preferences
    @Published var launchAtLogin: Bool = MountService.isLoginItemEnabled()
    @Published var preferredTerminal: String
    @Published var availableTerminals: [(name: String, id: String)] = []

    // Feedback & Errors
    @Published var lastError: String? = nil
    @Published var showError: Bool = false
    @Published var successMessage: String? = nil
    @Published var showSuccess: Bool = false

    private var isNetworkUp: Bool = true

    // Dependencies
    private let storage = PersistenceService()
    private let eventMonitor = EventMonitorService()
    private var cancellables = Set<AnyCancellable>()

    // Logger
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
        // 1. Network Status (Reachability) - High Priority Reaction
        eventMonitor.networkStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }

                // Update internal state
                let wasUp = self.isNetworkUp
                self.isNetworkUp = (status == .satisfied)

                if self.isNetworkUp != wasUp {
                    self.logger.info(
                        "Global Network Changed: \(self.isNetworkUp ? "UP" : "DOWN")"
                    )
                }

                // Trigger refresh immediately on ANY status update.
                // Priority: .userInitiated (High) for responsiveness.
                Task(priority: .userInitiated) {
                    await self.refreshState()
                    if self.isNetworkUp { await self.runAutomount() }
                }
            }
            .store(in: &cancellables)

        // 2. Interfaces Changed (VPN Toggles) - High Priority Reaction
        eventMonitor.interfacesChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                self?.logger.info(
                    "Interface topology changed. Retrying connections."
                )
                // Priority: .userInitiated (High) to catch VPNs quickly
                Task(priority: .userInitiated) {
                    await self?.refreshState()
                    await self?.runAutomount()
                }
            }
            .store(in: &cancellables)

        // 3. File System (Manual Mounts)
        eventMonitor.fileSystemChanged
            .receive(on: RunLoop.main)
            .sink { [weak self] in
                Task(priority: .utility) { await self?.refreshState() }
            }
            .store(in: &cancellables)

        // 4. Heartbeat Timer (Silent Death Check)
        // Interval: 5s (Snappy)
        // Optimization: Gated by Network Status & Lower QoS
        // .default mode (not .common) so the timer does not fire during UI event tracking.
        Timer.publish(every: 5, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isNetworkUp else { return }
                // Priority: .utility (Low/Efficiency).
                // This allows the OS to use E-Cores, saving battery for routine checks.
                Task(priority: .utility) { await self.refreshState() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Logic

    private func runAutomount() async {
        guard isNetworkUp else { return }

        for volume in volumes where volume.isAutomountEnabled {
            // Check if not mounted AND not currently processing
            if mountPaths[volume.id] == nil && !busyVolumes.contains(volume.id) {
                busyVolumes.insert(volume.id)

                let isReachable = await ReachabilityService.isServerReachable(
                    address: volume.serverAddress
                )

                // Double-check mountPaths after reachability (async race protection)
                if isReachable && mountPaths[volume.id] == nil {
                    guard let url = URL(string: volume.serverAddress) else {
                        busyVolumes.remove(volume.id)
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

        // Run detection.
        // NOTE: Task inherits priority from the caller.
        // Events call this with .userInitiated (Fast).
        // Timer calls this with .utility (Efficient).
        let newPaths = await Task.detached {
            return await VolumeManager.detectMounts(
                volumes: currentVolumes,
                isNetworkUp: networkAvailable
            )
        }.value

        // Plain assignment — no withAnimation here. Background-triggered state
        // changes must not inject an animation transaction that could delay
        // visual feedback for concurrent user interactions (button presses, etc.).
        // Mount-state icon transitions are animated locally in VolumeRow instead.
        if self.mountPaths != newPaths {
            self.mountPaths = newPaths
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
                        // 1. TCP Reachability (Fastest fail for dropped VPNs)
                        // Note: This only runs for volumes that appear to be mounted.
                        // It does not waste battery pinging unmounted servers.
                        if await ReachabilityService.isServerReachable(
                            address: volume.serverAddress
                        ) {
                            // 2. IO Reachability (Catches hung kernel mounts)
                            if await ReachabilityService.isMountPointAlive(path: path) {
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
                self.lastError =
                    "Connection failed. Verify address and keychain credentials."
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

    // MARK: - Import / Export Logic

    func importVolumes(fromPath pathString: String) {
        let expandedPath = (pathString as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: expandedPath)

        // Data(contentsOf:) is synchronous blocking I/O — run it off the main actor.
        Task {
            do {
                let data = try await Task.detached(priority: .utility) {
                    try Data(contentsOf: url)
                }.value
                let importedVolumes = try JSONDecoder().decode([Volume].self, from: data)
                var count = 0
                for volume in importedVolumes {
                    if !self.volumes.contains(where: {
                        $0.serverAddress == volume.serverAddress
                    }) {
                        self.volumes.append(volume)
                        count += 1
                    }
                }
                self.storage.saveVolumes(self.volumes)
                await self.refreshState()
                self.successMessage = "Imported \(count) volumes successfully."
                self.showSuccess = true
            } catch {
                self.lastError = "Could not import: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    func exportToDownloads() {
        let snapshot = volumes
        // data.write(to:) is synchronous blocking I/O — run it off the main actor.
        Task {
            do {
                let downloadsURL = try FileManager.default.url(
                    for: .downloadsDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: false
                )
                let fileURL = downloadsURL.appendingPathComponent("MountyBackup.json")
                let data = try JSONEncoder().encode(snapshot)
                try await Task.detached(priority: .utility) {
                    try data.write(to: fileURL)
                }.value
                self.successMessage = "Backup saved to Downloads."
                self.showSuccess = true
            } catch {
                self.lastError = "Export failed: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
}
