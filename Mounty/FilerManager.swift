import Foundation
import AppKit
import ServiceManagement

@MainActor
class FilerManager: ObservableObject {
    @Published var filers: [Filer] = []
    @Published var mountedStatus: [UUID: Bool] = [:] // Tracks which filers are currently mounted
    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled {
        didSet { toggleLaunchAtLogin() }
    }
    
    private var timer: Timer?
    private let defaults = UserDefaults.standard
    
    init() {
        loadFilers()
        checkMountStatus() // Initial check
        
        // Start the monitoring loop (every 5 seconds)
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkMountStatus()
                self.runAutomountLogic()
            }
        }
    }
    
    // MARK: - Core Logic
    
    func checkMountStatus() {
        var newStatus: [UUID: Bool] = [:]
        for filer in filers {
            // Check if /Volumes/Name exists
            let exists = FileManager.default.fileExists(atPath: filer.localPath.path)
            newStatus[filer.id] = exists
        }
        self.mountedStatus = newStatus
    }
    
    func runAutomountLogic() {
        for filer in filers where filer.isAutomountEnabled {
            // If NOT mounted, check connectivity and try to mount
            if mountedStatus[filer.id] == false {
                checkConnectivityAndMount(filer)
            }
        }
    }
    
    private func checkConnectivityAndMount(_ filer: Filer) {
        guard let host = URL(string: filer.serverAddress)?.host else { return }
        
        // Run Ping in background to avoid freezing UI
        DispatchQueue.global(qos: .background).async {
            if self.isHostReachable(host) {
                DispatchQueue.main.async {
                    self.mount(filer)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    func mount(_ filer: Filer) {
        guard let url = URL(string: filer.serverAddress) else { return }
        NSWorkspace.shared.open(url)
    }
    
    func unmount(_ filer: Filer) {
        NSWorkspace.shared.unmountAndEjectDevice(at: filer.localPath) { error in
            if let error = error {
                print("Error unmounting: \(error.localizedDescription)")
            } else {
                Task { @MainActor in self.checkMountStatus() }
            }
        }
    }
    
    func copyPath(_ filer: Filer) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(filer.localPath.path, forType: .string)
    }
    
    // MARK: - CRUD
    
    func addFiler(_ filer: Filer) {
        filers.append(filer)
        saveFilers()
    }
    
    func removeFiler(id: UUID) {
        filers.removeAll { $0.id == id }
        saveFilers()
    }
    
    func toggleAutomount(for id: UUID) {
        if let index = filers.firstIndex(where: { $0.id == id }) {
            filers[index].isAutomountEnabled.toggle()
            saveFilers()
        }
    }
    
    // MARK: - Helpers & Persistence
    
    private func isHostReachable(_ host: String) -> Bool {
        let process = Process()
        process.launchPath = "/sbin/ping"
        process.arguments = ["-c", "1", "-t", "1", host] // 1 ping, 1s timeout
        process.launch()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
    
    private func saveFilers() {
        if let encoded = try? JSONEncoder().encode(filers) {
            defaults.set(encoded, forKey: "SavedFilers")
        }
    }
    
    private func loadFilers() {
        if let data = defaults.data(forKey: "SavedFilers"),
           let decoded = try? JSONDecoder().decode([Filer].self, from: data) {
            filers = decoded
        }
    }
    
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