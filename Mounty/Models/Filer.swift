import Foundation

struct Filer: Identifiable, Codable, Equatable, Sendable {
    var id = UUID()
    var name: String
    var serverAddress: String
    var isAutomountEnabled: Bool = false
    
    // Helper: Extracts "server.local" from "smb://server.local/share"
    var host: String? {
        return URL(string: serverAddress)?.host
    }
}

enum AppViewMode {
    case list
    case add
    case settings
}
