#!/usr/bin/env bash
#==============================================================================:
# Script Name:    test_davit_logger.sh
# Description:    Test and demonstration script for DAVIT Logger and Theme
# Author:         David Mullins
# License:        MIT
# Version:        0.1.0
# Created:        2025-11-02
# UUID:           8e0a3df8-ccf2-46a9-8bb5-17f45d4d9061
# $Id: code-style v0.3.1 2025/10/01 10:46:54
#==============================================================================:
# shellcheck disable=SC1090,SC1091

#------------------------------------------------------------------------------:
# GLOBALS
#------------------------------------------------------------------------------:

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="/opt/davit/development/davit-logger"
LOG_DIR="${PROJECT_DIR}/logs"
LOG_FILE="${LOG_DIR}/test_davit_logger.log"
readonly LOG_FILE LOG_DIR PROJECT_DIR SCRIPT_DIR SCRIPT_NAME
DAVIT_THEME_MODE="${DAVIT_THEME_MODE:-dark}"   # or light|minimal
LOG_LEVEL="${LOG_LEVEL:-DEBUG}"
export LOG_DIR LOG_FILE LOG_LEVEL DAVIT_THEME_MODE

mkdir -p "$LOG_DIR"

#------------------------------------------------------------------------------:
# IMPORT LOGGER
#------------------------------------------------------------------------------:
# Try system location, fallback to project scripts
if ! source "/opt/davit/bin/davit-logger.sh" 2>/dev/null; then
  source "${PROJECT_DIR}/scripts/davit-logger.sh" 2>/dev/null || {
    echo "❌ Unable to source davit-logger.sh"; exit 1;
  }
fi

#------------------------------------------------------------------------------:
# TEST CASES
#------------------------------------------------------------------------------:
run_tests() {
  log_header   "=== DAVIT LOGGER TEST SUITE ==="
  log_info     "Logger loaded successfully in theme: ${DAVIT_THEME_MODE}"
  log_debug    "Debugging is active because LOG_LEVEL=${LOG_LEVEL}"
  log_warn     "This is a warning message (yellow in dark mode)."
  log_error    "This is an error message (red)."
  log_success  "Operation completed successfully (green)."
  log_highlight "Highlight this message for user attention (magenta)."
  # JSON example for feedback loop ingestion
  log_json "INFO" "Machine-readable JSON entry example"
  # Uncomment to test exit behavior
  # log_critical "This simulates a critical failure (terminates script)."
  log_info     "All log levels tested."
  log_header   "=== END OF TEST SUITE ==="
}

#------------------------------------------------------------------------------:
# VALIDATION AND DISPLAY
#------------------------------------------------------------------------------:
verify_logs() {
  log_info "Verifying log file contents..."
  if [[ -s "$LOG_FILE" ]]; then
    log_success "Log file created: ${LOG_FILE}"
    echo ""
    log_header "=== LAST 10 LINES OF LOG FILE ==="
    tail -n 10 "$LOG_FILE"
    echo ""
    log_header "=== JSON STRUCTURED OUTPUT ==="
    local json_file="${LOG_FILE%.log}.jsonl"
    if [[ -f "$json_file" ]]; then
      tail -n 3 "$json_file"
    else
      log_warn "No JSON log file found."
    fi
  else
    log_error "Log file not found or empty."
  fi
}

#------------------------------------------------------------------------------:
# MAIN
#------------------------------------------------------------------------------:
main() {
  log_info "Running ${SCRIPT_NAME} from ${SCRIPT_DIR}"
  run_tests
  verify_logs
  log_info "Test sequence complete. Review logs for output verification."
}

main "$@"
#------------------------------------------------------------------------------:
# FOOTER / TODO
#------------------------------------------------------------------------------:
#  fix, feat or request---------------------¬
#  [I]ssue, [T]ask or [F]unc number---¬     |     
#  section or line number-------¬     |     |
#  script---¬            |      |     |     |
#           ↓            ↓      ↓     ↓     ↓
# TOD0(${script_name}):[main]|[130]:[T001]: Implement business logic.
# F1XME(${script_name}):[parse_args]|[115]:[F001]: Extend option parsing.
# NOTES: Created using DAVIT create_script.sh v${VERSION}
#==============================================================================:

# TOD0(${script_name}):[21]:[T001]: Set PROJECT_NAME variable