# STORY-018: Settings scrolling and dialog presentation

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Keep settings accessible when they exceed the menu-bar frame and ensure dismissing speed-test dialogs immediately restores interaction with Mounty.

## Acceptance criteria

- [x] Settings scroll with automatic indicators when their content exceeds the available height.
- [x] Speed-test result and error dialogs use direct presentation state and clear the completed test state on dismissal.
- [x] Focused validation passes.

## Validation

`xcrun swift-format lint --strict -r Mounty MountyTests`, the complete macOS
`xcodebuild` test suite, and `git diff --check` passed.