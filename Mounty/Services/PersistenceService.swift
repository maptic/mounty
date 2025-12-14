import Foundation

struct PersistenceService {
    private let key = "SavedFilers"
    private let defaults = UserDefaults.standard
    
    func save(_ filers: [Filer]) {
        if let encoded = try? JSONEncoder().encode(filers) {
            defaults.set(encoded, forKey: key)
        }
    }
    
    func load() -> [Filer] {
        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([Filer].self, from: data) {
            return decoded
        }
        return []
    }
}
