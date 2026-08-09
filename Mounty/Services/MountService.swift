import AppKit
import Darwin
import Foundation
import NetFS
import ServiceManagement
import os

/// Action Service.
struct MountService {

    // MARK: - Logger
    nonisolated private static let logger = Logger(
        subsystem: "Mounty",
        category: "MountService"
    )

    // MARK: - Mounting

    /// Mounts network share via NetFSMountURLSync.
    /// Returns the mount path if successful, nil otherwise.
    static func mount(url: URL) async -> String? {
        await Task.detached(priority: .userInitiated) {

            // 1. Check if already mounted
            if let existing = SystemMountService.findMountPath(forURL: url) {
                logger.info(
                    "Share already mounted: \(url.absoluteString) -> \(existing)"
                )
                return existing
            }

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

            // 2. Success
            if result == 0,
                let points = mountpoints?.takeRetainedValue() as? [String],
                let path = points.first
            {
                logger.info(
                    "Mount successful: \(url.absoluteString) -> \(path)"
                )
                return path
            }

            // 3. Treat Error 17 (already exists) as success
            if result == 17,
                let existing = SystemMountService.findMountPath(forURL: url)
            {
                logger.info(
                    "Share already mounted (NetFSMountURLSync EEXIST): \(url.absoluteString) -> \(existing)"
                )
                return existing
            }

            // 4. Real failure
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
                let forceResult = Darwin.unmount(path, MNT_FORCE)
                if forceResult == 0 {
                    logger.info("Force unmount successful: \(path)")
                } else {
                    logger.error("Force unmount failed: \(path). errno: \(errno)")
                }
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

    // SMAppService is thread-safe; no main-actor requirement.
    nonisolated static func toggleLoginItem(enabled: Bool) {
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

    nonisolated static func isLoginItemEnabled() -> Bool {
        return SMAppService.mainApp.status == .enabled
    }
}
