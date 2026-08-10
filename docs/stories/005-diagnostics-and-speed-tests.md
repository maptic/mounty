# STORY-005: In-app diagnostics and speed tests

- Status: CLOSED
- Type: feat
- Date: 2026-08-08
- Commits: `a045687`, `502cd57`, `13351cf`

## Intent

Give users an in-app log viewer and a one-shot SMB speed test with honest measurements and dependable cleanup.

## Acceptance criteria

- [x] Logs can be viewed from the menu-bar interface with useful filtering.
- [x] A configured volume can run a one-shot read/write speed test.
- [x] Speed results use uncached measurements and clean up temporary data.
- [x] Header, controls, and footer remain usable at narrow widths.

## Validation

Focused logger and speed-test tests, strict format lint, and the macOS test suite passed.
