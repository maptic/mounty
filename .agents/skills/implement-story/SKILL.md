---
name: implement-story
description: Implement an approved project story end to end and close its single Markdown record.
argument-hint: Story ID, for example 009
---

# Implement Story

1. Read `AGENTS.md`, `docs/stories/INDEX.md`, and the requested story. Continue only for `OPEN` or `IN_PROGRESS`.
2. Set the story and index to `IN_PROGRESS`.
3. Implement the smallest change that satisfies every acceptance criterion. Keep business logic in services or models and preserve existing changes.
4. After each edit slice, run the cheapest focused format, build, or test check available.
5. Update the story with completed criteria, outcome, tests, and validation. Set it and the index to `CLOSED` only when all criteria are met.
6. Do not commit or push unless explicitly requested; use the story's Conventional Commit type if a commit is requested.
