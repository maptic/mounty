---
name: new-story
description: Create and register a concise project story for a feature, fix, refactor, test, documentation, or configuration change.
argument-hint: Describe the change
---

# New Story

1. Read `AGENTS.md`, `docs/stories/INDEX.md`, and the relevant existing stories.
2. Confirm the request is not already covered by an `OPEN` or `IN_PROGRESS` story.
3. Choose the next numeric ID and a Conventional Commit type: `feat`, `fix`, `refactor`, `perf`, `docs`, `test`, `chore`, or `ci`.
4. Copy `docs/stories/TEMPLATE.md` to `docs/stories/NNN-short-name.md` and fill it with status `OPEN`, intent, concise acceptance criteria, and validation expectations.
5. Add it to `docs/stories/INDEX.md` in descending numeric order.
6. Do not implement the story until it is approved.
