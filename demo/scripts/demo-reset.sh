#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

VAGRANT_CWD="${VAGRANT_CWD:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../vagrant" && pwd)}"
BASELINE_SNAPSHOT_NAME="${BASELINE_SNAPSHOT_NAME:-baseline}"
DEMO_PROVIDER="${DEMO_PROVIDER:-}"

log_info() {
  printf "%b[INFO]%b %s\n" "${BLUE}" "${NC}" "$*"
}

log_warn() {
  printf "%b[WARN]%b %s\n" "${YELLOW}" "${NC}" "$*"
}

log_error() {
  printf "%b[ERROR]%b %s\n" "${RED}" "${NC}" "$*" >&2
}

log_success() {
  printf "%b[OK]%b %s\n" "${GREEN}" "${NC}" "$*"
}

detect_provider() {
  if [[ -n "${DEMO_PROVIDER}" ]]; then
    echo "${DEMO_PROVIDER}"
    return
  fi
  local os arch plugins
  os="$(uname -s)"
  arch="$(uname -m)"
  plugins="$(vagrant plugin list 2>/dev/null || true)"

  if [[ "${os}" == "Darwin" && "${arch}" == "arm64" ]] && grep -qi "qemu" <<<"${plugins}"; then
    echo "qemu"
  elif [[ "${os}" == "Linux" ]] && grep -qi "libvirt" <<<"${plugins}"; then
    echo "libvirt"
  elif command -v VBoxManage >/dev/null 2>&1; then
    echo "virtualbox"
  else
    echo "virtualbox"
  fi
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    log_error "Missing required command: $1"
    exit 1
  }
}

verify_running() {
  local not_running
  not_running="$(cd "${VAGRANT_CWD}" && vagrant status --machine-readable | awk -F, '$3=="state" && $4!="running" {print $2}' | sort -u || true)"
  if [[ -n "${not_running}" ]]; then
    log_error "Reset incomplete; non-running VMs: ${not_running//$'\n'/, }"
    return 1
  fi
}

verify_clean_state() {
  if ! (cd "${VAGRANT_CWD}" && vagrant ssh mgmt01 -c "test ! -d /shared/projects/helios"); then
    log_warn "Project Helios artifacts still present after reset"
    return 1
  fi

  return 0
}

main() {
  local start_ts end_ts elapsed
  start_ts="$(date +%s)"

  require_cmd vagrant
  DEMO_PROVIDER="$(detect_provider)"
  log_info "Selected provider: ${DEMO_PROVIDER}"

  log_info "Restoring baseline snapshot '${BASELINE_SNAPSHOT_NAME}'"
  (cd "${VAGRANT_CWD}" && vagrant snapshot pop "${BASELINE_SNAPSHOT_NAME}")

  log_info "Refreshing baseline snapshot '${BASELINE_SNAPSHOT_NAME}'"
  (cd "${VAGRANT_CWD}" && vagrant snapshot push "${BASELINE_SNAPSHOT_NAME}" --no-provision)

  log_info "Verifying reset status"
  verify_running
  verify_clean_state

  end_ts="$(date +%s)"
  elapsed="$((end_ts - start_ts))"

  log_success "Lab reset complete in ${elapsed}s"
}

main "$@"
