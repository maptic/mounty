import Darwin
import Foundation

struct SpeedTestService {
    struct Result: Sendable {
        let writeSpeed: Double  // MB/s
        let readSpeed: Double  // MB/s
        let fileSizeMB: Double
    }

    // All file I/O runs on a global queue so the Swift cooperative thread pool
    // is never blocked during multi-second network transfers.
    nonisolated static func measure(
        at mountPath: String, fileSizeMB: Double = 10
    ) async throws -> Result {
        // UUID suffix guarantees the file name never collides with an existing
        // user file, even if two tests run concurrently on the same share.
        let testURL = URL(fileURLWithPath: mountPath)
            .appendingPathComponent(".mounty_speed_\(UUID().uuidString)")
        let path = testURL.path
        let byteCount = Int(fileSizeMB * 1024 * 1024)

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // defer runs in all exit paths (success, throw, early return)
                    // so the test file is always removed on the server.
                    // The only exception is a hard process crash (SIGKILL); in that
                    // case a single hidden file (.mounty_speed_<UUID>) is left but
                    // is harmless — it will not overwrite or shadow any user data.
                    defer { removeWithRetry(at: testURL) }

                    let data = Data(count: byteCount)

                    // --- Write ---
                    // F_FULLFSYNC tells the SMB client to commit buffered bytes
                    // to the server before we stop the clock. Without it, write()
                    // returns as soon as the kernel accepts the data locally, which
                    // can be near-instant even for slow links.
                    let writeStart = Date()
                    try data.write(to: testURL)
                    let wfd = Darwin.open(path, O_RDONLY)
                    if wfd >= 0 {
                        _ = Darwin.fcntl(wfd, F_FULLFSYNC)
                        Darwin.close(wfd)
                    }
                    let writeDuration = max(Date().timeIntervalSince(writeStart), 0.001)

                    // --- Read ---
                    // F_NOCACHE bypasses the unified buffer cache. Without it the
                    // OS would serve the just-written bytes from RAM, reporting
                    // multi-GB/s "speeds" that have nothing to do with the network.
                    var readDuration = 0.001
                    let rfd = Darwin.open(path, O_RDONLY)
                    if rfd >= 0 {
                        _ = Darwin.fcntl(rfd, F_NOCACHE, 1)
                        let readStart = Date()
                        var buffer = [UInt8](repeating: 0, count: byteCount)
                        // read(2) may return fewer bytes than requested on network
                        // filesystems; loop until all bytes are consumed or EOF/error.
                        buffer.withUnsafeMutableBytes { ptr in
                            var remaining = byteCount
                            var offset = 0
                            while remaining > 0 {
                                let n = Darwin.read(
                                    rfd, ptr.baseAddress!.advanced(by: offset), remaining
                                )
                                if n <= 0 { break }
                                offset += n
                                remaining -= n
                            }
                        }
                        readDuration = max(Date().timeIntervalSince(readStart), 0.001)
                        Darwin.close(rfd)
                    }

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

    // Retries up to 3 times so a transient network hiccup doesn't leave
    // the test file on the server permanently.
    private nonisolated static func removeWithRetry(at url: URL) {
        for attempt in 1...3 {
            do {
                try FileManager.default.removeItem(at: url)
                return
            } catch {
                if attempt < 3 { Thread.sleep(forTimeInterval: 0.2) }
            }
        }
    }
}
