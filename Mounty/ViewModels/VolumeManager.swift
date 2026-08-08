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

    // In-app log buffer (capped at maxLogEntries)
    @Published var logEntries: [LogEntry] = []

    // Speed test state
    @Published var speedTestVolumeId: UUID? = nil
    @Published var isRunningSpeedTest = false
    @Published var speedTestResult: SpeedTestService.Result? = nil
    @Published var speedTestError: String? = nil

    private var isNetworkUp: Bool = true
    private let maxLogEntries = 200

    // Dependencies
    private let storage = PersistenceService()
    private let eventMonitor = EventMonitorService()
    private var cancellables = Set<AnyCancellable>()

    // Logger (os.Logger for Console.app; log() also feeds the in-app ring buffer)
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

    var speedTestVolumeName: String {
        volumes.first { $0.id == speedTestVolumeId }?.name ?? "Volume"
    }

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case dateAdded = "Date Added"
    }

    enum SortDirection {
        case ascending, descending
    }

    // MARK: - Logging

    private func log(_ message: String, level: LogEntry.Level = .info) {
        switch level {
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
        logEntries.append(LogEntry(timestamp: Date(), level: level, message: message))
        if logEntries.count > maxLogEntries { logEntries.removeFirst() }
    }

    func clearLogs() {
        logEntries.removeAll()
    }

    // MARK: - Speed Test

    func runSpeedTest(for volume: Volume) {
        guard let path = mountPaths[volume.id] else { return }
        speedTestVolumeId = volume.id
        isRunningSpeedTest = true
        speedTestResult = nil
        speedTestError = nil
        log("Speed test started for \(volume.name)")

        Task {
            do {
                let result = try await SpeedTestService.measure(at: path)
                self.speedTestResult = result
                self.log(
                    "Speed test (\(volume.name)): "
                        + "write \(String(format: "%.1f", result.writeSpeed)) MB/s, "
                        + "read \(String(format: "%.1f", result.readSpeed)) MB/s"
                )
            } catch {
                self.speedTestError = error.localizedDescription
                self.log(
                    "Speed test failed for \(volume.name): \(error.localizedDescription)",
                    level: .error
                )
            }
            self.isRunningSpeedTest = false
        }
    }

    func clearSpeedTest() {
        speedTestVolumeId = nil
        speedTestResult = nil
        speedTestError = nil
    }

    // MARK: - Event Pipelines

    private func setupPipelines() {
        // 1. Network Status (Reachability) - High Priority Reaction
        eventMonitor.networkStatus
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                guard let self else { return }

                let wasUp = self.isNetworkUp
                self.isNetworkUp = (status == .satisfied)

                if self.isNetworkUp != wasUp {
                    self.log("Network: \(self.isNetworkUp ? "UP" : "DOWN")")
                }

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
                self?.log("Network interface changed — retrying connections")
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
        // .default mode (not .common) so the timer does not fire during UI event tracking.
        Timer.publish(every: 5, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isNetworkUp else { return }
                Task(priority: .utility) { await self.refreshState() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Logic

    private func runAutomount() async {
        guard isNetworkUp else { return }

        let candidates = volumes.filter {
            $0.isAutomountEnabled && mountPaths[$0.id] == nil && !busyVolumes.contains($0.id)
        }
        guard !candidates.isEmpty else { return }
        for v in candidates { busyVolumes.insert(v.id) }

        await withTaskGroup(of: (UUID, String?, String).self) { group in
            for volume in candidates {
                guard let url = URL(string: volume.serverAddress) else {
                    busyVolumes.remove(volume.id)
                    continue
                }
                let addr = volume.serverAddress
                let name = volume.name
                let id = volume.id
                group.addTask {
                    let isReachable = await ReachabilityService.isServerReachable(address: addr)
                    guard isReachable else { return (id, nil, name) }
                    return (id, await MountService.mount(url: url), name)
                }
            }

            for await (id, path, name) in group {
                if let path {
                    self.mountPaths[id] = path
                    log("Automounted \(name) → \(path)")
                } else {
                    log("Automount failed for \(name)", level: .warning)
                }
                busyVolumes.remove(id)
            }
        }
    }

    func refreshState() async {
        let currentVolumes = self.volumes
        let networkAvailable = self.isNetworkUp

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

    // Runs the 6 NSWorkspace lookups off the main actor so the first UI frame
    // is never blocked by Launch Services queries.
    // Task.detached is required here — Task(priority:) inherits @MainActor and
    // would run the synchronous lookups on the main thread.
    private func refreshInstalledTerminals() {
        let known = knownTerminals
        Task.detached(priority: .utility) { [weak self] in
            let installed = known.filter { (_, bundleID) in
                NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.availableTerminals = installed
                if !self.availableTerminals.contains(where: { $0.id == self.preferredTerminal }) {
                    self.preferredTerminal = "com.apple.Terminal"
                }
            }
        }
    }

    func mount(_ volume: Volume) {
        guard let url = URL(string: volume.serverAddress) else { return }
        busyVolumes.insert(volume.id)
        log("Connecting \(volume.name)…")

        Task {
            if let path = await MountService.mount(url: url) {
                self.mountPaths[volume.id] = path
                self.log("Connected: \(volume.name) → \(path)")
            } else {
                self.lastError =
                    "Connection failed. Verify address and keychain credentials."
                self.showError = true
                self.log("Connection failed: \(volume.name)", level: .error)
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
        log("Disconnecting \(volume.name)")

        Task {
            await MountService.unmount(path: path)
            self.busyVolumes.remove(volume.id)
            self.log("Disconnected: \(volume.name)")
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
        log("Added volume: \(volume.name)")
        Task { await refreshState() }
    }

    func removeVolume(_ id: UUID) {
        if let v = volumes.first(where: { $0.id == id }) {
            log("Removed volume: \(v.name)")
        }
        volumes.removeAll { $0.id == id }
        storage.saveVolumes(volumes)
        Task { await refreshState() }
    }

    func clearAllVolumes() {
        log("Cleared all volumes")
        volumes.removeAll()
        storage.saveVolumes(volumes)
        Task { await refreshState() }
    }

    func toggleAutomount(_ id: UUID) {
        if let idx = volumes.firstIndex(where: { $0.id == id }) {
            volumes[idx].isAutomountEnabled.toggle()
            storage.saveVolumes(volumes)
            let v = volumes[idx]
            log("Automount \(v.isAutomountEnabled ? "enabled" : "disabled") for \(v.name)")
            if v.isAutomountEnabled { Task { await runAutomount() } }
        }
    }

    private func disableAutomount(for volume: Volume) {
        if let idx = volumes.firstIndex(where: { $0.id == volume.id }) {
            volumes[idx].isAutomountEnabled = false
            storage.saveVolumes(volumes)
        }
    }

    func toggleLaunchAtLogin(_ enabled: Bool) {
        // SMAppService calls can be slow; run off the main actor to avoid
        // blocking the UI when the toggle is flipped in Settings.
        Task.detached(priority: .userInitiated) { [weak self] in
            MountService.toggleLoginItem(enabled: enabled)
            let isEnabled = MountService.isLoginItemEnabled()
            await MainActor.run { self?.launchAtLogin = isEnabled }
        }
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
                self.log("Imported \(count) volume(s) from backup")
                self.successMessage = "Imported \(count) volumes successfully."
                self.showSuccess = true
            } catch {
                self.log("Import failed: \(error.localizedDescription)", level: .error)
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
                self.log("Exported \(snapshot.count) volume(s) to Downloads")
                self.successMessage = "Backup saved to Downloads."
                self.showSuccess = true
            } catch {
                self.log("Export failed: \(error.localizedDescription)", level: .error)
                self.lastError = "Export failed: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
}
