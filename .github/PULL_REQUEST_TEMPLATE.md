<!--
The PR title MUST be a valid Conventional Commit (e.g. "feat: add reconnect backoff").
It becomes the squash-merge commit and drives the automated release.
-->

## What & why

<!-- Describe the change and the motivation. Link the spec in specs/ if applicable. -->

## Type of change

- [ ] `fix` — bug fix (patch release)
- [ ] `feat` — new feature (minor release)
- [ ] breaking change (`!` / `BREAKING CHANGE:` — major release)
- [ ] `docs` / `chore` / `refactor` / `test` / `ci` (no release)

## Checklist

- [ ] PR title is a valid Conventional Commit
- [ ] Code is formatted (`swift-format`) and CI is green
- [ ] Business logic changes are covered by tests
- [ ] If AI-assisted, commits include a `Generated-by: <model-id>` trailer
