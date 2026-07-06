---

title: Analysis and Design
version: 0.1.0
status: draft
author: David Mullins
project: davit-logger
package: davit-logger
Language: Bash (primary); Node.js / Python / Go (planned adapters)
target_platform: Linux Mint / DAVIT OS
design_method: SSADM
created: 2026-06-27
last_updated: 2026-06-27
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
- Log rotation or archival (belongs to system administration layer)
- Monitoring dashboards or alerting
- Multi-language adapters (planned; see §14 Future Work)

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
├── lib/
│   └── configs/davit-logger/
│       └── loggin-theme.json    # Colour theme
└── logs/
    ├── davit.log                # MAIN / default
    ├── davit-audit.log          # AUDIT category
    ├── davit-admin.log          # ADMIN category
    ├── davit-system.log         # SYSTEM category
    └── davit-projects.log       # PROJECT category (central copy)
```

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
| `/opt/davit/logs/davit.log` | All (default) | Master log; receives all entries not matched by a specific category |
| `/opt/davit/logs/davit-audit.log` | AUDIT | Security and compliance events |
| `/opt/davit/logs/davit-admin.log` | ADMIN | Administrative and daemon events |
| `/opt/davit/logs/davit-system.log` | SYSTEM | Kernel and OS-level events |
| `/opt/davit/logs/davit-projects.log` | PROJECT | Central copy of all project-level entries |
| `<project>/logs/<project>.log` | PROJECT | Local copy within the calling project |

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

## 12 Package Structure

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
├── scripts/
│   ├── davit-logger.sh         # Bash adapter — primary implementation
│   ├── install.sh              # Installation script
│   ├── test_davit_logger.sh    # Test suite
│   └── theme_davit.sh          # Theme utility
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

---

# Part III — Implementation Design

---

## 13 Pseudocode Design

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

## 14 Future Work

- **v1.6.0**: Node.js ESM adapter; unified error code system (JSON schema).
- **v1.7.0**: Python and Go adapters conforming to the same specification.
- **v2.0.0**: Central log management daemon; log rotation policies; log streaming API.
- Structured pseudocode directory (`docs/pseudocode/`) with per-component files.
- Formal JSON schema for `loggin-theme.json` and error codes file.
- Log entry validation against schema (optional strict mode).

---

## 15 DEMP Integration

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

## 16 References

- [Bash Logging Specification](./logging-specs.md)
- [Log Format Reference](./log-format.md)
- [Pseudocode](./Pseudocode.md)
- [DAVIT Event Management Platform (DEMP)](/opt/davit/development/event-management-platform/README.md)
- [davit-log-harness](/opt/davit/development/davit-log-harness/README.md) — test harness for this package

---

## 17 Glossary

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

## 18 Revision History

| Version | Date | Author | Description |
|---------|------|--------|-------------|
| 0.1.0 | 2026-06-27 | David Mullins | Initial skeleton — SSADM structure, content derived from existing docs and source |

---

# Appendix

---

## Appendix I — Known Issues

Active issues are tracked in [docs/ISSUES/](./ISSUES/).

| ID | Issue | Status |
|----|-------|--------|
| ISS-001 | Version variables need alignment with new `davit-config` system | Open |
