# README

## Project davit-logger

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Build Status](https://img.shields.io/badge/build-passing-green.svg)](https://example.com/ci)  <!-- Add actual CI if set up -->
[![Version](https://img.shields.io/badge/version-0.0.1-blue.svg)](https://example.com/releases)

A modular logging utility for development projects, primarily focused on Bash scripts but extensible to Python, Perl, Node.js, etc. It provides escalated logging levels, source identification, and easy integration into existing scripts.

## Table of Contents
- [Overview](#overview)
- [Project Definition](#project-definition)
- [Phased Development](#phased-development)
- [Requirements and Limits](#requirements-and-limits)
- [Installation](#installation)
- [Usage](#usage)
- [Script Overview](#script-overview)
- [Error Checks](#error-checks)
- [Testing](#testing)
- [TODO](#todo)
- [Contributing](#contributing)
- [License](#license)

---

## Overview

Creating a central bash utility or function script for multipurpose logging can be achieved through several methods, ranging from simple in script functions to more sophisticated modules or helper utilities. 

This project is to define a reusable logging function, that is integrated or modular, sourced by multiple scripts, application or system commands. For instance, assuming a **[basic function](#Basic-Logging)** can be created to log messages with timestamps to a specified file. 

A more advanced approach involves using a dedicated logging module, with various calling functions. 

This module, can include a set of functions like 

| Function    | Description                                                  | inputs | outputs |
| ----------- | ------------------------------------------------------------ | ------ | ------- |
| log         | basic default logging                                        |        |         |
| log_info    | from basic script run time user feedback into terminal display and or log file. |        |         |
| log_warn    |                                                              |        |         |
| log_error   |                                                              |        |         |
| log_debug   |                                                              |        |         |
| log_caption |                                                              |        |         |
| log_changed |                                                              |        |         |
| log_skipped |                                                              |        |         |
| log_dialog  |                                                              |        |         |
| log_message |                                                              |        |         |
| log_level   |                                                              |        |         |
| log_color   |                                                              |        |         |

which can be sourced or called into a script.

This module allows for configuration of the log file, log levels (e.g., INFO, DEBUG), and time zone (e.g., UTC), and must be initialised with `init_logger` before use so that the calling script or project either uses the 'logger' module or its inbuilt basic logging function. This method of centralising logging or per Project logic, ensures consistent output across different scripts. 

Another method involves using the `logger` command, which interfaces with the system's syslog module to write messages to system log files like `/var/log/syslog` or `/var/log/messages`. This command supports log levels and can tag messages for easier filtering, such as `logger -t script.sh -p user.debug "Debug message"`. While this integrates well with system logging, it may not be suitable for dedicated log files for a script. Therefore, separating logging per defined target files and folders. 

For an enhanced functionality, a logging module can be designed to handle structured logging, where messages are formatted consistently and can be easily parsed. This can be combined with techniques like using `exec` to redirect all script output to a project root log ``./log/file`, ensuring that even command outputs are captured. Additionally, using named pipes can provide a buffer for logging, allowing for asynchronous log writing and potentially better performance.

A central logging utility can be built using a custom function or a module that provides consistent, timestamped, and configurable logging. Especially useful if post triggering functions, depending on logging logic and messages. Also to capture run time Metadata to facilitate environment variables. This utility can be sourced by any script, promoting code reuse and maintainability. The choice between using a simple function, a dedicated module, or the `logger` command depends on the specific needs, such as the requirement for system integration or the need for a dedicated log file.

The aim of this Logging module is to offer various features, primarily for scripting debugging, performance and user feedback that will enhance project or script development.  With enhanced features to include escalation levels, errors and or severity, together tracing both source and metadata issues can help track issues and improve debugging cycles.

This Logging module should include some self maintenance features that will manage the creation and upkeep and deletion of log files.  During project  developing and testing phases, log files may get over populated with redundant logs, which generally need clearing logs files or sections of date within them. 

Lastly, most logs, tend to be text files that contain line be line data.  This log files could be sourced and redirected to Terminal output, properly formatted, with optional colours. If   Logging module has included other functions to analysis and redirect Logs file or filtered sections, may provide input into other integrated or GUI applications, to offer further processing, as an example to open a log line, target file and its associated MIME application.   

## Structure dependencies

Logging module would be called my script or application, but would depend on environmental variables. Currently, we adopt two types of files that help configure the local Project/Package.

1.  **`.env`** or `.env_local`  This is a text file (snippet below) usually in the Package root that need to be set manually with key-value pairs

    
    
2. `requirements.yaml` This is a yaml configuration file that is associated with the initialisation or upkeep of the Package. This file would set configurations for the Package and may initialise logging 

If either of the two files are not present then the logging functions may have to rely on embedded functions, like those below.

### Basic Logging

```bash
# Basic logging function (expand later if logging.sh exists) wth timestamp
log() {
    local LEVEL=$1  # [INFO|WARN|ERROR|DEBUG] 
    shift
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$LEVEL] $*" >> "$LOG_FILE"
}
```

Example input:

```bash
log "Total lines in tmp/temp_input_1757281344817941864.txt: "
```

Example output: **.log*

```bash
[2025-09-07 23:42:26] Total lines in tmp/temp_input_1757281344817941864.txt:
```

### Basic Logging with Escalation Levels

```bash
# Logging function: with Level
log() {
    local LEVEL=$1
    shift
    local MSG="$@"
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] [$LEVEL] $MSG" >> "$LOG_FILE"
}
```

Example input:

```bash
log "INFO" "Total lines in tmp/temp_input_1757281344817941864.txt: "
```

Example output: **.log*

```bash
[2025-09-07 23:42:26] [INFO] Total lines in tmp/temp_input_1757281344817941864.txt:
```

### Basic Logging with Escalation Levels and Source ID

```bash
VERSION=$(head -5 "$0" | grep -m1 -oP '(?<=^# Version: ).*')
SID="$(basename "$0" .sh)_v${VERSION}.sh"

# Logging function: with Level and source script ID
log() {
    local LEVEL=$1
    shift
    local MSG="$@"
    local TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] [$SID] [$LEVEL] $MSG" >> "$LOG_FILE"
}

```

Example input:

```bash
log "INFO" "Processing file: $INPUT_FILE"
```

Example output: **.log*

```bash
[2025-09-07 23:42:24] [convert_to_csv_v0.0.4.sh] [INFO] Processing file: tests/playlist.txt
```

#### Establishing Libraries, Tools, Utilities, and Helpers

- Logging:

  Standard utility – Append to LOG_FILE with timestamp/level (info/warn/error). 

  Pseudo-code: 

  ```
  FUNCTION log(message, level="info"):
      timestamp = current_time(UTC)
      WRITE "[timestamp] [level]: [message]" to LOG_FILE
  ```

## Advanced Logger

Other options for logger

To add the following at the beginning of every script (especially if it'll run as a daemon):

```bash
#!/bin/bash
exec 3>&1 4>&2
trap 'exec 2>&4 1>&3' 0 1 2 3
exec 1>log.out 2>&1
# Everything below will go to the file 'log.out':
```

Explanation:

1. `exec 3>&1 4>&2`

   Saves file descriptors so they can be restored to whatever they were before redirection or used themselves to output to whatever they were before the following redirect.

2. `trap 'exec 2>&4 1>&3' 0 1 2 3`

   Restore file descriptors for particular signals. Not generally necessary since they should be restored when the sub-shell exits.

3. `exec 1>log.out 2>&1`

   Redirect `stdout` to file `log.out` then redirect `stderr` to `stdout`. Note that the order is important when you want them going to the same file. `stdout` *must* be redirected before `stderr` is redirected to `stdout`.

From then on, to see output on the console (maybe), you can simply redirect to `&3`. For example,

```bash
echo "$(date) : part 1 - start" >&3
```

will go to wherever `stdout` was directed, presumably the console, prior to executing line 3 above.

## Directory Structure

Below is the directory structure after initialisation, using `vscode.sh`  which creates a standard structure and VScode framework. 
[This project used Vs code-insiders (code-insiders 1.105.0-insider)]

```bash
davit-logger$ tree -a -I .git
├── archives
├── docs
│   ├── hist
│   └── README.md
├── .env
├── .gitignore
├── logs
│   └── davit-logger.log
├── main.sh
├── README.md
├── requirements.yaml
├── scripts
│   ├── INSTALL   # Install/uninstall script to push to production /opt/davit/bin
├── tests
├── .vscode
```

## Project Definition

This utility centralizes logging for modular Bash helpers and utilities. It replaces basic in-built logging in your scripts with a more robust, optional system. Key goals:
- **Escalation Levels**: Support DEBUG, INFO, WARN, ERROR, CRITICAL levels with color-coded output.
- **Source ID**: Automatically include the calling script's name or ID in logs for traceability.
- **Integration**: Install to `/opt/davit/bin`, source it in scripts, and auto-update `.env` with `LOGGING="$BIN_DIR/logging-utility"`.
- **Extensible**: Start Bash-focused; add multi-language support later.
- **Current Status**: MVP with basic logging. See [phased development](#phased-development) for roadmap.

## Phased Development

Development is iterative:
1. **Phase 1: Foundation** 

   Improve docs, basic logging script, INSTALL script, VSCode config,  error checks, and tests.

2. **Phase 2: Core Enhancements**

   File rotation, timestamps, custom formats
3. **Phase 3: Integration** – Auto .env updates, sourcing in old scripts, multi-language hooks.
4. **Phase 4: Advanced** – Robust error handling, security, plugins.
5. **Phase 5: Deployment** – Packaging, CI/CD.

Track progress in ISSUES or a [docs/ROADMAP.md](docs/ROADMAP.md) file.

## Requirements and Limits

- **Requirements**:
  - Bash 4.0+ (for associative arrays and advanced features).
  - Unix-like OS (tested on Linux/Mac; Windows via WSL).
  - No external dependencies initially (keep it lightweight).
  - See `requirements.yaml` for dev tools (e.g., VSCode extensions).

- **Limits**:
  - Not for production-critical logging (e.g., no distributed tracing yet).
  - Output to stdout/stderr or files; no remote logging in Phase 1.
  - Max log file size: Unlimited initially (add rotation in Phase 2).
  - Security: No sensitive data handling; avoid logging secrets.

## Installation

Run the `INSTALL` script as root/sudo for system-wide install:

```bash
sudo .scripts/INSTALL
```
For uninstall: 

```bash
sudo ./scripts/INSTALL -u
```

Updates .env if present.


This:

- Copies logging-utility to /opt/davit/bin.
- Sets executable permissions.
- Optionally updates project .env if in a git repo (detects and appends LOGGING="$BIN_DIR/logging-utility").

For local dev: Source directly via . ./davit-logger

## Usage

Source in your Bash scripts:


```bash
source /opt/davit/bin/davit-logger.sh

log_info "Message"
log_info "Starting script..."
log_error "Something went wrong!"

```

## Initial Script Overview

The core davit-logger script provides basic functions:

`davit-logger.sh` (v0.0.1): Basic functions with levels, colors, timestamp, source.

- log_debug(msg): Debug level (gray).
- log_info(msg): Info level (green).
- log_warn(msg): Warn level (yellow).
- log_error(msg): Error level (red).
- log_critical(msg): Critical level (bold red, exits script).

Each includes timestamp, level, and source script name. Example implementation (simplified):


```bash
# davit-logger (excerpt)
log_info() {
  echo "$(date +'%Y-%m-%d %H:%M:%S') [INFO] [${BASH_SOURCE[1]}] $1"
}
```

## Error Checks

Built-in checks:

- Valid levels: verify log level is valid (else default to INFO).
- Check if sourced (not run standalone).
- Handle missing args (e.g., empty message → "No message provided").

See davit-logger for details.

Use manual checks or add a framework like bats in later phases.

## License

MIT License. See LICENSE.
