import Foundation
import Network
import AppKit
import Combine
import os

class EventMonitorService {
    // Publishers for the ViewModel to subscribe to
    let networkChanged = PassthroughSubject<Void, Never>()
    let fileSystemChanged = PassthroughSubject<Void, Never>()
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.mounty.network", qos: .background)
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Mounty", category: "EventMonitor")
    
    init() {
        startNetworkMonitoring()
        startFileSystemMonitoring()
    }
    
    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.logger.debug("Network path changed: \(path.status == .satisfied ? "Up" : "Down")")
            
            // Debounce to avoid rapid flickering (e.g., switching WiFi APs)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self?.networkChanged.send()
            }
        }
        monitor.start(queue: queue)
    }
    
    private func startFileSystemMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        
        // React immediately when drives are mounted/unmounted externally
        Publishers.Merge3(
            center.publisher(for: NSWorkspace.didMountNotification),
            center.publisher(for: NSWorkspace.didUnmountNotification),
            center.publisher(for: NSWorkspace.didRenameVolumeNotification)
        )
        .sink { [weak self] note in
            self?.logger.debug("Filesystem event: \(note.name.rawValue)")
            self?.fileSystemChanged.send()
        }
        .store(in: &cancellables)
    }
}
