import Foundation

// Defines the data structure for a network share
struct Filer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var serverAddress: String
    var isAutomountEnabled: Bool = false
    
    // Helper to extract "192.168.1.1" from "smb://192.168.1.1/share"
    var host: String? {
        return URL(string: serverAddress)?.host
    }
}

// Defines the navigation state of the popup window
enum AppViewMode {
    case list
    case add
    case settings
}
