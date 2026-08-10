# STORY-017: Main list resize layout

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Keep the main list header and footer at their fixed geometry when users resize the menu-bar window beyond the number of configured volumes.

## Acceptance criteria

- [x] Increasing the visible row capacity expands only the main list region.
- [x] Header, resize handle, and footer retain their dimensions with fewer volumes than the selected capacity.
- [x] Focused validation passes.

## Validation

`xcrun swift-format lint --strict -r Mounty MountyTests`, the complete macOS
`xcodebuild` test suite, and `git diff --check` passed.