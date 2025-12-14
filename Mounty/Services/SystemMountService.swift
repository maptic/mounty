import Foundation
import Darwin

struct SystemMountService {
    struct MountPoint: Sendable {
        let path: String
        let source: String
    }
    
    /// Low-level C-API call to get mount table
    nonisolated static func getSystemMounts() -> [MountPoint] {
        var mounts: [MountPoint] = []
        var mntbuf: UnsafeMutablePointer<statfs>? = nil
        // MNT_NOWAIT is crucial to avoid hanging on dead mounts during enumeration
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
    
    /// Matches a Filer config (smb://host/share) to a System Mount (//user@host/share)
    nonisolated static func findMountPath(for filer: Filer, in mounts: [MountPoint]) -> String? {
        guard let configUrl = URL(string: filer.serverAddress) else { return nil }
        let configPath = configUrl.path.lowercased() // e.g., "/share"
        let configHost = configUrl.host?.lowercased() ?? "unknown"
        
        for mount in mounts {
            let source = mount.source.lowercased()
            
            // Check 1: Host match
            if source.contains(configHost) {
                // Check 2: Path match (if share path is specified)
                if configPath.count > 1 {
                    if source.hasSuffix(configPath) { return mount.path }
                } else {
                    // Root mount
                    return mount.path
                }
            }
        }
        return nil
    }
}
