#!/usr/bin/env bash
# Script-ID: 0a038395-f690-4cff-a2b0-b9e122ad3023
# ==============================================================================
# Script      : scripts/build.sh
# Description : Manifest-driven build — assemble dist/ from src/ artifacts
# Author      : David Mullins
# Created     : 2026/07/07
# Version     : 0.3.0
# Part of     : davit-logger
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

LOG_LEVEL="INFO" # DEBUG | INFO | WARN | ERROR — consumed by davit-logger.sh
SCRIPT_NAME="build.sh"

readonly SCRIPT_VERSION="0.3.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
readonly PROJECT_ROOT
readonly MANIFEST="${PROJECT_ROOT}/manifest.json"
readonly DIST_DIR="${PROJECT_ROOT}/dist"

log_info "=== ${SCRIPT_NAME} v${SCRIPT_VERSION} started ==="

# ──────────────────────────────────────────────────────────────────────────────
# Display helpers — formatted build output (complementary to davit-logger)
# ──────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
	C_RESET=$'\e[0m'
	C_BOLD=$'\e[1m'
	C_GREEN=$'\e[32m'
	C_YELLOW=$'\e[33m'
	C_RED=$'\e[31m'
	C_CYAN=$'\e[36m'
else
	C_RESET=""
	C_BOLD=""
	C_GREEN=""
	C_YELLOW=""
	C_RED=""
	C_CYAN=""
fi

_info() { printf '%s\n' "${C_GREEN}  ✓${C_RESET}  $*"; }
_warn() {
	printf '%s\n' "${C_YELLOW}  ⚠${C_RESET}  $*"
	log_warn "$*"
}
_step() { printf '\n%s\n' "${C_BOLD}$*${C_RESET}"; }
_dry() { printf '%s\n' "${C_CYAN}  ⟶${C_RESET}  [dry] $*"; }
_fatal() {
	printf '%s\n' "${C_RED}  ✗${C_RESET}  ERROR: $*" >&2
	log_error "$*"
	exit 1
}

DRY_RUN=false
CLEAN=false
SKIP_VALIDATE=false

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

# Strip the src/ prefix from a manifest "path" field, whether the artifact
# sits directly in src/ (path == "src") or in a subdirectory (path == "src/x").
# ${path#src/} alone leaves "src" untouched when there is no subdirectory,
# which would leak a literal "src" segment into the dist/install layout.
_strip_src_prefix() {
	local path="$1" rel
	rel="${path#src}"
	rel="${rel#/}"
	printf '%s' "$rel"
}

# ==============================================================================
# PHASES
# ==============================================================================

check_prerequisites() {
	command -v jq &>/dev/null || _fatal "jq is required but not installed"
	[[ -f "$MANIFEST" ]] || _fatal "manifest.json not found: $MANIFEST"
}

clean_dist() {
	_step "0  Clean dist/"
	if [[ "$DRY_RUN" == "true" ]]; then
		_dry "rm dist/* (keep .gitkeep)"
		return
	fi
	find "${DIST_DIR}" -mindepth 1 ! -name '.gitkeep' -delete 2>/dev/null || true
	_info "dist/ cleaned"
	log_info "dist/ cleaned"
}

run_precheck() {
	_step "Pre-build  Validate source artifacts"
	local manifest_bin
	manifest_bin="$(command -v manifest || true)"
	if [[ -z "$manifest_bin" ]]; then
		_warn "manifest CLI not found — skipping pre-build validation"
		return 0
	fi
	if [[ "$DRY_RUN" == "true" ]]; then
		_dry "manifest validate --all"
		return 0
	fi
	"$manifest_bin" validate --all || _fatal "Pre-build validation failed — fix errors above and retry"
}

build_artifacts() {
	_step "Build  Assemble dist/ from manifest.json"
	local count=0

	while IFS= read -r artifact; do
		local name path bin_name type status
		name="$(jq -r '.name' <<<"$artifact")"
		path="$(jq -r '.path' <<<"$artifact")"
		bin_name="$(jq -r '.bin_name' <<<"$artifact")"
		type="$(jq -r '.type' <<<"$artifact")"
		status="$(jq -r '.status' <<<"$artifact")"

		[[ "$status" == "deprecated" ]] && continue

		local src="${PROJECT_ROOT}/${path}/${name}"
		if [[ ! -f "$src" ]]; then
			_warn "Source missing: $src — skipping"
			continue
		fi

		local rel
		rel="$(_strip_src_prefix "$path")"
		local dist_dir="${DIST_DIR}${rel:+/$rel}"

		local dest_name
		case "$type" in
		bash | shell) dest_name="$bin_name" ;;
		*) dest_name="$name" ;;
		esac

		local dst="${dist_dir}/${dest_name}"

		if [[ "$DRY_RUN" == "true" ]]; then
			_dry "cp $src → $dst"
			count=$((count + 1))
			continue
		fi

		mkdir -p "$dist_dir"
		cp "$src" "$dst"
		chmod 755 "$dst"
		_info "$dst"
		log_info "Built: $dst"
		count=$((count + 1))
	done < <(jq -c '.artifacts[]' "$MANIFEST")

	if [[ "$DRY_RUN" == "true" ]]; then
		_info "$count artifact(s) would be built"
	else
		_info "$count artifact(s) built"
		log_info "Build complete: $count artifact(s)"
	fi
}

generate_dist_manifest() {
	_step "Manifest  Write dist/manifest.json"
	local dist_manifest="${DIST_DIR}/manifest.json"
	local ts
	ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

	if [[ "$DRY_RUN" == "true" ]]; then
		_dry "write dist/manifest.json (built_at: $ts)"
		return
	fi

	# Build enriched artifact list: root manifest fields + dist_path + sha256
	local artifacts_json="[]"

	while IFS= read -r artifact; do
		local name path bin_name type status
		name="$(jq -r '.name' <<<"$artifact")"
		path="$(jq -r '.path' <<<"$artifact")"
		bin_name="$(jq -r '.bin_name' <<<"$artifact")"
		type="$(jq -r '.type' <<<"$artifact")"
		status="$(jq -r '.status' <<<"$artifact")"

		[[ "$status" == "deprecated" ]] && continue

		local dest_name
		case "$type" in
		bash | shell) dest_name="$bin_name" ;;
		*) dest_name="$name" ;;
		esac

		local rel
		rel="$(_strip_src_prefix "$path")"
		local dist_path="${rel:+$rel/}${dest_name}"
		local dist_file="${DIST_DIR}/${dist_path}"
		local sha256="missing"
		[[ -f "$dist_file" ]] && sha256="$(_checksum "$dist_file")"

		local entry
		entry="$(jq -n \
			--argjson src "$artifact" \
			--arg dist_path "$dist_path" \
			--arg sha256 "$sha256" \
			'$src + {dist_path: $dist_path, sha256: $sha256}')"

		artifacts_json="$(jq --argjson e "$entry" '. += [$e]' <<<"$artifacts_json")"
	done < <(jq -c '.artifacts[]' "$MANIFEST")

	jq -n \
		--arg generated "$ts" \
		--arg tool "${SCRIPT_NAME} v${SCRIPT_VERSION}" \
		--argjson artifacts "$artifacts_json" \
		'{meta: {generated: $generated, tool: $tool}, artifacts: $artifacts}' \
		>"$dist_manifest"

	local count
	count="$(jq '.artifacts | length' "$dist_manifest")"
	_info "dist/manifest.json written ($count artifact(s), built_at: $ts)"
	log_info "dist/manifest.json generated: $count artifact(s)"
}

# ==============================================================================
# USAGE + MAIN
# ==============================================================================

usage() {
	printf '%b\n' "
${C_BOLD}build.sh${C_RESET} v${SCRIPT_VERSION} — Manifest-driven build

${C_BOLD}USAGE${C_RESET}
  ./scripts/build.sh [options]

${C_BOLD}OPTIONS${C_RESET}
  --clean           Clean dist/ before building
  --dry-run         Show what would be built; write nothing
  --skip-validate   Skip pre-build manifest validation
  --help, -h        This help
"
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		--clean) CLEAN=true ;;
		--dry-run) DRY_RUN=true ;;
		--skip-validate) SKIP_VALIDATE=true ;;
		--help | -h)
			usage
			exit 0
			;;
		*) _fatal "Unknown option: $1" ;;
		esac
		shift
	done
}

main() {
	parse_args "$@"
	printf '\n%s\n' "${C_BOLD}build.sh v${SCRIPT_VERSION}${C_RESET}"
	printf '  Project : %s\n' "$PROJECT_ROOT"
	printf '  Manifest: %s\n' "$MANIFEST"
	[[ "$DRY_RUN" == "true" ]] && printf '  Mode    : %s\n' "${C_YELLOW}DRY RUN${C_RESET}"

	check_prerequisites
	[[ "$CLEAN" == "true" ]] && clean_dist
	[[ "$SKIP_VALIDATE" != "true" ]] && run_precheck
	build_artifacts
	[[ "$DRY_RUN" != "true" ]] && generate_dist_manifest

	printf '\n'
	if [[ "$DRY_RUN" == "true" ]]; then
		printf '  %s\n\n' "${C_YELLOW}Dry run — no files written${C_RESET}"
		exit 2
	fi
	printf '  %s\n\n' "${C_GREEN}Build complete → dist/${C_RESET}"
	log_info "=== ${SCRIPT_NAME} finished ==="
}

main "$@"
