# STORY-022: Documentation source artwork

- Status: CLOSED
- Type: docs
- Date: 2026-08-10
- Commit: _none_

## Intent

Keep the raw logo and menu-icon source files with documentation assets while leaving Xcode's runtime asset catalog unchanged.

## Acceptance criteria

- [x] Raw logo and menu-icon source files live in `docs/assets/`.
- [x] The README logo resolves from the documentation asset path.
- [x] Xcode asset-catalog paths remain unchanged.
- [x] Focused validation passes.

## Validation

The asset catalog compiled successfully. `xcodebuild` ran the focused Volume
tests, all project tests, source-asset path checks, and `git diff --check`
passed.