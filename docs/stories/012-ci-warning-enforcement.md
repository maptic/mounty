# STORY-012: CI warning enforcement

- Status: CLOSED
- Type: ci
- Date: 2026-08-10
- Commit: _none_

## Intent

Make CI enforce the documented zero-warning policy instead of allowing compiler warnings to merge.

## Acceptance criteria

- [x] Swift and Clang compiler warnings fail the CI build-test job.
- [x] The warning-enforced build and test command passes locally.

## Validation

`xcodebuild -project Mounty.xcodeproj -scheme Mounty -configuration Debug -destination 'platform=macOS,arch=arm64' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES GCC_TREAT_WARNINGS_AS_ERRORS=YES clean test` passed.
