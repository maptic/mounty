import AppKit
import Darwin
import Foundation
import NetFS
import ServiceManagement
import os

// MARK: - Logging

enum Log {
    nonisolated static let mount = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Mounty",
        category: "MountService"
    )
}

// MARK: - Mount Service

/// Action Service.
/// Executes imperative system commands: Mounting, Unmounting, and Application Launching.
struct MountService {

    /// Mounts a network share using the low-level NetFS framework.
    ///
    /// This method bypasses the Finder UI to allow programmatic control while still
    /// leveraging the System Keychain for authentication.
    ///
    /// - Important: App Sandbox must be DISABLED in Xcode "Signing & Capabilities".
    /// - Parameter url: The server URL (e.g., `smb://server/share`).
    /// - Returns: The local mount path (e.g., `/Volumes/share`) if successful, otherwise `nil`.
    static func mount(url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {
            var mountpoints: Unmanaged<CFArray>? = nil
            let cfUrl = url as CFURL

            // Allow UI interaction (Password Prompt) if Keychain lookup fails
            // NoMountOnDir prevents recursive mounting on existing folders
            let openOptions: [String: Any] = [
                "AllowUserInteraction": true,
                "NoMountOnDir": true,
            ]

            let mutableOpenOptions =
                CFDictionaryCreateMutableCopy(
                    nil,
                    0,
                    openOptions as CFDictionary
                )

            let result = NetFSMountURLSync(
                cfUrl,
                nil,
                nil,
                nil,
                mutableOpenOptions,
                nil,
                &mountpoints
            )

            if result == 0,
                let points = mountpoints?.takeRetainedValue() as? [String],
                let path = points.first
            {
                return path
            }

            Log.mount.error(
                "Mount failed for \(url.absoluteString). Error code: \(result)"
            )
            return nil
        }.value
    }

    /// Disconnects a mount point.
    ///
    /// Attempts a "polite" unmount via NSWorkspace first (allowing apps to save data).
    /// If the drive is unresponsive/hung, executes a forced unmount at the Kernel level.
    ///
    /// - Parameter path: The local file path to unmount.
    static func unmount(path: String) async {
        await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                Log.mount.info("Polite unmount successful: \(path)")
            } catch {
                Log.mount.warning(
                    "Polite unmount failed. Executing Force Unmount (MNT_FORCE)."
                )
                _ = Darwin.unmount(path, MNT_FORCE)
            }
        }.value
    }

    /// Opens a local path in the Finder.
    @MainActor
    static func openInFinder(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    /// Opens a local path in a specific Terminal application.
    ///
    /// - Parameters:
    ///   - path: The local directory to open.
    ///   - bundleId: The Bundle Identifier of the terminal app (defaults to Apple Terminal).
    @MainActor
    static func openInTerminal(path: String, with bundleId: String? = nil) {
        let url = URL(fileURLWithPath: path)
        let terminalId = bundleId ?? "com.apple.Terminal"

        guard
            let appUrl =
                NSWorkspace.shared.urlForApplication(
                    withBundleIdentifier: terminalId
                )
        else {
            // Fallback to default system handler
            NSWorkspace.shared.open(url)
            return
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        NSWorkspace.shared.open(
            [url],
            withApplicationAt: appUrl,
            configuration: config,
            completionHandler: nil
        )
    }

    // MARK: - Login Item Management

    @MainActor
    static func toggleLoginItem(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.mount.error(
                "Login Item toggle failed: \(error.localizedDescription)"
            )
        }
    }

    @MainActor
    static func isLoginItemEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}
