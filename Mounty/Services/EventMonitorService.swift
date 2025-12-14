import Foundation
import Network
import AppKit
import Combine
import os

/// Monitors OS events to trigger application logic.
/// Observes Network Status, Interface Fingerprints (VPN), and Kernel Mount events.
class EventMonitorService {
    
    let networkStatus = CurrentValueSubject<NWPath.Status, Never>(.satisfied)
    let interfacesChanged = PassthroughSubject<Void, Never>()
    let fileSystemChanged = PassthroughSubject<Void, Never>()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mounty.network", qos: .background)
    private var cancellables = Set<AnyCancellable>()
    private var lastInterfaceFingerprint: String = ""
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Mounty", category: "EventMonitor")
    
    init() {
        startNetworkMonitoring()
        startFileSystemMonitoring()
    }
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            
            // Update Global Status
            self.networkStatus.send(path.status)
            
            // VPN Detection: Fingerprint active interfaces
            let currentInterfaces = path.availableInterfaces
                .map { "\($0.name):\($0.type)" }
                .sorted()
                .joined(separator: ",")
            
            if currentInterfaces != self.lastInterfaceFingerprint {
                self.logger.debug("Interface change detected. Fingerprint: \(currentInterfaces, privacy: .public)")
                self.lastInterfaceFingerprint = currentInterfaces
                
                // Debounce to allow routing tables to settle
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
        ).sink { [weak self] note in
            self?.logger.debug("FileSystem event: \(note.name.rawValue, privacy: .public)")
            self?.fileSystemChanged.send()
        }
        .store(in: &cancellables)
    }
}
