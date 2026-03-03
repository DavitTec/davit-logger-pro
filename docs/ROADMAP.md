# Project development



## Phase 1

### Additional Phase 1 Deliverables

To implement this phase:

1. **Initial Script for Deployment (logging-utility)**:
   Create a basic Bash script with the logging functions mentioned. Include escalation levels (DEBUG/INFO/WARN/ERROR/CRITICAL) and source ID using `${BASH_SOURCE[1]}` or `$0`. Use ANSI colours for console output (e.g., `\e[32m` for green). Keep it under 100 lines—focus on MVP.

   Example skeleton:
   ```bash
   #!/bin/bash
   # logging-utility
   
   # Prevent direct execution
   if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
     echo "Error: This script must be sourced, not executed."
     exit 1
   fi
   
   log_debug() { echo -e "\e[90m$(date +'%Y-%m-%d %H:%M:%S') [DEBUG] 		[${BASH_SOURCE[1]}] $1\e[0m"; }
   # Similarly for other levels...
   log_critical() { echo -e "\e[1;31m$(date +'%Y-%m-%d %H:%M:%S') [CRITICAL] [${BASH_SOURCE[1]}] $1\e[0m"; exit 1; }
   ```

2. **INSTALL Script**:
   A simple Bash installer.
   ```bash
   #!/bin/bash
   # INSTALL.sh
   
   BIN_DIR="/opt/davit/bin"
   SCRIPT_NAME="logging-utility"
   
   mkdir -p "$BIN_DIR"
   cp "$SCRIPT_NAME" "$BIN_DIR/"
   chmod +x "$BIN_DIR/$SCRIPT_NAME"
   
   # Update .env if exists
   if [[ -f .env ]]; then
     grep -q "^LOGGING=" .env && sed -i "s|^LOGGING=.*|LOGGING=\"$BIN_DIR/$SCRIPT_NAME\"|" .env || echo "LOGGING=\"$BIN_DIR/$SCRIPT_NAME\"" >> .env
   fi
   
   echo "Installed to $BIN_DIR/$SCRIPT_NAME"
   ```

3. **Some Error Checks**:
   - In logging functions: `if [ -z "$1" ]; then log_warn "Empty message"; return; fi`
   - In INSTALL: Check for sudo (`if [ "$EUID" -ne 0 ]; then echo "Run as sudo"; exit 1; fi`), dir existence, copy success.

4. **Some Testing Scripts**:
   Create a `tests/` dir with 2-3 scripts.
   - `basic_test.sh`: Source and call each log function, visually check output.
   - `error_test.sh`: Test empty args, invalid levels (e.g., add a dispatcher function that checks level validity).
   Manually run them; later add assertions.

Once Phase 1 is done, test by modifying one old script: Source the utility, replace old logging calls, and verify .env updates.

### VSCode (vscode-insiders) Configuration

For VSCode Insiders: Install extensions via code-insiders --install-extension <id>. Suggested config:

- **Extensions** (for Bash dev):
  - timonwong.shellcheck (linting)
  - foxundermoon.shell-format (formatting)
  - ms-vscode-remote.remote-ssh (if remote)
  - jeff-hykin.better-shellscript-syntax (syntax)
- **launch.json** (in .vscode/ for debugging Bash; use VSCode's Bash debugger extension if installed):



### Formatted davit-logger.sh (v0.0.1)

Here's the basic script with functions. Formatted with consistent style (4-space indent, comments).



### Test Script and test.log


## Phase 2: Core Enhancements (v0.1.0)
- Add file logging (append to log file).
- Timestamps customizable.
- Log rotation (size/time-based).

## Phase 3: Integration (v0.2.0)
- Auto .env in multiple projects.
- Hooks for Python/Perl/Node (e.g., wrappers).

## Phase 4: Advanced (v0.3.0)
- Full error handling (try-catch like).
- Redaction for secrets.
- Plugins system.

## Phase 5: Deployment (v1.0.0)
- Package as deb/rpm.
- CI/CD with GitHub Actions.
- Multi-OS support.