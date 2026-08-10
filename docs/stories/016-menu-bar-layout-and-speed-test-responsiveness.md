# STORY-016: Menu-bar layout and speed-test responsiveness

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Keep Mounty interactive after a speed-test result is dismissed, preserve a stable menu-bar window frame across every view, and retain the selected volume sort preferences.

## Acceptance criteria

- [x] Dismissing a speed-test result or failure clears all speed-test presentation and operation state.
- [x] Main, log, add, edit, and settings views use one stable window width and height.
- [x] The log content and footer use the same bottom spacing as the main view at every window size.
- [x] Sort method and direction persist after returning to the main list and after relaunching.
- [x] Focused tests and project validation pass without project-code warnings.

## Validation

`xcrun swift-format lint --strict -r Mounty MountyTests`, the complete macOS
`xcodebuild` test suite, and `git diff --check` passed. The persistence test
suite includes a sort-preference round trip. Xcode emitted its existing
AppIntents metadata notice because the app has no AppIntents framework
dependency.