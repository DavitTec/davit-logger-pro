---

title: Analysis and Design
version: 0.2.1
status: draft
author: David Mullins
project: davit-logger
package: davit-logger
Language: Bash (primary); Node.js / Python / Go (planned adapters)
target_platform: Linux Mint / DAVIT OS
design_method: SSADM
created: 2026-06-27
last_updated: 2026-07-07
docid: f4a5c39d-c3bf-458f-b8a1-64e86845ee73
---

# Analysis and Design [ANDES]

[TOC]

---

# Part I — Analysis

---

## 1 Introduction

**davit-logger** ([README.md](../README.md)) is the authoritative, universal logging framework for the DAVIT ecosystem. It is the single source of truth for logging behaviour across all DAVIT packages and scripts. The primary implementation is a Bash adapter; multi-language adapters (Node.js, Python, Go) are planned.

### 1.1 Purpose

davit-logger provides a consistent, structured logging layer for all DAVIT system components. It abstracts the mechanics of log formatting, routing, and output so that individual packages need only call a simple API (`log_info`, `log_error`, etc.) and receive:

- Human-readable, colour-coded terminal output during development.
- Pipe-delimited structured text logs for administration and audit.
- JSON-structured logs for machine consumption (ELK, Loki, DEMP).
- Centralised routing to `/opt/davit/logs/` alongside local project logs.

### 1.2 Objectives

- Provide a single, stable logging API consumed by all DAVIT packages.
- Support dual output modes (text and JSON) switchable at runtime without code changes.
- Route log entries to the correct destination by category (SYSTEM, ADMIN, AUDIT, PROJECT).
- Degrade gracefully when configuration, theme, or log directories are absent.
- Support multiple language runtimes through a common specification and per-language adapters.

### 1.3 Intended Audience

| Audience | Interest |
|----------|----------|
| DAVIT Developer | Integration, extension, debugging |
| System Administrator | Log management, rotation, monitoring |
| DEMP Integration Team | Consuming structured JSON output for event processing |
| davit-log-harness | Testing and validating logger behaviour under simulated sessions |

---

## 2 Problem Statement

DAVIT packages historically used ad-hoc `echo` statements and inconsistent log paths, making it impossible to correlate events across packages, filter by severity, or feed logs into automated processing. A centralised, structured logger is required that all packages can source without duplicating formatting, routing, or level-filtering logic. The logger must be lightweight enough to source in any Bash script with no hard dependencies, while producing output rich enough to feed DEMP's event processing layer.

---

## 3 Background

### 3.1 Log Levels

davit-logger defines eight named levels with numeric priorities for filtering:

| Level | Priority | Description |
|-------|----------|-------------|
| `debug` | 10 | Developer diagnostics |
| `info` | 20 | Normal operation |
| `warn` | 30 | Recoverable issue |
| `error` | 40 | Operational failure |
| `critical` | 50 | System-level failure |
| `success` | 25 | Explicit success confirmation |
| `header` | 15 | Section / banner markers |
| `todo` | 12 | Developer reminders (dev mode only) |

### 3.2 Log Categories

Log entries are classified by category to drive routing to the correct destination file:

| Category | Destination | Description |
|----------|-------------|-------------|
| `SYSTEM` | `davit-system.log` | Kernel, boot, OS-level activity |
| `ADMIN` | `davit-admin.log` | Administrative and daemon events |
| `AUDIT` | `davit-audit.log` | Security, user actions, compliance trail |
| `PROJECT` | `davit-projects.log` + local | Application and project-level events |

### 3.3 Log Format

All log entries share a common pipe-delimited structure:

```
TIMESTAMP | USER | LEVEL | CATEGORY | SUBCAT | CONTEXT | EXTRA | MODE | PID | SCRIPT | MESSAGE
```

Example (text):
```
2026-04-19 11:56:12.898 | david | INFO | AUDIT | generic | - | MODE:dev | pid:9707 | script:test-01-log.sh | Audit category test
```

Example (JSON):
```json
{
  "timestamp": "2026-04-27T22:15:38.822Z",
  "level": "INFO",
  "category": "PROJECT",
  "project": "davit-logger-test",
  "version": "1.0.3",
  "mode": "dev",
  "user": "david",
  "pid": 61230,
  "script": "test-05-log.sh",
  "message": "Application started"
}
```

### 3.4 System Context

davit-logger sits at the base of the DAVIT observability stack:

| Package | Relationship |
|---------|-------------|
| **davit-logger** | This package — logging foundation |
| **davit-log-harness** | Test consumer; validates logger output via PTY simulation |
| **DEMP** | Production consumer; processes structured JSON log stream |
| All other DAVIT packages | Source davit-logger to emit their logs |

---

## 4 Scope

### 4.1 In Scope

- Bash logging API (`log_info`, `log_warn`, `log_error`, `log_critical`, `log_debug`, `log_success`, `log_header`)
- Log level filtering (`LOG_LEVEL` environment variable)
- Dual output format: pipe-delimited text and JSON
- Terminal output with ANSI colour theming
- Dual routing: local project log + central `/opt/davit/logs/`
- Category-based routing (SYSTEM, ADMIN, AUDIT, PROJECT)
- Runtime configuration via environment variables and `.env` file
- Command-line flag parsing (`--quiet`, `--verbose`, `--debug`, `--json`, `--no-console`, `--console`)
- Theme loading from `loggin-theme.json`
- Smart project detection (via `package.json` or fallback)
- Graceful degradation when config or log directories are absent
- Bash adapter (current primary implementation)
- Installation script

### 4.2 Out of Scope

- Log aggregation, indexing, or search
- Event correlation or pattern detection (belongs to DEMP)
- Execution of log rotation/archival (performed by `logrotate` and host operations, not davit-logger code — see §12 Log File Management for the location, rotation, and archiving contract this module commits to)
- Monitoring dashboards or alerting
- Multi-language adapters (planned; see §15 Future Work)

---

## 5 Stakeholders

| Stakeholder | Role | Interest |
|-------------|------|----------|
| David Mullins | DAVIT Developer / Author | Design, implementation, maintenance |
| DAVIT Packages (callers) | API consumers | Consistent, reliable log emission |
| davit-log-harness | Test consumer | Reproducible, structured output for validation |
| DEMP | Production consumer | Structured JSON stream for event processing |
| System Administrator | Operations | Log files at known paths, correct permissions |

---

## 6 Requirements

### 6.1 Functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| FR-001 | The logger shall provide named functions for each log level: `log_debug`, `log_info`, `log_warn`, `log_error`, `log_critical`, `log_success`, `log_header`. | High |
| FR-002 | The logger shall filter log entries below the active `LOG_LEVEL` without writing to any output. | High |
| FR-003 | The logger shall write log entries to the correct category destination file in `/opt/davit/logs/`. | High |
| FR-004 | The logger shall write a copy of PROJECT-category entries to the local project log at `./logs/<project>.log`. | High |
| FR-005 | The logger shall support `LOG_FORMAT=text` (pipe-delimited) and `LOG_FORMAT=json` (structured JSON) switchable at runtime. | High |
| FR-006 | The logger shall emit colour-coded terminal output when `TERMINAL_OUTPUT=1` and suppress it when `TERMINAL_OUTPUT=0`. | High |
| FR-007 | The logger shall load colour theme from `loggin-theme.json` when present; fall back to internal defaults when absent. | Medium |
| FR-008 | The logger shall detect the calling project name and version from `package.json` when available. | Medium |
| FR-009 | The logger shall parse command-line flags (`--quiet`, `--verbose`, `--debug`, `--json`, `--no-console`, `--console`) via `davit_parse_flags`. | Medium |
| FR-010 | The logger shall operate without error when log directories, config files, or theme files are absent. | High |

### 6.2 Non-functional Requirements

| ID | Requirement | Priority |
|----|-------------|----------|
| NR-001 | The logger shall execute on Linux Mint 21+ without any packages beyond bash and standard coreutils. | High |
| NR-002 | The logger shall execute on DAVIT OS without modification to core logic. | High |
| NR-003 | The Bash adapter shall conform to POSIX-compatible Bash (v4.0+) with no ksh or zsh extensions. | High |
| NR-004 | Sourcing the logger shall add no measurable latency to the calling script when no log entries are emitted. | High |
| NR-005 | The logger shall not exit or abort the calling script on internal failure; all errors shall be handled silently or via bootstrap log only. | High |
| NR-006 | The logger shall guard against double-sourcing via the `_D_LOGGER_LOADED` guard variable. | High |
| NR-007 | Log entries shall contain a monotonic timestamp accurate to millisecond resolution. | Medium |

### 6.3 Assumptions

- Bash 4.0+ is available on the target host.
- `/opt/davit/logs/` is writable by the executing user, or can be created on first use.
- The calling script sources the logger before invoking any log function.
- `D_MODE` (dev / stage / prod) is set in the environment or `.env` file; if absent, the logger defaults to `dev`.
- `jq` is available when JSON theme parsing is required; if absent, internal colour defaults apply.

---

# Part II — System Design

---

## 7 Architecture

### 7.1 Overview

davit-logger is a sourced Bash library, not a daemon. Callers source `davit-logger.sh` and immediately gain access to the logging API. No background process is started; all I/O is synchronous within the calling script's process.

The adapter pattern isolates the specification (log levels, format, routing rules) from the runtime implementation. The Bash adapter is the current reference implementation; future adapters (Node.js, Python, Go) will implement the same specification.

### 7.2 Primary Architecture Diagram

```mermaid

```

### 7.3 Component Interaction

```
Caller Script
      ↓  source davit-logger.sh
Config Loader ← .env / environment
      ↓
Theme Loader  ← loggin-theme.json
      ↓
Project Detector ← package.json
      ↓
  log_info / log_error / etc.
      ↓
Level Filter (_dl_should_log)
      ↓
Formatter (text | JSON)
      ↓
      ├─→ Terminal Output (ANSI colour)
      └─→ Router
              ├─→ Central Log  /opt/davit/logs/<category>.log
              └─→ Local Log    ./logs/<project>.log
```

### 7.4 Design Principles

| Principle | Description |
|-----------|-------------|
| Single Source of Truth | One logger specification, consumed by all DAVIT packages. |
| Fail Safe | Internal errors must never abort the calling script. |
| Zero Hard Dependencies | Core Bash adapter requires only bash and coreutils. |
| Runtime Configurable | All behaviour controlled by environment variables; no recompilation. |
| Adapter Pattern | Specification is language-independent; adapters implement it per runtime. |
| Graceful Degradation | Missing config, theme, or log directories produce warnings, not failures. |

### 7.5 Design Rationale

The library-sourcing model (rather than a daemon or subprocess) was chosen because:

- No IPC overhead; logging is a synchronous call in-process.
- Works correctly inside PTY sessions, subshells, and piped commands.
- Compatible with `set -e` / `set -Eeo pipefail` calling scripts via careful internal error handling.
- Installable as a single file with no service management.

The category-routing model (rather than a single log file) allows administrators and DEMP to tail or index only the relevant stream without grep-filtering a monolithic file.

---

## 8 Components

### 8.1 Config Loader

- **Responsibilities**: Reads `.env` file if present; exports `LOG_LEVEL`, `TERMINAL_OUTPUT`, `LOG_TO_LOCAL`, `LOG_TO_CENTRAL`, `LOG_FORMAT`, `D_MODE` with safe defaults if absent.
- **Inputs**: `.env` file in the calling project root; shell environment.
- **Outputs**: Exported environment variables available to all subsequent functions.
- **Errors**: If `.env` is unreadable, defaults apply silently.

### 8.2 Theme Loader

- **Responsibilities**: Reads `loggin-theme.json` from a set of known paths; maps level names to ANSI colour codes; falls back to internal hardcoded colours if no file is found.
- **Inputs**: `loggin-theme.json` (searched in lib, bin, and `~/.config/davit/`).
- **Outputs**: Populated `DAVIT_COLOR_*` global variables.
- **Errors**: Missing or malformed theme file silently applies internal defaults.

### 8.3 Project Detector

- **Responsibilities**: Resolves the calling project's name and version from `package.json` in the working directory or a parent; falls back to the directory name.
- **Inputs**: `package.json` (optional).
- **Outputs**: `_DL_PROJECT` and `_DL_VERSION` variables used in log entries.
- **Errors**: If no `package.json` is found, directory name is used as project identifier.

### 8.4 Level Filter

- **Responsibilities**: Compares the entry's level priority against the active `LOG_LEVEL`; suppresses the entry if below threshold.
- **Inputs**: Entry level, active `LOG_LEVEL`.
- **Outputs**: Pass or suppress decision.
- **Errors**: Unknown level names default to INFO priority.

### 8.5 Formatter

- **Responsibilities**: Assembles the log entry string in either pipe-delimited text or JSON format based on `LOG_FORMAT`.
- **Inputs**: Level, category, message, metadata (user, pid, script, project, version, mode).
- **Outputs**: Formatted log string.
- **Errors**: None; formatting is pure string construction.

### 8.6 Router

- **Responsibilities**: Writes formatted entries to the correct destination files based on category and routing switches.
- **Inputs**: Formatted log string, category, `LOG_TO_LOCAL`, `LOG_TO_CENTRAL` switches.
- **Outputs**: Appended lines in `/opt/davit/logs/<category>.log` and/or `./logs/<project>.log`.
- **Errors**: Write failures are silently swallowed to protect the calling script.

### 8.7 Flag Parser

- **Responsibilities**: Parses command-line flags passed to `davit_parse_flags`; sets runtime variables accordingly.
- **Inputs**: `"$@"` from the calling script.
- **Outputs**: Updated `LOG_LEVEL`, `TERMINAL_OUTPUT`, `LOG_FORMAT` variables.
- **Errors**: Unknown flags are ignored.

---

## 9 Data Flow

### 9.1 Normal Log Entry Flow

```
Caller: log_info "message"
      ↓
_dl_should_log  →  suppressed if below LOG_LEVEL
      ↓
_dl_build_entry (text | JSON)
      ↓
      ├─→ [TERMINAL_OUTPUT=1] print to stdout with ANSI colour
      └─→ [LOG_TO_CENTRAL=1]  append to /opt/davit/logs/<category>.log
          [LOG_TO_LOCAL=1]    append to ./logs/<project>.log
```

### 9.2 Bootstrap Flow (pre-config)

Before the Config Loader has run, the logger uses a minimal bootstrap function that writes to `davit.log` only, without colour or routing, to capture any initialisation errors.

```
source davit-logger.sh
      ↓
_dl_bootstrap_log (direct write, no theme/config)
      ↓
Config Loader
      ↓
Theme Loader
      ↓
Project Detector
      ↓
Logger ready
```

---

## 10 Runtime Environment

davit-logger runs inside the host Linux environment under the DAVIT framework root at `/opt/davit/`. It has no daemon, no background process, and no service registration. It is activated by sourcing.

**Path layout at runtime:**

```
/opt/davit/
├── bin/
│   └── davit-logger.sh          # Installed logger (sourced by callers)
├── etc/
│   └── davit.conf               # Central config — source of DAVIT_LOGS_DIR etc. (§12.2)
├── lib/
│   └── configs/davit-logger/
│       └── loggin-theme.json    # Colour theme
└── var/log/                     # DAVIT_LOGS_DIR — canonical (§12.1)
    ├── davit.log                # MAIN / default
    ├── davit-audit.log          # AUDIT category
    ├── davit-admin.log          # ADMIN category
    ├── davit-system.log         # SYSTEM category
    ├── davit-projects.log       # PROJECT category (central copy)
    └── archive/                 # Rotated + compressed logs (§12.4)
```

> **Target state.** As of this revision, `davit-logger.sh` still writes to
> the legacy `/opt/davit/logs/` and does not yet source `davit.conf`. See
> §12 Log File Management and
> [2do #2](./ISSUES/2-[NEW]_draft-andes-md-log-file-location-rotation-archiving-query-config-management-procedures.md)
> for the migration plan.

---

## 11 Interfaces

### 11.1 Public Logging API

- **Purpose**: The functions callers invoke to emit log entries.
- **Inputs**: Message string; optional metadata overrides.
- **Outputs**: Terminal output and/or file entries depending on runtime configuration.
- **Dependencies**: Logger must be sourced; `LOG_LEVEL` must be set or defaulted.

```bash
log_debug    "message"
log_info     "message"
log_warn     "message"
log_error    "message"
log_critical "message"
log_success  "message"
log_header   "message"
log_todo     "message"
```

### 11.2 Flag Parser API

- **Purpose**: Allows calling scripts to expose logger flags to their own CLI.
- **Inputs**: `"$@"` — raw command-line arguments from the calling script.
- **Outputs**: Updated runtime variables (`LOG_LEVEL`, `TERMINAL_OUTPUT`, `LOG_FORMAT`).
- **Dependencies**: Must be called after sourcing but before the first log call.

```bash
davit_parse_flags "$@"
```

Supported flags:

| Flag | Effect |
|------|--------|
| `--quiet` | Errors only; disables console output |
| `--verbose` | Sets `LOG_LEVEL=INFO` |
| `--debug` | Sets `LOG_LEVEL=DEBUG`; enables console |
| `--json` | Sets `LOG_FORMAT=json` |
| `--text` | Sets `LOG_FORMAT=text` |
| `--no-console` | Sets `TERMINAL_OUTPUT=0` |
| `--console` | Sets `TERMINAL_OUTPUT=1` |

### 11.3 Configuration Interface

- **Purpose**: Controls all logger behaviour at runtime without code changes.
- **Inputs**: Shell environment or `.env` file in the project root.
- **Outputs**: Active configuration applied to all subsequent log calls.
- **Dependencies**: Loaded at source time.

| Variable | Default | Description |
|----------|---------|-------------|
| `LOG_LEVEL` | `INFO` | Minimum level to emit: DEBUG / INFO / WARN / ERROR / CRITICAL |
| `TERMINAL_OUTPUT` | `1` | `1` = emit to terminal; `0` = suppress terminal |
| `LOG_TO_LOCAL` | `1` | `1` = write to local `./logs/<project>.log` |
| `LOG_TO_CENTRAL` | `1` | `1` = write to `/opt/davit/logs/` |
| `LOG_FORMAT` | `text` | `text` = pipe-delimited; `json` = structured JSON |
| `D_MODE` | `dev` | Execution mode: `dev` / `stage` / `prod` |

### 11.4 Theme Interface

- **Purpose**: Defines ANSI colour assignments for each log level.
- **Inputs**: `loggin-theme.json` file (searched at install paths and `~/.config/davit/`).
- **Outputs**: Populated `DAVIT_COLOR_*` variables.
- **Dependencies**: `jq` recommended for full JSON parsing; internal defaults used as fallback.

### 11.5 Output Files

- **Purpose**: Persistent log records written by the router.
- **Inputs**: Formatted log entries from the Formatter.
- **Outputs**: Appended lines at the destinations below.

| File | Category | Notes |
|------|----------|-------|
| `${DAVIT_LOGS_DIR}/davit.log` | All (default) | Master log; receives all entries not matched by a specific category |
| `${DAVIT_LOGS_DIR}/davit-audit.log` | AUDIT | Security and compliance events |
| `${DAVIT_LOGS_DIR}/davit-admin.log` | ADMIN | Administrative and daemon events |
| `${DAVIT_LOGS_DIR}/davit-system.log` | SYSTEM | Kernel and OS-level events |
| `${DAVIT_LOGS_DIR}/davit-projects.log` | PROJECT | Central copy of all project-level entries |
| `<project>/logs/<project>.log` | PROJECT | Local copy within the calling project |

`${DAVIT_LOGS_DIR}` resolves to `/opt/davit/var/log/` per §12.1/§12.2 — see
that section for current-vs-target status and rotation/archiving (§12.3,
§12.4).

### 11.6 Traceability

| Requirement | Component | Pseudocode | Script |
|-------------|-----------|------------|--------|
| FR-001 | Public Logging API | bash-adapter.pseudocode | davit-logger.sh |
| FR-002 | Level Filter | bash-adapter.pseudocode | davit-logger.sh |
| FR-003 | Router | bash-adapter.pseudocode | davit-logger.sh |
| FR-004 | Router | bash-adapter.pseudocode | davit-logger.sh |
| FR-005 | Formatter | bash-adapter.pseudocode | davit-logger.sh |
| FR-006 | Formatter + Router | bash-adapter.pseudocode | davit-logger.sh |
| FR-007 | Theme Loader | bash-adapter.pseudocode | davit-logger.sh |
| FR-008 | Project Detector | bash-adapter.pseudocode | davit-logger.sh |
| FR-009 | Flag Parser | bash-adapter.pseudocode | davit-logger.sh |
| FR-010 | All components | bash-adapter.pseudocode | davit-logger.sh |

---

## 12 Log File Management

Location, rotation, archiving, query, and configuration ownership for all log
files produced by davit-logger and consumed across the DAVIT domain. This
section resolves the drift tracked in
[2do #2](./ISSUES/2-[NEW]_draft-andes-md-log-file-location-rotation-archiving-query-config-management-procedures.md):
`davit.conf` already declares a canonical log directory that the Bash adapter
does not yet honour.

### 12.1 Canonical Location

| Scope | Path | Notes |
|-------|------|-------|
| Domain-central logs | `${DAVIT_LOGS_DIR}` → `/opt/davit/var/log/` | Canonical; matches the FHS `var/log` convention and the value already declared in `davit.conf` LAYER 2. Replaces the current de facto `/opt/davit/logs/`. |
| Project-local copy | `${PROJECT_LOG_DIR}` → `<project>/logs/<project>.log` | Unchanged; per `project-env.template`. Not affected by this decision. |

`/opt/davit/logs/` is retired as a log destination once the migration
(§12.7) is complete. `/opt/davit/var/log/` already exists on this host but
currently holds unrelated content (`fritzbox/`, `tubeit/`, `davit_v1.log`);
davit-logger's files are added alongside it, not replacing it.

### 12.2 Configuration Ownership

davit-logger must not hardcode `/opt/davit` or maintain its own copy of the
logging switches. `davit.conf` LAYER 2/3 is already the intended source of
truth:

```
DAVIT_LOGS_DIR       = ${DAVIT_ROOT}/var/log
DAVIT_LOG_LEVEL       (deprecated alias: LOG_LEVEL)
DAVIT_LOG_FORMAT      (deprecated alias: LOG_FORMAT)
DAVIT_LOG_CONSOLE     (deprecated alias: TERMINAL_OUTPUT)
DAVIT_LOG_TO_PROJECT  (deprecated alias: LOG_TO_LOCAL)
DAVIT_LOG_TO_CENTRAL  (no rename needed — already matches)
```

`davit.conf` already marks `LOG_LEVEL`, `LOG_FORMAT`, `TERMINAL_OUTPUT`, and
`LOG_TO_LOCAL` as deprecated aliases of the `DAVIT_LOG_*` names — the config
layer anticipated exactly the names the Bash adapter currently uses
internally. Closing that loop is the fix:

1. `davit-logger.sh` sources `davit.conf` (when present at
   `${DAVIT_ROOT}/etc/davit.conf`) before applying its own defaults.
2. Internal variables are renamed to the `DAVIT_LOG_*` forms; the old names
   remain accepted as input for one deprecation cycle, per the deprecated-
   alias convention already used throughout `davit.conf`.
3. When `davit.conf` is absent (e.g. running outside a DAVIT host), the
   adapter falls back to its current internal defaults, per FR-010 / NR-005 —
   preserving "zero hard dependencies" (§7.4).
4. Project-local `.env` may still override `PROJECT_LOG_DIR` for the local
   copy only; it must never redefine `DAVIT_LOGS_DIR` (domain-wide, LAYER 2 —
   "never override in project scripts").

### 12.3 Rotation

davit-logger opens, appends, and closes each destination file on every write
(`_dl_write()` — no long-lived file descriptor is held open), so standard
`logrotate` works without `copytruncate` and without signalling the process.
Rotation is therefore a system-administration concern executed by
`logrotate`, not by davit-logger code; davit-logger's contract is limited to
writing to a stable, config-derived path.

Proposed default policy (host-tunable):

| Setting | Value |
|---------|-------|
| Frequency | weekly |
| Keep | 8 rotations (~2 months) |
| Compression | `compress`, `delaycompress` (skip the most recent rotation) |
| Ownership/mode | preserve `DAVIT_LOG_MODE` (660) and `davit` group |

Shipped as `config/logrotate/davit-logger.logrotate`, templated against
`${DAVIT_LOGS_DIR}` (never a literal path), installed by `install.sh`.

### 12.4 Archiving

Archiving is distinct from rotation: rotation manages recent files in place;
archiving moves aged-out, already-rotated logs to cold storage.

| Scope | Destination | Retention |
|-------|-------------|-----------|
| Domain-central | `${DAVIT_LOGS_DIR}/archive/` | Compressed rotations older than the rotation window, until manually pruned or a size cap is hit |
| Per-project | `<project>/archives/` | Existing convention (see this repo's own `archives/` directory) — project-specific, not prescribed further here |

No automated deletion is proposed at this stage; archiving is a move +
compress step, not a retention-expiry deletion policy. Automated expiry is
future work (§15) once volume data justifies one.

### 12.5 Query & Monitoring

`multitail` remains the standard interactive query tool
(`config/multitail/*.conf`, `config/multitail/bash/aliases.sh`). These
currently hardcode `/opt/davit/logs/*.log`. Once the canonical location moves
(§12.1):

- `config/multitail/bash/aliases.sh` (a Bash script) sources `davit.conf` and
  references `${DAVIT_LOGS_DIR}` directly instead of the literal path.
- The static `*.conf` scheme files (multitail's own config format) cannot
  read shell variables at multitail-runtime; `install.sh` templates the
  resolved `${DAVIT_LOGS_DIR}` into them at install time instead of shipping
  the literal `/opt/davit/logs/` path.

### 12.6 Permissions & Operational Management

- File mode `660` / writable-dir mode `2770` (setgid, `davit` group) per
  `davit.conf` LAYER 7 (`DAVIT_LOG_MODE`, `DAVIT_WRITABLE_DIR_MODE`) —
  already enforced by the `umask 002` guard in `_dl_write()` (see CHANGELOG
  v1.6.1, "force group-writable umask around log file writes").
- Disk-usage alerting is out of scope for davit-logger; it is a future
  DEMP/monitoring concern (§16 DEMP Integration), not this module's
  responsibility.
- Multi-host consistency: any host running DAVIT packages is expected to
  source the same `davit.conf` shape, so `DAVIT_LOGS_DIR` resolves
  consistently — no per-host hardcoding.

### 12.7 Migration (current → target)

| Step | Action |
|------|--------|
| 1 | Ship `davit.conf` sourcing + `DAVIT_LOG_*` rename in `davit-logger.sh` (deprecated aliases still accepted). |
| 2 | One-time move of existing `/opt/davit/logs/*` content into `/opt/davit/var/log/`, reconciled with the unrelated content already there. |
| 3 | Update `config/multitail/*` paths (§12.5). |
| 4 | Install `config/logrotate/davit-logger.logrotate` (§12.3). |
| 5 | §10 and §11.5 of this document already reflect the target state, ahead of the code — update them again only if the target changes. |

Tracked as
[2do #2](./ISSUES/2-[NEW]_draft-andes-md-log-file-location-rotation-archiving-query-config-management-procedures.md);
split into FEATURE/FIX items once this section is approved.

---

## 13 Package Structure

```
davit-logger/
│
├── README.md                   # User guide and quick start
├── LICENSE                     # DAVIT licence
├── CHANGELOG.md                # Changelog
├── requirements.yaml           # Package and IDE requirements
├── INSTALL                     # Installation instructions
├── .env                        # Local development environment
├── .env.example                # Example .env for reference
│
├── docs/
│   ├── ANDES.md                # Analysis & design (this document)
│   ├── log-format.md           # Log format specification
│   ├── logging-specs.md        # Logging specification v1.0
│   ├── Pseudocode.md           # Pseudocode for Bash and Node adapters
│   ├── color-schemes.md        # Theme and colour scheme reference
│   ├── bash-aliases.md         # Recommended bash aliases for development
│   ├── multitail-integration.md # Multitail setup for log monitoring
│   └── disaster-recovery.md   # Recovery procedures
│
├── charts/
│   └── MERMAID_DIAGRAMS.md     # Architecture and flow diagrams
│
├── src/                         # Source root (DAVIT src/ standard — see below)
│   ├── bin/
│   │   └── davit-logger.sh     # Bash adapter — primary implementation
│   └── lib/configs/davit-logger/
│       └── logging-theme.json  # Colour theme
│
├── scripts/                     # Build/install/test tooling — NOT application source
│   ├── install.sh              # Installation script
│   ├── build.sh                # Build script
│   ├── test_davit_logger.sh    # Test suite
│   └── theme_davit.sh          # Theme utility
│
├── config/
│   └── multitail/              # multitail query configs (§12.5)
│
├── tests/
│   ├── basic_test.sh           # Basic integration tests
│   └── test-v1.3.sh            # Version 1.3 regression tests
│
├── logs/
│   ├── davit-logger.log        # Local development log
│   └── events.jsonl            # JSON event stream (development)
│
└── archives/                   # Historical snapshots and old versions
```

> **`src/` vs `scripts/`.** Per the DAVIT platform standard
> (`davit-os-alpha` ANDES.md §6, Project Structure Standard), `src/` is the
> only valid location for application source — davit-logger's primary
> implementation lives at `src/bin/davit-logger.sh` (not `scripts/`, as an
> earlier revision of this document incorrectly showed). `scripts/` is
> retained here only for build/install/test tooling, which the platform-wide
> migration issue (`davit-os-alpha` 2do #10) treats as acceptable — only
> application source is required to live under `src/`.

---

# Part III — Implementation Design

---

## 14 Pseudocode Design

Each pseudocode module is maintained under `docs/pseudocode/` (to be created). Current pseudocode is consolidated in [docs/Pseudocode.md](./Pseudocode.md).

**Bash Adapter (current)**

```
FUNCTION load_env():
    IF .env exists THEN
        export variables
    ELSE
        apply defaults

FUNCTION load_theme(file):
    IF file exists THEN
        parse ANSI colours into DAVIT_COLOR_* vars
    ELSE
        use internal hardcoded defaults

FUNCTION log(level, message):
    IF level_priority < LOG_LEVEL THEN
        return
    colour = DAVIT_COLOR_[level]
    entry  = format(timestamp, user, level, category, message)
    IF TERMINAL_OUTPUT=1 THEN print coloured entry
    IF LOG_TO_CENTRAL=1  THEN append to /opt/davit/logs/<category>.log
    IF LOG_TO_LOCAL=1    THEN append to ./logs/<project>.log
```

---

## 15 Future Work

- **v1.6.0**: Node.js ESM adapter; unified error code system (JSON schema).
- **v1.7.0**: Python and Go adapters conforming to the same specification.
- **v2.0.0**: Central log management daemon; log rotation policies; log streaming API.
- Structured pseudocode directory (`docs/pseudocode/`) with per-component files.
- Formal JSON schema for `loggin-theme.json` and error codes file.
- Log entry validation against schema (optional strict mode).

---

## 16 DEMP Integration

davit-logger is a primary data source for DEMP (DAVIT Event Management Platform). The integration boundary is:

```
DAVIT Packages
      ↓  (source and call)
davit-logger
      ↓  (structured JSON log stream)
    DEMP
      ↓
Event Processing / Correlation / Alerts
```

davit-logger's responsibility ends at writing structured output. DEMP is responsible for consuming, correlating, and acting on that output. The JSON log format (`LOG_FORMAT=json`) is the intended production interface for DEMP consumption.

See [DEMP README](/opt/davit/development/event-management-platform/README.md).

---

## 17 References

- [Bash Logging Specification](./logging-specs.md)
- [Log Format Reference](./log-format.md)
- [Pseudocode](./Pseudocode.md)
- [DAVIT Event Management Platform (DEMP)](/opt/davit/development/event-management-platform/README.md)
- [davit-log-harness](/opt/davit/development/davit-log-harness/README.md) — test harness for this package

---

## 18 Glossary

| Term | Explanation |
|------|-------------|
| ANDES | Analysis and Design |
| ANSI | American National Standards Institute — terminal colour escape codes |
| Adapter | A language-specific implementation of the davit-logger specification |
| DAVIT | DAVIT personal OS and tooling framework |
| DEMP | DAVIT Event Management Platform |
| D_MODE | Execution mode: dev / stage / prod |
| JSON | JavaScript Object Notation — structured log format |
| PTY | Pseudo Terminal |
| Router | Component that directs log entries to destination files |
| SSADM | Structured Systems Analysis and Design Method |

---

## 19 Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 0.1.0 | 2026-06-27 | David Mullins | Initial skeleton — SSADM structure, content derived from existing docs and source |
| 0.2.0 | 2026-07-07 | David Mullins (drafted with Claude) | Added §12 Log File Management (location, config ownership, rotation, archiving, query, permissions, migration plan); updated §4.2, §10, §11.5 to reference it; renumbered §12–§18 → §13–§19 |
| 0.2.1 | 2026-07-07 | David Mullins (drafted with Claude) | Corrected §13 Package Structure — primary implementation is `src/bin/davit-logger.sh`, not `scripts/davit-logger.sh`; clarified `src/` vs `scripts/` per `davit-os-alpha` platform standard |

---

# Appendix

---

## Appendix I — Known Issues

Active issues are tracked in [docs/ISSUES/](./ISSUES/).

| ID | Issue | Status |
|----|-------|--------|
| ISS-001 | Version variables need alignment with new `davit-config` system | Open |
