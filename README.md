<div align="center">

# <img src="./assets/source/logo.png" alt="Mounty logo" width="36" /> Mounty

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

### Direct download

1. Download the latest `Mounty.dmg` from the [**Releases**](https://github.com/maptic/mounty/releases/latest) page.
2. Open the DMG and drag **Mounty** into `Applications`.

> [!IMPORTANT]
> **First-launch Gatekeeper note.** Releases are signed and notarized when the release workflow has
> Developer ID credentials. For an ad-hoc-signed release, macOS may refuse to open it on the first
> try. To allow that build:
>
> - **Right-click** `Mounty.app` → **Open** → **Open** in the dialog, **or**
> - remove the quarantine flag from a terminal:
>   ```sh
>   xattr -dr com.apple.quarantine /Applications/Mounty.app
>   ```
>
> This is a one-time step and is unnecessary for notarized releases.

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
