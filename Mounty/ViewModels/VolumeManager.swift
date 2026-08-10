import Network
import SwiftUI

/// ViewModel: Orchestrates detection logic, automounting, state management, and data persistence.
@MainActor
@Observable
final class VolumeManager {

    // MARK: - UI State
    var volumes: [Volume] = []
    var mountPaths: [UUID: String] = [:]
    var busyVolumes: Set<UUID> = []
    private(set) var isClearingVolumes = false

    // UI Controls
    var searchText = ""
    var sortOrder: SortOrder = .name
    var sortDirection: SortDirection = .ascending
    var showSearch = false

    // Preferences
    var launchAtLogin = false
    var preferredTerminal: String
    var availableTerminals: [(name: String, id: String)] = []

    // Feedback & Errors
    var lastError: String?
    var showError = false
    var successMessage: String?
    var showSuccess = false

    // In-app log buffer (capped at maxLogEntries)
    var logEntries: [LogEntry] = []
    var minimumLogLevel: LogEntry.Level

    // Speed test state
    var speedTestVolumeId: UUID?
    var isRunningSpeedTest = false
    var speedTestResult: SpeedTestService.Result?
    var speedTestError: String?

    private var isNetworkUp = true
    private let maxLogEntries = 200

    // Dependencies
    private let storage = PersistenceService()
    private let eventMonitor = EventMonitorService()

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
        self.minimumLogLevel = storage.loadMinimumLogLevel()

        startLogObservation()
        startEventObservation()
        refreshInstalledTerminals()
        refreshLoginItemStatus()

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
        return filtered.sorted { lhs, rhs in
            switch sortOrder {
            case .name:
                let cmp = lhs.name.localizedStandardCompare(rhs.name)
                return sortDirection == .ascending
                    ? cmp == .orderedAscending : cmp == .orderedDescending
            case .dateAdded:
                let cmp = lhs.dateAdded.compare(rhs.dateAdded)
                return sortDirection == .ascending
                    ? cmp == .orderedAscending : cmp == .orderedDescending
            case .state:
                let lp = statePriority(lhs), rp = statePriority(rhs)
                if lp != rp {
                    return sortDirection == .ascending ? lp < rp : lp > rp
                }
                let cmp = lhs.name.localizedStandardCompare(rhs.name)
                return sortDirection == .ascending
                    ? cmp == .orderedAscending : cmp == .orderedDescending
            }
        }
    }

    private func statePriority(_ volume: Volume) -> Int {
        if mountPaths[volume.id] != nil { return 0 }
        if busyVolumes.contains(volume.id) { return 1 }
        return 2
    }

    var speedTestVolumeName: String {
        volumes.first { $0.id == speedTestVolumeId }?.name ?? "Volume"
    }

    var hasActiveVolumeOperations: Bool {
        isClearingVolumes || !busyVolumes.isEmpty || isRunningSpeedTest
    }

    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case dateAdded = "Date Added"
        case state = "State"
    }

    enum SortDirection {
        case ascending, descending
    }

    // MARK: - Logging

    private func log(_ message: String, level: LogEntry.Level = .info) {
        AppLogger.log(message, level: level, source: .manager)
    }

    private func startLogObservation() {
        Task { [weak self] in
            for await entry in AppLogger.entries {
                guard let self else { break }
                logEntries.append(entry)
                if logEntries.count > maxLogEntries {
                    logEntries.removeFirst(logEntries.count - maxLogEntries)
                }
            }
        }
    }

    func clearLogs() {
        logEntries.removeAll()
        AppLogger.clearHistory()
    }

    func setMinimumLogLevel(_ level: LogEntry.Level) {
        minimumLogLevel = level
        storage.saveMinimumLogLevel(level)
    }

    // MARK: - Speed Test

    func runSpeedTest(for volume: Volume) {
        guard !isClearingVolumes, !busyVolumes.contains(volume.id), !isRunningSpeedTest else {
            return
        }
        guard let path = mountPaths[volume.id] else { return }
        speedTestVolumeId = volume.id
        isRunningSpeedTest = true
        speedTestResult = nil
        speedTestError = nil
        let volumeID = volume.id
        let volumeName = volume.name

        Task.detached(priority: .userInitiated) { [weak self] in
            AppLogger.log(
                "Speed test started for \(volumeName)",
                source: .manager
            )
            do {
                let result = try await SpeedTestService.measure(at: path)
                AppLogger.log(
                    "Speed test (\(volumeName)): "
                        + "write \(String(format: "%.1f", result.writeSpeed)) MB/s, "
                        + "read \(String(format: "%.1f", result.readSpeed)) MB/s",
                    source: .manager
                )
                await MainActor.run {
                    guard self?.speedTestVolumeId == volumeID else { return }
                    self?.speedTestResult = result
                    self?.isRunningSpeedTest = false
                }
            } catch {
                let message = error.localizedDescription
                AppLogger.log(
                    "Speed test failed for \(volumeName): \(message)",
                    level: .error,
                    source: .manager
                )
                await MainActor.run {
                    guard self?.speedTestVolumeId == volumeID else { return }
                    self?.speedTestError = message
                    self?.isRunningSpeedTest = false
                }
            }
        }
    }

    func clearSpeedTest() {
        speedTestVolumeId = nil
        speedTestResult = nil
        speedTestError = nil
    }

    // MARK: - Event Observation

    private func startEventObservation() {
        // The observer tasks inherit MainActor and release it at each `for await` suspension.
        // Services move kernel, network, and filesystem work off the actor.

        // 1. Network Status — high-priority reaction
        let networkStatusStream = eventMonitor.networkStatusStream
        Task { [weak self] in
            for await status in networkStatusStream {
                guard let self else { break }
                let wasUp = isNetworkUp
                isNetworkUp = (status == .satisfied)
                if isNetworkUp != wasUp {
                    log("Network: \(isNetworkUp ? "UP" : "DOWN")")
                }
                await refreshState()
                if isNetworkUp { await runAutomount() }
            }
        }

        // 2. Interface changes (VPN) — debounce applied in EventMonitorService
        let interfacesChangedStream = eventMonitor.interfacesChangedStream
        Task { [weak self] in
            for await _ in interfacesChangedStream {
                guard let self else { break }
                log("Network interface changed — retrying connections")
                await refreshState()
                await runAutomount()
            }
        }

        // 3. File system (manual mounts by other apps)
        let fileSystemChangedStream = eventMonitor.fileSystemChangedStream
        Task { [weak self] in
            for await _ in fileSystemChangedStream {
                guard let self else { break }
                await refreshState()
            }
        }

        // 4. Heartbeat (silent death check, every 5 s)
        // Task.sleep is RunLoop-independent and does not interact with event-tracking
        // modes — it fires from the cooperative thread pool after the sleep interval.
        Task(priority: .utility) { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                guard let self else { break }
                guard isNetworkUp else { continue }
                await refreshState()
                await runAutomount()
            }
        }
    }

    // MARK: - Logic

    private func runAutomount() async {
        guard isNetworkUp, !isClearingVolumes else { return }

        let candidates = volumes.filter {
            $0.isAutomountEnabled && mountPaths[$0.id] == nil && !busyVolumes.contains($0.id)
        }
        guard !candidates.isEmpty else { return }
        log(
            "Automount: \(candidates.count) candidate(s) — \(candidates.map(\.name).joined(separator: ", "))",
            level: .debug
        )
        for v in candidates { busyVolumes.insert(v.id) }

        let reachableIDs = await withTaskGroup(of: (UUID, Bool).self) { group in
            for volume in candidates {
                let id = volume.id
                group.addTask {
                    let reachable = await ReachabilityService.isServerReachable(
                        address: volume.serverAddress
                    )
                    return (id, reachable)
                }
            }

            var ids = Set<UUID>()
            for await (id, reachable) in group where reachable {
                ids.insert(id)
            }
            return ids
        }

        // Multiple simultaneous NetFS authentication sessions can interfere with one another,
        // so only the inexpensive TCP probes are parallelized. Mount requests run one at a time.
        for volume in candidates {
            defer { busyVolumes.remove(volume.id) }

            guard reachableIDs.contains(volume.id) else {
                log("Automount skipped: \(volume.name); SMB port 445 is unreachable", level: .info)
                continue
            }
            guard let url = URL(string: volume.serverAddress) else {
                log("Automount skipped: \(volume.name); invalid server URL", level: .error)
                continue
            }

            let result = await MountService.mount(url: url)
            if let path = result.path {
                mountPaths[volume.id] = path
                log("Automounted: \(volume.name) → \(path)")
            } else {
                log(
                    "Automount failed: \(volume.name); \(result.debugDescription)",
                    level: .warning
                )
            }
        }
    }

    func refreshState() async {
        let currentVolumes = self.volumes
        let networkAvailable = self.isNetworkUp
        let prevPaths = self.mountPaths

        let newPaths = await Task.detached {
            await VolumeManager.detectMounts(
                volumes: currentVolumes,
                isNetworkUp: networkAvailable
            )
        }.value

        // Log volumes that disappeared from the kernel mount table since last check.
        for (id, _) in prevPaths where newPaths[id] == nil {
            let name = currentVolumes.first(where: { $0.id == id })?.name ?? id.uuidString
            log("Lost connection: \(name)")
        }

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
                    guard
                        let path = SystemMountService.findMountPath(
                            for: volume,
                            in: systemMounts
                        )
                    else { return (volume.id, nil) }
                    guard
                        await ReachabilityService.isServerReachable(
                            address: volume.serverAddress
                        )
                    else { return (volume.id, nil) }
                    guard await ReachabilityService.isMountPointAlive(path: path) else {
                        return (volume.id, nil)
                    }
                    return (volume.id, path)
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

    private func refreshLoginItemStatus() {
        Task.detached(priority: .utility) { [weak self] in
            let isEnabled = MountService.isLoginItemEnabled()
            await MainActor.run { self?.launchAtLogin = isEnabled }
        }
    }

    func mount(_ volume: Volume) {
        guard !isClearingVolumes, !busyVolumes.contains(volume.id) else { return }
        guard let url = URL(string: volume.serverAddress) else { return }
        busyVolumes.insert(volume.id)
        log("Connecting \(volume.name)…")

        Task {
            // Fail fast: surface an unreachable server immediately rather than
            // burning 90 s on a NetFS call that will never complete.
            let reachable = await ReachabilityService.isServerReachable(
                address: volume.serverAddress
            )
            guard reachable else {
                let host = URL(string: volume.serverAddress)?.host ?? "unknown-host"
                log(
                    "SMB probe failed: \(volume.name); host=\(host); port=445",
                    level: .debug
                )
                self.lastError = "Cannot reach \(volume.name). Check network and VPN."
                self.showError = true
                self.log("Not reachable: \(volume.name)", level: .error)
                self.busyVolumes.remove(volume.id)
                return
            }

            let result = await MountService.mount(url: url)
            log("NetFS: \(volume.name) — \(result.debugDescription)", level: .debug)

            switch result {
            case .success(let path):
                self.mountPaths[volume.id] = path
                self.log("Connected: \(volume.name) → \(path)")
            case .failed(let code):
                self.lastError =
                    "Connection failed for \(volume.name) (error \(code))."
                self.showError = true
                self.log(
                    "Failed: \(volume.name); \(result.debugDescription)",
                    level: .error
                )
            }
            self.busyVolumes.remove(volume.id)
            await self.refreshState()
        }
    }

    func unmount(_ volume: Volume) {
        guard !isClearingVolumes, !busyVolumes.contains(volume.id) else { return }
        disableAutomount(for: volume)
        guard let path = mountPaths[volume.id] else { return }

        busyVolumes.insert(volume.id)
        log("Disconnecting \(volume.name)")

        Task {
            guard await MountService.unmount(path: path) else {
                self.reportUnmountFailure(for: volume, action: "Disconnect")
                await self.refreshState()
                return
            }
            self.mountPaths.removeValue(forKey: volume.id)
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
        guard !isClearingVolumes else { return }
        volumes.append(volume)
        storage.saveVolumes(volumes)
        log("Added volume: \(volume.name)")
        Task { await refreshState() }
    }

    func removeVolume(_ id: UUID) {
        guard !isClearingVolumes, !busyVolumes.contains(id) else { return }
        guard speedTestVolumeId != id || !isRunningSpeedTest else { return }
        guard let volume = volumes.first(where: { $0.id == id }) else { return }
        guard let path = mountPaths[id] else {
            removeVolumeConfiguration(id: id, name: volume.name)
            Task { await refreshState() }
            return
        }

        busyVolumes.insert(id)
        log("Removing volume: \(volume.name)")
        Task {
            guard await MountService.unmount(path: path) else {
                self.reportUnmountFailure(for: volume, action: "Remove")
                await self.refreshState()
                return
            }
            self.mountPaths.removeValue(forKey: id)
            self.busyVolumes.remove(id)
            self.removeVolumeConfiguration(id: id, name: volume.name)
            await self.refreshState()
        }
    }

    func editVolume(id: UUID, name: String, serverAddress: String) {
        guard !isClearingVolumes, !busyVolumes.contains(id) else { return }
        guard speedTestVolumeId != id || !isRunningSpeedTest else { return }
        guard let idx = volumes.firstIndex(where: { $0.id == id }) else { return }
        let old = volumes[idx]
        let addressChanged = old.serverAddress != serverAddress

        if !addressChanged {
            volumes[idx].name = name
            storage.saveVolumes(volumes)
            log("Updated volume: \(name)")
            return
        }

        guard let oldPath = mountPaths[id] else {
            volumes[idx].name = name
            volumes[idx].serverAddress = serverAddress
            storage.saveVolumes(volumes)
            log("Updated volume: \(name)")
            return
        }

        // Unmount the old connection by its recorded path, then remount at the new address.
        // Using oldPath (not the new address) ensures we disconnect the right kernel mount
        // even if the new address points to a different share entirely.
        busyVolumes.insert(id)
        Task {
            guard await MountService.unmount(path: oldPath) else {
                self.reportUnmountFailure(for: old, action: "Reconnect")
                await self.refreshState()
                return
            }
            self.mountPaths.removeValue(forKey: id)
            guard let currentIndex = self.volumes.firstIndex(where: { $0.id == id }) else {
                self.busyVolumes.remove(id)
                return
            }
            self.volumes[currentIndex].name = name
            self.volumes[currentIndex].serverAddress = serverAddress
            self.storage.saveVolumes(self.volumes)
            self.log("Updated volume: \(name)")
            guard let url = URL(string: serverAddress) else {
                self.busyVolumes.remove(id)
                return
            }
            let result = await MountService.mount(url: url)
            self.log("Reconnect: \(name) — \(result.debugDescription)", level: .debug)
            if let newPath = result.path {
                self.mountPaths[id] = newPath
                self.log("Reconnected \(name) → \(newPath)")
            } else {
                self.log("Reconnect failed after edit: \(name)", level: .error)
                self.lastError = "Reconnect failed. Verify address and credentials."
                self.showError = true
            }
            self.busyVolumes.remove(id)
            await self.refreshState()
        }
    }

    func clearAllVolumes() {
        guard !hasActiveVolumeOperations else {
            lastError = "Wait for active volume operations to finish before clearing."
            showError = true
            return
        }

        isClearingVolumes = true
        let configuredVolumes = volumes
        let configuredIDs = Set(configuredVolumes.map(\.id))
        let mountedVolumes = configuredVolumes.compactMap { volume in
            mountPaths[volume.id].map { (volume, $0) }
        }
        for (volume, _) in mountedVolumes { busyVolumes.insert(volume.id) }

        Task {
            defer { self.isClearingVolumes = false }
            var retainedIDs = Set<UUID>()
            for (volume, path) in mountedVolumes {
                guard await MountService.unmount(path: path) else {
                    retainedIDs.insert(volume.id)
                    self.reportUnmountFailure(for: volume, action: "Clear")
                    continue
                }
                self.mountPaths.removeValue(forKey: volume.id)
                self.busyVolumes.remove(volume.id)
            }
            self.volumes.removeAll {
                configuredIDs.contains($0.id) && !retainedIDs.contains($0.id)
            }
            self.storage.saveVolumes(self.volumes)
            if retainedIDs.isEmpty {
                self.log("Cleared all volumes")
            } else {
                self.log("Clear retained \(retainedIDs.count) mounted volume(s)", level: .warning)
            }
            await self.refreshState()
        }
    }

    private func removeVolumeConfiguration(id: UUID, name: String) {
        volumes.removeAll { $0.id == id }
        storage.saveVolumes(volumes)
        log("Removed volume: \(name)")
    }

    private func reportUnmountFailure(for volume: Volume, action: String) {
        busyVolumes.remove(volume.id)
        lastError = "Could not disconnect \(volume.name). The share remains mounted."
        showError = true
        log("\(action) failed; \(volume.name) remains mounted", level: .error)
    }

    func toggleAutomount(_ id: UUID) {
        guard !isClearingVolumes, !busyVolumes.contains(id) else { return }
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
            // Rebind as 'let' so MainActor.run captures a constant, not the
            // 'var' weak-optional 'self' — fixes the Swift 6 concurrency warning.
            let ref = self
            await MainActor.run { ref?.launchAtLogin = isEnabled }
        }
    }

    func setPreferredTerminal(_ bundleID: String) {
        preferredTerminal = bundleID
        storage.saveTerminalBundleID(bundleID)
    }

    // MARK: - Import / Export

    func importVolumes(fromURL url: URL) {
        // Data(contentsOf:) is synchronous blocking I/O — run it off the main actor.
        Task {
            do {
                let data = try await Task.detached(priority: .utility) {
                    try Data(contentsOf: url)
                }.value
                let importedVolumes = try JSONDecoder().decode([Volume].self, from: data)
                let result = VolumeConfigurationService.merging(
                    importedVolumes,
                    into: self.volumes
                )
                self.volumes = result.volumes
                self.storage.saveVolumes(self.volumes)
                await self.refreshState()
                self.log("Imported \(result.importedCount) volume(s) from backup")
                self.successMessage = "Imported \(result.importedCount) volumes successfully."
                self.showSuccess = true
            } catch {
                self.log("Import failed: \(error.localizedDescription)", level: .error)
                self.lastError = "Could not import: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }

    func exportToURL(_ url: URL) {
        let snapshot = volumes
        // data.write(to:) is synchronous blocking I/O — run it off the main actor.
        Task {
            do {
                let data = try JSONEncoder().encode(snapshot)
                try await Task.detached(priority: .utility) {
                    try data.write(to: url)
                }.value
                self.log("Exported \(snapshot.count) volume(s)")
                self.successMessage = "Backup saved successfully."
                self.showSuccess = true
            } catch {
                self.log("Export failed: \(error.localizedDescription)", level: .error)
                self.lastError = "Export failed: \(error.localizedDescription)"
                self.showError = true
            }
        }
    }
}
