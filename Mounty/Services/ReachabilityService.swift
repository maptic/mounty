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

            let workItem = DispatchWorkItem { [weak conn] in
                if conn?.state != .ready {
                    conn?.cancel()
                    continuation.resume(returning: false)
                }
            }

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
