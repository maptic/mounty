# Specs — Spec-Driven Development

Non-trivial changes to Mounty start with a spec, not code. This keeps intent explicit and lets any
AI agent (Claude, GPT/Copilot, Cursor, …) or human pick up the work with full context.

## Workflow

```
specify  →  plan  →  tasks  →  implement
 (what)     (how)   (steps)    (code + tests)
```

1. **Specify** — capture *what* and *why* (the problem, goals, user-visible behavior, acceptance
   criteria). Template: [`templates/spec-template.md`](./templates/spec-template.md).
2. **Plan** — capture *how* (architecture, files to touch, data flow, trade-offs). Template:
   [`templates/plan-template.md`](./templates/plan-template.md).
3. **Tasks** — break the plan into small, verifiable steps. Template:
   [`templates/tasks-template.md`](./templates/tasks-template.md).

## How to use

Create a numbered folder per feature and copy the templates into it:

```
specs/
├─ README.md
├─ templates/
│  ├─ spec-template.md
│  ├─ plan-template.md
│  └─ tasks-template.md
└─ 001-example-feature/
   ├─ spec.md
   ├─ plan.md
   └─ tasks.md
```

This structure is intentionally tool-agnostic — it is plain Markdown, works with any assistant, and
requires no extra tooling. See [`../AGENTS.md`](../AGENTS.md) for the full agent guide.
