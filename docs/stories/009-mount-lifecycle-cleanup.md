# STORY-009: Mount lifecycle cleanup and failure handling

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Keep SMB shares managed during removal, reset, and edits by unmounting explicitly and preserving configuration when unmounting fails.

## Acceptance criteria

- [x] Removing or resetting a mounted volume unmounts it before deleting its configuration.
- [x] Failed unmounts retain the volume configuration and mounted state, with actionable feedback.
- [x] Editing a mounted volume stops before reconnecting when its old mount cannot be unmounted.
- [x] Manual unmount failure is reported accurately.

## Validation

`swift-format lint --strict Mounty/ViewModels/VolumeManager.swift` and
`xcodebuild -scheme Mounty -destination 'platform=macOS,arch=arm64' test
CODE_SIGNING_ALLOWED=NO` passed. Editor diagnostics reported no errors.