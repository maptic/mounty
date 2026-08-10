# Plan: Mount reliability and unified logging

- **Spec:** ./spec.md
- **Status:** implemented

## Approach

Introduce a thread-safe application log channel that writes every Mounty-owned event to `os.Logger`
and an `AsyncStream` consumed by `VolumeManager`. Replace the timing-out asynchronous NetFS bridge
with the previously working synchronous API, isolated in a detached task and serialized by the
automount workflow. Do not expose a false timeout for a C operation that cannot be cancelled.

Update the heartbeat to refresh and then automount. Share one in-flight filesystem liveness probe
per path so repeated checks cannot consume an unbounded number of threads.

## Architecture & data flow

`AppLogger` in Services emits categorized `LogEntry` values and Unified Logging records.
`VolumeManager` consumes the stream on `MainActor` and owns the capped display buffer. Services log
directly through `AppLogger`. `MountService` performs NetFS work in `Task.detached`; UI state remains
owned by `VolumeManager`.

## Files to change

| File | Change |
| ---- | ------ |
| `Mounty/Models/LogEntry.swift` | Add source category and nonisolated construction. |
| `Mounty/Services/AppLogger.swift` | Add unified Console/in-app logging channel. |
| `Mounty/Services/MountService.swift` | Restore reliable off-main synchronous NetFS mounting. |
| `Mounty/Services/EventMonitorService.swift` | Route service diagnostics through `AppLogger`. |
| `Mounty/Services/ReachabilityService.swift` | Bound blocking liveness probes and improve diagnostics. |
| `Mounty/ViewModels/VolumeManager.swift` | Consume logs and retry automount from heartbeat. |
| `Mounty/Views/LogsView.swift` | Display log categories. |
| `MountyTests/AppLoggerTests.swift` | Test categorized in-app stream delivery. |

## Reused existing code

Reuse `LogEntry.Level`, `ResumeGate`, `SystemMountService.findMountPath`, the existing automount
candidate workflow, and `PersistenceService` log-level storage.

## Trade-offs / risks

- Synchronous NetFS cannot be cancelled once entered. It remains off `MainActor`, and sequential
  invocation prevents request storms. TCP preflight avoids entering it for unreachable servers.
- Interactive mounts are intentionally serialized to avoid competing NetAuth dialogs.
- A permanently hung liveness syscall can occupy one dedicated worker, but repeated heartbeats do
  not create additional blocked workers.

## Verification

Run focused Swift Testing tests, strict `swift-format` lint, and the complete macOS test suite.
Manually verify on a configured SMB share that MountService Debug records appear in the app and the
mount completes without UI stalls.