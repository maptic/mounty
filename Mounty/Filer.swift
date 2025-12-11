import Foundation

struct Filer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var serverAddress: String // e.g., smb://server/share
    var mountPoint: String    // e.g., share
    var isAutomountEnabled: Bool = false
    
    // Computed property to determine where macOS mounts this
    var localPath: URL {
        return URL(fileURLWithPath: "/Volumes/\(mountPoint)")
    }
}