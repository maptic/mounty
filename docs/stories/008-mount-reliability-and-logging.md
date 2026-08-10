# STORY-008: Reliable mounting and unified logging

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commits: `d008b35`, `29d8dc2`

## Intent

Restore reliable SMB mounting, make Mounty-owned service logs visible in the app and Console, retry lost automounts, and keep liveness work bounded.

## Acceptance criteria

- [x] Reachable automount candidates use the proven synchronous NetFS operation off the UI actor.
- [x] Mounty-owned service and view-model diagnostics share one categorized log stream.
- [x] Heartbeat refreshes mount state and retries eligible lost shares.
- [x] Repeated liveness checks cannot create an unbounded number of blocked workers.
- [x] Speed-test and footer behavior remains responsive after the final layout cleanup.

## Validation

`swift-format lint --strict -r Mounty MountyTests`, `xcodebuild -scheme Mounty -destination 'platform=macOS,arch=arm64' test CODE_SIGNING_ALLOWED=NO`, and `git diff --check` passed.
