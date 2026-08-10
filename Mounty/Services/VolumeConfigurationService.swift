import Foundation

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
        var knownIdentities = Set(existingVolumes.map { serverIdentity(for: $0.serverAddress) })
        var importedCount = 0

        for volume in importedVolumes {
            let identity = serverIdentity(for: volume.serverAddress)
            guard !knownIDs.contains(volume.id), !knownIdentities.contains(identity)
            else { continue }

            knownIDs.insert(volume.id)
            knownIdentities.insert(identity)
            mergedVolumes.append(volume)
            importedCount += 1
        }

        return MergeResult(volumes: mergedVolumes, importedCount: importedCount)
    }

    static func hasDuplicateServerIdentity(
        for serverAddress: String,
        in volumes: [Volume],
        excludingID: UUID? = nil
    ) -> Bool {
        let identity = serverIdentity(for: serverAddress)
        return volumes.contains {
            $0.id != excludingID && serverIdentity(for: $0.serverAddress) == identity
        }
    }

    static func serverIdentity(for serverAddress: String) -> String {
        let normalizedAddress = Volume.smbServerAddress(from: serverAddress)
        guard let url = URL(string: normalizedAddress), let host = url.host else {
            return normalizedAddress.lowercased()
        }

        let normalizedPath = url.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { $0.lowercased() }
            .joined(separator: "/")
        return "\(host.lowercased())/\(normalizedPath)"
    }
}
