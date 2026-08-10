# STORY-006: Swift concurrency correctness

- Status: CLOSED
- Type: fix
- Date: 2026-08-08
- Commits: `78369b9`, `c0c8b3b`

## Intent

Parallelize independent automount checks while keeping blocking work off `MainActor` and remove Swift 6 actor-isolation warnings.

## Acceptance criteria

- [x] Independent reachability checks run concurrently where safe.
- [x] Blocking filesystem and mount operations do not run on the UI actor.
- [x] The project builds without Swift concurrency warnings.

## Validation

The project passed strict format lint and `xcodebuild ... test` with signing disabled.
