---
name: review-codebase
description: Perform a read-only codebase review for bugs, risks, spec drift, test gaps, and candidate project stories.
argument-hint: Optional review focus
---

# Review Codebase

1. Inspect the current worktree and branch without modifying files or performing Git operations.
2. Read `AGENTS.md`, `docs/stories/INDEX.md`, and relevant stories.
3. Look for reproducible bugs, security or data risks, contract drift, CI gaps, and meaningful missing tests.
4. Report findings first, ordered by severity, with file and line links. Distinguish evidence from assumptions.
5. Suggest new stories only for work not already covered by an `OPEN` or `IN_PROGRESS` story. Do not create or implement them without approval.
