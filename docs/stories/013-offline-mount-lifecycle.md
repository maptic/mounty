# STORY-013: Offline mount lifecycle preservation

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Keep configurations managed when network state clears the cached mount path but the SMB share remains present in the kernel mount table.

## Acceptance criteria

- [x] Remove resolves a kernel mount before deleting its configuration.
- [x] Clear resolves kernel mounts before deciding which configurations to delete.
- [x] Focused checks and the full test suite pass.

## Validation

Focused `VolumeConfigurationServiceTests`, strict Swift formatting for touched files, editor diagnostics, and the full `xcodebuild` test suite passed.
