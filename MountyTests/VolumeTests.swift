import Testing

@testable import Mounty

struct VolumeTests {
    @Test func normalizesSMBServerAddresses() {
        #expect(Volume.shareAddress(from: "nas.local/media") == "nas.local/media")
        #expect(Volume.shareAddress(from: "smb://nas.local/media") == "nas.local/media")
        #expect(Volume.smbServerAddress(from: "ftp://nas.local/media") == "smb://nas.local/media")
    }
}
