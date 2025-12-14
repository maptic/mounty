import Foundation
import Network
import AppKit
import Combine
import os

/// Monitors OS events to trigger application logic.
/// Tracks Network Status, Interface changes (VPN), and FileSystem mounts.
class EventMonitorService {
    // Signals
    let networkStatus = CurrentValueSubject<NWPath.Status, Never>(.satisfied)
    let interfacesChanged = PassthroughSubject<Void, Never>()
    let fileSystemChanged = PassthroughSubject<Void, Never>()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mounty.network", qos: .background)
    private var cancellables = Set<AnyCancellable>()
    private var lastInterfaceFingerprint: String = ""
    
    init() {
        startNetworkMonitoring()
        startFileSystemMonitoring()
    }
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            
            // 1. Update Global Status
            self.networkStatus.send(path.status)
            
            // 2. Interface Fingerprinting (VPN Detection)
            // Detects if interfaces (utun, gpd, en0) appear or disappear.
            let currentInterfaces = path.availableInterfaces
                .map { "\($0.name):\($0.type)" }
                .sorted()
                .joined(separator: ",")
            
            if currentInterfaces != self.lastInterfaceFingerprint {
                self.lastInterfaceFingerprint = currentInterfaces
                
                // Debounce to allow VPN routes/DNS to settle before triggering Automount
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.interfacesChanged.send()
                }
            }
        }
        monitor.start(queue: queue)
    }
    
    private func startFileSystemMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        Publishers.Merge3(
            center.publisher(for: NSWorkspace.didMountNotification),
            center.publisher(for: NSWorkspace.didUnmountNotification),
            center.publisher(for: NSWorkspace.didRenameVolumeNotification)
        ).sink { [weak self] _ in self?.fileSystemChanged.send() }
        .store(in: &cancellables)
    }
}
