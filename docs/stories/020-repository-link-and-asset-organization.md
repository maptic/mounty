# STORY-020: Repository link and asset organization

- Status: CLOSED
- Type: feat
- Date: 2026-08-10
- Commit: _none_

## Intent

Make Mounty's repository easy to find from the About section, show its transparent logo in the README, and organize raw source graphics without changing Xcode's asset-catalog layout.

## Acceptance criteria

- [x] Settings includes a subtle link to the Mounty repository.
- [x] The README header displays the transparent Mounty logo.
- [x] Root-level source graphics are grouped outside the Xcode catalog while its layout remains unchanged.
- [x] Focused validation passes.

## Validation

The restored asset catalog compiled successfully. `xcodebuild` ran the focused
Volume tests, source-asset path checks, and `git diff --check` passed.