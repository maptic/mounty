import AppKit
import Foundation
import Network

/// Monitors OS events and exposes them as async sequences.
class EventMonitorService {

    let networkStatusStream: AsyncStream<NWPath.Status>
    let interfacesChangedStream: AsyncStream<Void>
    let fileSystemChangedStream: AsyncStream<Void>

    private let networkStatusContinuation: AsyncStream<NWPath.Status>.Continuation
    private let interfacesChangedContinuation: AsyncStream<Void>.Continuation
    private let fileSystemChangedContinuation: AsyncStream<Void>.Continuation

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mounty.network", qos: .background)
    // Written and read exclusively on monitorQueue — nonisolated(unsafe) bypasses the
    // implicit @MainActor isolation without requiring an @unchecked Sendable wrapper.
    private nonisolated(unsafe) var lastInterfaceFingerprint = ""
    init() {
        (networkStatusStream, networkStatusContinuation) = AsyncStream.makeStream(
            of: NWPath.Status.self, bufferingPolicy: .bufferingNewest(1)
        )
        (interfacesChangedStream, interfacesChangedContinuation) = AsyncStream.makeStream(
            of: Void.self, bufferingPolicy: .bufferingNewest(1)
        )
        (fileSystemChangedStream, fileSystemChangedContinuation) = AsyncStream.makeStream(
            of: Void.self, bufferingPolicy: .bufferingNewest(1)
        )
        startNetworkMonitoring()
        startFileSystemMonitoring()
    }

    private func startNetworkMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            networkStatusContinuation.yield(path.status)

            let currentInterfaces = path.availableInterfaces
                .map { "\($0.name):\($0.type)" }
                .sorted()
                .joined(separator: ",")

            if currentInterfaces != lastInterfaceFingerprint {
                AppLogger.log(
                    "Interface topology changed: \(currentInterfaces)",
                    level: .debug,
                    source: .eventMonitor
                )
                lastInterfaceFingerprint = currentInterfaces
                // 1-second debounce: let the interface topology settle before
                // triggering a reconnect attempt.
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    self?.interfacesChangedContinuation.yield()
                }
            }
        }
        monitor.start(queue: monitorQueue)
    }

    private func startFileSystemMonitoring() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification,
        ] {
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                AppLogger.log(
                    "Kernel filesystem event received: \(name.rawValue)",
                    level: .debug,
                    source: .eventMonitor
                )
                self?.fileSystemChangedContinuation.yield()
            }
        }
    }
}
