# STORY-002: Privacy-safe reachability checks

- Status: CLOSED
- Type: fix
- Date: 2026-08-07
- Commit: `380f761`

## Intent

Stop reachability checks from enumerating mounted directories and triggering unnecessary macOS TCC prompts.

## Acceptance criteria

- [x] Filesystem liveness uses `statfs` rather than directory enumeration.
- [x] Reachability checks retain the existing mounted-volume behavior.
- [x] No unnecessary privacy prompt is caused by the liveness probe.

## Validation

The reachability service was updated and covered by the project build and test validation.
