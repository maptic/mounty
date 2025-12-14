import Foundation
import NetFS
import AppKit
import ServiceManagement

struct MountService {
    
    // MARK: - Mounting (NetFS)
    
    /// Mounts an SMB share using NetFS.
    ///
    /// - Important: **App Sandbox must be DISABLED** in Xcode "Signing & Capabilities".
    /// If Sandboxed, this will fail with error 0x5 and cannot access the System Keychain.
    static func mount(url: URL) async -> String? {
        return await Task.detached(priority: .userInitiated) {
            var mountpoints: Unmanaged<CFArray>? = nil
            let cfUrl = url as CFURL
            
            // Configuration to allow UI Prompts and access Keychain
            let openOptions: [String: Any] = [
                // Allows the OS to prompt for Username/Password if not in Keychain
                "AllowUserInteraction": true,
                // Ensures we don't accidentally mount inside another mount
                "NoMountOnDir": true
            ]
            
            // Convert to CFMutableDictionary for the C-API
            let rawOptions = openOptions as CFDictionary
            let mutableOpenOptions = CFDictionaryCreateMutableCopy(nil, 0, rawOptions)
            
            // Call NetFSMountURLSync
            // Arguments: URL, MountPath (nil=default), User (nil=auto), Pass (nil=auto), OpenOptions, MountOptions, Results
            let result = NetFSMountURLSync(cfUrl, nil, nil, nil, mutableOpenOptions, nil, &mountpoints)
            
            // Check Success (0)
            if result == 0,
               let points = mountpoints?.takeRetainedValue() as? [String],
               let path = points.first {
                return path
            }
            
            // Debugging info if it fails (check Console.app)
            if result != 0 {
                print("[MountService] NetFSMountURLSync failed with error code: \(result)")
            }
            
            return nil
        }.value
    }
    
    // MARK: - Unmounting
    
    static func unmount(path: String) async {
        let url = URL(fileURLWithPath: path)
        
        await Task.detached(priority: .userInitiated) {
            do {
                // Try "Polite" unmount via NSWorkspace (allows closing files)
                // Note: Synchronous call wrapped in Task.detached to prevent UI blocking
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                print("[MountService] Polite unmount failed. Forcing...")
                // Fallback: Force Unmount (C-API)
                _ = Darwin.unmount(path, MNT_FORCE)
            }
        }.value
    }
    
    // MARK: - App Actions
    
    @MainActor
    static func openInFinder(path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    @MainActor
    static func openInTerminal(path: String, with bundleId: String? = nil) {
        let url = URL(fileURLWithPath: path)
        let terminalId = bundleId ?? "com.apple.Terminal"
        
        if let appUrl = NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalId) {
            let config = NSWorkspace.OpenConfiguration()
            config.arguments = [path] // Pass path as argument to set working directory
            NSWorkspace.shared.openApplication(at: appUrl, configuration: config, completionHandler: nil)
        }
    }
    
    // MARK: - Login Item
    
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
