import Foundation

struct Filer: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var serverAddress: String
    var isAutomountEnabled: Bool = false
    
    var host: String? {
        return URL(string: serverAddress)?.host
    }
}
