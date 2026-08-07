# AGENTS.md

> **Single source of truth for all AI coding agents** working on Mounty — Claude, GPT/Copilot,
> Cursor, Gemini, and any other assistant. Tool-specific files (`CLAUDE.md`,
> `.github/copilot-instructions.md`, `.cursorrules`) are thin pointers to this file. Keep this file
> up to date; do not duplicate its content elsewhere.

## Project overview

Mounty is a macOS **menu-bar app** (SwiftUI) that keeps SMB network shares mounted automatically.
It reacts to network/VPN/reachability changes and re-mounts shares as soon as their server is
reachable.

- Language: Swift 5 / Swift Concurrency (`async`/`await`). **Avoid Combine for new code** — prefer
  async APIs (existing `EventMonitorService` still uses Combine; do not expand that pattern).
- UI: SwiftUI, `MenuBarExtra` (`.window` style).
- Target: macOS 26.1+, Xcode 26+. Bundle id `ch.maptic.Mounty`.
- Concurrency: default actor isolation is `MainActor` (see build settings); services that touch the
  kernel/network are `nonisolated` and hop to detached tasks.

## Architecture (MVVM)

```
Mounty/Mounty/
├─ MountyApp.swift            # @main App, MenuBarExtra scene
├─ Models/
│  └─ Volume.swift            # Volume value type (+ AppViewMode enum)
├─ Services/                  # Stateless/side-effecting units — the business logic
│  ├─ MountService.swift        # mount/unmount via NetFS, open in Finder/terminal, login item
│  ├─ SystemMountService.swift  # query kernel mounts (getmntinfo), match config → mount path
│  ├─ ReachabilityService.swift # TCP (port 445) + I/O liveness checks
│  ├─ EventMonitorService.swift # NWPathMonitor + workspace mount notifications (Combine subjects)
│  └─ PersistenceService.swift  # UserDefaults-backed storage (injectable defaults)
├─ ViewModels/
│  └─ VolumeManager.swift     # @MainActor ObservableObject; orchestrates detection/automount/state
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

## Testing policy

Test **business logic that can actually break** — keep the suite minimal and meaningful. Do **not**
test trivial getters, SwiftUI views, or the network-driven side effects of `VolumeManager`. Good
targets: mount-path matching (`SystemMountService`), URL parsing (`Volume.host`), persistence
round-trips. Use the **Swift Testing** framework (`import Testing`, `@Test`, `#expect`), not XCTest.

## Commits & releases (Conventional Commits)

Versioning and releases are **fully automated** by `release-please` from commit history. Every commit
(and every PR title) MUST follow [Conventional Commits](https://www.conventionalcommits.org/):
`feat:` → minor, `fix:` → patch, `feat!:`/`BREAKING CHANGE:` → major; `docs/chore/refactor/test/ci`
→ no release.

### Mandatory model attribution for agent commits

Any commit you create as an AI agent MUST include a `Generated-by:` git trailer naming the exact
model id, e.g.:

```
feat: add reconnect backoff

Generated-by: claude-opus-4-8
```

Use your real model id (`claude-opus-4-8`, `gpt-5`, `gemini-2.5-pro`, …). This is provider-neutral.
Keep any `Co-Authored-By:` line as well if your harness adds one.

## Spec-Driven Development (SDD)

For non-trivial work, write the spec before the code. Templates live in `specs/templates/`:

1. **Specify** *what & why* → `specs/templates/spec-template.md`
2. **Plan** *how* → `specs/templates/plan-template.md`
3. **Tasks** breakdown → `specs/templates/tasks-template.md`

Copy the templates into `specs/<NNN-short-name>/` for the feature you are working on.

## Guardrails

- **Zero warnings policy.** The project must build and test with zero warnings. Before submitting a
  PR, use `XcodeListNavigatorIssues` (severity: `warning`) and confirm the list is empty.
  Pay particular attention to Swift Concurrency warnings — the project uses
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, meaning every type and method is implicitly
  `@MainActor` unless explicitly marked `nonisolated`. Common patterns to follow:
  - Value types shared across actors: add an explicit `nonisolated static func ==` (see
    `Volume.swift`).
  - Classes shared across `@Sendable` closures: mark as `@unchecked Sendable`, protect mutable
    state with `NSLock`, and annotate mutable properties `nonisolated(unsafe)` (see
    `ReachabilityService.ResumeGate`).
  - Methods called from `@Sendable` closures: mark `nonisolated`.
- Keep changes scoped to the request; don't refactor unrelated code.
- Never commit secrets, `.p12`, provisioning profiles, or notarization keys.
- Don't add third-party dependencies without discussion — this app is intentionally dependency-free.
