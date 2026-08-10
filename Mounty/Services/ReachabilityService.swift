import Darwin
import Foundation
import Network

/// Verifies server and mount point responsiveness.
struct ReachabilityService {
    nonisolated private static let mountProbes = MountProbeRegistry()

    /// Validates filesystem responsiveness by calling statfs(2) on the mount path.
    ///
    /// statfs() queries kernel-level filesystem metadata without reading file content,
    /// so it never triggers the macOS TCC "access files on a network volume" prompt.
    /// It will block (and thus timeout) on a hung/dead mount, which is exactly the
    /// behaviour we need to detect silently dead kernel mounts.
    ///
    /// Async: dispatches statfs to a background thread so the Swift cooperative
    /// thread pool is never blocked waiting for a hung mount.
    nonisolated static func isMountPointAlive(path: String) async -> Bool {
        return await withCheckedContinuation { continuation in
            guard mountProbes.register(path: path, continuation: continuation) else { return }

            DispatchQueue.global(qos: .utility).async {
                defer { mountProbes.finish(path: path) }
                // Allocate uninitialized memory instead of calling statfs.init(),
                // which is @MainActor under SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
                // The C statfs(2) syscall writes the struct entirely so zero-init
                // is unnecessary and the @MainActor init can be bypassed safely.
                let buf = UnsafeMutablePointer<statfs>.allocate(capacity: 1)
                defer { buf.deallocate() }
                let status = statfs(path, buf)
                let errorCode = errno
                let alive = status == 0
                if mountProbes.resolve(path: path, result: alive) {
                    if !alive {
                        AppLogger.log(
                            "Mount probe failed: \(path); errno=\(errorCode): \(String(cString: strerror(errorCode)))",
                            level: .warning,
                            source: .reachability
                        )
                    }
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                if mountProbes.resolve(path: path, result: false) {
                    AppLogger.log(
                        "Mount probe timed out after 1 s: \(path)",
                        level: .warning,
                        source: .reachability
                    )
                }
            }
        }
    }

    /// Validates TCP connectivity to SMB port (445).
    nonisolated static func isServerReachable(address: String) async -> Bool {
        guard let host = URL(string: address)?.host else { return false }

        return await withCheckedContinuation { continuation in
            let hostEP = NWEndpoint.Host(host)
            let portEP = NWEndpoint.Port(integerLiteral: 445)
            let conn = NWConnection(
                to: .hostPort(host: hostEP, port: portEP),
                using: .tcp
            )

            // Thread-safe gate: ensures continuation.resume is called exactly once
            // even when the timeout and stateUpdateHandler fire concurrently.
            // @unchecked Sendable is safe here because NSLock guards the mutation.
            let gate = ResumeGate()

            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
                if gate.tryResume() {
                    conn.cancel()
                    AppLogger.log(
                        "SMB probe timed out: host=\(host); port=445; timeout=2 s",
                        level: .debug,
                        source: .reachability
                    )
                    continuation.resume(returning: false)
                }
            }

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.tryResume() {
                        conn.cancel()
                        continuation.resume(returning: true)
                    }
                case .failed(let error):
                    if gate.tryResume() {
                        AppLogger.log(
                            "SMB probe failed: host=\(host); port=445; error=\(error)",
                            level: .debug,
                            source: .reachability
                        )
                        continuation.resume(returning: false)
                    }
                case .cancelled:
                    if gate.tryResume() {
                        continuation.resume(returning: false)
                    }
                default: break
                }
            }
            conn.start(queue: .global())
        }
    }
}

private final class MountProbeRegistry: @unchecked Sendable {
    private struct ProbeState {
        var result: Bool?
        var waiters: [CheckedContinuation<Bool, Never>]
    }

    private let lock = NSLock()
    private nonisolated(unsafe) var probes: [String: ProbeState] = [:]

    /// Registers a caller and returns true only when it must start the underlying syscall.
    nonisolated func register(
        path: String,
        continuation: CheckedContinuation<Bool, Never>
    ) -> Bool {
        var immediateResult: Bool?
        let shouldStart = lock.withLock {
            guard var state = probes[path] else {
                probes[path] = ProbeState(result: nil, waiters: [continuation])
                return true
            }
            if let result = state.result {
                immediateResult = result
            } else {
                state.waiters.append(continuation)
                probes[path] = state
            }
            return false
        }
        if let immediateResult {
            continuation.resume(returning: immediateResult)
        }
        return shouldStart
    }

    /// Resolves all current and future waiters while the non-cancellable syscall remains active.
    @discardableResult
    nonisolated func resolve(path: String, result: Bool) -> Bool {
        let waiters: [CheckedContinuation<Bool, Never>]? = lock.withLock {
            guard var state = probes[path], state.result == nil else { return nil }
            state.result = result
            let waiters = state.waiters
            state.waiters.removeAll()
            probes[path] = state
            return waiters
        }
        guard let waiters else { return false }
        for continuation in waiters {
            continuation.resume(returning: result)
        }
        return true
    }

    nonisolated func finish(path: String) {
        lock.withLock { _ = probes.removeValue(forKey: path) }
    }
}

/// Single-use boolean flag protected by NSLock; safe to share across @Sendable closures.
final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    // nonisolated(unsafe): opts out of implicit @MainActor isolation;
    // thread safety is guaranteed by `lock`.
    private nonisolated(unsafe) var resumed = false

    // Explicit nonisolated init: SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor would make
    // the synthesised init() @MainActor, causing a warning when ResumeGate is created
    // from nonisolated contexts. NSLock and Bool are not actor-isolated, so this is safe.
    nonisolated init() {}

    /// Returns `true` the first time it is called; `false` on all subsequent calls.
    nonisolated func tryResume() -> Bool {
        lock.withLock {
            guard !resumed else { return false }
            resumed = true
            return true
        }
    }
}
