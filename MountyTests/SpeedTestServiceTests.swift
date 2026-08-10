import Testing

@testable import Mounty

struct SpeedTestServiceTests {
    @Test func rejectsNonpositiveFileSize() async {
        await #expect(throws: (any Error).self) {
            try await SpeedTestService.measure(at: "/", fileSizeMB: 0)
        }
        await #expect(throws: (any Error).self) {
            try await SpeedTestService.measure(at: "/", fileSizeMB: -1)
        }
    }
}
