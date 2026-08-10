# Tasks: Mount reliability and unified logging

- **Plan:** ./plan.md

- [x] **T1** — Add unified categorized application logging _(commit: `feat(logging): unify service logs`)_
- [x] **T2** — Restore reliable off-main NetFS mounting _(commit: `fix(mount): restore reliable NetFS mounting`)_
- [x] **T3** — Repair heartbeat retry and bound liveness work _(commit: `fix(automount): retry dead shares safely`)_
- [x] **T4** — Add focused logging tests _(commit: `test(logging): cover categorized formatting`)_

## Definition of done

- [x] All acceptance criteria in `spec.md` met
- [x] Business logic covered by Swift Testing tests
- [x] `swift-format lint --strict` clean
- [ ] CI green