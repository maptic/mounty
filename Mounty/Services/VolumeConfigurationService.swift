struct VolumeConfigurationService {
    struct MergeResult: Sendable {
        let volumes: [Volume]
        let importedCount: Int
    }

    static func merging(
        _ importedVolumes: [Volume],
        into existingVolumes: [Volume]
    ) -> MergeResult {
        var mergedVolumes = existingVolumes
        var knownIDs = Set(existingVolumes.map(\.id))
        var knownAddresses = Set(existingVolumes.map(\.serverAddress))
        var importedCount = 0

        for volume in importedVolumes {
            guard !knownIDs.contains(volume.id), !knownAddresses.contains(volume.serverAddress)
            else { continue }

            knownIDs.insert(volume.id)
            knownAddresses.insert(volume.serverAddress)
            mergedVolumes.append(volume)
            importedCount += 1
        }

        return MergeResult(volumes: mergedVolumes, importedCount: importedCount)
    }
}
