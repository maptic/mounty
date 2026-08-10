# STORY-014: Volume identity enforcement

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Prevent manual additions, edits, and imports from creating multiple configurations for the same SMB share.

## Acceptance criteria

- [x] SMB host and share identity is compared case-insensitively with normalized paths.
- [x] Add, edit, and import reject duplicate SMB identities.
- [x] Focused checks and the full test suite pass.

## Validation

Focused `VolumeConfigurationServiceTests`, strict Swift formatting for touched files, editor diagnostics, and the full `xcodebuild` test suite passed.
