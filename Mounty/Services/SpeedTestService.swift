import Foundation

struct SpeedTestService {
    struct Result: Sendable {
        let writeSpeed: Double  // MB/s
        let readSpeed: Double  // MB/s
        let fileSizeMB: Double
    }

    // All file I/O is dispatched to a global queue so the Swift cooperative
    // thread pool is never blocked during multi-second network transfers.
    nonisolated static func measure(
        at mountPath: String, fileSizeMB: Double = 10
    ) async throws -> Result {
        let testURL = URL(fileURLWithPath: mountPath)
            .appendingPathComponent(".mounty_speed_\(UUID().uuidString)")
        let byteCount = Int(fileSizeMB * 1024 * 1024)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    defer { try? FileManager.default.removeItem(at: testURL) }

                    let data = Data(count: byteCount)

                    let writeStart = Date()
                    try data.write(to: testURL)
                    let writeDuration = max(Date().timeIntervalSince(writeStart), 0.001)

                    let readStart = Date()
                    _ = try Data(contentsOf: testURL)
                    let readDuration = max(Date().timeIntervalSince(readStart), 0.001)

                    continuation.resume(
                        returning: Result(
                            writeSpeed: fileSizeMB / writeDuration,
                            readSpeed: fileSizeMB / readDuration,
                            fileSizeMB: fileSizeMB
                        ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
