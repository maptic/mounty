import Foundation
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

    @Test func reportsFailureBeforeCleanupRetriesFinish() async {
        let missingMount = "/tmp/mounty-missing-\(UUID().uuidString)/share"
        let clock = ContinuousClock()
        let start = clock.now

        await #expect(throws: (any Error).self) {
            try await SpeedTestService.measure(at: missingMount, fileSizeMB: 0.001)
        }

        #expect(start.duration(to: clock.now) < .milliseconds(300))
    }
}
