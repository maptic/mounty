import Foundation
import Network

struct ReachabilityService {
    
    /// Checks if a TCP connection can be established to the host (Port 445 for SMB)
    static func isServerReachable(address: String) async -> Bool {
        guard let host = URL(string: address)?.host else { return false }
        
        return await withCheckedContinuation { continuation in
            let hostEP = NWEndpoint.Host(host)
            let portEP = NWEndpoint.Port(integerLiteral: 445)
            let conn = NWConnection(to: .hostPort(host: hostEP, port: portEP), using: .tcp)
            
            let workItem = DispatchWorkItem {
                if conn.state != .ready {
                    conn.cancel()
                    continuation.resume(returning: false)
                }
            }
            // 2 second timeout for network check
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0, execute: workItem)
            
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    workItem.cancel()
                    conn.cancel()
                    continuation.resume(returning: true)
                case .failed(_), .cancelled:
                    workItem.cancel()
                    // Don't resume here, let the timeout handle it to avoid multiple resumes
                default: break
                }
            }
            conn.start(queue: .global())
        }
    }
    
    /// Checks if a filesystem path is responsive (Zombie Check).
    /// Executes on a background thread to prevent UI locking.
    nonisolated static func isMountPointAlive(path: String) -> Bool {
        let group = DispatchGroup()
        group.enter()
        var isAlive = false
        
        DispatchQueue.global(qos: .userInteractive).async {
            // access() returns 0 on success. If VPN is dead, this usually hangs.
            if access(path, F_OK) == 0 {
                isAlive = true
            }
            group.leave()
        }
        
        // Strict 1.0s timeout. If it takes longer, consider it a Zombie.
        let result = group.wait(timeout: .now() + 1.0)
        return result == .success && isAlive
    }
}
