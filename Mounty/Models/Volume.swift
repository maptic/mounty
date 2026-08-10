import Foundation

struct Volume: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var serverAddress: String
    var isAutomountEnabled: Bool = false
    var dateAdded: Date = Date()

    nonisolated static func shareAddress(from value: String) -> String {
        guard let separator = value.range(of: "://") else { return value }
        return String(value[separator.upperBound...])
    }

    nonisolated static func smbServerAddress(from value: String) -> String {
        "smb://\(shareAddress(from: value))"
    }

    // Explicit nonisolated conformance so Equatable can be used freely across
    // actor boundaries (otherwise the implicit @MainActor isolation from the
    // project-wide default would produce a warning in nonisolated contexts).
    nonisolated static func == (lhs: Volume, rhs: Volume) -> Bool {
        lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.serverAddress == rhs.serverAddress
            && lhs.isAutomountEnabled == rhs.isAutomountEnabled
            && lhs.dateAdded == rhs.dateAdded
    }
}

enum AppViewMode: Equatable { case list, add, settings, logs, edit(Volume) }
