# STORY-026: Automount must not disturb busy mounts

- Status: CLOSED
- Type: fix
- Date: 2026-08-13
- Commit: _none_

## Intent

A slow liveness probe on a healthy but busy share currently makes automount force-unmount and
remount it, which tears down in-flight file I/O in other applications every few minutes. Automount
must only recover mounts that are provably dead, never mounts that are merely slow to answer.

Reported failure: with automount enabled, the SMB connection drops briefly every few minutes and
Java file I/O on the share aborts; disabling automount makes the problem disappear.

Chain (heartbeat, every 5 s):

1. `VolumeManager.detectMounts` probes each mount with `ReachabilityService.isMountPointAlive`,
   whose `statfs(2)` is abandoned after a 1 s deadline. Heavy SMB traffic — exactly what a Java
   workload produces — pushes `statfs` past that deadline, so the probe reports the mount as dead.
2. The volume drops out of `mountPaths` and therefore becomes an automount candidate.
3. `runAutomount` calls `MountService.mount`, which finds the existing mount and re-probes it before
   deciding to recover it.
4. That re-probe returns the **cached** `false` from step 1: `MountProbeRegistry` keeps the timed-out
   verdict as the probe result until the still-blocked `statfs` thread calls `finish(path:)`, so the
   guard protecting the destructive branch cannot see a healthy mount.
5. `MountService.unmount` runs. The polite `unmountAndEjectDevice` fails with `EBUSY` because the
   other application holds open descriptors, so the fallback `unmount(path, MNT_FORCE)` succeeds and
   the kernel tears down a healthy share — killing those descriptors.
6. The next heartbeat remounts it, which is why the outage looks brief and recurring.

## Acceptance criteria

- [x] A mount-point probe distinguishes *alive*, *dead* (a real `statfs` errno), and *indeterminate*
      (deadline reached while the syscall is still outstanding).
- [x] An indeterminate probe never removes a volume from the detected mount state and never triggers
      the recovery unmount; only a definitive `statfs` error does.
- [x] Concurrent probes of the same path still share one syscall, and a timed-out verdict is never
      served to a later caller as if it were a completed result.
- [x] A volume that is present in the kernel mount table and answering is left untouched by
      automount, with no unmount and no remount.
- [x] Recovery of a genuinely dead mount (including the `MNT_FORCE` fallback) keeps working.
- [x] Probe timeouts are logged at a level that does not flood the in-app log on a busy share.

## Outcome

`ReachabilityService.isMountPointAlive` became `probeMountPoint`, returning the three-state
`MountProbe`. `MountProbeRegistry` no longer stores a verdict at all: an entry lives only while its
syscall is outstanding, a caller that hits its own deadline is simply dropped from the waiters, and a
later caller joins the running syscall instead of inheriting the earlier timeout. Probes of one path
still share a single syscall, so repeated checks cannot pile up blocked workers (STORY-008).

`MountService.mountExclusively` now switches on the verdict: `.alive` and `.indeterminate` both
return the existing mount untouched, and only `.dead` reaches the unmount-and-retry branch — so the
`MNT_FORCE` fallback can no longer be aimed at a healthy share. `VolumeManager.detectMounts` keeps a
volume mounted unless the probe is definitively `.dead`, which also stops the "Lost connection" log
churn on a busy share.

Silent-death detection is preserved by `hangGrace` (60 s): a deadline that elapses while the syscall
itself has been stuck past that interval reports `.dead(ETIMEDOUT)` instead of `.indeterminate`, so a
mount whose `statfs` never returns is still recovered. The per-caller deadline rose from 1 s to 2 s
and its log dropped to `debug`, since a busy share crossing it is now expected and harmless.

## Validation

`ReachabilityServiceTests` covers the three verdicts, ten concurrent probes of one path, the
timed-out caller leaving no verdict behind, the completed probe not being reused, and the
hang-grace escalation. `xcrun swift-format lint --strict -r Mounty MountyTests` is clean, and
`xcodebuild -scheme Mounty -destination 'platform=macOS' test CODE_SIGNING_ALLOWED=NO` succeeds; a
`clean build` reports zero source warnings.

Live run against a corporate SMB share with automount enabled: three minutes of
sustained load (four parallel read/write workers plus one long-lived descriptor doing
`write`/`fsync`, 0.32 GB written and 0.10 GB read) while a watchdog sampled the kernel mount table
twice a second.

- `statfs(2)` on the share peaked at **3291 ms**, so the probe deadline really was exceeded — the
  exact trigger the old 1 s deadline turned into a "dead" verdict.
- Eleven probe timeouts were logged across the two mounted shares, every one of them as
  `the mount is busy, not dead`.
- **Zero unmounts and zero remounts**: 400 of 400 watchdog samples found the mount present, with a
  constant device id, and no `Lost connection`, `unmounting before retry`, or `Automount` entry
  appeared for the duration.
- The long-lived descriptor finished with **no I/O errors** — the failure the report describes.

A manual connect/disconnect during the same session mounted the share in 1.97 s and unmounted it
politely, so the user-initiated paths are unaffected.

Not verified on hardware: recovery of a genuinely dead mount. The share could not be unmounted
cleanly (other processes held files open) and force-unmounting a live share was out of scope for
the test, so that branch rests on `syscallStuckPastTheGraceIntervalProbesDead` and the `.dead`
switch case.
