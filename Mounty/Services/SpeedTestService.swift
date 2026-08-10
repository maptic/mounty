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
        guard byteCount > 0 else { throw SpeedTestError.invalidFileSize }

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = Data(count: byteCount)

                    // --- Write ---
                    // F_FULLFSYNC tells the SMB client to commit buffered bytes
                    // to the server before we stop the clock. Without it, write()
                    // returns as soon as the kernel accepts the data locally, which
                    // can be near-instant even for slow links.
                    let writeStart = Date()
                    try data.write(to: testURL)
                    let writeDescriptor = Darwin.open(path, O_RDONLY)
                    guard writeDescriptor >= 0 else { throw posixError() }
                    defer { Darwin.close(writeDescriptor) }
                    try synchronize(writeDescriptor)
                    let writeDuration = max(Date().timeIntervalSince(writeStart), 0.001)

                    // --- Read ---
                    // F_NOCACHE bypasses the unified buffer cache. Without it the
                    // OS would serve the just-written bytes from RAM, reporting
                    // multi-GB/s "speeds" that have nothing to do with the network.
                    let readDescriptor = Darwin.open(path, O_RDONLY)
                    guard readDescriptor >= 0 else { throw posixError() }
                    defer { Darwin.close(readDescriptor) }
                    try disableCaching(readDescriptor)

                    let readStart = Date()
                    var buffer = [UInt8](repeating: 0, count: byteCount)
                    let bytesRead = try buffer.withUnsafeMutableBytes { pointer in
                        guard let baseAddress = pointer.baseAddress else {
                            throw SpeedTestError.invalidFileSize
                        }
                        var offset = 0
                        while offset < byteCount {
                            let count = Darwin.read(
                                readDescriptor,
                                baseAddress.advanced(by: offset),
                                byteCount - offset
                            )
                            if count < 0 { throw posixError() }
                            if count == 0 { break }
                            offset += count
                        }
                        return offset
                    }
                    guard bytesRead == byteCount else {
                        throw SpeedTestError.incompleteRead(expected: byteCount, actual: bytesRead)
                    }
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

                // Resume the caller before cleanup. Removing a file from an
                // unavailable SMB share can block or retry, but must never delay
                // publishing the result back to the UI.
                removeWithRetry(at: testURL)
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

    private nonisolated static func synchronize(_ descriptor: Int32) throws {
        if Darwin.fcntl(descriptor, F_FULLFSYNC) == 0 { return }

        let fullSyncError = errno
        guard isUnsupportedFileControl(fullSyncError) else {
            throw posixError(code: fullSyncError)
        }
        guard Darwin.fsync(descriptor) == 0 else { throw posixError() }
    }

    private nonisolated static func disableCaching(_ descriptor: Int32) throws {
        if Darwin.fcntl(descriptor, F_NOCACHE, 1) == 0 { return }

        let noCacheError = errno
        guard isUnsupportedFileControl(noCacheError) else {
            throw posixError(code: noCacheError)
        }
    }

    private nonisolated static func isUnsupportedFileControl(_ code: Int32) -> Bool {
        code == ENOTSUP || code == EINVAL || code == ENOTTY
    }

    private nonisolated static func posixError(code: Int32 = errno) -> NSError {
        NSError(domain: NSPOSIXErrorDomain, code: Int(code))
    }

    private enum SpeedTestError: LocalizedError {
        case invalidFileSize
        case incompleteRead(expected: Int, actual: Int)

        nonisolated var errorDescription: String? {
            switch self {
            case .invalidFileSize:
                "Speed test size must be greater than zero."
            case .incompleteRead(let expected, let actual):
                "Speed test read \(actual) of \(expected) bytes."
            }
        }
    }
}
