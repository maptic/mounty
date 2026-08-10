# STORY-019: Copy mounted path

- Status: CLOSED
- Type: feat
- Date: 2026-08-10
- Commit: _none_

## Intent

Let users copy a mounted volume's local filesystem path from the context menu for use in scripts and other tools.

## Acceptance criteria

- [x] Mounted volume context menus include a Copy Mount Path action.
- [x] The action copies the resolved local mount path to the pasteboard.
- [x] The action is unavailable for disconnected volumes.
- [x] Focused validation passes.

## Validation

`xcrun swift-format lint --strict -r Mounty MountyTests`, the complete macOS
`xcodebuild` test suite, and `git diff --check` passed.