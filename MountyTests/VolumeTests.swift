import Foundation
import Testing

@testable import Mounty

struct VolumeTests {

    @Test func hostIsParsedFromServerAddress() {
        let volume = Volume(name: "NAS", serverAddress: "smb://nas.local/media")
        #expect(volume.host == "nas.local")
    }

    @Test func hostIsNilForAddressWithoutHost() {
        let volume = Volume(name: "bad", serverAddress: "not-a-url")
        #expect(volume.host == nil)
    }
}
