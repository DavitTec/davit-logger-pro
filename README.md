# Davit Logger Pro

[![GitHub tag (latest by date)](https://img.shields.io/github/v/tag/DavitTec/davit-logger-pro?style=for-the-badge&logo=github)](https://github.com/DavitTec/davit-logger-pro/tag)[![GitHub open issues](https://img.shields.io/github/issues-raw/DavitTec/davit-logger-pro?style=for-the-badge&label=Open%20Issues)](https://github.com/DavitTec/davit-logger-pro/issues)[![GitHub top language](https://img.shields.io/github/languages/top/DavitTec/davit-logger-pro?style=for-the-badge)](https://github.com/DavitTec/davit-logger-pro)[![GitHub license](https://img.shields.io/github/license/DavitTec/davit-logger-pro?style=for-the-badge)](https://github.com/DavitTec/davit-logger-pro)

---

![davit-logger-screenshot](./assets/Screenshot%20at%202025-11-15%2013-45-15.png)

Universal logging specification and multi-language adapters for the Davit ecosystem.

For your ecosystem, logger should be:

> A system-level utility + language adapters.

Lightweight. Structured. Extensible. Linux-first.

---

## Summary

**davit-logger-pro** is a unified logging framework designed for cross-language consistency across the `/opt/davit` ecosystem.

It provides:

- A formal logging specification (v1.0)
- Shared theme and error configuration standards
- Bash and Node (CommonJS) adaptors (initial release)
- Advanced system inspection logging (CPU, memory, ping, pipes, etc.)
- Safe fallback behaviour (works without configure files)
- Linux-first architecture (Windows/macOS support planned)
- Multiview and colourised terminal windows (see  [multitail-integration.md](docs/multitail-integration.md) )

This project replaces and evolves the private `davit-logger` v0.3.3 into a public, structured monorepo.

---

## Philosophy

- One Logging SPEC
- Multiple Language Adopters
- Zero hard dependency on config files
- Always fail-safe
- Designed for system-level diagnostics
- Production-safe defaults

If configuration exists → enhance behaviour  
If configuration is missing → degrade gracefully

---

## Core Features

### Structured Logging

- debug
- info
- warn
- error
- critical

Each level has:

- priority
- color (theme-based)
- optional error code
- optional action hint

---

### Theme-Based CLI Rendering

Supports configurable:

- ANSI color mapping
- Level styling
- Timestamp format
- Max message length
- Future extensibility (icons, bold, underline, etc.)

Default theme is embedded internally — logger never depends on external theme file.

---

### Error Code System

Supports structured error definitions:

```json
{
  "GEN001": {
    "code": "GEN001",
    "status": "error",
    "message": "General validation error",
    "action": "Check input and try again"
  }
}
```

Allows:

- Standardised project-wide errors
- Actionable CLI output
- Consistent cross-language behaviour

---

### Advanced System Logging (Linux-first)

Optional system inspection module:

- CPU temperature
- Memory usage
- Disk usage
- Ping latency
- Process alive check
- Pipe/file descriptor check
- Cache inspection

Designed for:

- DevOps scripts
- Daemons
- Monitoring tasks
- Infrastructure automation

---

## Repository Structure

```bash
davit-logger-pro/
│
├── README.md ✅
├── VERSION
├── LICENSE
│
├── docs/ ✅
│   ├── charts/
│   │    └── MERMAID_DIAGRAMS.mmd
│   ├── SPEC_v1.0.md
│   ├── FLOW.md
│   ├── ARCHITECTURE.md
│   ├── TODO.md ✅
│   └── ROADMAP.md
│
├── spec/
│   ├── theme.schema.json
│   ├── errors.schema.json
│   └── logging.contract.md
│
├── config/
│   ├── theme.default.json
│   ├── errors.default.json
│   └── defaults.json
│
├── adapters/
│   ├── bash/
│   └── node-commonjs/
│
└── examples/
```

---

## Installation (Linux)

### Option 1 — Local Project Use

Clone into your project:

```bash
git clone https://github.com/DavitTec/davit-logger-pro.git
```

Use adapter directly:

```bash
./adapters/bash/logger.sh
```

or in Node:

```js
const logger = require("./adapters/node-commonjs/logger");
```

---

### Option 2 — Global Install (Planned)

Target path:

```bash
/opt/davit/
    bin/davit-log
    lib/logger/
    config/
```

Install script (coming in v1.0 stable):

```bash
sudo ./install.sh --global
```

---

## Usage Examples

### Bash Example

```bash
source logger.sh

log_info "Application started"
log_warn "VAL002"
log_error "GEN001"
```

---

### Node (CommonJS) Example

```js
const logger = require("./logger");

logger.info("Application started");
logger.warn("VAL002");
logger.error("GEN001");
```

---

### Example Output

```bash
[2026-03-03T14:22:01Z] [INFO] Application started
[2026-03-03T14:22:03Z] [WARN] [VAL002] Slide exceeds word limit
 → Action: Trim content in MD file
```

---

## Environment Configuration

Optional `.env` support:

```bash
LOGGER_LEVEL=debug
LOGGER_THEME=./config/theme.json
LOGGER_ERRORS=./config/errors.json
LOGGER_OUTPUT=console
```

If missing:

- Internal defaults are used.
- Logger continues operating safely.

---

## TODO

- Planned: See [TODO.md](docs/TODO.md)

---

## License

MIT License

- adapted to Davit ecosystem licensing policy.

---

## References

- POSIX Shell Standards
- Node.js CommonJS
- Linux `/proc` filesystem
- ANSI escape codes
- JSON Schema Draft-07

---

## Contributing

Internal Davit ecosystem project.

Public contributions may be enabled in future releases.

---

## Author

Davit Technologies (David Mullins)

---

## Version

[This repository supersedes: `davit-logger` (private) v0.3.3]

Version: 0.4.0-alpha
