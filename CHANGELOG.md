# Changelog

All notable changes to the ["/DavitTec/davit-logger"](/DavitTec/davit-logger) project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)/(_Davit Scheme v0.1.2_)

## [Unreleased]

### 🐛 Bug Fixes

Remove `readonly` from `_D_LOGGER_LOADED`, `user`, `_D_ROOT`, `_D_BIN`,
`_D_LOGS`, `_D_LIB` in `davit-logger.sh` (v1.4.4 → v1.4.5).

Per the bash manual, assigning to a `readonly` variable "fails and the shell
exits" in a non-interactive shell — unconditionally, regardless of `set -e`.
Any re-source of `davit-logger.sh` in the same shell process (a developer
re-sourcing after an edit, a long-lived daemon, a wrapper script sourcing
several sub-scripts) that reached past the `_D_LOGGER_LOADED` guard would
crash the entire calling process the instant the `readonly` lines executed
a second time. The guard exists precisely to make re-sourcing a safe no-op;
that only holds if nothing it protects is `readonly`. Confirmed fixed: a
forced re-source (bypassing the guard) now completes without error where it
previously terminated the shell.

Source `davit.conf` for `DAVIT_LOGS_DIR` instead of hardcoding
`/opt/davit/logs` (v1.4.5 → v1.4.6).

`davit-logger.sh` now sources `${DAVIT_ROOT:-/opt/davit}/etc/davit.conf`
(when not already sourced by the caller) and derives `_D_ROOT`/`_D_LOGS`
from `DAVIT_ROOT`/`DAVIT_LOGS_DIR`, falling back to the old hardcoded
defaults only when `davit.conf` isn't present at all (FR-010/NR-005 — zero
hard dependencies preserved). Logs now land in `/opt/davit/var/log/` (the
canonical location per ANDES.md §12), not the retired `/opt/davit/logs/`.
Surfaced by David deliberately deleting `/opt/davit/logs/` as a dependency
smoke test — every write failed with "No such file or directory" because
`david` (non-owner) can't `mkdir` directly under `/opt/davit/` root (2750)
to recreate it, and the script had no config-driven fallback location to
try instead.

## [1.6.1] - 2026-07-06 ([v1.6.1](/DavitTec/davit-logger/releases/tag/v1.6.1))

### 🐛 Bug Fixes

Force group-writable umask around log file writes (b18a1cd…)

/opt/davit/*/logs/ dirs are shared within the davit group (setgid,
e.g. drwxrws---), but _dl_write() and the project-log-header init
block created new log files under whatever umask the calling process
had, so a file first created by one user (e.g. david, 640) blocked
every other group member (e.g. davit) from appending to it later.

Surfaced by: `sudo -u davit scripts/install.sh --all` failing with
"Permission denied" writing to this project's own
logs/davit-logger.log, which had been created earlier under david.

Wraps each write site in umask 002 / restore, so new log files are
always created 664 regardless of the caller's umask. Existing files
created before this fix still need a one-time chmod g+w.

### 📚 Documentation

Close issue #1 (fixed and merged in v1.6.0) (59d192a…)

## [1.6.0] - 2026-07-06 ([v1.6.0](/DavitTec/davit-logger/releases/tag/v1.6.0))

### ⚙️ Miscellaneous Tasks

Bump project_version to 1.6.0 (c858e00…)

Also fixes a stale header comment in src/bin/davit-logger.sh left over
from the src/ restructuring (still said "Script: src/davit-logger.sh").

Restore executable bit on build.sh/install.sh (f222444…)

Re-register davit-logger.sh in manifest.json with correct bin_name (ded4a28…)

Unregister davit-logger.sh from manifest.json (da78295…)

Re-adding next to pick up the new Bin-Name header (preserves the literal
davit-logger.sh filename instead of the auto-derived davit_logger).

Register src/configs/davit-logger/logging-theme.json in manifest.json (376d17f…)

Register src/davit-logger.sh in manifest.json (4ae1055…)

### 🐛 Bug Fixes

Correct logging-theme.json version in manifest.json (055655d…)

manifest add couldn't read the version from JSON artifacts (bug in
the manifest project's extract_metadata, fixed separately); backfilling
the correct 1.4.3 here now that manifest_manager.sh supports it.

Align version-variable detection and restructure src/ for dist build [#1](/DavitTec/davit-logger/issues/1) (7c404fc…)

_dl_detect_context() now reads PROJECT_VERSION= (falling back to VERSION=)
so D_PRJ_VER no longer shows "unknown" for projects using the new .env
template. Moves davit-logger.sh and its theme JSON into src/, rewrites
scripts/build.sh (was a stray copy from the generate-env project) to
assemble dist/, and rewrites scripts/install.sh to deploy from dist/
instead of scripts/. Also fixes a loggin-theme.json -> logging-theme.json
typo that silently broke theme loading, and drops the superseded root
INSTALL script now that scripts/install.sh covers it.

Missing bin root (f40b90d…)

Add package version check (966e347…)

INSTALL script (af7c815…)

### 📚 Documentation

Update CHANGELOG for v1.6.0 (4ba7d14…)

Update CHANGELOG (8c6f3f7…)

### 🚜 Refactor

Mirror src/ layout to the real /opt/davit deploy targets (c7cb6f8…)

Manifest-driven build.sh/install.sh, matching manifest project's pattern (7cb6d89…)

Replaces the hardcoded copy/paste build.sh and install.sh with the
manifest-driven pattern already proven in the manifest and generate-env
projects: build.sh assembles dist/ from manifest.json's artifact list and
writes an enriched dist/manifest.json (dist_path + sha256); install.sh
reads dist/manifest.json and deploys to ${DAVIT_ROOT}/<dist_path>, gated
by a GADM identity check (must run as the davit user), a PROJECT_STATUS/
branch deploy-context check, per-artifact status ("deployed"/--force),
and pre-install backups.

Also fixes an edge case the reference pattern doesn't handle: manifest
paths for artifacts that sit directly in src/ (not a subdirectory) are
exactly "src", and "${path#src/}" doesn't strip that — it would leak a
literal "src" segment into dist/ and the install target. Added
_strip_src_prefix() to handle both cases correctly.

Also adds a Bin-Name header to src/davit-logger.sh: it's a sourced
library (source "/opt/davit/bin/davit-logger.sh" appears throughout the
DAVIT ecosystem), not an aliased CLI tool, so it must keep its literal
filename in dist/ and /opt/davit/bin/ rather than the auto-derived
bin_name ("davit_logger") the manifest-driven build otherwise assumes.

## [1.5.0] - 2026-04-27 ([v1.5.0](/DavitTec/davit-logger/releases/tag/v1.5.0))

### 🐛 Bug Fixes

Update logger with feat v1.3.x (7555680…)

- fix: changed theme name (e1a98b9…)

### 📚 Documentation

Update README (41ed98e…)

### 🚀 Features

_(logger)_
V1.3.2 - Add JSON output mode + improved console/routing control (edd141e…)

- Added LOG_FORMAT=text|json support with structured fields
- Enhanced davit_parse_flags with --json/--text
- Improved _dl_should_log robustness (no more arithmetic errors)
- Better console control and routing flexibility
- Updated test-05-log.sh with comprehensive coverage

## [1.4.15] - 2026-04-21 ([v1.4.15](/DavitTec/davit-logger/releases/tag/v1.4.15))

### ⚙️ Miscellaneous Tasks

Update screenshot (9f02970…)

Update (c139919…)

### 🐛 Bug Fixes

Davit-logger (1.2.15) (0612e9e…)

- fix: INSTALL
- add: temp install.sh minimal
- doc: README minor fix
- update: log-format-md

Install and logger v1.4.0 (d39228e…)

### 📚 Documentation

Update readme (69b33ea…)

Update README.md (875f522…)

### 🚀 Features

Add multtail drafts WIP (220f2a7…)

- clean: maintenance

Add mutitail configs (05694b6…)

- add: docs
  _(davit-logger)_
  Merge #003 dev/v0.3.3 (v1.4.0) (35d5c06…)

Add v0.3.3 package (89ba529…)

## [0.4.0] - 2026-03-03 ([v0.4.0](/DavitTec/davit-logger/releases/tag/v0.4.0))
