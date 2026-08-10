import Darwin
import Foundation

/// Queries macOS Kernel for active mount points.
struct SystemMountService {
    struct MountPoint: Sendable {
        let path: String
        let source: String
    }

    /// Fetches system mounts via `getmntinfo` (MNT_NOWAIT).
    nonisolated static func getSystemMounts() -> [MountPoint] {
        var mounts: [MountPoint] = []
        var mntbuf: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&mntbuf, MNT_NOWAIT)

        if count > 0, let mntbuf {
            for i in 0..<Int(count) {
                let mnt = mntbuf[i]
                let path = withUnsafePointer(to: mnt.f_mntonname) {
                    $0.withMemoryRebound(
                        to: CChar.self,
                        capacity: Int(MAXPATHLEN)
                    ) { String(cString: $0) }
                }
                let source = withUnsafePointer(to: mnt.f_mntfromname) {
                    $0.withMemoryRebound(
                        to: CChar.self,
                        capacity: Int(MAXPATHLEN)
                    ) { String(cString: $0) }
                }
                mounts.append(MountPoint(path: path, source: source))
            }
        }
        return mounts
    }

    /// Resolves a local mount path from Mounty's volume configuration.
    nonisolated static func findMountPath(
        for volume: Volume,
        in mounts: [MountPoint]
    ) -> String? {
        guard let configUrl = URL(string: volume.serverAddress) else {
            return nil
        }
        guard let host = configUrl.host else { return nil }
        return findMountPath(host: host, path: configUrl.path, in: mounts)
    }

    /// Checks if a network URL is already mounted.
    nonisolated static func findMountPath(forURL url: URL) -> String? {
        guard let host = url.host else { return nil }
        return findMountPath(host: host, path: url.path, in: getSystemMounts())
    }

    private nonisolated static func findMountPath(
        host: String,
        path: String,
        in mounts: [MountPoint]
    ) -> String? {
        let normalizedHost = host.lowercased()
        let normalizedPath = path.lowercased()
        return mounts.first { mount in
            guard extractHost(from: mount.source) == normalizedHost else { return false }
            return normalizedPath.count <= 1
                || mount.source.lowercased().hasSuffix(normalizedPath)
        }?.path
    }

    /// Extracts the hostname from a kernel mount source of the form
    /// "//[domain;user@]host/share". Uses string splitting rather than URL
    /// parsing to correctly handle SMB sources with "domain;user@host" userinfo
    /// that Foundation's URL parser may reject.
    private nonisolated static func extractHost(from source: String) -> String? {
        guard source.hasPrefix("//") else { return nil }
        let withoutSlashes = String(source.dropFirst(2))
        // Take the segment after the last "@" to strip any "domain;user@" prefix.
        let afterAt = withoutSlashes.components(separatedBy: "@").last ?? withoutSlashes
        let host = afterAt.components(separatedBy: "/").first ?? afterAt
        return host.isEmpty ? nil : host.lowercased()
    }
}
