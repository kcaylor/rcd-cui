#!/usr/bin/env bash
# Shared helper library for demo scripts (bake, refresh, setup).
# Source this file; do not execute directly.
#
# Depends on: jq

# ---------- Guard against direct execution ----------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "ERROR: lib-demo-common.sh must be sourced, not executed" >&2
  exit 1
fi

# ---------- Colour codes ----------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ---------- Logging ----------
log_info()    { printf "%b[INFO]%b %s\n"  "${BLUE}"   "${NC}" "$*"; }
log_warn()    { printf "%b[WARN]%b %s\n"  "${YELLOW}" "${NC}" "$*"; }
log_success() { printf "%b[OK]%b %s\n"    "${GREEN}"  "${NC}" "$*"; }
log_error()   { printf "%b[ERROR]%b %s\n" "${RED}"    "${NC}" "$*" >&2; }

# ---------- Provider detection ----------
# Sets/returns the detected Vagrant provider string.
# Respects DEMO_PROVIDER if already set by the caller.
detect_provider() {
  local os arch plugins
  os="$(uname -s)"
  arch="$(uname -m)"
  plugins="$(vagrant plugin list 2>/dev/null || true)"

  if [[ -n "${DEMO_PROVIDER:-}" ]]; then
    echo "${DEMO_PROVIDER}"
    return
  fi

  if [[ "${os}" == "Darwin" && "${arch}" == "arm64" ]] && grep -qi "qemu" <<<"${plugins}"; then
    echo "qemu"
    return
  fi

  if [[ "${os}" == "Linux" ]] && grep -qi "libvirt" <<<"${plugins}"; then
    echo "libvirt"
    return
  fi

  if command -v VBoxManage >/dev/null 2>&1; then
    echo "virtualbox"
    return
  fi

  if grep -qi "libvirt" <<<"${plugins}"; then
    echo "libvirt"
    return
  fi

  if grep -qi "qemu" <<<"${plugins}"; then
    echo "qemu"
    return
  fi

  echo "virtualbox"
}

# ---------- Paths ----------
# All paths are relative to the repository root.
# Callers should set REPO_ROOT before sourcing this library.
_lib_repo_root() {
  echo "${REPO_ROOT:?REPO_ROOT must be set before sourcing lib-demo-common.sh}"
}

_lib_boxes_dir() {
  echo "$(_lib_repo_root)/demo/vagrant/boxes"
}

_lib_manifest_path() {
  echo "$(_lib_boxes_dir)/manifest.json"
}

# ---------- Manifest helpers ----------
# All manifest operations use jq for JSON manipulation.

# Ensure jq is available.
_require_jq() {
  command -v jq >/dev/null 2>&1 || {
    log_error "jq is required but not installed"
    return 1
  }
}

# Create an empty manifest if none exists.
init_manifest() {
  _require_jq || return 1
  local manifest
  manifest="$(_lib_manifest_path)"
  if [[ ! -f "${manifest}" ]]; then
    mkdir -p "$(dirname "${manifest}")"
    cat > "${manifest}" << 'JSON'
{
  "version": 1,
  "staleness_days": 7,
  "sets": {}
}
JSON
    log_info "Initialized empty manifest at ${manifest}"
  fi
}

# Read the full manifest JSON to stdout.
read_manifest() {
  _require_jq || return 1
  local manifest
  manifest="$(_lib_manifest_path)"
  if [[ ! -f "${manifest}" ]]; then
    init_manifest
  fi
  cat "${manifest}"
}

# Write a complete manifest JSON from stdin.
write_manifest() {
  _require_jq || return 1
  local manifest tmp
  manifest="$(_lib_manifest_path)"
  tmp="${manifest}.tmp.$$"
  # Validate JSON before writing
  if jq '.' > "${tmp}"; then
    mv "${tmp}" "${manifest}"
  else
    rm -f "${tmp}"
    log_error "Invalid JSON; manifest not updated"
    return 1
  fi
}

# Return the label of the box set with status "current", or empty string.
get_current_set() {
  _require_jq || return 1
  read_manifest | jq -r '.sets | to_entries[] | select(.value.status == "current") | .key // empty'
}

# Return the label of the box set with status "previous", or empty string.
get_previous_set() {
  _require_jq || return 1
  read_manifest | jq -r '.sets | to_entries[] | select(.value.status == "previous") | .key // empty'
}

# Generate a set label: rcd-demo-YYYYMMDD-NN
# NN is auto-incremented for the given date.
generate_set_label() {
  _require_jq || return 1
  local today prefix n existing_labels next
  today="$(date +%Y%m%d)"
  prefix="rcd-demo-${today}"
  existing_labels="$(read_manifest | jq -r ".sets | keys[]" 2>/dev/null || true)"
  n=0
  while IFS= read -r label; do
    if [[ "${label}" == "${prefix}"-* ]]; then
      local suffix="${label##*-}"
      if (( 10#${suffix} > n )); then
        n="$((10#${suffix}))"
      fi
    fi
  done <<< "${existing_labels}"
  next=$(( n + 1 ))
  printf "%s-%02d" "${prefix}" "${next}"
}

# Check whether the current box set is stale.
# Returns 0 if stale (or no current set), 1 if fresh.
# Prints a warning message when stale.
check_staleness() {
  _require_jq || return 1
  local manifest current_label created_at staleness_days now_epoch created_epoch age_days
  manifest="$(read_manifest)"
  current_label="$(echo "${manifest}" | jq -r '.sets | to_entries[] | select(.value.status == "current") | .key // empty')"

  if [[ -z "${current_label}" ]]; then
    return 0  # no current set counts as stale
  fi

  staleness_days="$(echo "${manifest}" | jq -r '.staleness_days // 7')"
  staleness_days="${DEMO_STALE_DAYS:-${staleness_days}}"
  created_at="$(echo "${manifest}" | jq -r ".sets[\"${current_label}\"].created_at")"

  # Parse ISO 8601 date to epoch (portable across macOS and Linux)
  if date --version >/dev/null 2>&1; then
    # GNU date
    created_epoch="$(date -d "${created_at}" +%s 2>/dev/null || echo 0)"
  else
    # macOS/BSD date
    created_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${created_at}" +%s 2>/dev/null || \
                     date -j -f "%Y-%m-%dT%H:%M:%S%z" "${created_at}" +%s 2>/dev/null || echo 0)"
  fi

  now_epoch="$(date +%s)"
  age_days="$(( (now_epoch - created_epoch) / 86400 ))"

  if (( age_days > staleness_days )); then
    log_warn "Baked box set '${current_label}' is ${age_days} days old (threshold: ${staleness_days} days)"
    return 0  # stale
  fi

  return 1  # fresh
}

# Return box info for the current set as JSON.
# Useful for display and validation.
get_set_info() {
  _require_jq || return 1
  local label="${1:?Usage: get_set_info <label>}"
  read_manifest | jq --arg label "${label}" '.sets[$label] // empty'
}

# Return the number of box sets in the manifest.
count_sets() {
  _require_jq || return 1
  read_manifest | jq '.sets | length'
}

# Human-readable file size.
human_size() {
  local bytes="${1:?Usage: human_size <bytes>}"
  if (( bytes >= 1073741824 )); then
    printf "%.1f GB" "$(echo "scale=1; ${bytes}/1073741824" | bc)"
  elif (( bytes >= 1048576 )); then
    printf "%.1f MB" "$(echo "scale=1; ${bytes}/1048576" | bc)"
  else
    printf "%d KB" "$(( bytes / 1024 ))"
  fi
}
