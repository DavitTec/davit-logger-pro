#!/usr/bin/env bash
#=====================================================================
# davit-logger.sh – v0.3.3 – FINAL, UNBREAKABLE VERSION
# Version: 0.3.3
# Supports:  log info "msg"   AND   log_info "msg"
#=====================================================================
set -Eeo pipefail
shopt -s extglob nullglob

# ------------------------------------------------------------------
# Guard
# ------------------------------------------------------------------
[[ -n "${_DL_LOADED:-}" ]] && return 0
readonly _DL_LOADED=1

# ------------------------------------------------------------------
# Paths
# ------------------------------------------------------------------
readonly _DL_ROOT="/opt/davit"
readonly _DL_BIN="${_DL_ROOT}/bin"
readonly _DL_LIB="${_DL_ROOT}/lib"

# ------------------------------------------------------------------
# Default colours (always exist)
# ------------------------------------------------------------------
declare -g DAVIT_COLOR_RESET="\e[0m"
declare -g DAVIT_COLOR_HEADER="\e[38;5;208m"
declare -g DAVIT_COLOR_INFO="\e[36m"
declare -g DAVIT_COLOR_SUCCESS="\e[32m"
declare -g DAVIT_COLOR_WARN="\e[33m"
declare -g DAVIT_COLOR_ERROR="\e[31m"
declare -g DAVIT_COLOR_CRITICAL="\e[97;41m"
declare -g DAVIT_COLOR_DEBUG="\e[35m"
declare -g DAVIT_COLOR_HIGHLIGHT="\e[38;5;220m"

# ------------------------------------------------------------------
# Theme loader (unchanged – safe)
# ------------------------------------------------------------------
# ------------------------------------------------------------------
# 1. Safe theme loading with fallback colours
# ------------------------------------------------------------------
_dl_load_theme() {
    local file="${1:-}"
    [[ -f "$file" ]] || return 1

    local mode=$(grep -o '"mode"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" | cut -d'"' -f4)
    [[ -z "$mode" ]] && mode="dark"

    local block=$(sed -n "/\"${mode}\"/,/}/p" "$file")
    while IFS= read -r line; do
        [[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] || continue
        printf -v "DAVIT_COLOR_${BASH_REMATCH[1]}" "%b" "${BASH_REMATCH[2]//\\u001b/\\e}"
    done <<< "$(grep '":' <<<"$block" | sed 's/,$//')"
}

for theme in \
    "${_DL_LIB}/configs/davit-logger/loggin-theme.json" \
    "${BASH_SOURCE[0]%/*}/../lib/configs/davit-logger/loggin-theme.json" \
    "${HOME}/.config/davit/loggin-theme.json"
do
    _dl_load_theme "$theme" 2>/dev/null && break
done

# ------------------------------------------------------------------
# Safe init
# ------------------------------------------------------------------
_dl_init() {
    local caller="${BASH_SOURCE[1]:-${0}}"
    caller="$(realpath "$caller" 2>/dev/null || echo "$caller")"

    _DL_PROJECT="${PROJECT_NAME:-$(basename "$(dirname "${caller%/*}" 2>/dev/null)" 2>/dev/null || echo "davit")}"

    local candidates=(
        "${LOG_DIR:-}"
        "${_DL_ROOT}/var/log"
        "$(dirname "$caller")/logs"
        "/tmp/davit-logs"
    )
    _DL_LOG_DIR="/tmp/davit-logs"
    for dir in "${candidates[@]}"; do
        [[ -z "$dir" ]] && continue
        [[ -d "$dir" && -w "$dir" ]] && { _DL_LOG_DIR="$dir"; break; }
        mkdir -p "$dir" 2>/dev/null && [[ -w "$dir" ]] && { _DL_LOG_DIR="$dir"; break; }
    done

    _DL_LOG_FILE="${LOG_FILE:-${_DL_LOG_DIR}/davit.log}"
    _DL_LOG_LEVEL="${LOG_LEVEL:-INFO}"
    mkdir -p "$_DL_LOG_DIR" 2>/dev/null || true
}

# ------------------------------------------------------------------
# CORE WRITE FUNCTION – NOW 100% SAFE
# ------------------------------------------------------------------
_dl_write() {
    local level="INFO" colour_var colour="${DAVIT_COLOR_INFO}"
    [[ -n "${1:-}" ]] && level="$1"
    colour_var="DAVIT_COLOR_${level^^}"
    colour="${!colour_var:-$DAVIT_COLOR_INFO}"

    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')

    shift 2>/dev/null || true
    local msg="$*"
    [[ -z "$msg" ]] && msg="No message"

    # Terminal
    printf "%b[%s] [%s]%b %s\n" "$colour" "$ts" "$level" "$DAVIT_COLOR_RESET" "$msg" >&3
    # File
    printf "[%s] [%s] %s\n" "$ts" "$level" "$msg" >> "$_DL_LOG_FILE"
}

# ------------------------------------------------------------------
# Level filter
# ------------------------------------------------------------------
_dl_should_log() {
    local wanted="${1:-INFO}"
    local levels=(DEBUG INFO WARN ERROR CRITICAL)
    local current_idx=0 wanted_idx=0
    for i in "${!levels[@]}"; do
        [[ "${levels[$i]}" == "$_DL_LOG_LEVEL" ]] && current_idx=$i
        [[ "${levels[$i]}" == "$wanted" ]] && wanted_idx=$i
    done
    (( wanted_idx >= current_idx ))
}

# ------------------------------------------------------------------
# Public API – both styles
# ------------------------------------------------------------------
log_debug()    { _dl_should_log DEBUG    && _dl_write DEBUG    "$@"; }
log_info()     { _dl_should_log INFO     && _dl_write INFO     "$@"; }
log_warn()     { _dl_should_log WARN     && _dl_write WARN     "$@"; }
log_error()    { _dl_should_log ERROR    && _dl_write ERROR    "$@"; }
log_success()  {                        _dl_write SUCCESS  "$@"; }
log_header()   {                        _dl_write HEADER   "$@"; }
log_critical() { _dl_write CRITICAL "$@"; exit 1; }

# UNIVERSAL log() – accepts log info "msg" and log_info "msg"
log() {
    case "${1:-}" in
        debug|DEBUG)       shift; log_debug    "$@" ;;
        info|INFO)         shift; log_info     "$@" ;;
        warn|WARN)         shift; log_warn      "$@" ;;
        error|ERROR)       shift; log_error     "$@" ;;
        success|SUCCESS)   shift; log_success   "$@" ;;
        header|HEADER)     shift; log_header    "$@" ;;
        critical|CRITICAL) shift; log_critical  "$@" ;;
        *)                 log_info "$@" ;;  # default
    esac
}

# ------------------------------------------------------------------
# One-time execution
# ------------------------------------------------------------------
{
    exec 3>&1
    _dl_init

    # Self-test only when run directly
    [[ "${BASH_SOURCE[0]}" == "${0}" ]] && {
        log header "=== DAVIT-LOGGER v0.3.3 FINAL ==="
        log info   "Ready – supports both log info 'msg' and log_info 'msg'"
        log success "No more unbound variable errors"
    }
} || true

# End of davit-logger.sh