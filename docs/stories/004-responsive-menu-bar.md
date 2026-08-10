# STORY-004: Responsive menu-bar interaction

- Status: CLOSED
- Type: fix
- Date: 2026-08-08
- Commits: `d6c42a7`, `7943079`, `4168d36`, `ebf6c05`, `bcc44e7`, `5734c41`, `09ba72a`

## Intent

Keep the popover responsive while users resize it, navigate settings, and interact with row actions.

## Acceptance criteria

- [x] Blocking reachability and mount work stays off the main actor.
- [x] Animations, resizing, navigation, and footer layout remain stable.
- [x] Child buttons respond immediately and have reliable hit areas.
- [x] Settings actions preserve their intended icon-only layout and hover behavior.

## Validation

Strict Swift format lint and the complete macOS Swift Testing suite passed after the interaction and concurrency fixes.
