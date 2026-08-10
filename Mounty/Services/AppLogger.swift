import Foundation
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

private final class LogHub: @unchecked Sendable {
    private let lock = NSLock()
    private nonisolated(unsafe) var history: [LogEntry] = []
    private nonisolated(unsafe) var subscribers: [UUID: AsyncStream<LogEntry>.Continuation] = [:]

    nonisolated func makeStream() -> AsyncStream<LogEntry> {
        let subscriberID = UUID()
        return AsyncStream(bufferingPolicy: .bufferingNewest(500)) { continuation in
            lock.withLock {
                subscribers[subscriberID] = continuation
                for entry in history {
                    continuation.yield(entry)
                }
            }
            continuation.onTermination = { [weak self] _ in
                self?.removeSubscriber(subscriberID)
            }
        }
    }

    nonisolated func emit(_ entry: LogEntry) {
        let continuations = lock.withLock {
            history.append(entry)
            if history.count > 500 {
                history.removeFirst(history.count - 500)
            }
            return Array(subscribers.values)
        }
        for continuation in continuations {
            continuation.yield(entry)
        }
    }

    nonisolated func clearHistory() {
        lock.withLock { history.removeAll() }
    }

    nonisolated private func removeSubscriber(_ id: UUID) {
        lock.withLock { _ = subscribers.removeValue(forKey: id) }
    }
}
