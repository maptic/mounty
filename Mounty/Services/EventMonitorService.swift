import AppKit
import Combine
import Foundation
import Network
import os

/// Monitors OS events to trigger application logic.
/// Observes Network Status, Interface Fingerprints (VPN), and Kernel Mount events.
class EventMonitorService {

    let networkStatus = CurrentValueSubject<NWPath.Status, Never>(.satisfied)
    let interfacesChanged = PassthroughSubject<Void, Never>()
    let fileSystemChanged = PassthroughSubject<Void, Never>()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(
        label: "com.mounty.network",
        qos: .background
    )
    private var cancellables = Set<AnyCancellable>()
    private var lastInterfaceFingerprint: String = ""
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Mounty",
        category: "EventMonitor"
    )

    init() {
        startNetworkMonitoring()
        startFileSystemMonitoring()
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }

            self.networkStatus.send(path.status)

            // Fingerprint interfaces to detect VPN tunnels
            let currentInterfaces = path.availableInterfaces
                .map { "\($0.name):\($0.type)" }
                .sorted()
                .joined(separator: ",")

            if currentInterfaces != self.lastInterfaceFingerprint {
                self.logger.debug(
                    "Interface topology changed: \(currentInterfaces, privacy: .public)"
                )
                self.lastInterfaceFingerprint = currentInterfaces

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
        ).sink { [weak self] _ in
            self?.logger.debug("Kernel filesystem event received")
            self?.fileSystemChanged.send()
        }
        .store(in: &cancellables)
    }
}
