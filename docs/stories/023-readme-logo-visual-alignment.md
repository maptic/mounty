# STORY-023: README logo visual alignment

- Status: CLOSED
- Type: fix
- Date: 2026-08-10
- Commit: _none_

## Intent

Nudge the README title logo upward at its fixed 50px display width without relying on GitHub-stripped inline CSS.

## Acceptance criteria

- [x] The README logo artwork is shifted upward by approximately three CSS pixels at its fixed 50px display width.
- [x] The adjustment remains stable across display densities and viewport sizes.
- [x] Documentation validation passes.

## Validation

The README renders a fixed 50px SVG whose artwork is shifted by 51 of 1024
viewBox units. Strict formatting, all macOS tests, and `git diff --check` passed.