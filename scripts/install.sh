#!/usr/bin/env bash
# Script-ID: d14a1c64-ea50-49d1-b5d1-9621ed1716d7
# ==============================================================================
# Script      : scripts/install.sh
# Description : Manifest-driven installer — deploy dist/ artifacts to /opt/davit
# Author      : David Mullins
# Created     : 2026/07/07
# Version     : 0.6.0
# Part of     : davit-logger
#
# Usage:
#   ./scripts/install.sh --all                  Install all artifacts
#   ./scripts/install.sh --all --force          Install regardless of status
#   ./scripts/install.sh --dry-run --all        Preview without writing
#   ./scripts/install.sh --check                Compare dist vs installed versions
# ==============================================================================

set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
# Source central logger + environment (fail-fast if missing)
# ──────────────────────────────────────────────────────────────────────────────
# shellcheck source=/dev/null
source "/opt/davit/bin/davit-logger.sh" || {
	echo "ERROR: Failed to source davit-logger.sh" >&2
	exit 1
}

export LOG_LEVEL="INFO" # DEBUG | INFO | WARN | ERROR — consumed by davit-logger.sh
SCRIPT_NAME="install.sh"

readonly INSTALLER_VERSION="0.6.0"
INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALLER_DIR

# Source .env before declaring PROJECT_ROOT readonly — .env may set PROJECT_ROOT
ENV_FILE="${INSTALLER_DIR}/../.env"
if [[ -f "$ENV_FILE" ]]; then
	# shellcheck source=/dev/null
	source "$ENV_FILE"
fi

# Always derive PROJECT_ROOT from script location; override any .env value
PROJECT_ROOT="$(cd "${INSTALLER_DIR}/.." && pwd)"
readonly PROJECT_ROOT

# Normalise: canonical key is PROJECT_STATUS; MODE is a legacy alias.
if [[ -z "${PROJECT_STATUS:-}" ]]; then
	case "${MODE:-dev}" in
	prod | production) PROJECT_STATUS="production" ;;
	stage | staging) PROJECT_STATUS="staging" ;;
	*) PROJECT_STATUS="development" ;;
	esac
	[[ -n "${MODE:-}" ]] && log_warn ".env uses legacy MODE='${MODE}' — rename to PROJECT_STATUS"
fi
readonly PROJECT_STATUS

readonly DIST_MANIFEST="${PROJECT_ROOT}/dist/manifest.json"
readonly DAVIT_ROOT="${DAVIT_ROOT:-/opt/davit}"
BACKUP_DIR="${DAVIT_ROOT}/var/backups/$(date +%Y%m%d_%H%M%S)"
readonly BACKUP_DIR
readonly ALIASES_FILE="${HOME}/.davit_aliases"

DRY_RUN=false
CHECK_ONLY=false
INSTALL_ALL=false
FORCE=false
ERRORS=0

log_info "=== ${SCRIPT_NAME} v${INSTALLER_VERSION} started ==="

# ──────────────────────────────────────────────────────────────────────────────
# Display helpers (complementary to davit-logger structured output)
# ──────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
	C_RESET="\e[0m"
	C_GREEN="\e[32m"
	C_YELLOW="\e[33m"
	C_CYAN="\e[36m"
	C_BOLD='\e[033;1m'
else
	C_RESET=""
	C_GREEN=""
	C_YELLOW=""
	C_CYAN=""
	C_BOLD=""
fi

_step() { echo -e "\n${C_BOLD}${C_CYAN}▶ $*${C_RESET}"; }
_dry() { echo -e "${C_YELLOW}[DRY]${C_RESET}   $*"; }

# Increment error counter then log — keeps ERRORS in sync with log_error calls
_err() {
	ERRORS=$((ERRORS + 1))
	log_error "$*"
}

# ==============================================================================
# CHECKSUM
# ==============================================================================
_checksum() {
	local file="$1"
	if command -v sha256sum &>/dev/null; then
		sha256sum "$file" | awk '{print $1}'
	elif command -v shasum &>/dev/null; then
		shasum -a 256 "$file" | awk '{print $1}'
	else
		printf "n/a"
	fi
}

# ==============================================================================
# GADM GUARD
# /opt/davit/ is owned davit:davit (2750). Write operations require the davit
# user (GADM). If not already davit, refuse and tell the caller how to switch.
# Skipped for --dry-run and --check (no writes).
# ==============================================================================
_enforce_gadm() {
	[[ "$(id -un)" == "davit" ]] && return 0
	log_error "Must run as 'davit' (GADM) — current user: $(id -un)"
	echo >&2
	echo >&2 "  Install writes to /opt/davit/ (owned davit:davit 2750)."
	echo >&2 "  Switch to the davit user first:"
	echo >&2
	echo >&2 "    ssh davit@\$(hostname)   # recommended"
	echo >&2 "    su - davit               # alternative"
	echo >&2
	echo >&2 "  Then re-run: $0 $*"
	echo >&2
	exit 1
}

# ==============================================================================
# DEPLOY CONTEXT CHECK
# Rules:
#   production  → branch MUST be 'main'; blocks otherwise
#   staging     → any branch; warns
#   development → any branch; warns; --force still required for status gate
# ==============================================================================
_check_deploy_context() {
	local branch
	branch="$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
	log_info "Deploy context: PROJECT_STATUS=${PROJECT_STATUS} branch=${branch}"

	case "${PROJECT_STATUS}" in
	production)
		if [[ "$branch" != "main" ]]; then
			log_error "Production deploy blocked — branch must be 'main', current: '${branch}'"
			echo >&2
			echo >&2 "  Options:"
			echo >&2 "    1. Merge to main:  git checkout main && git merge ${branch} --no-ff"
			echo >&2 "    2. Set PROJECT_STATUS=staging in .env for pre-production testing"
			echo >&2
			exit 1
		fi
		log_info "Production deploy from 'main' — allowed"
		;;
	staging)
		log_warn "Staging deploy — target: ${DAVIT_ROOT}"
		[[ "$branch" != "main" ]] && log_warn "Staging deploy from non-main branch: '${branch}'"
		;;
	development | *)
		log_warn "Development deploy — PROJECT_STATUS=${PROJECT_STATUS}, branch=${branch}"
		log_warn "Target is production (/opt/davit/) — set PROJECT_STATUS=production on main for real deploy"
		;;
	esac
}

# ==============================================================================
# PREREQUISITES
# ==============================================================================
check_prerequisites() {
	_step "Checking prerequisites"
	local missing=0

	command -v jq &>/dev/null || {
		_err "jq is required but not installed"
		missing=$((missing + 1))
	}

	if [[ ! -f "$DIST_MANIFEST" ]]; then
		_err "dist/manifest.json not found — run ./scripts/build.sh first"
		missing=$((missing + 1))
	fi

	[[ -d "$DAVIT_ROOT" ]] || {
		_err "DAVIT_ROOT not found: ${DAVIT_ROOT}"
		missing=$((missing + 1))
	}

	if ((missing > 0)); then
		log_error "Prerequisites failed (${missing} issue(s)). Aborting."
		exit 1
	fi

	log_success "Prerequisites satisfied"
}

# ==============================================================================
# ALIAS REGISTRATION
# Writes/updates a single alias line in ~/.davit_aliases
# ==============================================================================
register_alias() {
	local alias_name="$1"
	local bin_path="$2"
	local alias_line="alias ${alias_name}='${bin_path}'"

	if [[ "$DRY_RUN" == "true" ]]; then
		_dry "Would write to ${ALIASES_FILE}: ${alias_line}"
		return
	fi

	if [[ -f "$ALIASES_FILE" ]]; then
		sed -i "/^alias ${alias_name}=/d" "$ALIASES_FILE"
	fi
	echo "$alias_line" >>"$ALIASES_FILE"
	log_success "Alias registered: ${alias_line}"
}

# ==============================================================================
# INSTALL ARTIFACTS
# Reads dist/manifest.json; installs to /opt/davit/<dist_path>
# Default: only artifacts with status == "deployed"; --force overrides
# ==============================================================================
install_artifacts() {
	_step "Installing artifacts"
	local count=0

	while IFS= read -r artifact; do
		local dist_path alias_name version status
		dist_path="$(jq -r '.dist_path' <<<"$artifact")"
		alias_name="$(jq -r '.alias' <<<"$artifact")"
		version="$(jq -r '.version' <<<"$artifact")"
		status="$(jq -r '.status' <<<"$artifact")"

		if [[ "$status" != "deployed" && "$FORCE" != "true" ]]; then
			log_warn "Skipping '${dist_path}' — status '${status}' (use --force to override)"
			continue
		fi

		local src="${PROJECT_ROOT}/dist/${dist_path}"
		local dst="${DAVIT_ROOT}/${dist_path}"

		if [[ ! -f "$src" ]]; then
			_err "Dist file missing: ${src} — run ./scripts/build.sh first"
			continue
		fi

		if [[ "$DRY_RUN" == "true" ]]; then
			_dry "Would install: ${src} → ${dst} (chmod 750)"
			[[ -n "$alias_name" ]] && _dry "Would register alias: ${alias_name}='${dst}'"
			count=$((count + 1))
			continue
		fi

		if [[ -f "$dst" ]]; then
			mkdir -p "$BACKUP_DIR"
			cp -p "$dst" "${BACKUP_DIR}/$(basename "$dst").bak"
			log_info "Backed up: ${dst}"
		fi

		mkdir -p "$(dirname "$dst")"
		cp "$src" "$dst"
		chmod 750 "$dst"
		log_success "Installed: ${dst} (v${version})"

		[[ -n "$alias_name" ]] && register_alias "$alias_name" "$dst"
		count=$((count + 1))
	done < <(jq -c '.artifacts[]' "$DIST_MANIFEST")

	log_info "${count} artifact(s) processed"
}

# ==============================================================================
# CHECK MODE — compare dist vs installed
# ==============================================================================
run_check() {
	_step "Version check (dist vs installed)"

	if [[ ! -f "$DIST_MANIFEST" ]]; then
		_err "dist/manifest.json not found — run ./scripts/build.sh first"
		exit 1
	fi

	printf "%-25s %-10s %-40s %s\n" "ALIAS" "VERSION" "INSTALLED PATH" "STATUS"
	printf "%-25s %-10s %-40s %s\n" "-----" "-------" "--------------" "------"

	while IFS= read -r artifact; do
		local dist_path alias_name version
		dist_path="$(jq -r '.dist_path' <<<"$artifact")"
		alias_name="$(jq -r '.alias' <<<"$artifact")"
		version="$(jq -r '.version' <<<"$artifact")"

		local dst="${DAVIT_ROOT}/${dist_path}"
		local status_str

		if [[ ! -f "$dst" ]]; then
			status_str="${C_YELLOW}not installed${C_RESET}"
		else
			local src="${PROJECT_ROOT}/dist/${dist_path}"
			local dist_sum installed_sum
			dist_sum="$(_checksum "$src" 2>/dev/null || echo "?")"
			installed_sum="$(_checksum "$dst" 2>/dev/null || echo "?")"
			if [[ "$dist_sum" == "$installed_sum" ]]; then
				status_str="${C_GREEN}up-to-date${C_RESET}"
			else
				status_str="${C_YELLOW}update available${C_RESET}"
			fi
		fi

		printf "%-25s %-10s %-40s " "${alias_name:-$dist_path}" "$version" "$dst"
		echo -e "$status_str"
	done < <(jq -c '.artifacts[]' "$DIST_MANIFEST")
}

# ==============================================================================
# USAGE
# ==============================================================================
usage() {
	printf '%b\n' "
${C_BOLD}install.sh${C_RESET} v${INSTALLER_VERSION} — Manifest-driven davit-logger installer

${C_BOLD}USAGE${C_RESET}
  ./scripts/install.sh --all                  Install all deployed artifacts
  ./scripts/install.sh --all --force          Install regardless of status
  ./scripts/install.sh --dry-run --all        Preview changes without writing
  ./scripts/install.sh --check                Compare dist vs installed versions

${C_BOLD}OPTIONS${C_RESET}
  --all         Process all artifacts in dist/manifest.json
  --force       Override status check (install even if not 'deployed')
  --dry-run     Show what would change; write nothing
  --check       Version comparison only; no install
  --help        This help

${C_BOLD}NOTES${C_RESET}
  Source of truth : dist/manifest.json  (run ./scripts/build.sh first)
  Install target  : ${DAVIT_ROOT}/<dist_path>
  Permissions     : 750
  Aliases file    : ${ALIASES_FILE}
  Backups         : ${DAVIT_ROOT}/var/backups/YYYYMMDD_HHMMSS/
"
}

# ==============================================================================
# ARGUMENT PARSER
# ==============================================================================
parse_args() {
	if [[ $# -eq 0 ]]; then
		usage
		exit 0
	fi

	while [[ $# -gt 0 ]]; do
		case "$1" in
		--dry-run) DRY_RUN=true ;;
		--check) CHECK_ONLY=true ;;
		--all) INSTALL_ALL=true ;;
		--force) FORCE=true ;;
		--help | -h)
			usage
			exit 0
			;;
		*)
			_err "Unknown option: $1"
			usage
			exit 1
			;;
		esac
		shift
	done
}

# ==============================================================================
# MAIN
# ==============================================================================
main() {
	parse_args "$@"

	if [[ "$DRY_RUN" != "true" && "$CHECK_ONLY" != "true" ]]; then
		_check_deploy_context # branch + mode gate — fail fast, no sudo needed
		_enforce_gadm "$@"    # identity gate — must be davit (GADM)
	fi

	echo -e "\n${C_BOLD}davit-logger Installer${C_RESET} v${INSTALLER_VERSION}"
	echo -e "  Project : ${PROJECT_ROOT}"
	echo -e "  Mode    : ${PROJECT_STATUS}"
	echo -e "  Target  : ${DAVIT_ROOT}"
	[[ "$DRY_RUN" == "true" ]] && echo -e "  ${C_YELLOW}[DRY RUN — no files will be written]${C_RESET}"
	[[ "$FORCE" == "true" ]] && echo -e "  ${C_YELLOW}[FORCE — status check bypassed]${C_RESET}"
	echo ""

	if [[ "$CHECK_ONLY" == "true" ]]; then
		run_check
		exit 0
	fi

	check_prerequisites

	if [[ "$INSTALL_ALL" == "true" ]]; then
		install_artifacts
	fi

	echo ""
	if ((ERRORS > 0)); then
		log_error "Completed with ${ERRORS} error(s)"
		exit 1
	fi
	log_success "Install complete"
	log_info "=== ${SCRIPT_NAME} finished ==="
}

main "$@"
