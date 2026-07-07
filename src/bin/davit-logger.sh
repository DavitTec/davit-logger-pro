#!/usr/bin/env bash
# Script-ID: 8796413b-0a78-4b78-9d93-7efd11b1db7c
# ==============================================================================
# Script      : src/bin/davit-logger.sh
# Description : Davit Logger - STABLE POSTMASTER – Authoritative Davit Logger
#               JSON + Text output, robust project detection, console control
# Author      : David Mullins
# Created     : 2025-11-02
# Version     : 1.4.6
# Project     : davit-logger
# Alias       : logger
# Bin-Name    : davit-logger.sh
# ==============================================================================

# ──────────────────────────────────────────────────────────────────────────────
# Source central logger + environment (fail-fast if missing)
# ──────────────────────────────────────────────────────────────────────────────
# shellcheck source=/dev/null

set -Eeo pipefail
shopt -s extglob nullglob

# Guard
# NOTE: deliberately NOT `readonly` below. A readonly reassignment is a hard
# error in bash — and per the bash manual, assigning to a readonly variable
# "fails and the shell exits" in a non-interactive shell, unconditionally,
# regardless of `set -e`. Any re-source of this file in the same shell (a
# dev re-sourcing after an edit, a long-lived daemon, a wrapper sourcing
# several sub-scripts) would otherwise crash the entire calling process the
# instant this file is loaded a second time — the guard below exists
# precisely to make re-sourcing a safe no-op, which only works if nothing
# it protects is `readonly`.
[[ -n "${_D_LOGGER_LOADED:-}" ]] && return 0
_D_LOGGER_LOADED=1

user=${SUDO_USER:-$USER}

# ------------------------------------------------------------------
# Core Paths
# ------------------------------------------------------------------
# davit.conf is the authoritative source for DAVIT_ROOT / DAVIT_LOGS_DIR
# (davit-os-alpha ANDES.md §12 / §6 LAYER 2) — source it if the caller
# hasn't already, so the log directory is config-driven rather than
# hardcoded. Degrade to the historical defaults if davit.conf isn't present
# at all (FR-010 / NR-005 — zero hard dependencies).
if [[ -z "${DAVIT_ROOT:-}" ]]; then
	_dl_conf="${DAVIT_ROOT:-/opt/davit}/etc/davit.conf"
	# shellcheck source=/dev/null
	[[ -r "${_dl_conf}" ]] && source "${_dl_conf}" 2>/dev/null
	unset _dl_conf
fi

_D_ROOT="${DAVIT_ROOT:-/opt/davit}"
_D_BIN="${DAVIT_BIN:-${_D_ROOT}/bin}"
_D_LOGS="${DAVIT_LOGS_DIR:-${_D_ROOT}/logs}"
_D_LIB="${DAVIT_LIB:-${_D_ROOT}/lib}"

mkdir -p "${_D_LOGS}" 2>/dev/null || true

# ------------------------------------------------------------------
# Configurable Switches
# ------------------------------------------------------------------
LOG_LEVEL=${LOG_LEVEL:-INFO}
TERMINAL_OUTPUT=${TERMINAL_OUTPUT:-1}
LOG_TO_LOCAL=${LOG_TO_LOCAL:-1}
LOG_TO_CENTRAL=${LOG_TO_CENTRAL:-1}
LOG_FORMAT=${LOG_FORMAT:-text} # text | json

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

# Theme loader
_dl_load_theme() {
	local file="$1" mode block
	[[ -f "$file" ]] || return 1
	mode=$(grep -o '"mode"[[:space:]]*:[[:space:]]*"[^"]*"' "$file" 2>/dev/null | cut -d'"' -f4 || echo "dark")
	block=$(sed -n "/\"${mode}\"/,/}/p" "$file" 2>/dev/null)
	while IFS= read -r line; do
		[[ "$line" =~ \"([^\"]+)\"[[:space:]]*:[[:space:]]*\"([^\"]*)\" ]] || continue
		printf -v "DAVIT_COLOR_${BASH_REMATCH[1]}" "%b" "${BASH_REMATCH[2]//\\u001b/\\e}"
	done <<<"$(grep '":' <<<"$block" | sed 's/,$//' 2>/dev/null)"
}

for theme in \
	"${_D_LIB}/configs/davit-logger/logging-theme.json" \
	"${_D_BIN}/../lib/configs/davit-logger/logging-theme.json" \
	"${HOME}/.config/davit/logging-theme.json"; do
	_dl_load_theme "$theme" 2>/dev/null && break
done

# ------------------------------------------------------------------
# Bootstrap
# ------------------------------------------------------------------
_dl_bootstrap_log() {
	local level="$1" msg="$2"
	local ts
	ts=$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
	printf "[%s] [%s] [BOOTSTRAP] %s\n" "$ts" "$level" "$msg" >>"${_D_LOGS}/davit.log"
	[[ -t 1 ]] && printf "%b[%s] [BOOTSTRAP]%b %s\n" "${DAVIT_COLOR_WARN}" "$level" "${DAVIT_COLOR_RESET}" "$msg" >&2
}

# ------------------------------------------------------------------
# Final Simple & Reliable Detection (v1.4.0)
# ------------------------------------------------------------------
_dl_detect_context() {
	local script_path script_dir rel_path

	script_path="${BASH_SOURCE[1]:-${0}}"
	script_path="$(realpath -s "$script_path" 2>/dev/null || echo "$script_path")"
	script_dir="$(dirname "$script_path")"

	export D_PRJ_CALL="${script_path}"

	# MODE: Force DEV if under development tree
	if [[ -z "${D_MODE:-}" ]]; then
		if [[ "$script_dir" == /opt/davit/development/* || "$PWD" == /opt/davit/development/* ]]; then
			export D_MODE="dev"
		else
			export D_MODE="prod"
		fi
	fi

	# Project Name: Take folder directly under development/
	if [[ "$script_dir" == /opt/davit/development/* || "$PWD" == /opt/davit/development/* ]]; then
		local base="${PWD#/opt/davit/development/}"
		export D_PRJ_NAME="${base%%/*}"
	else
		export D_PRJ_NAME="${D_PRJ_NAME:-unknown}"
	fi

	export D_PRJ_NAME="${D_PRJ_NAME:-unknown}"

	if [[ ! ${D_PRJ_NAME} == "unknown" ]]; then
		src="/opt/davit/development/${D_PRJ_NAME}/package.json"
		if [[ -f $src ]]; then
			D_PRJ_VER=$(jq -r .version "${src}")
		else
			src="/opt/davit/development/${D_PRJ_NAME}/.env"
			if [[ -f $src ]]; then
				D_PRJ_VER=$(grep -m1 '^PROJECT_VERSION=' "${src}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
				if [[ -z "$D_PRJ_VER" ]]; then
					D_PRJ_VER=$(grep -m1 '^VERSION=' "${src}" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
				fi
			fi
		fi
	fi

	export D_PRJ_VER="${D_PRJ_VER:-unknown}"
	export D_PRJ_PATH="${D_PRJ_PATH:-${PWD}}"

	export D_PRJ_FOLDER="${D_PRJ_NAME}"
	export D_PRJ_BIN="${D_PRJ_PATH}/bin"

	# Local project log only for real projects
	if [[ "${D_PRJ_NAME}" != "unknown" && "${D_PRJ_NAME}" != "davit" && "${D_PRJ_NAME}" != "generic" ]]; then
		export D_PROJECT_LOG="${D_PRJ_PATH}/logs/${D_PRJ_NAME}.log"
		mkdir -p "${D_PRJ_PATH}/logs" 2>/dev/null || true
	else
		export D_PROJECT_LOG=""
	fi

	export D_CATEGORY="${D_CATEGORY:-PROJECT}"

	if [[ -z "${LOG_LEVEL:-}" ]]; then
		[[ "${D_MODE}" == "dev" ]] && LOG_LEVEL="DEBUG" || LOG_LEVEL="INFO"
		export LOG_LEVEL
	fi
}

# ------------------------------------------------------------------
# Flag Parser
# ------------------------------------------------------------------
davit_parse_flags() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--quiet)
			LOG_LEVEL="ERROR"
			TERMINAL_OUTPUT=0
			;;
		--verbose)
			LOG_LEVEL="INFO"
			TERMINAL_OUTPUT=1
			;;
		--debug)
			LOG_LEVEL="DEBUG"
			TERMINAL_OUTPUT=1
			;;
		--json) LOG_FORMAT="json" ;;
		--text) LOG_FORMAT="text" ;;
		--no-console | --noconsole) TERMINAL_OUTPUT=0 ;;
		--console) TERMINAL_OUTPUT=1 ;;
		esac
		shift
	done
	export LOG_LEVEL TERMINAL_OUTPUT LOG_FORMAT
}

# ------------------------------------------------------------------
# Build Text Line
# ------------------------------------------------------------------
_dl_build_line() {
	local level="$1" msg="$2"
	local ts pid script_name mode_str tag

	ts=$(date '+%Y-%m-%d %H:%M:%S.%3N' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')
	pid=$$
	script_name="$(basename "${0}")"

	mode_str="MODE:${D_MODE:-prod}"

	if [[ "${D_PRJ_NAME:-unknown}" != "unknown" && "${D_PRJ_NAME:-unknown}" != "davit" ]]; then
		tag="${D_PRJ_NAME} | ${D_PRJ_VER:-unknown}"
	else
		tag="generic | -"
	fi

	printf "%s | %s | %s | %s | %s | %s | pid:%s | script:%s | %s" \
		"$ts" "$user" "$level" "${D_CATEGORY:-PROJECT}" "$tag" "$mode_str" "$pid" "$script_name" "$msg"
}

# ------------------------------------------------------------------
# Build JSON Line
# ------------------------------------------------------------------
_dl_build_json() {
	local level="$1" msg="$2"
	local ts
	ts=$(date '+%Y-%m-%dT%H:%M:%S.%3NZ' 2>/dev/null || date '+%Y-%m-%d %H:%M:%S')

	cat <<EOF | jq -c . 2>/dev/null || printf '{"timestamp":"%s","level":"%s","message":"%s"}\n' "$ts" "$level" "$msg"
{
"timestamp": "$ts",
"level": "$level",
"category": "${D_CATEGORY:-PROJECT}",
"project": "${D_PRJ_NAME:-unknown}",
"version": "${D_PRJ_VER:-unknown}",
"mode": "${D_MODE:-prod}",
"user": "$user",
"pid": $$,
"script": "$(basename "${0}")",
"message": $(jq -R <<<"$msg")
}
EOF
}

# ------------------------------------------------------------------
# Core Write
# ------------------------------------------------------------------
_dl_write() {
	local level="$1" colour_var colour msg line clean_line files=()

	colour_var="DAVIT_COLOR_${level^^}"
	colour="${!colour_var:-$DAVIT_COLOR_INFO}"

	shift
	msg="$*"
	[[ -z "$msg" ]] && msg="No message"

	if [[ "${LOG_FORMAT}" == "json" ]]; then
		line=$(_dl_build_json "$level" "$msg")
		clean_line="$line"
	else
		line=$(_dl_build_line "$level" "$msg")
		clean_line=$(printf "%s" "$line" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g')
	fi

	# Console output
	if [[ "${TERMINAL_OUTPUT}" == "1" ]]; then
		if [[ "${LOG_FORMAT}" == "json" ]]; then
			printf "%s\n" "$line" >&1
		elif [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]]; then
			printf "%b%s%b\n" "$colour" "$line" "$DAVIT_COLOR_RESET" >&2
		else
			printf "%b%s%b\n" "$colour" "$line" "$DAVIT_COLOR_RESET" >&1
		fi
	fi

	# File routing
	if [[ "${LOG_TO_LOCAL}" == "1" && -n "${D_PROJECT_LOG}" ]]; then
		files+=("${D_PROJECT_LOG}")
	fi

	if [[ "${LOG_TO_CENTRAL}" == "1" ]]; then
		case "${D_CATEGORY}" in
		SYSTEM) files+=("${_D_LOGS}/davit-system.log") ;;
		ADMIN) files+=("${_D_LOGS}/davit-admin.log") ;;
		AUDIT) files+=("${_D_LOGS}/davit-audit.log") ;;
		PROJECT | *) files+=("${_D_LOGS}/davit-projects.log") ;;
		esac
		[[ "$level" == "ERROR" || "$level" == "CRITICAL" ]] && files+=("${_D_LOGS}/davit.log")
	fi

	# /opt/davit/ log dirs are shared within the davit group (setgid, e.g.
	# drwxrws---); a restrictive umask still creates each new file
	# non-group-writable, so whichever user creates a log file first blocks
	# every other group member from appending to it later. Force
	# group-writable (002) only around these writes, then restore.
	local _dl_prev_umask
	_dl_prev_umask="$(umask)"
	umask 002
	for f in "${files[@]}"; do
		mkdir -p "$(dirname "$f")" 2>/dev/null || true
		printf "%s\n" "$clean_line" >>"$f"
	done
	umask "$_dl_prev_umask"
}

# ------------------------------------------------------------------
# Level Filter
# ------------------------------------------------------------------
_dl_should_log() {
	local wanted="${1:-INFO}"
	[[ -z "${LOG_LEVEL:-}" ]] && LOG_LEVEL="INFO"

	local levels=(DEBUG INFO WARN ERROR CRITICAL)
	local current=0 wanted_idx=0 i

	for i in "${!levels[@]}"; do
		[[ "${levels[$i]}" == "${LOG_LEVEL}" ]] && current=$i
		[[ "${levels[$i]}" == "$wanted" ]] && wanted_idx=$i
	done

	((wanted_idx >= current)) 2>/dev/null || return 0
}

# ------------------------------------------------------------------
# Public API
# ------------------------------------------------------------------
log_debug() { _dl_should_log DEBUG && _dl_write DEBUG "$@"; }
log_info() { _dl_should_log INFO && _dl_write INFO "$@"; }
log_warn() { _dl_should_log WARN && _dl_write WARN "$@"; }
log_error() { _dl_should_log ERROR && _dl_write ERROR "$@"; }
log_critical() {
	_dl_write CRITICAL "$@"
	exit 1
}
log_success() { _dl_write SUCCESS "$@"; }
log_header() { _dl_write HEADER "$@"; }

log_term() {
	[[ "${TERMINAL_OUTPUT}" == "1" ]] || return 0
	printf "%b%s%b\n" "${DAVIT_COLOR_HIGHLIGHT}" "$*" "${DAVIT_COLOR_RESET}" >&1
}

log_todo() {
	local msg="$1" serial="${2:-TODO-$(date +%Y%m%d-%H%M%S)}"
	_dl_write WARN "TODO: ${msg} (serial: ${serial})"
	log_term "TODO [$serial]: $msg"
}

log() {
	case "${1:-}" in
	debug | DEBUG)
		shift
		log_debug "$@"
		;;
	info | INFO)
		shift
		log_info "$@"
		;;
	warn | WARN)
		shift
		log_warn "$@"
		;;
	error | ERROR)
		shift
		log_error "$@"
		;;
	success | SUCCESS)
		shift
		log_success "$@"
		;;
	header | HEADER)
		shift
		log_header "$@"
		;;
	critical | CRITICAL)
		shift
		log_critical "$@"
		;;
	term | TERM)
		shift
		log_term "$@"
		;;
	todo | TODO)
		shift
		log_todo "$@"
		;;
	*) log_info "$@" ;;
	esac
}

# ------------------------------------------------------------------
# Initialization
# ------------------------------------------------------------------
{
	_dl_detect_context

	if [[ -n "${D_PROJECT_LOG}" && (! -f "${D_PROJECT_LOG}" || -z "$(head -c 100 "${D_PROJECT_LOG}" 2>/dev/null)") ]]; then
		# See _dl_write() — force group-writable so the next user to append
		# to this project log (possibly a different davit-group member)
		# isn't blocked by a restrictive creation umask.
		_dl_prev_umask="$(umask)"
		umask 002
		{
			echo "# DAVIT LOG HEADER - PROJECT: ${D_PRJ_NAME} | VERSION: ${D_PRJ_VER} | MODE: ${D_MODE} | Created: $(date)"
			echo "# ======================================================="
		} >>"${D_PROJECT_LOG}"
		umask "$_dl_prev_umask"
	fi

	logger_ver=$($_D_BIN/get-version.sh /opt/davit/bin/davit-logger.sh)

	if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
		log_header "=== DAVIT-LOGGER v${logger_ver} – STABLE POSTMASTER ==="
		log_info "Format:${LOG_FORMAT} Console:${TERMINAL_OUTPUT} Local:${LOG_TO_LOCAL} Central:${LOG_TO_CENTRAL}"
		log_success "Logger ready"
	fi
} || true
