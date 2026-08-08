import Foundation
import SwiftUI

struct LogEntry: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Date
    let level: Level
    let message: String

    enum Level: Sendable {
        case info, warning, error

        var color: Color {
            switch self {
            case .info: .secondary
            case .warning: .orange
            case .error: .red
            }
        }

        var symbol: String {
            switch self {
            case .info: "circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .error: "xmark.circle.fill"
            }
        }

        var label: String {
            switch self {
            case .info: "INFO"
            case .warning: "WARN"
            case .error: "ERROR"
            }
        }
    }

    // Full-fidelity string used for clipboard export.
    var formatted: String {
        let ts = timestamp.formatted(.dateTime.year().month().day().hour().minute().second())
        return "[\(ts)] [\(level.label)] \(message)"
    }
}
