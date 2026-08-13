import Darwin
import Foundation
import Network
import Synchronization

/// Outcome of a mount-point liveness probe.
enum MountProbe: Sendable, Equatable {
    /// statfs(2) answered: the mount is responsive.
    case alive
    /// statfs(2) answered with an error: the mount is gone or unusable.
    case dead(code: Int32)
    /// The deadline elapsed while statfs(2) was still outstanding. A share saturated
    /// with I/O answers slowly — it is busy, not dead — so this outcome must never
    /// be treated as a failure or trigger recovery.
    case indeterminate

    nonisolated static func == (lhs: MountProbe, rhs: MountProbe) -> Bool {
        switch (lhs, rhs) {
        case (.alive, .alive), (.indeterminate, .indeterminate): true
        case (.dead(let lhsCode), .dead(let rhsCode)): lhsCode == rhsCode
        default: false
        }
    }
}

/// Verifies server and mount point responsiveness.
struct ReachabilityService {
    nonisolated private static let mountProbes = MountProbeRegistry()

    /// Probes filesystem responsiveness by calling statfs(2) on the mount path.
    ///
    /// statfs() queries kernel-level filesystem metadata without reading file content,
    /// so it never triggers the macOS TCC "access files on a network volume" prompt.
    /// It will block on a hung/dead mount, which is exactly the behaviour we need to
    /// detect silently dead kernel mounts.
    ///
    /// A busy share also answers slowly, so an elapsed deadline reports `.indeterminate`
    /// rather than a failure: only an errno from statfs(2) proves the mount is `.dead`.
    ///
    /// Async: dispatches statfs to a background thread so the Swift cooperative thread
    /// pool is never blocked waiting for a hung mount. Concurrent probes of one path
    /// share a single syscall, and every caller applies its own deadline.
    nonisolated static func probeMountPoint(
        path: String,
        timeout: TimeInterval = 2.0,
        hangGrace: Duration = .seconds(60)
    ) async -> MountProbe {
        let token = UUID()
        return await withCheckedContinuation { continuation in
            if mountProbes.register(path: path, token: token, continuation: continuation) {
                DispatchQueue.global(qos: .utility).async {
                    // Allocate uninitialized memory instead of calling statfs.init(),
                    // which is @MainActor under SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor.
                    // The C statfs(2) syscall writes the struct entirely so zero-init
                    // is unnecessary and the @MainActor init can be bypassed safely.
                    let buf = UnsafeMutablePointer<statfs>.allocate(capacity: 1)
                    defer { buf.deallocate() }
                    let status = statfs(path, buf)
                    let errorCode = errno
                    if status == 0 {
                        mountProbes.complete(path: path, result: .alive)
                    } else {
                        AppLogger.log(
                            "Mount probe failed: \(path); errno=\(errorCode): \(String(cString: strerror(errorCode)))",
                            level: .warning,
                            source: .reachability
                        )
                        mountProbes.complete(path: path, result: .dead(code: errorCode))
                    }
                }
            }

            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                switch mountProbes.timeOut(path: path, token: token, hangGrace: hangGrace) {
                case .indeterminate:
                    AppLogger.log(
                        "Mount probe still pending after \(timeout) s: \(path); the mount is busy, not dead",
                        level: .debug,
                        source: .reachability
                    )
                case .dead:
                    AppLogger.log(
                        "Mount probe has been stuck for over \(hangGrace): \(path); treating the mount as dead",
                        level: .warning,
                        source: .reachability
                    )
                default:
                    break
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

/// Coalesces concurrent statfs(2) probes of the same path onto a single syscall.
///
/// A probe entry exists only while its syscall is outstanding, and no verdict is ever
/// stored: a caller that gives up on its own deadline is simply dropped from the waiters.
/// A later caller therefore joins the still-running syscall and waits for the real
/// answer instead of inheriting an earlier caller's timeout as if it were a result.
final class MountProbeRegistry: Sendable {
    private struct ProbeState {
        let startedAt = ContinuousClock.now
        var waiters: [UUID: CheckedContinuation<MountProbe, Never>]
    }

    private let probes = Mutex([String: ProbeState]())

    /// Registers a caller and returns true only when it must start the underlying syscall.
    nonisolated func register(
        path: String,
        token: UUID,
        continuation: CheckedContinuation<MountProbe, Never>
    ) -> Bool {
        probes.withLock { probes in
            guard var state = probes[path] else {
                probes[path] = ProbeState(waiters: [token: continuation])
                return true
            }
            state.waiters[token] = continuation
            probes[path] = state
            return false
        }
    }

    /// Delivers the syscall's verdict to every remaining waiter and clears the probe.
    nonisolated func complete(path: String, result: MountProbe) {
        guard let state = probes.withLock({ $0.removeValue(forKey: path) }) else { return }
        for continuation in state.waiters.values {
            continuation.resume(returning: result)
        }
    }

    /// Releases a single caller whose deadline elapsed while the syscall is still
    /// outstanding, reporting the mount as busy rather than failed — unless the syscall
    /// itself has been stuck past `hangGrace`, which a live filesystem never is.
    ///
    /// Returns the verdict delivered, or `nil` when that caller was no longer waiting.
    @discardableResult
    nonisolated func timeOut(path: String, token: UUID, hangGrace: Duration) -> MountProbe? {
        typealias Resolution = (
            continuation: CheckedContinuation<MountProbe, Never>, verdict: MountProbe
        )

        let resolution = probes.withLock { probes -> Resolution? in
            guard var state = probes[path],
                let continuation = state.waiters.removeValue(forKey: token)
            else { return nil }
            probes[path] = state
            let isHung = state.startedAt.duration(to: .now) > hangGrace
            return (continuation, isHung ? .dead(code: ETIMEDOUT) : .indeterminate)
        }
        guard let resolution else { return nil }
        resolution.continuation.resume(returning: resolution.verdict)
        return resolution.verdict
    }
}

private final class ResumeGate: Sendable {
    private let resumed = Mutex(false)

    nonisolated init() {}

    /// Returns `true` the first time it is called; `false` on all subsequent calls.
    nonisolated func tryResume() -> Bool {
        resumed.withLock { resumed in
            guard !resumed else { return false }
            resumed = true
            return true
        }
    }
}
