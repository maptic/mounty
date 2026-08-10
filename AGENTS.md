# AGENTS.md

> **Single source of truth for all AI coding agents** working on Mounty — Claude, GPT/Copilot,
> Cursor, Gemini, and any other assistant. Tool-specific files (`CLAUDE.md`,
> `.github/copilot-instructions.md`, `.cursorrules`) are thin pointers to this file. Keep this file
> up to date; do not duplicate its content elsewhere.

## Project overview

Mounty is a macOS **menu-bar app** (SwiftUI) that keeps SMB network shares mounted automatically.
It reacts to network/VPN/reachability changes and re-mounts shares as soon as their server is
reachable.

- Language: Swift 6 / Swift Concurrency (`async`/`await`). **Avoid Combine entirely** — use
  `AsyncStream` for event sequences and `async`/`await` everywhere else.
- UI: SwiftUI, `MenuBarExtra` (`.window` style).
- Target: macOS 26.1+, Xcode 26+. Bundle id `ch.maptic.Mounty`.
- Concurrency: default actor isolation is `MainActor` (see build settings); services that touch the
  kernel/network are `nonisolated` and hop to detached tasks.

## Architecture (MVVM)

```
Mounty/Mounty/
├─ MountyApp.swift            # @main App, MenuBarExtra scene
├─ Models/
│  ├─ LogEntry.swift          # Categorized in-app log value type
│  └─ Volume.swift            # Volume value type, SMB normalization (+ AppViewMode enum)
├─ Services/                  # Side-effecting/state-owning units — the business logic
│  ├─ AppLogger.swift           # Unified Logging + thread-safe AsyncStream history
│  ├─ MountService.swift        # mount/unmount via NetFS, open in Finder/terminal, login item
│  ├─ SystemMountService.swift  # query kernel mounts (getmntinfo), match config → mount path
│  ├─ ReachabilityService.swift # TCP (port 445) + I/O liveness checks
│  ├─ SpeedTestService.swift     # uncached SMB read/write throughput measurement
│  ├─ EventMonitorService.swift # NWPathMonitor + workspace notifications via AsyncStream
│  └─ PersistenceService.swift  # UserDefaults-backed storage (injectable defaults)
├─ ViewModels/
│  └─ VolumeManager.swift     # @MainActor @Observable class; orchestrates detection/automount/state
└─ Views/                     # SwiftUI views only — no business logic
```

**Rule:** business logic lives in `Services/` and `Models/`. Views stay declarative; `VolumeManager`
orchestrates. New testable logic should be a `Service` (pure/injectable), not embedded in the view model.

## Build, test, format

```sh
# Build
xcodebuild -scheme Mounty -configuration Debug build

# Test (unit tests only, Swift Testing framework)
xcodebuild -scheme Mounty -destination 'platform=macOS' test

# Format (in place) / lint
xcrun swift-format format -i -r Mounty MountyTests
xcrun swift-format lint --strict -r Mounty MountyTests
```

When running inside an IDE with MCP tools available (e.g. Xcode), prefer `BuildProject` and
`RunAllTests` over shelling out.

## Code style

- 4-space indentation; formatted by `swift-format` (config `.swift-format`). The `pre-commit` hook
  formats staged files automatically.
- PascalCase types, camelCase members. `let` by default; `@State private var` for SwiftUI state.
- No force-unwrapping. Prefer `guard let`/`if let`. Leverage the strong type system.
- Comment non-obvious logic only; match the surrounding density.
- **Observable pattern**: use `@Observable` (not `ObservableObject`) for ViewModel classes.
  `@State` owns the instance (in the root scene); child views use plain `var` for read-only access
  or `@Bindable var` when two-way bindings (`$property`) are needed. Never use `@Published`,
  `@StateObject`, or `@ObservedObject`.

## Testing policy

Test **business logic that can actually break** — keep the suite minimal and meaningful. Do **not**
test trivial getters, SwiftUI views, or the network-driven side effects of `VolumeManager`. Good
targets: mount-path matching (`SystemMountService`), SMB address normalization (`Volume`), input
validation, and persistence round-trips. Use the **Swift Testing** framework (`import Testing`,
`@Test`, `#expect`), not XCTest.

## Commits & releases (Conventional Commits)

Versioning and releases are **fully automated** by `release-please` from commit history. Every commit
(and every PR title) MUST follow [Conventional Commits](https://www.conventionalcommits.org/):
`feat:` → minor, `fix:` → patch, `feat!:`/`BREAKING CHANGE:` → major; `docs/chore/refactor/test/ci`
→ no release.

### Release pipeline

```
push to main → release-please PR → merge → tag vX.Y.Z + GitHub Release
                                             │
                                             ├─ release-build.yml: DMG (+ notarization) → release assets
                                             └─ repository_dispatch "cask-release" → maptic/homebrew-tap
                                                                                     bumps Casks/mounty.rb
```

`release-build.yml` is **called by** `release-please.yml`, not triggered by the `release: published`
event — a release created with the default `GITHUB_TOKEN` does not emit that event. To re-package a
tag by hand: `gh workflow run release-build.yml -f tag=vX.Y.Z`.

The cask bump needs `HOMEBREW_TAP_TOKEN` (a fine-grained PAT with `contents: write` on
`maptic/homebrew-tap`) in this repository's secrets; without it the release still succeeds and only
the tap bump is skipped. The tap re-computes the `sha256` from the published asset itself, so the
dispatch payload carries just the cask token and the version.

### Mandatory model attribution for agent commits

Any commit you create as an AI agent MUST include a `Generated-by:` git trailer naming the exact
model id. This is the **only** attribution trailer needed — do **not** add `Co-Authored-By:` or
any similar trailer. The human user is the author; the model is a tool.

```
feat: add reconnect backoff

Generated-by: claude-opus-4-8
```

Use your real model id (`claude-opus-4-8`, `gpt-5`, `gemini-2.5-pro`, …). This is provider-neutral.
The `commit-msg` hook validates the format when the trailer is present.

## Stories

Keep one concise Markdown file per change in `docs/stories/`, registered in `docs/stories/INDEX.md`. Use the
next numeric ID and a Conventional Commit type (`feat`, `fix`, `refactor`, `perf`, `docs`, `test`,
`chore`, or `ci`). A story contains only status, type, date, intent, acceptance criteria, and
validation. New work starts `OPEN`, implementation moves it to `IN_PROGRESS`, and completed work
is `CLOSED`; update the index whenever the status changes. Historical stories may be written from
the commit history and should include the relevant commit IDs.

## UI responsiveness — non-negotiable rules

The menu-bar popover has no loading screen and no tolerance for lag. Violations of these rules
will break the user experience even if the code is otherwise correct.

1. **Never block `@MainActor`.** Anything that may take >1 ms must run off the main actor.
   - Use `Task.detached` (not `Task(priority:)`) when the work is CPU- or I/O-bound.
     `Task(priority:)` from a `@MainActor` context **inherits the actor** and still runs on the
     main thread — it does NOT move work off it. Only `Task.detached` escapes the actor.
   - Launch Services (`NSWorkspace.urlForApplication`), `SMAppService`, `statfs`, `NetFSMountURLSync`,
     and all network I/O must be in detached tasks or `nonisolated` services.
   - Use `withTaskGroup` to parallelise multiple async operations (e.g. reachability checks)
     instead of awaiting them sequentially.

2. **Never put padding outside a `Button` to extend its hit area.**
   Padding added *outside* the `Button` (via view modifiers) does **not** expand the button's
   interactive region — only the icon itself is clickable, causing missed clicks. Use a
   `ButtonStyle` instead: padding inside `makeBody` becomes part of the button's own frame.
   The project uses `IconHoverButtonStyle` (via `.iconButtonHover()`) for all plain icon buttons.
   Do NOT add `.buttonStyle(.plain)` before `.iconButtonHover()` — it overrides the style and
   reverts to the small hit area.

3. **Never use `.onTapGesture(count:)` on a parent that contains `Button` children.**
   A multi-tap gesture on an ancestor blocks single-tap recognition on child buttons until the
   system determines whether a second tap is coming. Use `.simultaneousGesture(TapGesture(count:))`
   instead so both recognizers run concurrently.

4. **The heartbeat uses `Task.sleep`, not a `Timer`.**
   `Task.sleep(for:)` fires from the cooperative thread pool and has no RunLoop mode — it never
   interferes with UI event tracking regardless of what the user is doing. The heartbeat task
   calls `refreshState()` which immediately delegates all I/O to `Task.detached`.

## Guardrails

- **Zero warnings policy.** The project must build and test with zero warnings. Before submitting a
  PR, use `XcodeListNavigatorIssues` (severity: `warning`) and confirm the list is empty.
  Pay particular attention to Swift Concurrency warnings — the project uses
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, meaning every type and method is implicitly
  `@MainActor` unless explicitly marked `nonisolated`. Common patterns to follow:
  - Value types shared across actors: add an explicit `nonisolated static func ==` (see
    `Volume.swift`).
  - Shared mutable state in synchronous callbacks: prefer `Synchronization.Mutex`. Avoid
    `@unchecked Sendable` and `nonisolated(unsafe)` unless an external API provides the
    synchronization guarantee and that guarantee is documented locally.
  - Methods called from `@Sendable` closures: mark `nonisolated`.
- Keep changes scoped to the request; don't refactor unrelated code.
- Never commit secrets, `.p12`, provisioning profiles, or notarization keys.
- Don't add third-party dependencies without discussion — this app is intentionally dependency-free.
- **Never include personal contact information** (email addresses, phone numbers, social handles)
  in any file you create or modify. Use only the GitHub advisory form URL for security reporting.
  If you need to attribute a maintainer, use their GitHub username, never a private email address.
