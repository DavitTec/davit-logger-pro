---
id: 2
type: TODO
status: NEW
title: Draft ANDES.md: log file location, rotation, archiving, query & config management procedures
created: 2026-07-07
updated: 2026-07-07
---

# Draft ANDES.md: log file location, rotation, archiving, query & config management procedures

## Description

Log file location is currently inconsistent and partly hardcoded. This task is to
draft a new **"Log File Management"** section in `docs/ANDES.md` that settles the
location, rotation, archiving, query, and configuration-ownership procedures
*before* any code changes are made. Once the ANDES section is reviewed and
finalised, split the actual work into FEATURE/FIX `2do` items.

### Findings (current state, as of 2026-07-07)

- `/opt/davit/etc/davit.conf` (LAYER 2) already declares the canonical var:
  `DAVIT_LOGS_DIR="${DAVIT_ROOT}/var/log"` — i.e. the config has *already*
  moved to `/opt/davit/var/log/`, with `_D_LOGS` marked deprecated.
- But `src/bin/davit-logger.sh` never sources `davit.conf` at all. It
  hardcodes its own root and log dir (`_D_ROOT="/opt/davit"`,
  `_D_LOGS="${_D_ROOT}/logs"`, lines 32-34) and its own un-prefixed runtime
  vars (`LOG_LEVEL`, `LOG_FORMAT`, `TERMINAL_OUTPUT`, `LOG_TO_LOCAL`,
  `LOG_TO_CENTRAL`) instead of the `DAVIT_LOG_*` names already defined in
  davit.conf LAYER 3 (`DAVIT_LOG_LEVEL`, `DAVIT_LOG_FORMAT`,
  `DAVIT_LOG_CONSOLE`, `DAVIT_LOG_TO_PROJECT`, `DAVIT_LOG_TO_CENTRAL`).
- `/opt/davit/logs/*` is the directory actually being written to today
  (live data, current timestamps).
- `/opt/davit/var/log/*` already exists too, but currently holds unrelated
  content (`fritzbox/`, `tubeit/`, `davit_v1.log`) — not davit-logger output.
  Any migration needs to reconcile this, not just start writing there.
- `ANDES.md` §10 and §11.5 still document `/opt/davit/logs/` as canonical —
  stale relative to davit.conf's already-declared LAYER 2 path.
- `config/multitail/*.conf` and `config/multitail/bash/aliases.sh` hardcode
  `/opt/davit/logs/*.log` paths for tailing — these are query/monitoring
  tooling that would need updating if the canonical dir moves.
- ANDES §4.2 currently puts log rotation/archival "Out of Scope... belongs to
  system administration layer" — needs revisiting: at minimum, davit-logger
  should document the expected rotation contract (e.g. logrotate config
  shipped alongside the module) even if it doesn't rotate logs itself.
- `logging-theme.json` location (`/opt/davit/lib/configs/davit-logger/`) is
  already config-driven via a search path in `davit-logger.sh` (lines 74-78)
  and is NOT part of this problem — only the log *destination* paths and
  runtime switches are hardcoded/misnamed.

### Design questions to resolve in the ANDES draft

1. **Canonical location**: confirm `/opt/davit/var/log/` (FHS-style, already
   declared in davit.conf) vs staying at `/opt/davit/logs/` (current de facto
   location, requires no data migration). Recommendation: adopt
   `/opt/davit/var/log/` to match davit.conf and standard Unix convention,
   with a documented one-time migration of existing `/opt/davit/logs/*`
   content.
2. **Config ownership**: davit-logger.sh should source `davit.conf` (when
   present) for `DAVIT_LOGS_DIR`, `DAVIT_LOG_LEVEL`, `DAVIT_LOG_FORMAT`,
   `DAVIT_LOG_CONSOLE`, `DAVIT_LOG_TO_PROJECT`, `DAVIT_LOG_TO_CENTRAL` —
   renaming its internal vars to match — while still degrading gracefully
   (internal defaults) per FR-010/NR-005 when davit.conf is absent (e.g. on a
   non-DAVIT host). Project-local `.env` (`PROJECT_LOG_DIR`) stays the
   override for the local copy, per the existing project-env.template layering.
3. **Rotation**: size/age policy, tool of choice (`logrotate` vs in-script),
   and where the rotation config itself lives (shipped in `scripts/` or
   `config/`?).
4. **Archiving**: retention window, compression, and destination for aged-out
   logs (relates to existing top-level `archives/` dir in this repo — confirm
   if that's the intended pattern or project-specific only).
5. **Query**: multitail is the existing tool (`config/multitail/*`); confirm
   it remains the standard and update its hardcoded paths to derive from
   config rather than literal `/opt/davit/logs/`.
6. **Management**: who/what is responsible for disk usage alerts, permissions
   (`DAVIT_LOG_MODE`/group-writable umask handling already in
   `_dl_write()`), and multi-host consistency.

## Tasks

- [x] Draft new "Log File Management" section (§12) in `docs/ANDES.md`
      covering: location, config ownership/layering, rotation, archiving,
      query, and operational management procedures.
- [x] Reconcile ANDES §4.2 Out-of-Scope statement on rotation/archival with
      the new procedures (narrowed to "execution... not davit-logger code",
      cross-referenced to §12).
- [x] Update ANDES §10 (Runtime Environment) and §11.5 (Output Files) to
      match the decided canonical location (`${DAVIT_LOGS_DIR}` →
      `/opt/davit/var/log/`), marked explicitly as target state pending
      implementation.
- [ ] Review draft with David; finalise ANDES.md (still `status: draft`,
      v0.2.0).
- [x] Source `davit.conf` in `davit-logger.sh` and derive `_D_LOGS` from
      `DAVIT_LOGS_DIR` (v1.4.6) — done ahead of full ANDES sign-off, forced
      by a live outage (see Notes below). Graceful fallback to the old
      default preserved when `davit.conf` is absent.
- [ ] Migrate `/opt/davit/logs/*` historical data into `/opt/davit/var/log/`
      (David already backed the directory up to
      `/opt/davit/var/backups/logs/` — the live directory itself is gone,
      not just its content).
- [ ] Update `config/multitail/*` configs to derive from `DAVIT_LOGS_DIR`
      instead of the literal `/opt/davit/logs/` path.
- [ ] Add `config/logrotate/davit-logger.logrotate`.
- [ ] Full `DAVIT_LOG_*` variable rename (`LOG_LEVEL`→`DAVIT_LOG_LEVEL` etc.)
      — deferred; only the log *directory* was fixed so far, not the other
      LAYER 3 switches. Separate pass.

## Notes / History

* 2026-07-07: Created
* 2026-07-07: Findings and design questions added after auditing davit.conf,
  src/bin/davit-logger.sh, ANDES.md, and config/multitail/*.
* 2026-07-07: Drafted ANDES.md §12 "Log File Management" (12.1 Canonical
  Location, 12.2 Configuration Ownership, 12.3 Rotation, 12.4 Archiving,
  12.5 Query & Monitoring, 12.6 Permissions & Operational Management, 12.7
  Migration). Renumbered §12–§18 → §13–§19, fixed the one internal
  cross-reference, updated §4.2/§10/§11.5, bumped ANDES to v0.2.0. Awaiting
  David's review before finalising and cutting FEATURE/FIX items.
* 2026-07-07: David deliberately deleted `/opt/davit/logs/` (backed up to
  `/opt/davit/var/backups/logs/`) as a dependency smoke test. Confirmed the
  worst case: every write in the deployed `davit-logger.sh` (v1.4.5, readonly
  fix only) failed with "No such file or directory", because it still
  hardcoded `/opt/davit/logs` and `david` can't `mkdir` directly under
  `/opt/davit/` (2750) to recreate it. Fixed in v1.4.6: sources `davit.conf`
  and uses `DAVIT_LOGS_DIR` (→ `/opt/davit/var/log/`, which already exists).
  Verified locally: writes succeed, no error. Not yet deployed to
  `/opt/davit/bin/` — needs `sudo -u davit cp src/bin/davit-logger.sh
  /opt/davit/bin/`.
* 2026-07-07: `davit-os-alpha` ANDES.md §6 permissions table updated to
  formally retire `/opt/davit/logs/` (cross-project follow-up filed as
  `davit-os-alpha` 2do #20). Broader grep also found two davit-logger-scoped
  stragglers to fold into this migration (§12.7), not #20: (1)
  `davit-log-harness/docs/ANDES.md` (lines 67, 324) — sibling test-harness
  project, same stale `/opt/davit/logs/` convention text, scaffolded from the
  same template as this document originally was; (2)
  `davit-logger-test/scripts/test-04-log.sh` — `log_info` help-text strings
  naming the old paths, not an actual write path.
