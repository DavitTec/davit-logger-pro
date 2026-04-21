# LOGGER Project – Multitail Integration & Log Visualization

## Overview

The **LOGGER** project is the central authority for:

- Log format definition
- Log visualization (terminal + colorized views)
- Multitail configuration
- Operational consistency across environments

This repository ensures that **log structure, display, and tooling are version-controlled, reproducible, and deployable**.

------

## Objectives

1. **Single Source of Truth**
   - All log formats and multitail color schemes are defined here.
   - Prevents drift between environments.
2. **Version Control**
   - All configs (`.multitailrc`, scheme files, aliases) are tracked in Git.
   - the location of `multitail` are lcated in `./configs/multitail/`
   - the bash aliases (`aliases.sh`) are located in `./configs/multitail/bash/`
   - Changes to log formats and visualization are auditable.
3. **Deployment Consistency**
   - LOGGER deploys both:
     - Logging format (producers)
     - Visualization config (consumers)
4. **Operational Clarity**
   - Consistent color schemes per log type:
     - ADMIN
     - SYSTEM
     - AUDIT
     - PROJECTS
     - TESTS
5. **Disaster Recovery Ready**
   - New system setup requires **no manual tweaking**
   - Fully reproducible from repo

------

## Directory Structure

```bash
davit-logger/
├── config/
│   ├── multitail/
│   │   ├── davit-base.conf
│   │   ├── davit-admin.conf
│   │   ├── davit-system.conf
│   │   ├── davit-audit.conf
│   │   ├── davit-projects.conf
│   │   └── multitailrc.template
│   ├── bash/
│   │   └── aliases.sh
│
├── logs/                # (optional test logs)
├── scripts/
│   └── install.sh     # Optional if central INSTALL is not deployed
│
├── docs/
│   ├── multitail-integration.md    # THIS DOCUMENT
│   ├── log-format.md
│   ├── color-schemes.md
│   └── disaster-recovery.md
│
└── README.md
```

------

## Log Format Standard

All logs must follow a **strict pipe-delimited format**:

```text
TIMESTAMP | USER | LEVEL | CATEGORY | SUBCAT | CONTEXT | EXTRA | MODE=env | pid=1234 | script=name.sh | MESSAGE
```

### Rules

- Always use `" | "` (space-pipe-space)
- Empty fields must be preserved: `| - |`
- Avoid nested delimiters where possible
- Prefer `key=value` over `[key:value]`

------

## Multitail Configuration

### Base Principles

- `cs_re` → semantic highlighting (ERROR, WARN, etc.)
- `cs_re_s` → column-specific coloring
- Layered rules:
  1. Severity
  2. Keywords
  3. Structure (columns)

------

## Usage

### Single view (Mate)

```bash
# Opens Mate Terminal scalled to 70% 
alias logp='mate-terminal --zoom=0.70 --geometry=280x5+10+530 -t "DAVIT-PROJECT-LOGS" -e "tail -f /opt/davit/logs/davit-projects.log "'
```



### Colored Single view

```bash
alias logallc='multitail \
  -cS davit-admin  -wh 12 -F /opt/davit/lib/multitail/davit-projects-log.conf -i /opt/davit/logs/davit-projects.log
```

### Coloured Multiview

```bash
alias logallc='multitail \
  -cS davit-admin  -wh 10 -F /opt/davit/lib/multitail/davit-admin-log.conf -i /opt/davit/logs/davit-admin.log \
  -cS davit-system -wh 10 -F /opt/davit/lib/multitail/davit-system-log.conf -i /opt/davit/logs/davit-system.log'
```

------

### Black & White (fallback)

```bash
alias logall='multitail \
  -i /opt/davit/logs/davit-admin.log \
  -i /opt/davit/logs/davit-system.log'
```

------

## Known Behaviour / Limitations

### Window Titles Disappear

- Multitail titles may disappear when resizing/moving terminal windows.
- **Workaround:** enable status bar

```bash
multitail -s 2
```

or ensure:

```ini
statusbar:on
```

------

## Synchronizing Aliases

All aliases must be maintained in:

```bash
config/bash/aliases.sh
```

To apply:

```bash
source config/bash/aliases.sh
```

Optional install step:

```bash
./scripts/install.sh
```

------

## Deployment Strategy

### Install Steps (Fresh System)

```bash
git clone <repo>
cd logger
./scripts/install.sh
```

### Install Script Responsibilities

- Copy multitail configs → `/opt/davit/lib/multitail/`
- Install `.multitailrc`
- Install/update aliases
- Validate log format compatibility

------

## Disaster Recovery Plan

### Goals

- Zero manual configuration
- Full reproducibility

### Recovery Steps

1. Install base system
2. Clone LOGGER repo
3. Run installer
4. Restart shell
5. Validate logs

```bash
# Open multi window view 
logallc
```

------

## Change Management

### When log format changes:

- Update:
  - `docs/log-format.md`
  - multitail configs
  - sample logs
- Bump version tag

### When color schemes change:

- Update:
  - `docs/color-schemes.md`
  - corresponding `.conf` files

------

## Documentation Requirements

All changes must include:

- Description of change
- Affected log types
- Before/after examples
- Impact on multitail configs

------

## Future Improvements

- Unified parser for all log types
- Auto-detection of log format
- JSON log compatibility mode
- Central theme engine
- TUI dashboard (beyond multitail)

------

## Summary

LOGGER is not just logging — it is:

- A **format standard**
- A **visualisation system**
- A **deployment artefact**
- A **compliance tool**

Everything lives in one place, versioned, reproducible, and predictable.

------

## TODO

- Develop fall back `install.sh`
- a cleaner alias manager
- a “universal” multitail config that adapts to all your DAVIT logs automatically
