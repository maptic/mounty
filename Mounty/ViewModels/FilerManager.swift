import SwiftUI
import Combine

@MainActor
class FilerManager: ObservableObject {
    // MARK: - State
    @Published var filers: [Filer] = []
    @Published var mountPaths: [UUID: String] = [:] // UUID -> /Volumes/Share
    @Published var busyFilers: Set<UUID> = []       // For UI Spinners
    @Published var launchAtLogin: Bool = ActionService.isLoginItemEnabled()
    
    // MARK: - Dependencies
    private let storage = PersistenceService()
    private var monitoringTask: Task<Void, Never>?
    
    init() {
        self.filers = storage.load()
        startEngine()
    }
    
    deinit {
        monitoringTask?.cancel()
    }
    
    // MARK: - The Engine (Loop)
    
    private func startEngine() {
        monitoringTask = Task {
            // Initial Check
            await refreshState()
            
            while !Task.isCancelled {
                // Sleep 4 seconds
                try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
                
                // 1. Refresh Mount Status (Detect Zombies/Disconnects)
                await refreshState()
                
                // 2. Run Automount Logic
                await runAutomount()
            }
        }
    }
    
    // MARK: - Logic: Refresh
    
    func refreshState() async {
        let currentFilers = self.filers // Snapshot
        
        // Run heavy lifting off Main Actor
        let newPaths = await Task.detached {
            return await FilerManager.detectMounts(filers: currentFilers)
        }.value
        
        // Update UI
        if self.mountPaths != newPaths {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.mountPaths = newPaths
            }
        }
    }
    
    /// Pure Logic: Matches Configs -> System Mounts -> Checks Liveness
    nonisolated private static func detectMounts(filers: [Filer]) async -> [UUID: String] {
        let systemMounts = SystemMountService.getSystemMounts()
        var results: [UUID: String] = [:]
        
        // Use TaskGroup to check liveness in parallel (Speed up VPN detection)
        await withTaskGroup(of: (UUID, String?).self) { group in
            for filer in filers {
                group.addTask {
                    // 1. Find potential path
                    if let path = SystemMountService.findMountPath(for: filer, in: systemMounts) {
                        // 2. Check if alive (Fixes VPN Zombie issue)
                        if ReachabilityService.isMountPointAlive(path: path) {
                            return (filer.id, path)
                        }
                    }
                    return (filer.id, nil)
                }
            }
            
            for await (id, path) in group {
                if let validPath = path {
                    results[id] = validPath
                }
            }
        }
        return results
    }
    
    // MARK: - Logic: Automount
    
    private func runAutomount() async {
        for filer in filers where filer.isAutomountEnabled {
            // Only attempt if not mounted AND not busy
            if mountPaths[filer.id] == nil && !busyFilers.contains(filer.id) {
                
                // Mark busy briefly to prevent spamming
                busyFilers.insert(filer.id)
                
                let isReachable = await ReachabilityService.isServerReachable(address: filer.serverAddress)
                
                if isReachable {
                    // Double check state hasn't changed
                    if mountPaths[filer.id] == nil {
                        print("Automounting: \(filer.name)")
                        ActionService.mount(filer: filer)
                        
                        // Wait a bit for Finder
                        try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
                        await refreshState()
                    }
                }
                
                busyFilers.remove(filer.id)
            }
        }
    }
    
    // MARK: - User Actions
    
    func mount(_ filer: Filer) {
        guard mountPaths[filer.id] == nil else { return }
        busyFilers.insert(filer.id)
        
        ActionService.mount(filer: filer)
        
        // Check outcome after delay
        Task {
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            self.busyFilers.remove(filer.id)
            await self.refreshState()
        }
    }
    
    func unmount(_ filer: Filer) {
        // Disable automount temporarily to prevent fighting
        disableAutomount(for: filer)
        
        guard let path = mountPaths[filer.id] else {
            Task { await refreshState() }
            return
        }
        
        // Optimistic UI update: Remove immediately so user sees reaction
        self.mountPaths.removeValue(forKey: filer.id)
        busyFilers.insert(filer.id)
        
        Task {
            // Perform Unmount
            await ActionService.unmount(path: path)
            
            self.busyFilers.remove(filer.id)
            await self.refreshState()
        }
    }
    
    func toggleLaunchAtLogin(_ enabled: Bool) {
        ActionService.toggleLoginItem(enabled: enabled)
        launchAtLogin = ActionService.isLoginItemEnabled()
    }
    
    // MARK: - Data Management
    
    func addFiler(_ filer: Filer) {
        filers.append(filer)
        storage.save(filers)
        Task { await refreshState() }
    }
    
    func removeFiler(_ id: UUID) {
        filers.removeAll { $0.id == id }
        storage.save(filers)
        Task { await refreshState() }
    }
    
    func removeAllFilers() {
        filers.removeAll()
        storage.save(filers)
        Task { await refreshState() }
    }
    
    func toggleAutomount(_ id: UUID) {
        if let idx = filers.firstIndex(where: { $0.id == id }) {
            filers[idx].isAutomountEnabled.toggle()
            storage.save(filers)
        }
    }
    
    private func disableAutomount(for filer: Filer) {
        if let idx = filers.firstIndex(where: { $0.id == filer.id }) {
            filers[idx].isAutomountEnabled = false
            storage.save(filers)
        }
    }
    
    // MARK: - Utilities
    
    func openTerminal(for filer: Filer) {
        guard let path = mountPaths[filer.id] else { return }
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") {
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = [path]
            NSWorkspace.shared.openApplication(at: appUrl, configuration: config, completionHandler: nil)
        }
    }
    
    func copyPath(for filer: Filer) {
        guard let path = mountPaths[filer.id] else { return }
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(path, forType: .string)
    }
}
