import Foundation

/// Manages persistent storage via UserDefaults.
struct PersistenceService {
    private let keyVolumes = "SavedVolumes"
    private let keyTerminal = "PreferredTerminal"
    private let keyMinimumLogLevel = "MinimumLogLevel"
    private let keySortOrder = "SortOrder"
    private let keySortDirection = "SortDirection"
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

    func saveMinimumLogLevel(_ level: LogEntry.Level) {
        defaults.set(level.rawValue, forKey: keyMinimumLogLevel)
    }

    func loadMinimumLogLevel() -> LogEntry.Level {
        guard let rawValue = defaults.string(forKey: keyMinimumLogLevel) else { return .info }
        return LogEntry.Level(rawValue: rawValue) ?? .info
    }

    func saveSortOrder(_ rawValue: String) {
        defaults.set(rawValue, forKey: keySortOrder)
    }

    func loadSortOrder() -> String? {
        defaults.string(forKey: keySortOrder)
    }

    func saveSortDirection(_ rawValue: String) {
        defaults.set(rawValue, forKey: keySortDirection)
    }

    func loadSortDirection() -> String? {
        defaults.string(forKey: keySortDirection)
    }
}
