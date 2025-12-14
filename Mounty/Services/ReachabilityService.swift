import Foundation
import Network

struct ReachabilityService {
    
    /// Checks if a filesystem path is responsive.
    /// Crucial for detecting "Zombie" mounts when VPN drops.
    nonisolated static func isMountPointAlive(path: String) -> Bool {
        let group = DispatchGroup()
        group.enter()
        var isAlive = false
        
        DispatchQueue.global(qos: .userInteractive).async {
            // access() blocks if the mount is unresponsive.
            if access(path, F_OK) == 0 {
                isAlive = true
            }
            group.leave()
        }
        
        // Strict 500ms timeout. If SMB doesn't answer instantly, treat as dead/laggy.
        let result = group.wait(timeout: .now() + 0.5)
        return result == .success && isAlive
    }
    
    /// Checks TCP connectivity to Port 445 (SMB) before attempting mount.
    static func isServerReachable(address: String) async -> Bool {
        guard let host = URL(string: address)?.host else { return false }
        
        return await withCheckedContinuation { continuation in
            let hostEP = NWEndpoint.Host(host)
            let portEP = NWEndpoint.Port(integerLiteral: 445)
            let conn = NWConnection(to: .hostPort(host: hostEP, port: portEP), using: .tcp)
            
            // Timeout safety for the handshake
            let workItem = DispatchWorkItem {
                if conn.state != .ready {
                    conn.cancel()
                    continuation.resume(returning: false)
                }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.0, execute: workItem)
            
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
