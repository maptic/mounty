import Foundation
import NetFS
import AppKit
import ServiceManagement

/// **Action Service (The Builder)**
///
/// This service handles the *imperative* commands to modify the system state.
/// - Connects to servers using `NetFS` (bypassing Finder UI).
/// - Unmounts drives.
/// - Opens Finder/Terminal.
///
/// It does **not** track state. It only executes commands.
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
            
            // Allow UI interaction (e.g. Password prompt) if Keychain lookup fails
            let openOptions: [String: Any] = [
                "AllowUserInteraction": true,
                "NoMountOnDir": true
            ]
            
            let rawOptions = openOptions as CFDictionary
            let mutableOpenOptions = CFDictionaryCreateMutableCopy(nil, 0, rawOptions)
            
            let result = NetFSMountURLSync(cfUrl, nil, nil, nil, mutableOpenOptions, nil, &mountpoints)
            
            if result == 0,
               let points = mountpoints?.takeRetainedValue() as? [String],
               let path = points.first {
                return path
            }
            
            if result != 0 {
                print("[MountService] NetFSMountURLSync failed with error: \(result)")
            }
            
            return nil
        }.value
    }
    
    // MARK: - Unmounting
    
    static func unmount(path: String) async {
        // Run on background thread to prevent UI blocking during unmount
        await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            
            do {
                // 1. Try "Polite" unmount (NSWorkspace)
                // This allows apps to save changes before closing
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
            } catch {
                print("[MountService] Polite unmount failed. Forcing...")
                // 2. Fallback: Force Unmount (C-API)
                // This cuts the connection immediately
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
