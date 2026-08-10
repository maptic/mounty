# Contributing to Mounty

Thanks for helping improve Mounty! This project is designed to be worked on by both humans and AI
coding agents, with an automated release pipeline. Please follow the conventions below.

## Getting started

```sh
git clone https://github.com/maptic/mounty.git
cd mounty
./scripts/install-hooks.sh   # installs the pre-commit + commit-msg git hooks
```

Open `Mounty.xcodeproj` in Xcode 26+ (macOS 26.1+), or build/test from the CLI:

```sh
xcodebuild -scheme Mounty -configuration Debug build
xcodebuild -scheme Mounty -destination 'platform=macOS' test
```

## Code style

- 4-space indentation, formatted by **`swift-format`** (config: [`.swift-format`](./.swift-format)).
- The `pre-commit` hook formats staged Swift files automatically. To format manually:
  ```sh
  xcrun swift-format format -i -r Mounty MountyTests
  ```
- CI fails if code is not formatted (`swift-format lint --strict`).

## Commits — Conventional Commits (required)

Releases and version bumps are **fully automated** from commit history, so commit messages matter.
Use [Conventional Commits](https://www.conventionalcommits.org/):

```
<type>[optional scope]: <description>

[optional body]

[optional footer(s)]
```

| Type                | Release effect        |
| ------------------- | --------------------- |
| `fix:`              | patch (x.y.**z**)     |
| `feat:`             | minor (x.**y**.0)     |
| `feat!:` / `BREAKING CHANGE:` footer | major (**x**.0.0) |
| `docs:` `chore:` `refactor:` `test:` `ci:` `style:` `perf:` | no release |

The `commit-msg` hook validates this format locally, and CI validates the **PR title**.

### AI agent attribution (required for agent commits)

If a commit was produced with the help of an AI coding agent, it **must** record the model used via
a `Generated-by:` git trailer. This is the **only** attribution trailer needed — do **not** add
`Co-Authored-By:` or any other trailer. The human is the author; the model is a tool.

```
feat: add reconnect backoff

Generated-by: claude-opus-4-8
```

Use the exact model **id** (e.g. `claude-opus-4-8`, `gpt-5`, `gemini-2.5-pro`). The `commit-msg`
hook validates the format when the trailer is present.

## Stories

Non-trivial changes start with a short story in [`docs/stories/`](./docs/stories/). Copy
[`TEMPLATE.md`](./docs/stories/TEMPLATE.md), register the story in [`INDEX.md`](./docs/stories/INDEX.md),
and keep its acceptance criteria and validation notes current.

See [`AGENTS.md`](./AGENTS.md) for the full agent-facing guide (architecture, commands, conventions).

## Pull requests

- Keep PRs focused. The **PR title must be a valid Conventional Commit** (it becomes the squash
  commit and drives the release).
- CI must be green: format check, build, and unit tests.
