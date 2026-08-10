# STORY-015: SMB endpoint validation and stable edits

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Reject SMB configurations Mounty cannot reach and avoid reconnecting a mounted share when an edit only changes its normalized address representation.

## Acceptance criteria

- [x] Add, edit, and import reject SMB addresses without a host or with an unsupported port.
- [x] Case-only and trailing-slash-only edits preserve an existing mount while updating the saved address.
- [x] Focused tests and the full validation suite pass.

## Validation

Focused `VolumeConfigurationServiceTests`, strict Swift formatting, the full `xcodebuild` test suite, and `git diff --check` passed.