# STORY-025: Gatekeeper install instructions

- Status: CLOSED
- Type: docs
- Date: 2026-08-10
- Commit: _none_

## Intent

The README told users to bypass Gatekeeper with **right-click → Open**, a shortcut Apple removed in
macOS 15 — it cannot work on the macOS 26 Mounty requires, leaving a first-time installer stuck at
"could not verify Mounty.app is free of malware".

## Acceptance criteria

- [x] The Gatekeeper note documents the System Settings → Privacy & Security → **Open Anyway** route.
- [x] The `xattr -dr` alternative states that it fails with `Operation not permitted` unless the
      terminal holds the **App Management** permission.
- [x] The Homebrew section states that only the full `maptic/tap/mounty` token resolves to this
      cask.

## Validation

Reproduced on macOS 26 with the 1.2.1 cask: `codesign -dvv` reports `Signature=adhoc` with no team
identifier, `spctl -a -t exec` rejects the bundle, and `xattr -dr com.apple.quarantine` fails on
every path inside the app. Approving once in System Settings launches it.
