import Foundation
import Network

/// Verifies responsiveness of servers and mount points.
struct ReachabilityService {

    /// Filesystem I/O Check (Zombie Detection).
    /// Forces a directory listing to bypass Kernel metadata cache.
    /// Critical for detecting dropped VPN connections where `access()` returns false positives.
    nonisolated static func isMountPointAlive(path: String) -> Bool {
        let group = DispatchGroup()
        group.enter()
        var isAlive = false

        DispatchQueue.global(qos: .userInteractive).async {
            // Perform lightweight I/O.
            if (try? FileManager.default.contentsOfDirectory(atPath: path))
                != nil
            {
                isAlive = true
            }
            group.leave()
        }

        // Strict 1.0s timeout catches hung connections immediately.
        let result = group.wait(timeout: .now() + 1.0)
        return result == .success && isAlive
    }

    /// Network TCP Check (Port 445).
    /// Detects missing routes (VPN drops) prior to mounting.
    static func isServerReachable(address: String) async -> Bool {
        guard let host = URL(string: address)?.host else { return false }

        return await withCheckedContinuation { continuation in
            let hostEP = NWEndpoint.Host(host)
            let portEP = NWEndpoint.Port(integerLiteral: 445)
            let conn = NWConnection(
                to: .hostPort(host: hostEP, port: portEP),
                using: .tcp
            )

            let workItem = DispatchWorkItem {
                if conn.state != .ready {
                    conn.cancel()
                    continuation.resume(returning: false)
                }
            }
            // 2s Handshake timeout
            DispatchQueue.global().asyncAfter(
                deadline: .now() + 2.0,
                execute: workItem
            )

            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    workItem.cancel()
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed(_), .cancelled:
                    workItem.cancel()
                default: break
                }
            }
            conn.start(queue: .global())
        }
    }
}
