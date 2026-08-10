import Foundation
import SwiftUI

struct LogEntry: Identifiable, Sendable {
    nonisolated let id: UUID
    nonisolated let timestamp: Date
    nonisolated let level: Level
    nonisolated let source: Source
    nonisolated let message: String

    nonisolated init(
        id: UUID = UUID(),
        timestamp: Date,
        level: Level,
        source: Source,
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.source = source
        self.message = message
    }

    enum Source: String, Sendable {
        case manager = "Manager"
        case mountService = "MountService"
        case eventMonitor = "EventMonitor"
        case reachability = "Reachability"

        nonisolated var label: String { rawValue }
    }

    enum Level: String, Sendable, Comparable, CaseIterable {
        case debug, info, warning, error

        nonisolated static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.severity < rhs.severity
        }

        nonisolated private var severity: Int {
            switch self {
            case .debug: 0
            case .info: 1
            case .warning: 2
            case .error: 3
            }
        }

        var color: Color {
            switch self {
            case .debug: .secondary.opacity(0.6)
            case .info: .secondary
            case .warning: .orange
            case .error: .red
            }
        }

        var symbol: String {
            switch self {
            case .debug: "circle"
            case .info: "circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.circle.fill"
            }
        }

        nonisolated var label: String {
            switch self {
            case .debug: "DEBUG"
            case .info: "INFO"
            case .warning: "WARN"
            case .error: "ERROR"
            }
        }
    }

    // Full-fidelity string used for clipboard export.
    nonisolated var formatted: String {
        let ts = timestamp.formatted(.dateTime.year().month().day().hour().minute().second())
        return "[\(ts)] [\(level.label)] [\(source.label)] \(message)"
    }
}
