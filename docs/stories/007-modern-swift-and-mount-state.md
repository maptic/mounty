# STORY-007: Modern Swift and accurate mount state

- Status: CLOSED
- Type: refactor
- Date: 2026-08-09
- Commits: `89fc09d`, `1b0ff8e`, `9e4379d`, `34233ca`

## Intent

Align the implementation with Swift 6 and the `@Observable` architecture while making mount matching and unmount diagnostics exact.

## Acceptance criteria

- [x] View-model observation uses the modern `@Observable` pattern.
- [x] Mount matching compares the extracted host exactly rather than by substring.
- [x] Reads complete across partial `read(2)` results and force-unmount outcomes are logged.
- [x] Services and views use the modernized Swift implementation without introducing warnings.

## Validation

Strict Swift format lint and the complete macOS test suite passed.
