import Foundation
import Network
import AppKit
import Combine
import os

class EventMonitorService {
    // Publish the status, default to satisfied (connected) so we don't block on launch
    let networkStatus = CurrentValueSubject<NWPath.Status, Never>(.satisfied)
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
            guard let self = self else { return }
            
            let statusStr = path.status == .satisfied ? "Up" : "Down"
            self.logger.debug("Network Path Update: \(statusStr)")
            
            // Emit the new status immediately
            // We use RunLoop.main in the Manager, so it's safe to emit from bg queue here
            self.networkStatus.send(path.status)
        }
        monitor.start(queue: queue)
    }
    
    private func startFileSystemMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        
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
