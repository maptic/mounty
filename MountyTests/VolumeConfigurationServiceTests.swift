import Foundation
import Testing

@testable import Mounty

@MainActor
struct VolumeConfigurationServiceTests {
    @Test func skipsExistingIDsAndAddresses() {
        let existing = Volume(
            id: UUID(),
            name: "Media",
            serverAddress: "smb://nas.local/media"
        )
        let valid = Volume(
            id: UUID(),
            name: "Archive",
            serverAddress: "smb://nas.local/archive"
        )
        let imported = [
            Volume(
                id: existing.id,
                name: "Duplicate ID",
                serverAddress: "smb://nas.local/other"
            ),
            Volume(
                id: UUID(),
                name: "Duplicate Address",
                serverAddress: existing.serverAddress
            ),
            valid,
        ]

        let result = VolumeConfigurationService.merging(imported, into: [existing])

        #expect(result.importedCount == 1)
        #expect(result.volumes == [existing, valid])
    }

    @Test func skipsDuplicateIdentitiesWithinImport() {
        let sharedID = UUID()
        let first = Volume(
            id: sharedID,
            name: "First",
            serverAddress: "smb://nas.local/first"
        )
        let imported = [
            first,
            Volume(
                id: sharedID,
                name: "Duplicate ID",
                serverAddress: "smb://nas.local/second"
            ),
            Volume(
                id: UUID(),
                name: "Duplicate Address",
                serverAddress: first.serverAddress
            ),
        ]

        let result = VolumeConfigurationService.merging(imported, into: [])

        #expect(result.importedCount == 1)
        #expect(result.volumes == [first])
    }

    @Test func treatsSMBHostsAndPathsAsCaseInsensitive() {
        let existing = Volume(
            name: "Media",
            serverAddress: "smb://NAS.local/Media/"
        )
        let duplicate = Volume(
            name: "Duplicate",
            serverAddress: "smb://nas.local/media"
        )

        #expect(
            VolumeConfigurationService.hasDuplicateServerIdentity(
                for: duplicate.serverAddress,
                in: [existing]
            )
        )

        let result = VolumeConfigurationService.merging([duplicate], into: [existing])
        #expect(result.importedCount == 0)
        #expect(result.volumes == [existing])
    }

    @Test func excludesEditedVolumeFromDuplicateCheck() {
        let existing = Volume(
            name: "Media",
            serverAddress: "smb://nas.local/media"
        )

        #expect(
            !VolumeConfigurationService.hasDuplicateServerIdentity(
                for: "smb://NAS.local/Media/",
                in: [existing],
                excludingID: existing.id
            )
        )
    }

    @Test func validatesReachableSMBEndpoints() {
        #expect(VolumeConfigurationService.isValidServerAddress("smb://nas.local/media"))
        #expect(VolumeConfigurationService.isValidServerAddress("nas.local/media"))
        #expect(!VolumeConfigurationService.isValidServerAddress("/media"))
        #expect(!VolumeConfigurationService.isValidServerAddress("smb:///media"))
        #expect(!VolumeConfigurationService.isValidServerAddress("smb://nas.local:1445/media"))
    }

    @Test func skipsInvalidAddressesDuringImport() {
        let invalid = Volume(name: "Invalid", serverAddress: "smb:///media")
        let valid = Volume(name: "Media", serverAddress: "smb://nas.local/media")

        let result = VolumeConfigurationService.merging([invalid, valid], into: [])

        #expect(result.importedCount == 1)
        #expect(result.volumes == [valid])
    }
}
