#!/usr/bin/env bash
#=====================================================================
# scripts/davit-logger.sh
# Version: 1.2.16
# Description: STABLE POSTMASTER – Single authoritative logger for SYSTEM/ADMIN/AUDIT/PROJECT
#              Auto-detects from package.json or folder name. Works anywhere (dev or prod).
# Supports:    log info "msg", log_info, log_debug, log_warn, log_error, log_success, log_header, log_term, log_todo
# Location:    /opt/davit/bin/davit-logger.sh
#=====================================================================

set -Eeo pipefail
shopt -s extglob nullglob

# Guard
[[ -n "${_D_LOGGER_LOADED:-}" ]] && return 0
readonly _D_LOGGER_LOADED=1

readonly user=${SUDO_USER:-$USER}

# ------------------------------------------------------------------
# Core DAVIT System Paths
# ------------------------------------------------------------------
readonly _D_ROOT="/opt/davit"
readonly _D_BIN="${_D_ROOT}/bin"
readonly _D_LOGS="${_D_ROOT}/logs"
readonly _D_LIB="${_D_ROOT}/lib"

mkdir -p "${_D_LOGS}" 2>/dev/null || true

# ------------------------------------------------------------------
# Colours
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
declare -g DAVIT_COLOR_TODO="\e[38;5;214m"

# Theme loader (safe)
_dl_load_theme() {
    local file="$1" mode block
    [[ -f "$file" ]] || return 1
    mode=$(grep -o '"mode"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" 2>/dev/null | cut -d'"' -f4 || echo "dark")
    block=$(sed -n "/\"${mode}\"/,/}/p" "$file" 2>/dev/null)
    while IFS= read -r line; do
        [[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] || continue
        printf -v "DAVIT_COLOR_${BASH_REMATCH[1]}" "%b" "${BASH_REMATCH[2]//\\u001b/\\e}"
    done <<< "$(grep '":' <<<"$block" | sed 's/,$//' 2>/dev/null)"
}

for theme in \
    "${_D_LIB}/configs/davit-logger/logging-theme.json" \
    "${_D_BIN}/../lib/configs/davit-logger/logging-theme.json" \
    "${HOME}/.config/davit/logging-theme.json"
do
    _dl_load_theme "$theme" 2>/dev/null && break
done

# ------------------------------------------------------------------
# Safe Bootstrap Logging
# ------------------------------------------------------------------
_dl_bootstrap_log() {
    local level="$1" msg="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] [%s] [BOOTSTRAP] %s\n" "$ts" "$level" "$msg" >> "${_D_LOGS}/davit.log"
    [[ -t 1 ]] && printf "%b[%s] [BOOTSTRAP]%b %s\n" "${DAVIT_COLOR_WARN}" "$level" "${DAVIT_COLOR_RESET}" "$msg" >&2
}

# ------------------------------------------------------------------
# MODE Detection
# ------------------------------------------------------------------
_dl_detect_mode() {
    local detected=""

    if [[ -n "${D_MODE:-}" ]]; then
        detected="${D_MODE}"
    elif [[ -f "${D_PRJ_PATH:-}/ .env" ]]; then
        detected=$(grep -E '^D_MODE=' "${D_PRJ_PATH}/.env" 2>/dev/null | cut -d= -f2- | tr -d ' "')
    fi

    detected="$(printf "%s" "${detected}" | tr '[:upper:]' '[:lower:]')"

    if [[ -z "${detected}" ]]; then
        if [[ "${D_PRJ_PATH:-}" == /opt/davit/development/* ]]; then
            detected="dev"
            _dl_bootstrap_log "INFO" "Development folder detected → defaulting D_MODE=dev"
        else
            detected="prod"
        fi
    fi

    case "${detected}" in
        dev|stage|prod) ;;
        *) detected="prod" ;;
    esac

    export D_MODE="${detected}"
}

# ------------------------------------------------------------------
# Auto-Detection — Robust for dev + prod (any location)
# ------------------------------------------------------------------
_dl_detect_context() {
    local script_path script_dir pkg_json search_dir folder_name

    # Determine calling script
    script_path="${BASH_SOURCE[1]:-${0}}"
    script_path="$(realpath -s "$script_path" 2>/dev/null || echo "$script_path")"
    script_dir="$(dirname "$script_path")"

    export D_PRJ_CALL="${script_path}"

    # Decide search root: prefer current directory (most reliable for tests/scripts)
    if [[ -n "${PWD:-}" && "$PWD" != "/" ]]; then
        search_dir="$PWD"
    else
        search_dir="$script_dir"
    fi

    # Search upward for package.json
    pkg_json=""
    local dir="$search_dir"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/package.json" ]]; then
            pkg_json="$dir/package.json"
            break
        fi
        dir="$(dirname "$dir")"
    done

    # Set project info
    if [[ -n "$pkg_json" ]] && command -v jq >/dev/null 2>&1; then
        export D_PRJ_NAME="${D_PRJ_NAME:-$(jq -r '.name // "unknown"' "$pkg_json" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '_')}"
        export D_PRJ_VER="${D_PRJ_VER:-$(jq -r '.version // "0.0.0"' "$pkg_json" 2>/dev/null)}"
        export D_PRJ_PATH="$(dirname "$pkg_json")"
    else
        # Fallback: use folder name (works in /opt/davit/bin or any prod location)
        folder_name="$(basename "$script_dir")"
        export D_PRJ_NAME="${D_PRJ_NAME:-${folder_name:-unknown}}"
        export D_PRJ_VER="${D_PRJ_VER:-unknown}"
        export D_PRJ_PATH="${D_PRJ_PATH:-$script_dir}"
    fi

    export D_PRJ_FOLDER="${D_PRJ_NAME}"
    export D_PRJ_BIN="${D_PRJ_PATH}/bin"

    # Local project log only for real projects
    if [[ "${D_PRJ_NAME}" != "unknown" && -n "${D_PRJ_NAME}" && "${D_PRJ_NAME}" != "generic" ]]; then
        export D_PROJECT_LOG="${D_PRJ_PATH}/logs/${D_PRJ_NAME}.log"
        mkdir -p "${D_PRJ_PATH}/logs" 2>/dev/null || true
    else
        export D_PROJECT_LOG=""
    fi

    # MODE + LOG_LEVEL
    _dl_detect_mode

    export D_CATEGORY="${D_CATEGORY:-PROJECT}"

    if [[ -z "${LOG_LEVEL:-}" ]]; then
        case "${D_MODE}" in
            dev)   LOG_LEVEL="DEBUG" ;;
            *)     LOG_LEVEL="INFO"  ;;
        esac
        export LOG_LEVEL
    fi
}

# ------------------------------------------------------------------
# Standardized Line
# ------------------------------------------------------------------
_dl_build_line() {
    local level="$1" msg="$2"
    local ts pid script_name mode_str tag

    ts=$(date '+%Y-%m-%d %H:%M:%S.%3N' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
    pid=$$
    script_name="$(basename "${0}")"

    mode_str="MODE:${D_MODE}"
    if [[ "${D_PRJ_NAME}" != "unknown" ]]; then
        tag="${D_PRJ_NAME} | ${D_PRJ_VER}"
    else
        tag="generic | -"
    fi

    printf "%s | %s | %s | %s | %s | %s | pid:%s | script:%s | %s" \
        "$ts" "$user" "$level" "${D_CATEGORY}" "$tag" "$mode_str" "$pid" "$script_name" "$msg"
}

# ------------------------------------------------------------------
# Core Write + Routing
# ------------------------------------------------------------------
_dl_write() {
    local level="$1" colour_var colour msg line clean_line files=()

    colour_var="DAVIT_COLOR_${level^^}"
    colour="${!colour_var:-$DAVIT_COLOR_INFO}"

    shift
    msg="$*"
    [[ -z "$msg" ]] && msg="No message"

    line=$(_dl_build_line "$level" "$msg")
    clean_line=$(printf "%s" "$line" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g')

    # Terminal
    if [[ -t 1 ]] || [[ "${LOG_TO_CONSOLE:-0}" == "1" ]]; then
        if [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]]; then
            printf "%b%s%b\n" "$colour" "$line" "$DAVIT_COLOR_RESET" >&2
        else
            printf "%b%s%b\n" "$colour" "$line" "$DAVIT_COLOR_RESET" >&1
        fi
    fi

    # Routing
    [[ -n "${D_PROJECT_LOG}" ]] && files+=("${D_PROJECT_LOG}")

    case "${D_CATEGORY}" in
        SYSTEM) files+=("${_D_LOGS}/davit-system.log") ;;
        ADMIN)  files+=("${_D_LOGS}/davit-admin.log")  ;;
        AUDIT)  files+=("${_D_LOGS}/davit-audit.log")  ;;
        PROJECT|*) 
            files+=("${_D_LOGS}/davit-projects.log")
            ;;
    esac

    [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]] && files+=("${_D_LOGS}/davit.log")

    # TEMP DEBUG (remove when happy)
    # echo "[DEBUG _dl_write] level=${level} D_CATEGORY='${D_CATEGORY}' D_PROJECT_LOG='${D_PROJECT_LOG}' files=(${files[*]})" >&2

    for f in "${files[@]}"; do
        mkdir -p "$(dirname "$f")" 2>/dev/null || true
        printf "%s\n" "$clean_line" >> "$f"
    done
}

# ------------------------------------------------------------------
# Level Filter + API
# ------------------------------------------------------------------
_dl_should_log() {
    local wanted="${1:-INFO}"
    [[ -z "${LOG_LEVEL:-}" ]] && return 0

    local levels=(DEBUG INFO WARN ERROR CRITICAL)
    local current=0 wanted_idx=0 i
    for i in "${!levels[@]}"; do
        [[ "${levels[$i]}" == "${LOG_LEVEL}" ]] && current=$i
        [[ "${levels[$i]}" == "$wanted" ]] && wanted_idx=$i
    done
    (( wanted_idx >= current ))
}

log_debug()    { _dl_should_log DEBUG    && _dl_write DEBUG    "$@"; }
log_info()     { _dl_should_log INFO     && _dl_write INFO     "$@"; }
log_warn()     { _dl_should_log WARN     && _dl_write WARN     "$@"; }
log_error()    { _dl_should_log ERROR    && _dl_write ERROR    "$@"; }
log_critical() { _dl_write CRITICAL "$@"; exit 1; }
log_success()  { _dl_write SUCCESS  "$@"; }
log_header()   { _dl_write HEADER   "$@"; }

log_term() {
    local msg="$*"
    if [[ -t 1 ]] || [[ "${LOG_TO_CONSOLE:-0}" == "1" ]]; then
        printf "%b%s%b\n" "${DAVIT_COLOR_HIGHLIGHT}" "$msg" "${DAVIT_COLOR_RESET}" >&1
    fi
}

log_todo() {
    local msg="$1" serial="${2:-TODO-$(date +%Y%m%d-%H%M%S)}"
    _dl_write WARN "TODO: ${msg} (serial: ${serial})"
    printf "%bTODO [%s]: %s%b\n" "${DAVIT_COLOR_TODO}" "${serial}" "${msg}" "${DAVIT_COLOR_RESET}" >&1
}

log() {
    case "${1:-}" in
        debug|DEBUG)       shift; log_debug    "$@" ;;
        info|INFO)         shift; log_info     "$@" ;;
        warn|WARN)         shift; log_warn     "$@" ;;
        error|ERROR)       shift; log_error    "$@" ;;
        success|SUCCESS)   shift; log_success  "$@" ;;
        header|HEADER)     shift; log_header   "$@" ;;
        critical|CRITICAL) shift; log_critical "$@" ;;
        term|TERM)         shift; log_term     "$@" ;;
        todo|TODO)         shift; log_todo     "$@" ;;
        *)                 log_info "$@" ;;
    esac
}

# ------------------------------------------------------------------
# Initialization
# ------------------------------------------------------------------
{
    _dl_detect_context

    # Project log header
    if [[ -n "${D_PROJECT_LOG}" && ( ! -f "${D_PROJECT_LOG}" || -z "$(head -c 100 "${D_PROJECT_LOG}" 2>/dev/null)" ) ]]; then
        {
            echo "# DAVIT LOG HEADER - PROJECT: ${D_PRJ_NAME} | VERSION: ${D_PRJ_VER} | MODE: ${D_MODE} | Created: $(date)"
            echo "# Suggested prune: dev=30d, stage=14d, prod=7d"
            echo "# ======================================================="
        } >> "${D_PROJECT_LOG}"
    fi

    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        log_header "=== DAVIT-LOGGER v1.2.14 – STABLE POSTMASTER ==="
        if [[ "${D_PRJ_NAME}" != "unknown" ]]; then
            log_info "Detected Project: ${D_PRJ_NAME} v${D_PRJ_VER} (MODE=${D_MODE})"
        else
            log_info "No development project detected (generic/production mode)"
        fi
        log_success "Logger ready"
    fi
} || true