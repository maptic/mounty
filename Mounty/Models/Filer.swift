import Foundation

struct Filer: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var serverAddress: String // e.g., smb://server/share
    var isAutomountEnabled: Bool = false
    
    var host: String? { URL(string: serverAddress)?.host }
}

enum AppViewMode { case list, add, settings }
