#!/usr/bin/env bash
#=====================================================================
# scrpts/davit-logger.sh
# Version: 1.2.4
# Description:  STABLE POSTMASTER Single file, central routing for all DAVIT logs (SYSTEM/ADMIN/AUDIT/PROJECT) – AUTHORITATIVE POSTMASTER VERSION
#               Auto-detects project from package.json (source of truth), supports MODE=dev|stage|prod
# Supports:     log info "msg", log_info "msg", log_term, log_todo
# Location:     /opt/davit/bin/davit-logger.sh
# NOTES:        Single authoritative logger. Strict D_* / D_PRJ_* naming.
#               No hard-coded project references. Safe bootstrap.
# Requirements: loggin-theme.json
#=====================================================================

set -Eeo pipefail
shopt -s extglob nullglob

# Guard
[[ -n "${_D_LOGGER_LOADED:-}" ]] && return 0
readonly _D_LOGGER_LOADED=1


readonly user=${SUDO_USER:-$USER}

# ------------------------------------------------------------------
# Core DAVIT System Paths (_D_* prefix)
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
    "${_D_LIB}/configs/davit-logger/loggin-theme.json" \
    "${_D_BIN}/../lib/configs/davit-logger/loggin-theme.json" \
    "${HOME}/.config/davit/loggin-theme.json"
do
    _dl_load_theme "$theme" 2>/dev/null && break
done

# ------------------------------------------------------------------
# Safe Bootstrap Logging (prevents circular issues during install)
# ------------------------------------------------------------------
_dl_bootstrap_log() {
    local level="$1" msg="$2"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
    printf "[%s] [%s] [BOOTSTRAP] %s\n" "$ts" "$level" "$msg" >> "${_D_LOGS}/davit.log"
    [[ -t 1 ]] && printf "%b[%s] [BOOTSTRAP]%b %s\n" "${DAVIT_COLOR_WARN}" "$level" "${DAVIT_COLOR_RESET}" "$msg" >&2
}

# ------------------------------------------------------------------
# Auto-Detection (Clean & Strict)
# ------------------------------------------------------------------
_dl_detect_context() {
    local script_path script_dir pkg_json get_ver_script detected_mode

    # Calling script
    script_path="${BASH_SOURCE[1]:-${0}}"
    script_path="$(realpath "$script_path" 2>/dev/null || echo "$script_path")"
    script_dir="$(dirname "$script_path")"

    export D_PRJ_CALL="${script_path}"

    # Find nearest package.json (upward)
    pkg_json=""
    local dir="$script_dir"
    while [[ "$dir" != "/" ]]; do
        if [[ -f "$dir/package.json" ]]; then
            pkg_json="$dir/package.json"
            break
        fi
        dir="$(dirname "$dir")"
    done

    if [[ -n "$pkg_json" ]] && command -v jq >/dev/null 2>&1; then
        export D_PRJ_NAME="${D_PRJ_NAME:-$(jq -r '.name // "unknown"' "$pkg_json" 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr ' ' '_')}"
        export D_PRJ_VER="${D_PRJ_VER:-$(jq -r '.version // "0.0.0"' "$pkg_json" 2>/dev/null)}"
        export D_PRJ_PATH="${D_PRJ_PATH:-$(dirname "$pkg_json")}"
    else
        # No project detected (common in production or generic installers)
        export D_PRJ_NAME="${D_PRJ_NAME:-unknown}"
        export D_PRJ_VER="${D_PRJ_VER:-unknown}"
        export D_PRJ_PATH="${D_PRJ_PATH:-$script_dir}"
    fi

    export D_PRJ_FOLDER="${D_PRJ_NAME}"
    export D_PRJ_BIN="${D_PRJ_PATH}/bin"

    # Version fallback via get-version.sh
    if [[ "${D_PRJ_VER}" == "unknown" || "${D_PRJ_VER}" == "0.0.0" ]]; then
        get_ver_script="${_D_BIN}/get-version.sh"
        if [[ -x "$get_ver_script" ]]; then
             local ver
             ver=$("$get_ver_script" "${D_PRJ_PATH}/$0" 2>/dev/null || echo "0.0.0")
            [[ -n "$ver" ]] && export D_PRJ_VER="$ver"
         fi
    fi

    # MODE (strict lowercase, validated)
    if [[ -z "${D_MODE:-}" ]]; then
        if [[ -f "${D_PRJ_PATH}/.env" ]]; then
            detected_mode=$(grep -E '^MODE=' "${D_PRJ_PATH}/.env" 2>/dev/null | cut -d= -f2- | tr -d ' "' | tr '[:upper:]' '[:lower:]' | head -n1)
        fi
        export D_MODE="${detected_mode:-prod}"
    else
        export D_MODE="$(printf "%s" "${D_MODE}" | tr '[:upper:]' '[:lower:]')"
    fi

    # Validate MODE
    case "${D_MODE}" in
        dev|stage|prod) ;;
        *)
            _dl_bootstrap_log "WARN" "Invalid D_MODE='${D_MODE}' → forced to 'prod'"
            export D_MODE="prod"
            ;;
    esac

    export D_CATEGORY="${D_CATEGORY:-PROJECT}"

    # LOG_LEVEL based on MODE
    if [[ -z "${LOG_LEVEL:-}" ]]; then
        case "${D_MODE}" in
            dev)   LOG_LEVEL="DEBUG" ;;
            *)     LOG_LEVEL="INFO"  ;;
        esac
        export LOG_LEVEL
    fi

    # Project log only if we have a real project name
    if [[ "${D_PRJ_NAME}" != "unknown" ]]; then
        export D_PROJECT_LOG="${D_PRJ_PATH}/logs/${D_PRJ_NAME}.log"
        mkdir -p "${D_PRJ_PATH}/logs" 2>/dev/null || true
    else
        export D_PROJECT_LOG=""
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
        tag="[${D_PRJ_NAME}]|[${D_PRJ_VER}]"
    else
        tag="|[generic]|"
    fi

    printf "%s|%s|%s|%s|%s|%s|[pid:%s]|[script:%s]|%s" \
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
    case "${D_CATEGORY}" in
        SYSTEM) files+=("${_D_LOGS}/davit-system.log") ;;
        ADMIN)  files+=("${_D_LOGS}/davit-admin.log")  ;;
        AUDIT)  files+=("${_D_LOGS}/davit-audit.log")  ;;
        PROJECT|*)
            [[ -n "${D_PROJECT_LOG}" ]] && files+=("${D_PROJECT_LOG}")
            files+=("${_D_LOGS}/davit-projects.log")
            ;;
    esac

    [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]] && files+=("${_D_LOGS}/davit.log")

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

    # Project log header (only if real project)
    if [[ -n "${D_PROJECT_LOG}" && ( ! -f "${D_PROJECT_LOG}" || -z "$(head -c 100 "${D_PROJECT_LOG}" 2>/dev/null)" ) ]]; then
        {
            echo "# DAVIT LOG HEADER - PROJECT: ${D_PRJ_NAME} | VERSION: ${D_PRJ_VER} | MODE: ${D_MODE} | Created: $(date)"
            echo "# Suggested prune: dev=30d, stage=14d, prod=7d"
            echo "# ======================================================="
        } >> "${D_PROJECT_LOG}"
    fi

    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        log_header "=== DAVIT-LOGGER v1.2.0 – STABLE POSTMASTER ==="
        if [[ "${D_PRJ_NAME}" != "unknown" ]]; then
            log_info "Detected Project: ${D_PRJ_NAME} v${D_PRJ_VER} (MODE=${D_MODE})"
        else
            log_info "No development project detected (generic/production mode)"
        fi
        log_success "Logger ready"
    fi
} || true

# End of davit-logger.sh
