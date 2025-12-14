//
//  NetworkService.swift
//  Mounty
//
//  Created by Merlin Unterfinger on 12.12.2025.
//


import Foundation
import Network

/// Handles TCP Reachability checks to prevent trying to mount when offline
struct NetworkService {
    
    static func isPortReachable(host: String, port: UInt16 = 445) async -> Bool {
        return await withCheckedContinuation { continuation in
            let hostEP = NWEndpoint.Host(host)
            let portEP = NWEndpoint.Port(integerLiteral: port)
            let conn = NWConnection(to: .hostPort(host: hostEP, port: portEP), using: .tcp)
            
            // Safety timeout
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
