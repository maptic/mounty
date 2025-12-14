import AppKit
import ServiceManagement
import Darwin

struct ActionService {
    
    @MainActor
    static func mount(filer: Filer) {
        guard let url = URL(string: filer.serverAddress) else { return }
        NSWorkspace.shared.open(url)
    }
    
    /// Unmounts safely.
    /// Uses Task.detached to wrap the blocking NSWorkspace call off the main thread.
    static func unmount(path: String) async {
        let url = URL(fileURLWithPath: path)
        
        await Task.detached(priority: .userInitiated) {
            do {
                // The compiler resolves this as synchronous/blocking, so we call it directly here.
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                print("Polite unmount failed: \(error). Attempting force unmount.")
                
                // Fallback: Force Unmount (C-API)
                _ = Darwin.unmount(path, MNT_FORCE)
            }
        }.value
    }
    
    @MainActor
    static func toggleLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login Item Error: \(error)")
        }
    }
    
    @MainActor
    static func isLoginItemEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
