import Foundation

/// Manages persistent storage via UserDefaults.
struct PersistenceService {
    private let keyVolumes = "SavedVolumes"
    private let keyTerminal = "PreferredTerminal"
    private let defaults: UserDefaults

    /// - Parameter defaults: injectable store; defaults to `.standard` (override in tests).
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveVolumes(_ volumes: [Volume]) {
        if let encoded = try? JSONEncoder().encode(volumes) {
            defaults.set(encoded, forKey: keyVolumes)
        }
    }

    func loadVolumes() -> [Volume] {
        if let data = defaults.data(forKey: keyVolumes),
            let decoded = try? JSONDecoder().decode([Volume].self, from: data)
        {
            return decoded
        }
        return []
    }

    func saveTerminalBundleID(_ bundleID: String) {
        defaults.set(bundleID, forKey: keyTerminal)
    }
    func loadTerminalBundleID() -> String {
        defaults.string(forKey: keyTerminal) ?? "com.apple.Terminal"
    }
}
