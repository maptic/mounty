import Foundation
import AppKit
import ServiceManagement
import SwiftUI
import Network
import UserNotifications
import Darwin
import Combine

@MainActor
class FilerManager: ObservableObject {
    @Published var filers: [Filer] = []
    @Published var mountPaths: [UUID: String] = [:]
    @Published var pendingOperations: Set<UUID> = []
    
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet {
            // Only toggle if the state actually needs changing
            if launchAtLogin != (SMAppService.mainApp.status == .enabled) {
                toggleLaunchAtLogin()
            }
        }
    }
    
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    
    init() {
        loadFilers()
        setupNotifications()
        setupSystemObservers()
        
        // Initial fast check
        refreshMountsFast()
        
        // Smart Polling Loop (5s)
        // Checks for Zombies (VPN drops) and handles Automounts
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.runAutomountLogic()
                self.verifyMountLiveness() // Deep check for zombies
            }
        }
    }
    
    // MARK: - 1. Fast Detection (Kernel Table)
    
    func refreshMountsFast(notify: Bool = false) {
        let currentMounts = getCurrentMounts()
        var newPaths: [UUID: String] = [:]
        
        for filer in filers {
            if let match = currentMounts.first(where: { isMatch(filer: filer, mount: $0) }) {
                newPaths[filer.id] = match.path
            }
        }
        
        if newPaths != mountPaths {
            mountPaths = newPaths
        }
    }
    
    // MARK: - 2. Deep Detection & Liveness
    
    func verifyMountLiveness() {
        // Snapshot data on MainActor to avoid concurrency issues
        let filersSnapshot = self.filers
        
        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            
            let currentMounts = self.getCurrentMounts()
            var pathsFound: [UUID: String] = [:]
            
            for filer in filersSnapshot {
                if let match = currentMounts.first(where: { self.isMatch(filer: filer, mount: $0) }) {
                    let path = match.path
                    // Only keep it if it is responsive (Zombie check)
                    if self.isMountResponsive(path: path) {
                        pathsFound[filer.id] = path
                    }
                }
            }
            
            // Create immutable copy for actor transfer
            let finalVerifiedPaths = pathsFound
            
            await MainActor.run {
                if self.mountPaths != finalVerifiedPaths {
                    self.mountPaths = finalVerifiedPaths
                }
            }
        }
    }
    
    // MARK: - Terminal Logic (Sandbox Safe)
    
    func openTerminal(for filer: Filer) {
        guard let path = mountPaths[filer.id] else { return }
        
        // 1. Detect the Default Terminal App
        // We use scheme detection (ssh://) to find the user's preferred terminal (iTerm2, Terminal, Hyper, etc.)
        var appUrl = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "ssh://localhost")!)
        
        // Fallback to Apple Terminal if detection fails
        if appUrl == nil {
            appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
        }
        
        guard let targetApp = appUrl else { return }
        
        // 2. Open using Arguments (The Sandbox Fix)
        // Instead of asking NSWorkspace to open the FILE (which triggers Sandbox permission errors),
        // we ask NSWorkspace to launch the APP and pass the path as a TEXT ARGUMENT.
        // The Terminal app receives the string and opens the path itself.
        
        let config = NSWorkspace.OpenConfiguration()
        config.arguments = [path] // Pass the path as a string argument
        config.promptsUserIfNeeded = false
        
        NSWorkspace.shared.openApplication(at: targetApp, configuration: config, completionHandler: nil)
    }
    
    // MARK: - Actions: Mount & Unmount
    
    func mount(_ filer: Filer) {
        guard let url = URL(string: filer.serverAddress) else { return }
        
        // Lock UI to prevent spam
        pendingOperations.insert(filer.id)
        
        NSWorkspace.shared.open(url)
        
        // Remove lock after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.pendingOperations.remove(filer.id)
        }
    }
    
    func unmount(_ filer: Filer) {
        // 1. Disable Automount immediately on manual disconnect
        if let index = filers.firstIndex(where: { $0.id == filer.id }) {
            filers[index].isAutomountEnabled = false
            saveFilers()
        }
        
        // 2. Find path
        var targetPath = mountPaths[filer.id]
        if targetPath == nil {
            // Fallback search in kernel
            let mounts = getCurrentMounts()
            if let match = mounts.first(where: { isMatch(filer: filer, mount: $0) }) {
                targetPath = match.path
            }
        }
        
        guard let path = targetPath else { return }
        let url = URL(fileURLWithPath: path)
        
        Task {
            // Lock
            await MainActor.run { _ = self.pendingOperations.insert(filer.id) }
            defer { Task { @MainActor in self.pendingOperations.remove(filer.id) } }
            
            do {
                // Try Polite Unmount
                try await unmountSafely(at: url)
                await MainActor.run { self.refreshMountsFast() }
            } catch {
                print("Polite unmount failed. Force unmounting...")
                // Force Unmount (MNT_FORCE)
                let result = Darwin.unmount(path, MNT_FORCE)
                if result == 0 {
                    await MainActor.run { self.refreshMountsFast() }
                } else {
                    let err = String(cString: strerror(errno))
                    await MainActor.run { self.sendNotification(title: "Unmount Failed", body: err) }
                }
            }
        }
    }
    
    private func unmountSafely(at url: URL) async throws {
        try await Task.detached(priority: .userInitiated) {
            try NSWorkspace.shared.unmountAndEjectDevice(at: url)
        }.value
    }
    
    // MARK: - Automount Logic
    
    func runAutomountLogic() {
        for filer in filers where filer.isAutomountEnabled {
            // Only try if disconnected AND not currently working on it
            if mountPaths[filer.id] == nil && !pendingOperations.contains(filer.id) {
                checkConnectivityAndMount(filer)
            }
        }
    }
    
    private func checkConnectivityAndMount(_ filer: Filer) {
        guard let host = filer.host else { return }
        
        pendingOperations.insert(filer.id)
        
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            let isReachable = await self.isSMBServiceAvailable(host: host)
            
            await MainActor.run {
                self.pendingOperations.remove(filer.id)
                if isReachable {
                    if self.mountPaths[filer.id] == nil {
                        self.mount(filer)
                    }
                }
            }
        }
    }
    
    func copyPath(_ filer: Filer) {
        guard let currentPath = mountPaths[filer.id] else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(currentPath, forType: .string)
    }
    
    // MARK: - Helpers & Kernel Info
    
    nonisolated private func isMatch(filer: Filer, mount: SystemMount) -> Bool {
        guard let configUrl = URL(string: filer.serverAddress) else { return false }
        
        let configPath = configUrl.path.lowercased()
        // Check if the mount source (//user@host/share) ends with the config path (/share)
        if !configPath.isEmpty && configPath != "/" {
            if mount.source.lowercased().hasSuffix(configPath) { return true }
        }
        
        return false
    }
    
    nonisolated private func isMountResponsive(path: String) -> Bool {
        let group = DispatchGroup()
        group.enter()
        var isAlive = false
        DispatchQueue.global(qos: .background).async {
            // access() blocks on dead SMB mounts
            if access(path, F_OK) == 0 { isAlive = true }
            group.leave()
        }
        // Strict timeout to prevent beachball
        let result = group.wait(timeout: .now() + 1.5)
        return result == .success && isAlive
    }
    
    struct SystemMount { let path: String; let source: String }
    
    nonisolated private func getCurrentMounts() -> [SystemMount] {
        var mounts: [SystemMount] = []
        var mntbuf: UnsafeMutablePointer<statfs>? = nil
        let count = getmntinfo(&mntbuf, MNT_NOWAIT)
        if count > 0, let mntbuf = mntbuf {
            for i in 0..<Int(count) {
                let mnt = mntbuf[i]
                let path = withUnsafePointer(to: mnt.f_mntonname) { $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) } }
                let source = withUnsafePointer(to: mnt.f_mntfromname) { $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) } }
                mounts.append(SystemMount(path: path, source: source))
            }
        }
        return mounts
    }

    nonisolated private func isSMBServiceAvailable(host: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            let hostEP = NWEndpoint.Host(host)
            let portEP = NWEndpoint.Port(integerLiteral: 445)
            let conn = NWConnection(to: .hostPort(host: hostEP, port: portEP), using: .tcp)
            let timeout = DispatchWorkItem { if conn.state != .ready { conn.cancel(); continuation.resume(returning: false) } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0, execute: timeout)
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready: timeout.cancel(); conn.cancel(); continuation.resume(returning: true)
                case .failed(_), .cancelled: timeout.cancel()
                default: break
                }
            }
            conn.start(queue: .global())
        }
    }
    
    // MARK: - Setup & Persist
    
    private func setupSystemObservers() {
        Task {
            let center = NSWorkspace.shared.notificationCenter
            for await _ in center.notifications(named: NSWorkspace.didMountNotification) { self.refreshMountsFast(notify: true) }
        }
        Task {
            let center = NSWorkspace.shared.notificationCenter
            for await _ in center.notifications(named: NSWorkspace.didUnmountNotification) { self.refreshMountsFast(notify: true) }
        }
    }
    
    private func setupNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }
    
    func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
    
    func addFiler(_ filer: Filer) { filers.append(filer); saveFilers(); refreshMountsFast() }
    func removeFiler(id: UUID) { filers.removeAll { $0.id == id }; saveFilers() }
    func toggleAutomount(for id: UUID) {
        if let idx = filers.firstIndex(where: { $0.id == id }) { filers[idx].isAutomountEnabled.toggle(); saveFilers() }
    }
    
    private func saveFilers() { if let e = try? JSONEncoder().encode(filers) { defaults.set(e, forKey: "SavedFilers") } }
    private func loadFilers() { if let d = defaults.data(forKey: "SavedFilers"), let o = try? JSONDecoder().decode([Filer].self, from: d) { filers = o } }
    
    private func toggleLaunchAtLogin() {
        do {
            if launchAtLogin {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to toggle login item: \(error)")
        }
    }
}
