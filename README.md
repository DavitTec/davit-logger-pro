# Davit Logger Pro

[![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/DavitTec/davit-logger-pro?style=for-the-badge&logo=github)](https://github.com/DavitTec/davit-logger-pro/tag)[![GitHub open issues](https://img.shields.io/github/issues-raw/DavitTec/davit-logger-pro?style=for-the-badge&label=Open%20Issues)](https://github.com/DavitTec/davit-logger-pro/issues)[![GitHub top language](https://img.shields.io/github/languages/top/DavitTec/davit-logger-pro?style=for-the-badge)](https://github.com/DavitTec/davit-logger-pro)[![GitHub license](https://img.shields.io/github/license/DavitTec/davit-logger-pro?style=for-the-badge)](https://github.com/DavitTec/davit-logger-pro)

---

**Universal, production-grade logging framework** for the Davit ecosystem.

**Lightweight • Structured • JSON-ready • Console-controlled • Cross-project**

---

## Summary

**davit-logger-pro** is the authoritative logging solution for the `/opt/davit` ecosystem.

It provides a **single source of truth** for logging behaviour across Bash, Node.js, and future languages.

### Current Version: **1.5.0**

### Core Features (v1.5.0)

- **Bash Adapter v1.3.2** (highly mature)
  - Full JSON structured output (`LOG_FORMAT=json`)
  - Console control (`TERMINAL_OUTPUT=0/1`, `--no-console`, `--console`)
  - Local + Central log routing (`LOG_TO_LOCAL`, `LOG_TO_CENTRAL`)
  - Smart project detection (package.json + fallback)
  - Category-based routing (`SYSTEM`, `ADMIN`, `AUDIT`, `PROJECT`)
  - Robust flag parser (`--quiet`, `--verbose`, `--debug`, `--json`)
  - Safe dynamic `LOG_LEVEL` changes
  - Theme-based coloured terminal output

- **Structured Logging Levels**
  - `debug`, `info`, `warn`, `error`, `critical`, `success`, `header`, `todo`

- **Production Safe**
  - Graceful degradation when config files are missing
  - No hard dependencies
  - Works in `/opt/davit/development` and production paths

- **Future-ready**
  - JSON Schema for themes and error codes
  - Planned: Node.js ESM adapter, Python, Go

---

## Quick Start (Bash)

```bash
# In your script
export D_MODE="${D_MODE:-}"   # let logger auto-detect

source /opt/davit/bin/davit-logger.sh

log_info "Application started successfully"
log_debug "Detailed debug info"
log_error "Something went wrong"

# Advanced usage
davit_parse_flags --debug --json "$@"

log_info "This will be logged as JSON"
```

### Console & Output Control

Bash

```
export TERMINAL_OUTPUT=0          # Silent mode (files only)
export LOG_FORMAT=json            # Structured output
export LOG_TO_LOCAL=1
export LOG_TO_CENTRAL=1
```

**Command-line flags** (via davit_parse_flags):

- --quiet → Errors only + no console
- --verbose → Info level
- --debug → Debug level + console
- --json → JSON structured output
- --no-console / --console

------

## Repository Structure

Bash

```
davit-logger-pro/
├── README.md
├── VERSION                 # 1.5.0
├── LICENSE
├── davit-logger.sh         # Main Bash implementation (v1.3.2)
├── scripts/test-05-log.sh  # Comprehensive test suite
├── adapters/
│   ├── bash/
│   └── node-commonjs/      # Planned
├── config/
│   └── loggin-theme.json
└── docs/
    ├── SPEC_v1.0.md
    ├── ARCHITECTURE.md
    └── ROADMAP.md
```

------

## Philosophy

- **One Logging Specification**, Multiple Adapters
- Always fail-safe
- Linux-first, production-oriented
- Developer-friendly with beautiful terminal output
- JSON-first for log aggregation (ELK, Loki, etc.)

------

## Environment Variables

| Variable        | Default | Description                    |
| --------------- | ------- | ------------------------------ |
| LOG_LEVEL       | INFO    | DEBUG/INFO/WARN/ERROR/CRITICAL |
| TERMINAL_OUTPUT | 1       | 0 = disable console            |
| LOG_TO_LOCAL    | 1       | Write to ./logs/<project>.log  |
| LOG_TO_CENTRAL  | 1       | Write to /opt/davit/logs/      |
| LOG_FORMAT      | text    | text or json                   |
| D_MODE          | auto    | dev / stage / prod             |

------

## Example JSON Output

JSON

```
{
  "timestamp": "2026-04-27T22:15:38.822Z",
  "level": "INFO",
  "category": "PROJECT",
  "project": "davit-logger-test",
  "version": "1.0.3-test05",
  "mode": "dev",
  "user": "david",
  "pid": 61230,
  "script": "test-05-log.sh",
  "message": "This is a JSON formatted message"
}
```

------

## Roadmap

- v1.6.0: Full Node.js adapter + unified error code system
- v1.7.0: Python & Go adapters
- v2.0.0: Central log management daemon + rotation policies

------

## Contributing

Internal Davit Technologies project. Public contributions welcome after v2.0.

------

## Author

**Davit Technologies** (David Mullins)

------

Version: 1.5.0 — Stable with JSON + Full Console Control

