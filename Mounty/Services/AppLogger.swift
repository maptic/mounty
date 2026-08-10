import Foundation
import Synchronization
import os

/// Routes Mounty-owned diagnostics to Unified Logging and the in-app log stream.
struct AppLogger {
    nonisolated private static let hub = LogHub()

    nonisolated static var entries: AsyncStream<LogEntry> {
        hub.makeStream()
    }

    nonisolated static func log(
        _ message: String,
        level: LogEntry.Level = .info,
        source: LogEntry.Source
    ) {
        let logger = Logger(subsystem: "ch.maptic.Mounty", category: source.label)
        switch level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .info: logger.info("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }

        hub.emit(
            LogEntry(timestamp: Date(), level: level, source: source, message: message)
        )
    }

    nonisolated static func clearHistory() {
        hub.clearHistory()
    }
}

private final class LogHub: Sendable {
    private struct State {
        var history: [LogEntry] = []
        var subscribers: [UUID: AsyncStream<LogEntry>.Continuation] = [:]
    }

    private let state = Mutex(State())

    nonisolated func makeStream() -> AsyncStream<LogEntry> {
        let subscriberID = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(500)) { continuation in
            state.withLock { state in
                state.subscribers[subscriberID] = continuation
                for entry in state.history {
                    continuation.yield(entry)
                }
            }
            continuation.onTermination = { [weak self] _ in
                self?.removeSubscriber(subscriberID)
            }
        }
    }

    nonisolated func emit(_ entry: LogEntry) {
        let continuations = state.withLock { state in
            state.history.append(entry)
            if state.history.count > 500 {
                state.history.removeFirst(state.history.count - 500)
            }
            return Array(state.subscribers.values)
        }
        for continuation in continuations {
            continuation.yield(entry)
        }
    }

    nonisolated func clearHistory() {
        state.withLock { $0.history.removeAll() }
    }

    nonisolated private func removeSubscriber(_ id: UUID) {
        state.withLock { _ = $0.subscribers.removeValue(forKey: id) }
    }
}
