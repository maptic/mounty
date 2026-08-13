import Foundation
import Testing

@testable import Mounty

private typealias ProbeContinuation = CheckedContinuation<MountProbe, Never>

/// Tests the mount-point liveness probe — the logic that decides whether a kernel mount
/// is healthy, gone, or merely busy. A wrong verdict here makes automount recover (and
/// thus unmount) a share that other processes are actively reading and writing.
struct ReachabilityServiceTests {

    @Test func respondingMountProbesAlive() async {
        #expect(await ReachabilityService.probeMountPoint(path: "/") == .alive)
    }

    @Test func missingPathProbesDead() async {
        let result = await ReachabilityService.probeMountPoint(
            path: "/nonexistent-\(UUID().uuidString)"
        )
        #expect(result == .dead(code: ENOENT))
    }

    @Test func concurrentProbesOfOnePathAllResolve() async {
        let results = await withTaskGroup(of: MountProbe.self) { group in
            for _ in 0..<10 {
                group.addTask { await ReachabilityService.probeMountPoint(path: "/") }
            }
            var results: [MountProbe] = []
            for await result in group { results.append(result) }
            return results
        }
        #expect(results.count == 10)
        #expect(results.allSatisfy { $0 == .alive })
    }

    /// The regression: a caller that hits its deadline must be released as `.indeterminate`
    /// without leaving a verdict behind. Caching it made the next caller — the guard that
    /// decides whether to unmount — see a dead mount that was only slow to answer.
    @Test func timedOutCallerLeavesNoVerdictForLaterCallers() async {
        let registry = MountProbeRegistry()
        let path = "/probe"
        let first = UUID()
        let second = UUID()

        let firstResult = await withCheckedContinuation { (continuation: ProbeContinuation) in
            #expect(registry.register(path: path, token: first, continuation: continuation))
            // The syscall is still outstanding when this caller's deadline elapses.
            let verdict = registry.timeOut(path: path, token: first, hangGrace: .seconds(60))
            #expect(verdict == .indeterminate)
        }
        #expect(firstResult == .indeterminate)

        // The next caller joins the still-running syscall and waits for its real answer.
        let secondResult = await withCheckedContinuation { (continuation: ProbeContinuation) in
            let startsSyscall = registry.register(
                path: path,
                token: second,
                continuation: continuation
            )
            #expect(startsSyscall == false)
            registry.complete(path: path, result: .alive)
        }
        #expect(secondResult == .alive)
    }

    /// A syscall that stays stuck far past any plausible metadata round trip is a dead
    /// mount, not a busy one — the silent-death case automount must still recover.
    @Test func syscallStuckPastTheGraceIntervalProbesDead() async {
        let registry = MountProbeRegistry()
        let path = "/probe"
        let token = UUID()

        let result = await withCheckedContinuation { (continuation: ProbeContinuation) in
            #expect(registry.register(path: path, token: token, continuation: continuation))
            #expect(registry.timeOut(path: path, token: token, hangGrace: .zero) != nil)
        }
        #expect(result == .dead(code: ETIMEDOUT))
    }

    @Test func completedProbeIsNotReusedByTheNextCaller() async {
        let registry = MountProbeRegistry()
        let path = "/probe"

        let result = await withCheckedContinuation { (continuation: ProbeContinuation) in
            #expect(registry.register(path: path, token: UUID(), continuation: continuation))
            registry.complete(path: path, result: .dead(code: ENOTCONN))
        }
        #expect(result == .dead(code: ENOTCONN))

        // A finished probe leaves no entry behind, so the next caller — asserted by the
        // `true` return — starts a fresh syscall instead of reusing the old verdict.
        let laterResult = await withCheckedContinuation { (continuation: ProbeContinuation) in
            #expect(registry.register(path: path, token: UUID(), continuation: continuation))
            registry.complete(path: path, result: .alive)
        }
        #expect(laterResult == .alive)
    }
}
