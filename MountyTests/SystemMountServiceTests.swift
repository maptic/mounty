import Foundation
import Testing

@testable import Mounty

/// Tests the mount-detection matching — the core business logic that decides whether a
/// configured volume is currently mounted, by correlating its address with the kernel mount table.
struct SystemMountServiceTests {

    private func volume(_ address: String) -> Volume {
        Volume(name: "test", serverAddress: address)
    }

    @Test func matchesHostAndPathSuffix() {
        let mounts = [
            SystemMountService.MountPoint(
                path: "/Volumes/media",
                source: "//user@nas.local/media"
            )
        ]
        let result = SystemMountService.findMountPath(
            for: volume("smb://nas.local/media"),
            in: mounts
        )
        #expect(result == "/Volumes/media")
    }

    @Test func matchesHostOnlyWhenNoPath() {
        // A bare server address (no share path) matches any mount from that host.
        let mounts = [
            SystemMountService.MountPoint(
                path: "/Volumes/share",
                source: "//nas.local/share"
            )
        ]
        let result = SystemMountService.findMountPath(
            for: volume("smb://nas.local"),
            in: mounts
        )
        #expect(result == "/Volumes/share")
    }

    @Test func matchingIsCaseInsensitive() {
        let mounts = [
            SystemMountService.MountPoint(
                path: "/Volumes/media",
                source: "//nas.local/media"
            )
        ]
        let result = SystemMountService.findMountPath(
            for: volume("smb://NAS.local/Media"),
            in: mounts
        )
        #expect(result == "/Volumes/media")
    }

    @Test func doesNotMatchDifferentHost() {
        let mounts = [
            SystemMountService.MountPoint(
                path: "/Volumes/media",
                source: "//nas.local/media"
            )
        ]
        let result = SystemMountService.findMountPath(
            for: volume("smb://other.local/media"),
            in: mounts
        )
        #expect(result == nil)
    }

    @Test func doesNotMatchWrongSharePath() {
        // Same host, but the configured share path is not the one that is mounted.
        let mounts = [
            SystemMountService.MountPoint(
                path: "/Volumes/media",
                source: "//nas.local/media"
            )
        ]
        let result = SystemMountService.findMountPath(
            for: volume("smb://nas.local/docs"),
            in: mounts
        )
        #expect(result == nil)
    }
}
