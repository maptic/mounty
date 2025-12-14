import Foundation
import Darwin

struct SystemMountService {
    struct MountPoint: Sendable {
        let path: String
        let source: String
    }
    
    /// Fetches currently mounted filesystems using getmntinfo(3).
    nonisolated static func getSystemMounts() -> [MountPoint] {
        var mounts: [MountPoint] = []
        var mntbuf: UnsafeMutablePointer<statfs>? = nil
        
        // MNT_NOWAIT is critical. It returns cached kernel data immediately.
        // MNT_WAIT would block indefinitely if a drive is hung.
        let count = getmntinfo(&mntbuf, MNT_NOWAIT)
        
        if count > 0, let mntbuf = mntbuf {
            for i in 0..<Int(count) {
                let mnt = mntbuf[i]
                let path = withUnsafePointer(to: mnt.f_mntonname) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
                }
                let source = withUnsafePointer(to: mnt.f_mntfromname) {
                    $0.withMemoryRebound(to: CChar.self, capacity: Int(MAXPATHLEN)) { String(cString: $0) }
                }
                mounts.append(MountPoint(path: path, source: source))
            }
        }
        return mounts
    }
    
    /// Helper to match a Config URL (smb://host/share) to a Mount Source (//user@host/share).
    nonisolated static func findMountPath(for filer: Filer, in mounts: [MountPoint]) -> String? {
        guard let configUrl = URL(string: filer.serverAddress) else { return nil }
        let configPath = configUrl.path.lowercased()
        let configHost = configUrl.host?.lowercased() ?? "unknown"
        
        for mount in mounts {
            let source = mount.source.lowercased()
            if source.contains(configHost) {
                // If config has a path, ensure suffix matches. Otherwise match root host.
                if configPath.count > 1 {
                    if source.hasSuffix(configPath) { return mount.path }
                } else {
                    return mount.path
                }
            }
        }
        return nil
    }
}
