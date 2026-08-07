import Foundation
import Network

/// Verifies server and mount point responsiveness.
struct ReachabilityService {

    /// Validates filesystem responsiveness via I/O.
    nonisolated static func isMountPointAlive(path: String) -> Bool {
        let group = DispatchGroup()
        group.enter()
        var isAlive = false

        DispatchQueue.global(qos: .userInteractive).async {
            if (try? FileManager.default.contentsOfDirectory(atPath: path))
                != nil
            {
                isAlive = true
            }
            group.leave()
        }

        let result = group.wait(timeout: .now() + 1.0)
        return result == .success && isAlive
    }

    /// Validates TCP connectivity to SMB port (445).
    static func isServerReachable(address: String) async -> Bool {
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
                case .failed, .cancelled:
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

/// Single-use boolean flag protected by NSLock; safe to share across @Sendable closures.
private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    // nonisolated(unsafe): opts out of implicit @MainActor isolation;
    // thread safety is guaranteed by `lock`.
    private nonisolated(unsafe) var resumed = false

    /// Returns `true` the first time it is called; `false` on all subsequent calls.
    nonisolated func tryResume() -> Bool {
        lock.withLock {
            guard !resumed else { return false }
            resumed = true
            return true
        }
    }
}
