# Spec: Mount reliability and unified logging

- **Status:** implemented
- **Author:** GitHub Copilot
- **Date:** 2026-08-10

## Problem / motivation

Automount and manual mounts stall until the 90-second deadline when using
`NetFSMountURLAsync`, although the earlier synchronous NetFS implementation worked for the same
shares. Mount-service diagnostics are visible in Console but absent from the in-app log because
services and the view model use separate logging paths. Heartbeat detection also removes dead
mounts from state without initiating automount recovery.

## Goals

- Reliably mount reachable SMB shares without blocking `MainActor`.
- Show all Mounty-owned service and view-model logs in both Console and the in-app log.
- Retry automount after heartbeat detection finds a lost mount.
- Prevent repeated liveness checks from creating unbounded blocked worker threads.
- Preserve actionable levels, categories, durations, error codes, and credential-safe targets.

## Non-goals

- Mirroring macOS framework logs, such as BaseBoard diagnostics, into the app.
- Replacing NetFS or storing SMB credentials.
- Parallel interactive authentication prompts.

## User-visible behavior

The Debug filter shows manager, event-monitor, reachability, and mount-service diagnostics. Mounts
are attempted one at a time off the UI actor. A dead automounted share is retried by the heartbeat
when its server remains reachable. Manual mount failures remain visible at Error level with their
underlying NetFS detail.

## Acceptance criteria

- [x] `MountService` diagnostics appear in the in-app log and Console with a category.
- [x] No Mounty-owned blocking filesystem, NetFS, or Launch Services call runs on `MainActor`.
- [x] Reachable automount candidates use the proven synchronous NetFS operation sequentially.
- [x] Heartbeat detection invokes automount after refreshing mount state.
- [x] A hung liveness probe cannot create an unbounded number of blocked workers.
- [x] Log-level selection remains persisted.
- [x] The project builds and tests without Swift warnings.

## Open questions

- Whether a future macOS release makes parallel `NetFSMountURLAsync` reliable enough to re-enable
  bounded concurrent authentication after real-network testing.