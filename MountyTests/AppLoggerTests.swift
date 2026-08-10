import Testing

@testable import Mounty

struct AppLoggerTests {
    @Test func emitsCategorizedEntryForInAppLog() async {
        let expectedMessage = "Mount started: filer.example/share"
        let nextEntry = Task<LogEntry?, Never> {
            for await entry in AppLogger.entries where entry.message == expectedMessage {
                return entry
            }
            return nil
        }

        AppLogger.log(expectedMessage, level: .debug, source: .mountService)

        let entry = await nextEntry.value
        #expect(entry?.level == .debug)
        #expect(entry?.source == .mountService)
        #expect(entry?.message == expectedMessage)
        #expect(entry?.formatted.contains("[MountService] \(expectedMessage)") == true)
    }
}
