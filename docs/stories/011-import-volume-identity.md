# STORY-011: Import volume identity integrity

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Keep imported volume configurations uniquely identifiable so mount state and actions cannot collide across duplicate UUIDs.

## Acceptance criteria

- [x] Imports skip entries whose UUID or server address already exists.
- [x] Duplicate UUIDs and addresses within one import are skipped consistently.
- [x] Meaningful merge tests and the full test suite pass.

## Validation

Focused `VolumeConfigurationServiceTests`, strict formatting for touched Swift files, editor diagnostics, and the full `xcodebuild` test suite passed.
