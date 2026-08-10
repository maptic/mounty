# GitHub Copilot instructions

This project's agent guidance is maintained in a single, provider-neutral source of truth.

👉 **Read [`AGENTS.md`](../AGENTS.md)** at the repository root. It covers the architecture,
build/test/format commands, code style, testing policy, Conventional-Commit + model-attribution
rules, and the Spec-Driven Development workflow.

Key reminders for generated code and commits:

- Follow **Conventional Commits**; PR titles must be valid Conventional Commits.
- Business logic goes in `Services/`/`Models/`, not in SwiftUI views.
- Use the **Swift Testing** framework for tests; keep them minimal and meaningful.
- Agent commits must include a `Generated-by: <model-id>` trailer (e.g. `Generated-by: gpt-5`).
  Do **not** add `Co-Authored-By:` — the human user is the author.
- Never include personal contact information (emails, phone numbers) in any file. Use only the
  GitHub advisory URL for security reporting.
