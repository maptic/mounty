import Foundation

struct Volume: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var serverAddress: String
    var isAutomountEnabled: Bool = false
    var dateAdded: Date = Date()

    var host: String? { URL(string: serverAddress)?.host }

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
