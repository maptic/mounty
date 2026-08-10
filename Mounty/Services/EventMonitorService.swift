import AppKit
import Foundation
import Network
import Synchronization

private struct InterfaceMonitorState: Sendable {
    var fingerprint = ""
    var pendingChange: Task<Void, Never>?
}

/// Monitors OS events and exposes them as async sequences.
final class EventMonitorService {

    let networkStatusStream: AsyncStream<NWPath.Status>
    let interfacesChangedStream: AsyncStream<Void>
    let fileSystemChangedStream: AsyncStream<Void>

    private let networkStatusContinuation: AsyncStream<NWPath.Status>.Continuation
    private let interfacesChangedContinuation: AsyncStream<Void>.Continuation
    private let fileSystemChangedContinuation: AsyncStream<Void>.Continuation

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.mounty.network", qos: .background)
    nonisolated private let interfaceState = Mutex(InterfaceMonitorState())

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

            let continuation = interfacesChangedContinuation
            let didChange = interfaceState.withLock { state in
                guard currentInterfaces != state.fingerprint else { return false }
                state.fingerprint = currentInterfaces
                state.pendingChange?.cancel()
                state.pendingChange = Task {
                    do {
                        try await Task.sleep(for: .seconds(1))
                        continuation.yield()
                    } catch {
                        // A newer interface update superseded this one.
                    }
                }
                return true
            }

            if didChange {
                AppLogger.log(
                    "Interface topology changed: \(currentInterfaces)",
                    level: .debug,
                    source: .eventMonitor
                )
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
