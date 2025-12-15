import Foundation

struct Volume: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var serverAddress: String
    var isAutomountEnabled: Bool = false
    var dateAdded: Date = Date()

    var host: String? { URL(string: serverAddress)?.host }
}

enum AppViewMode { case list, add, settings }
