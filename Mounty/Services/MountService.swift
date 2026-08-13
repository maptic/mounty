import AppKit
import Darwin
import Foundation
import NetFS
import ServiceManagement

/// Action Service.
struct MountService {
    nonisolated private static let mountGate = MountGate()

    // MARK: - Mount Result

    enum MountResult: Sendable {
        case success(path: String)
        case failed(code: Int32)

        nonisolated var path: String? {
            if case .success(let path) = self { return path }
            return nil
        }

        nonisolated var debugDescription: String {
            switch self {
            case .success(let path): return "success → \(path)"
            case .failed(let code):
                let detail =
                    code > 0
                    ? String(cString: strerror(code))
                    : NSError(domain: NSOSStatusErrorDomain, code: Int(code)).localizedDescription
                return "NetFS error \(code): \(detail)"
            }
        }
    }

    // MARK: - Mounting

    /// Mounts a network share with NetFS without blocking MainActor.
    nonisolated static func mount(url: URL) async -> MountResult {
        await mountGate.acquire()
        let result = await mountExclusively(url: url)
        await mountGate.release()
        return result
    }

    nonisolated private static func mountExclusively(url: URL) async -> MountResult {
        if let existing = await Task.detached(
            priority: .userInitiated,
            operation: {
                SystemMountService.findMountPath(forURL: url)
            }
        ).value {
            switch await ReachabilityService.probeMountPoint(path: existing) {
            case .alive:
                AppLogger.log(
                    "Mount skipped; already mounted and responsive: \(mountTarget(for: url)) -> \(existing)",
                    source: .mountService
                )
                return .success(path: existing)

            case .indeterminate:
                // A share saturated with I/O answers statfs slowly. Recovering it here
                // would force-unmount a healthy mount and destroy other processes'
                // open file descriptors, so a busy mount is always left alone.
                AppLogger.log(
                    "Mount skipped; already mounted and busy: \(mountTarget(for: url)) -> \(existing)",
                    source: .mountService
                )
                return .success(path: existing)

            case .dead(let code):
                AppLogger.log(
                    "Existing mount is dead: \(existing); errno=\(code): "
                        + "\(String(cString: strerror(code))); unmounting before retry",
                    level: .warning,
                    source: .mountService
                )
                guard await unmount(path: existing) else {
                    return .failed(code: EBUSY)
                }
            }
        }

        return await Task.detached(priority: .userInitiated) {
            performMount(url: url)
        }.value
    }

    nonisolated private static func performMount(url: URL) -> MountResult {
        let target = mountTarget(for: url)
        let startedAt = ContinuousClock.now
        AppLogger.log("Mount started: \(target)", level: .debug, source: .mountService)

        if let existing = SystemMountService.findMountPath(forURL: url) {
            AppLogger.log(
                "Mount resolved an existing share after retry preparation: \(target) -> \(existing)",
                source: .mountService
            )
            return .success(path: existing)
        }

        let watchdog = Task.detached(priority: .utility) {
            do {
                try await Task.sleep(for: .seconds(30))
                AppLogger.log(
                    "Mount still pending after 30 s: \(target); waiting for NetFS or authentication UI",
                    level: .warning,
                    source: .mountService
                )
            } catch {
                // Completion cancels the watchdog.
            }
        }
        defer { watchdog.cancel() }

        var mountpoints: Unmanaged<CFArray>?
        let status = NetFSMountURLSync(
            url as CFURL,
            nil,
            nil,
            nil,
            nil,
            nil,
            &mountpoints
        )
        let elapsed = startedAt.duration(to: .now)

        if status == 0 {
            if let paths = mountpoints?.takeRetainedValue() as? [String],
                let path = paths.first
            {
                AppLogger.log(
                    "Mount succeeded: \(target) -> \(path); duration=\(elapsed)",
                    source: .mountService
                )
                return .success(path: path)
            }
            if let existing = SystemMountService.findMountPath(forURL: url) {
                AppLogger.log(
                    "Mount succeeded and resolved from system mounts: \(target) -> \(existing); duration=\(elapsed)",
                    source: .mountService
                )
                return .success(path: existing)
            }
            AppLogger.log(
                "NetFS reported success without a mount path: \(target); duration=\(elapsed)",
                level: .error,
                source: .mountService
            )
            return .failed(code: EIO)
        }

        if status == EEXIST,
            let existing = SystemMountService.findMountPath(forURL: url)
        {
            AppLogger.log(
                "Mount resolved existing share: \(target) -> \(existing); duration=\(elapsed)",
                source: .mountService
            )
            return .success(path: existing)
        }

        let result = MountResult.failed(code: status)
        AppLogger.log(
            "Mount failed: \(target); \(result.debugDescription); duration=\(elapsed)",
            level: .error,
            source: .mountService
        )
        return result
    }

    nonisolated private static func mountTarget(for url: URL) -> String {
        "\(url.host ?? "unknown-host")\(url.path)"
    }

    /// Unmounts path via NSWorkspace, falling back to kernel-level force unmount.
    @discardableResult
    static func unmount(path: String) async -> Bool {
        await Task.detached(priority: .userInitiated) {
            let url = URL(fileURLWithPath: path)
            do {
                try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                AppLogger.log("Polite unmount succeeded: \(path)", source: .mountService)
                return true
            } catch {
                AppLogger.log(
                    "Polite unmount failed: \(path); \(error.localizedDescription); trying MNT_FORCE",
                    level: .warning,
                    source: .mountService
                )
                let forceResult = Darwin.unmount(path, MNT_FORCE)
                if forceResult == 0 {
                    AppLogger.log("Force unmount succeeded: \(path)", source: .mountService)
                    return true
                } else {
                    AppLogger.log(
                        "Force unmount failed: \(path); errno=\(errno): \(String(cString: strerror(errno)))",
                        level: .error,
                        source: .mountService
                    )
                    return false
                }
            }
        }.value
    }

    // MARK: - UI Actions

    nonisolated static func openInFinder(path: String) {
        Task.detached(priority: .userInitiated) {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    nonisolated static func openInTerminal(path: String, with bundleId: String? = nil) {
        Task.detached(priority: .userInitiated) {
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
            AppLogger.log(
                "Login item update failed: \(error.localizedDescription)",
                level: .error,
                source: .mountService
            )
        }
    }

    nonisolated static func isLoginItemEnabled() -> Bool {
        SMAppService.mainApp.status == .enabled
    }
}

private actor MountGate {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        guard isHeld else {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }
        waiters.removeFirst().resume()
    }
}
