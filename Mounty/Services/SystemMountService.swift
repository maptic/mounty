import Foundation
import Darwin

/// **State Service (The Inspector)**
///
/// This service queries the macOS Kernel (via `getmntinfo`) to see what is
/// *actually* mounted on the system right now.
///
/// It acts as the "Source of Truth" to handle cases where:
/// - The user mounted a drive via Finder.
/// - The user ejected a drive via Trash.
/// - The OS auto-mounted a drive at a different path (e.g. `/Volumes/Share-1`).
struct SystemMountService {
    
    struct MountPoint: Sendable {
        let path: String
        let source: String
    }
    
    /// Low-level C-API call to get the system mount table.
    /// Marked `nonisolated` to allow safe background execution.
    nonisolated static func getSystemMounts() -> [MountPoint] {
        var mounts: [MountPoint] = []
        var mntbuf: UnsafeMutablePointer<statfs>? = nil
        
        // MNT_NOWAIT returns immediately with cached kernel data.
        // Critical for app performance to avoid hanging on dead mounts.
        let count = getmntinfo(&mntbuf, MNT_NOWAIT)
        
        if count > 0, let mntbuf = mntbuf {
            for i in 0..<Int(count) {
                let mnt = mntbuf[i]
                
                // Convert C-Strings to Swift Strings
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
    
    /// Logic to find which local path corresponds to a specific Filer configuration.
    nonisolated static func findMountPath(for filer: Filer, in mounts: [MountPoint]) -> String? {
        guard let configUrl = URL(string: filer.serverAddress) else { return nil }
        let configPath = configUrl.path.lowercased()
        let configHost = configUrl.host?.lowercased() ?? "unknown"
        
        for mount in mounts {
            let source = mount.source.lowercased()
            
            // Check if the mount source contains the host we are looking for
            if source.contains(configHost) {
                // If config has a specific share path (e.g. /Data), match the suffix
                if configPath.count > 1 {
                    if source.hasSuffix(configPath) { return mount.path }
                } else {
                    // Otherwise, match the root mount
                    return mount.path
                }
            }
        }
        return nil
    }
}
