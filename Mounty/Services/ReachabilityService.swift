import Foundation
import Network

/// Reachability Service (The Sensor)
struct ReachabilityService {
    
    /// Filesystem I/O Check.
    /// Checks if the kernel allows reading the directory.
    nonisolated static func isMountPointAlive(path: String) -> Bool {
        let group = DispatchGroup()
        group.enter()
        var isAlive = false
        
        DispatchQueue.global(qos: .userInteractive).async {
            // Force I/O
            if let _ = try? FileManager.default.contentsOfDirectory(atPath: path) {
                isAlive = true
            }
            group.leave()
        }
        
        // Strict 1.0s timeout for hung filesystems
        let result = group.wait(timeout: .now() + 1.0)
        return result == .success && isAlive
    }
    
    /// Network TCP Check (Port 445).
    /// Detects missing routes (VPN drops) almost instantly.
    static func isServerReachable(address: String) async -> Bool {
        guard let host = URL(string: address)?.host else { return false }
        
        return await withCheckedContinuation { continuation in
            let hostEP = NWEndpoint.Host(host)
            let portEP = NWEndpoint.Port(integerLiteral: 445)
            let conn = NWConnection(to: .hostPort(host: hostEP, port: portEP), using: .tcp)
            
            // 2s Handshake timeout
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
                    workItem.cancel(); conn.cancel()
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
