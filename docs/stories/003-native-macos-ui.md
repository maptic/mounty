# STORY-003: Native macOS interface

- Status: CLOSED
- Type: feat
- Date: 2026-08-07
- Commits: `1b66e31`, `25396fd`, `972dde6`

## Intent

Modernize the menu-bar experience with native macOS controls and a consistent settings and volume-row layout.

## Acceptance criteria

- [x] Main, settings, add-volume, overlay, header, and volume-row views use native macOS patterns.
- [x] Settings actions remain discoverable without custom control chrome.
- [x] Icon-only row actions retain clear hover affordances.

## Validation

The affected SwiftUI views were formatted and verified through the macOS build and test suite.
