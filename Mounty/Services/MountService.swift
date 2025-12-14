import Foundation
import NetFS
import AppKit
import ServiceManagement
import Darwin

/// Action Service. Handles Mounting, Unmounting, and App Launching.
struct MountService {
    
    /// Mounts using NetFSMountURLSync.
    /// - Important: App Sandbox must be DISABLED to use System Keychain.
    static func mount(url: URL) async -> String? {
        return await Task.detached(priority: .userInitiated) {
            var mountpoints: Unmanaged<CFArray>? = nil
            let cfUrl = url as CFURL
            let openOptions: [String: Any] = ["AllowUserInteraction": true, "NoMountOnDir": true]
            let mutableOpenOptions = CFDictionaryCreateMutableCopy(nil, 0, openOptions as CFDictionary)
            
            let result = NetFSMountURLSync(cfUrl, nil, nil, nil, mutableOpenOptions, nil, &mountpoints)
            
            if result == 0,
               let points = mountpoints?.takeRetainedValue() as? [String],
               let path = points.first {
                return path
            }
            return nil
        }.value
    }
    
    /// Unmounts using polite request first, falls back to Force Unmount.
    static func unmount(path: String) async {
        await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                _ = Darwin.unmount(path, MNT_FORCE)
            }
        }.value
    }
    
    @MainActor
    static func openInFinder(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }
    
    @MainActor
    static func openInTerminal(path: String, with bundleId: String? = nil) {
        let url = URL(fileURLWithPath: path)
        let terminalId = bundleId ?? "com.apple.Terminal"
        
        guard let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalId) else {
            NSWorkspace.shared.open(url) // Fallback
            return
        }
        
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.open([url], withApplicationAt: appUrl, configuration: config, completionHandler: nil)
    }
    
    // Login Item Management
    @MainActor
    static func toggleLoginItem(enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { print("Login Item Error: \(error)") }
    }
    
    @MainActor
    static func isLoginItemEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
