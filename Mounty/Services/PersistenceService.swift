import Foundation

struct PersistenceService {
    private let keyFilers = "SavedFilers"
    private let keyTerminal = "PreferredTerminal"
    private let defaults = UserDefaults.standard
    
    func saveFilers(_ filers: [Filer]) {
        if let encoded = try? JSONEncoder().encode(filers) { defaults.set(encoded, forKey: keyFilers) }
    }
    
    func loadFilers() -> [Filer] {
        if let data = defaults.data(forKey: keyFilers),
           let decoded = try? JSONDecoder().decode([Filer].self, from: data) { return decoded }
        return []
    }
    
    func saveTerminalBundleID(_ bundleID: String) { defaults.set(bundleID, forKey: keyTerminal) }
    func loadTerminalBundleID() -> String { defaults.string(forKey: keyTerminal) ?? "com.apple.Terminal" }
}
