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
        var mntbuf: UnsafeMutablePointer<statfs>? = nil
        let count = getmntinfo(&mntbuf, MNT_NOWAIT)

        if count > 0, let mntbuf = mntbuf {
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

    /// Resolves local mount path from Filer configuration.
    nonisolated static func findMountPath(
        for volume: Volume,
        in mounts: [MountPoint]
    ) -> String? {
        guard let configUrl = URL(string: volume.serverAddress) else {
            return nil
        }
        let configPath = configUrl.path.lowercased()
        let configHost = configUrl.host?.lowercased() ?? "unknown"

        for mount in mounts {
            guard extractHost(from: mount.source) == configHost else { continue }
            if configPath.count > 1 {
                if mount.source.lowercased().hasSuffix(configPath) { return mount.path }
            } else {
                return mount.path
            }
        }
        return nil
    }

    /// Checks if a network URL is already mounted.
    nonisolated static func findMountPath(forURL url: URL) -> String? {
        let mounts = getSystemMounts()
        let host = url.host?.lowercased() ?? "unknown"
        let path = url.path.lowercased()

        for mount in mounts {
            guard extractHost(from: mount.source) == host else { continue }
            if path.count > 1 {
                if mount.source.lowercased().hasSuffix(path) { return mount.path }
            } else {
                return mount.path
            }
        }
        return nil
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
