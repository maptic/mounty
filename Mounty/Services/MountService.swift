import AppKit
import Darwin
import Foundation
import NetFS
import ServiceManagement
import os

/// Action Service.
struct MountService {

    // MARK: - Logger

    /// Detached-task safe logger
    nonisolated private static let logger = Logger(
        subsystem: "Mounty",
        category: "MountService"
    )

    // MARK: - Mounting

    /// Mounts network share via NetFSMountURLSync.
    static func mount(url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {
            var mountpoints: Unmanaged<CFArray>? = nil
            let cfUrl = url as CFURL

            let openOptions: [String: Any] = [
                "AllowUserInteraction": true, "NoMountOnDir": true,
            ]
            let mutableOpenOptions = CFDictionaryCreateMutableCopy(
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

            logger.error(
                "Mount failed: \(url.absoluteString). Error: \(result)"
            )
            return nil
        }.value
    }

    /// Unmounts path via NSWorkspace, falling back to kernel-level force unmount.
    static func unmount(path: String) async {
        await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                logger.info("Polite unmount successful: \(path)")
            } catch {
                logger.warning("Polite unmount failed. Executing MNT_FORCE.")
                _ = Darwin.unmount(path, MNT_FORCE)
            }
        }.value
    }

    // MARK: - UI Actions

    @MainActor
    static func openInFinder(path: String) {
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    @MainActor
    static func openInTerminal(path: String, with bundleId: String? = nil) {
        let url = URL(fileURLWithPath: path)
        let terminalId = bundleId ?? "com.apple.Terminal"

        guard
            let appUrl = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: terminalId
            )
        else {
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
            logger.error(
                "Login Item toggle failed: \(error.localizedDescription)"
            )
        }
    }

    @MainActor
    static func isLoginItemEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
