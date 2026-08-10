# STORY-010: Volume operation safety

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Prevent overlapping mount, edit, remove, and reset operations from leaving unmanaged mounts or deleting configurations created after a reset begins.

## Acceptance criteria

- [x] Destructive or mutating actions cannot overlap an active operation for the same volume.
- [x] Reset does not overlap active volume operations or start new automounts while unmounting.
- [x] Reset removes only configurations that existed when it began and retains configurations whose unmount fails.
- [x] Relevant focused checks and the full test suite pass.

## Validation

`swift-format lint --strict` passed for the four touched Swift files. Editor diagnostics reported no errors. `xcodebuild -scheme Mounty -destination 'platform=macOS,arch=arm64' test CODE_SIGNING_ALLOWED=NO` passed.
