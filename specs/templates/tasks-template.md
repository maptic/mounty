# Tasks: <feature name>

- **Plan:** ./plan.md

Break the plan into small, independently verifiable steps. Each task should map to a focused commit
with a Conventional-Commit message.

- [ ] **T1** — <task> _(commit: `feat: ...`)_
- [ ] **T2** — <task> _(commit: `test: ...`)_
- [ ] **T3** — <task> _(commit: `docs: ...`)_

## Definition of done

- [ ] All acceptance criteria in `spec.md` met
- [ ] Business logic covered by Swift Testing tests
- [ ] `swift-format lint --strict` clean
- [ ] CI green
