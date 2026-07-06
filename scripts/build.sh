#!/usr/bin/env bash
# Script-ID: a3f7c2d1-8b4e-4f9a-bc6d-1e2f3a4b5c6d
# =============================================================================
# build.sh
# Description: Assemble dist/ from src/ and generate dist/manifest.json
# Version:     0.2.0
# Part of:     davit-logger
#
# Usage:
#   ./scripts/build.sh [--clean] [--dry-run] [--help]
#
# Output: dist/bin/davit-logger.sh, dist/configs/davit-logger/logging-theme.json,
#         dist/manifest.json
# Exit codes:  0 = success   1 = error   2 = dry-run complete
# =============================================================================

set -euo pipefail

readonly SCRIPT_VERSION="0.2.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly SRC_DIR="${PROJECT_ROOT}/src"
readonly DIST_DIR="${PROJECT_ROOT}/dist"

# Colour
if [[ -t 1 ]]; then
    C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_GREEN=$'\e[32m'
    C_YELLOW=$'\e[33m'; C_RED=$'\e[31m'; C_CYAN=$'\e[36m'; C_DIM=$'\e[2m'
else
    C_RESET=""; C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""; C_DIM=""
fi

_info()  { printf '%s\n' "${C_GREEN}  ✓${C_RESET}  $*"; }
_warn()  { printf '%s\n' "${C_YELLOW}  ⚠${C_RESET}  $*"; }
_step()  { printf '\n%s\n' "${C_BOLD}$*${C_RESET}"; }
_dry()   { printf '%s\n' "${C_CYAN}  ⟶${C_RESET}  [dry] $*"; }
_fatal() { printf '%s\n' "${C_RED}  ✗${C_RESET}  ERROR: $*" >&2; exit 1; }

DRY_RUN=false
CLEAN=false

# =============================================================================
# HELPERS
# =============================================================================

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

_version_from_header() {
    local file="$1"
    grep -m1 -E '^\s*#\s*Version\s*:' "$file" 2>/dev/null \
        | sed 's/^.*Version[[:space:]]*:[[:space:]]*//' | tr -d '[:space:]' \
        || printf "0.0.0"
}

_project_version() {
    local env_file="${PROJECT_ROOT}/.env"
    local ver
    ver=$(grep -m1 '^PROJECT_VERSION=' "$env_file" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
    printf '%s' "${ver:-0.0.0}"
}

# =============================================================================
# PHASES
# =============================================================================

clean_dist() {
    _step "0  Clean dist/"
    if [[ "$DRY_RUN" == "true" ]]; then
        _dry "rm -rf ${DIST_DIR}/* (keep .gitkeep)"
        return
    fi
    find "${DIST_DIR}" -mindepth 1 ! -name '.gitkeep' -delete 2>/dev/null || true
    mkdir -p "${DIST_DIR}/bin" "${DIST_DIR}/configs/davit-logger"
    _info "dist/ cleaned"
}

build_logger() {
    _step "1/2  Logger → dist/bin/davit-logger.sh"
    local src="${SRC_DIR}/davit-logger.sh"
    local dst="${DIST_DIR}/bin/davit-logger.sh"
    [[ -f "$src" ]] || _fatal "Source missing: $src"
    if [[ "$DRY_RUN" == "true" ]]; then
        _dry "cp ${src} → ${dst}; chmod 755"
        return
    fi
    mkdir -p "${DIST_DIR}/bin"
    cp "$src" "$dst"
    chmod 755 "$dst"
    _info "dist/bin/davit-logger.sh  ($(_version_from_header "$src"))"
}

build_theme() {
    _step "2/2  Theme → dist/configs/davit-logger/logging-theme.json"
    local src="${SRC_DIR}/configs/davit-logger/logging-theme.json"
    local dst="${DIST_DIR}/configs/davit-logger/logging-theme.json"
    [[ -f "$src" ]] || _fatal "Source missing: $src"
    if [[ "$DRY_RUN" == "true" ]]; then
        _dry "cp ${src} → ${dst}"
        return
    fi
    mkdir -p "${DIST_DIR}/configs/davit-logger"
    cp "$src" "$dst"
    _info "dist/configs/davit-logger/logging-theme.json"
}

generate_manifest() {
    _step "  Manifest → dist/manifest.json"
    local manifest="${DIST_DIR}/manifest.json"
    local ts; ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    local logger_ver; logger_ver="$(_version_from_header "${SRC_DIR}/davit-logger.sh")"
    local project_ver; project_ver="$(_project_version)"

    if [[ "$DRY_RUN" == "true" ]]; then
        _dry "write manifest.json (logger ${logger_ver}, project ${project_ver}, ts ${ts})"
        return
    fi

    # Build artifact list with checksums
    local artifacts=()
    while IFS= read -r -d '' f; do
        local rel="${f#"${DIST_DIR}/"}"
        local sum; sum="$(_checksum "$f")"
        artifacts+=("    { \"path\": \"${rel}\", \"sha256\": \"${sum}\" }")
    done < <(find "${DIST_DIR}" -type f ! -name 'manifest.json' ! -name '.gitkeep' -print0 | sort -z)

    local artifact_json
    artifact_json="$(printf '%s,\n' "${artifacts[@]}")"
    artifact_json="${artifact_json%,}"   # strip trailing comma

    cat > "$manifest" <<EOF
{
  "_meta": {
    "generated": "${ts}",
    "tool": "davit-logger/scripts/build.sh v${SCRIPT_VERSION}",
    "project": "davit-logger",
    "project_version": "${project_ver}",
    "logger_version": "${logger_ver}"
  },
  "artifacts": [
${artifact_json}
  ]
}
EOF
    _info "dist/manifest.json  (${#artifacts[@]} artifacts)"
}

# =============================================================================
# USAGE
# =============================================================================

usage() {
    printf '%b\n' "
${C_BOLD}build.sh${C_RESET} v${SCRIPT_VERSION} — Assemble davit-logger dist/

${C_BOLD}USAGE${C_RESET}
  ./scripts/build.sh [options]

${C_BOLD}OPTIONS${C_RESET}
  --clean      Clean dist/ before building
  --dry-run    Show what would be built; write nothing
  --help, -h   This help

${C_BOLD}OUTPUT${C_RESET}
  dist/bin/davit-logger.sh
  dist/configs/davit-logger/logging-theme.json
  dist/manifest.json
"
}

# =============================================================================
# MAIN
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --clean)     CLEAN=true ;;
        --dry-run)   DRY_RUN=true ;;
        --help|-h)   usage; exit 0 ;;
        *)           _fatal "Unknown option: $1" ;;
        esac
        shift
    done
}

main() {
    parse_args "$@"

    printf '\n%s\n' "${C_BOLD}build.sh v${SCRIPT_VERSION}${C_RESET}"
    printf '  Project : %s\n' "$PROJECT_ROOT"
    [[ "$DRY_RUN" == "true" ]] && printf '  Mode    : %s\n' "${C_YELLOW}DRY RUN${C_RESET}"

    if [[ "$CLEAN" == "true" ]]; then
        clean_dist
    fi

    build_logger
    build_theme
    generate_manifest

    printf '\n'
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '  %s\n\n' "${C_YELLOW}Dry run — no files written${C_RESET}"
        exit 2
    fi
    printf '  %s\n\n' "${C_GREEN}Build complete → dist/${C_RESET}"
    exit 0
}

main "$@"
