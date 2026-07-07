---
id: 3
type: FIX
status: NEW
title: Fix readonly re-source crash bug in davit-logger.sh (v1.4.4 -> v1.4.5)
created: 2026-07-07
updated: 2026-07-07
---

# Fix readonly re-source crash bug in davit-logger.sh (v1.4.4 -> v1.4.5)

## Description

David flagged that `davit-logger.sh` v1.4.4 could not "get past" the old
`readonly _D_LOGS="${_D_ROOT}/logs"` line — in both dev and prod — and
correctly identified this as a symptom of a bigger gap: no way for an admin
to switch off a broken core module and fall back to something minimal.

**Cause:** `_D_LOGGER_LOADED`, `user`, `_D_ROOT`, `_D_BIN`, `_D_LOGS`, and
`_D_LIB` were all declared `readonly`. Per the bash manual, assigning to a
`readonly` variable "fails and the shell exits" in a non-interactive shell —
unconditionally, regardless of `set -e`. The `_D_LOGGER_LOADED` guard exists
to make re-sourcing a safe no-op, but that only works if the guard fires
*before* any `readonly` line runs a second time; anything that gets past the
guard (a dev re-sourcing after an edit in the same terminal, a long-lived
daemon, a wrapper sourcing several sub-scripts) hit the `readonly`
reassignment and crashed the entire calling process — not gracefully, not
caught by `set -e`, just an immediate shell exit.

**Fix applied (2026-07-07):** removed `readonly` from all six declarations
in `src/bin/davit-logger.sh`; bumped header `# Version:` 1.4.4 → 1.4.5;
CHANGELOG `[Unreleased]` entry added. Verified: a forced re-source
(bypassing the guard, simulating the crash scenario) now completes with
`rc=0` where it previously terminated the shell.

**Follow-on (bigger scope, not done here):** the underlying architectural
gap — no admin-facing way to disable a broken core module and fall back to
a minimal logger — is designed in `davit-os-alpha` ANDES.md §6 ("Core Module
Safety — Enable/Disable & Fallback") and tracked for implementation as
`davit-os-alpha` 2do #22 (`DAVIT_MODULE_LOGGER_ENABLED` switch +
`davit_log_minimal()` fallback in `davit.conf`). A suspected `src/etc/davit.conf`
vs deployed drift that looked like it would block #22 turned out to be a
false alarm (one stale placeholder comment, since fixed) — no reconciliation
was actually needed; see #22 for detail.

## Tasks

- [x] Remove `readonly` from `_D_LOGGER_LOADED`, `user`, `_D_ROOT`, `_D_BIN`,
      `_D_LOGS`, `_D_LIB` in `src/bin/davit-logger.sh`.
- [x] Bump script header version 1.4.4 → 1.4.5.
- [x] Add CHANGELOG `[Unreleased]` entry.
- [x] Verify fix: forced re-source no longer crashes the shell.
- [ ] David to confirm/close.
- [ ] Once `davit-os-alpha` 2do #22 (module enable/disable + fallback) lands,
      wire `davit-logger`'s own callers/docs to use `davit_load_logger()`
      instead of sourcing `davit-logger.sh` directly (cross-ref 2do #2,
      §12.2 Configuration Ownership).

## Notes / History

* 2026-07-07: Created and fixed in the same session — David reported the
  bug while discussing a broader "admin kill-switch for core modules"
  design; the immediate crash bug was low-risk and unambiguous so it was
  fixed directly, while the bigger design was written up and filed
  separately (`davit-os-alpha` 2do #22) rather than implemented
  immediately, since it touches the shared production `davit.conf`.
* 2026-07-07: The design was tested for real, sooner than expected — David
  deleted `/opt/davit/logs/` as a deliberate dependency smoke test (backed
  up to `/opt/davit/var/backups/logs/` first). Confirmed the catastrophic
  case: even with the readonly bug fixed, v1.4.5 still hardcoded
  `/opt/davit/logs` and broke on every write. Fixed in v1.4.6 (2do #2) —
  `davit-logger.sh` now sources `davit.conf` for `DAVIT_LOGS_DIR`. Also
  implemented `davit-os-alpha` 2do #22 (`DAVIT_MODULE_LOGGER_ENABLED` +
  `davit_log_minimal()` + `davit_load_logger()`) in `src/etc/davit.conf` —
  verified locally: disabled-switch and simulated-broken-module cases both
  degrade to the minimal fallback logger instead of crashing. Neither v1.4.6
  nor the `davit.conf` LAYER 8 addition is deployed to `/opt/davit/` yet.
* 2026-07-07: David deployed v1.4.6 to `/opt/davit/bin/` and the LAYER 8
  `davit.conf` to `/opt/davit/etc/`. Confirmed live: `davit-logger.sh -v`
  runs clean with no "No such file or directory" error, and
  `/opt/davit/var/log/davit-projects.log` is receiving writes.
  `/opt/davit/logs/` correctly stays gone — nothing recreates it anymore.
