import Foundation
import Testing

@testable import Mounty

@MainActor
struct PersistenceServiceTests {

    /// Round-trips volumes through an isolated UserDefaults suite so real preferences are untouched.
    @Test func savesAndLoadsVolumes() {
        let suiteName = "MountyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sut = PersistenceService(defaults: defaults)
        let volumes = [
            Volume(name: "NAS", serverAddress: "smb://nas.local/media", isAutomountEnabled: true),
            Volume(name: "Backup", serverAddress: "smb://nas.local/backup"),
        ]

        sut.saveVolumes(volumes)

        #expect(sut.loadVolumes() == volumes)
    }

    @Test func loadReturnsEmptyWhenNothingSaved() {
        let suiteName = "MountyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sut = PersistenceService(defaults: defaults)
        #expect(sut.loadVolumes().isEmpty)
    }

    @Test func savesAndLoadsMinimumLogLevel() {
        let suiteName = "MountyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sut = PersistenceService(defaults: defaults)
        #expect(sut.loadMinimumLogLevel() == .info)

        sut.saveMinimumLogLevel(.warning)

        #expect(sut.loadMinimumLogLevel() == .warning)
    }

    @Test func savesAndLoadsSortPreferences() {
        let suiteName = "MountyTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sut = PersistenceService(defaults: defaults)
        #expect(sut.loadSortOrder() == nil)
        #expect(sut.loadSortDirection() == nil)

        sut.saveSortOrder("State")
        sut.saveSortDirection("descending")

        #expect(sut.loadSortOrder() == "State")
        #expect(sut.loadSortDirection() == "descending")
    }
}
