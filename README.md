<div align="center">

<h1><img src="./docs/assets/logo-readme.svg" alt="Mounty logo" width="50" align="absmiddle" /> Mounty</h1>

**A tiny macOS menu-bar app that keeps your SMB network shares mounted — automatically.**

[![CI](https://github.com/maptic/mounty/actions/workflows/ci.yml/badge.svg)](https://github.com/maptic/mounty/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/maptic/mounty?sort=semver)](https://github.com/maptic/mounty/releases/latest)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)

</div>

Mounty lives in your menu bar and reconnects your network volumes the moment they become
reachable again — after a VPN toggles, Wi-Fi reconnects, or the Mac wakes from sleep. No more
manually re-mounting shares in Finder.

## Features

- **Automount** — enable per-volume automounting; Mounty reconnects as soon as the server is reachable.
- **Reachability-aware** — reacts to network changes, VPN tunnels, and detects silently dead mounts.
- **Quick actions** — open any mounted share in Finder or your preferred terminal (Terminal, iTerm2, Warp, …).
- **Import / export** — back up and restore your volume list as JSON.
- **Launch at login** — optional, one toggle.
- **Native & lightweight** — SwiftUI menu-bar app, no background daemons.

## Install

### Homebrew (recommended)

```sh
brew install --cask maptic/tap/mounty
```

Use the **full `maptic/tap/mounty` token**: `mounty` on its own is
[Mounty for NTFS](https://formulae.brew.sh/cask/mounty) in `homebrew/cask`, an unrelated app that
happens to share the name.

### Direct download

1. Download the latest `Mounty.dmg` from the [**Releases**](https://github.com/maptic/mounty/releases/latest) page.
2. Open the DMG and drag **Mounty** into `Applications`.

> [!IMPORTANT]
> **First launch is blocked by Gatekeeper.** Releases are only signed and notarized when the
> release workflow has Developer ID credentials; without them the app is ad-hoc signed, and macOS
> reports that it *"could not verify Mounty.app is free of malware"*. To allow it:
>
> 1. Try to open Mounty and dismiss the warning.
> 2. Open **System Settings → Privacy & Security**, scroll to the message about Mounty, and click
>    **Open Anyway**.
>
> This is a one-time approval — Homebrew carries it into later upgrades — and it is unnecessary for
> notarized releases. Note that the old **right-click → Open** shortcut no longer works: Apple
> removed it in macOS 15. Clearing the flag from a terminal
> (`xattr -dr com.apple.quarantine /Applications/Mounty.app`) fails with `Operation not permitted`
> unless that terminal is granted **App Management** in Privacy & Security.

## Build from source

Requirements: macOS 26.1+, Xcode 26+.

```sh
git clone https://github.com/maptic/mounty.git
cd mounty
./scripts/install-hooks.sh          # one-time: install formatting + commit-msg hooks
xcodebuild -scheme Mounty -configuration Debug build
```

## Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](./CONTRIBUTING.md) first. In short:

- Commits follow [**Conventional Commits**](https://www.conventionalcommits.org/) — releases are
  fully automated from commit history via [release-please](https://github.com/googleapis/release-please).
- Code is auto-formatted with `swift-format` on commit (via the provided git hook).
- The project uses lightweight, provider-neutral **story records** — see [`AGENTS.md`](./AGENTS.md)
  and [`docs/stories/`](./docs/stories/).

## License

[MIT](./LICENSE) © Merlin Unterfinger / maptic
