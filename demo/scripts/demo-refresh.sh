#!/usr/bin/env bash
# demo-refresh.sh — Destroy, reprovision, and re-bake demo cluster.
#
# Performs a full destroy → provision → bake cycle to create fresh
# baked boxes from the current codebase. Previous boxes are preserved
# as a safety net until the new bake succeeds.
#
# Usage:
#   demo-refresh.sh           # Full refresh cycle
#   demo-refresh.sh --help    # Show usage
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export REPO_ROOT

VAGRANT_CWD="${VAGRANT_CWD:-${REPO_ROOT}/demo/vagrant}"

# shellcheck source=lib-demo-common.sh
source "${SCRIPT_DIR}/lib-demo-common.sh"

usage() {
  cat << 'USAGE'
Usage: demo-refresh.sh [OPTIONS]

Destroys existing VMs, provisions from scratch, and bakes new boxes.
Previous baked boxes are preserved until the new bake succeeds.

Options:
  --help    Show this help message

Environment:
  DEMO_PROVIDER    Override provider detection (virtualbox|libvirt|qemu)
USAGE
}

main() {
  if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
  fi

  log_info "=== Demo Refresh: destroy → provision → bake ==="

  # Step 1: Destroy existing VMs
  log_info "Destroying existing VMs"
  (cd "${VAGRANT_CWD}" && vagrant destroy -f) || {
    log_warn "vagrant destroy reported errors (may be expected if no VMs exist)"
  }

  # Step 2: Fresh provision (force skip baked boxes)
  log_info "Provisioning from scratch (DEMO_USE_BAKED=0)"
  if ! DEMO_USE_BAKED=0 "${SCRIPT_DIR}/demo-setup.sh"; then
    log_error "Fresh provisioning failed"
    log_error "Previous baked boxes (if any) have been preserved"
    exit 1
  fi

  # Step 3: Bake the freshly provisioned cluster
  log_info "Baking new box set from fresh provision"
  if ! "${SCRIPT_DIR}/demo-bake.sh"; then
    log_error "Baking failed after successful provision"
    log_error "Previous baked boxes (if any) have been preserved"
    exit 1
  fi

  log_success "=== Demo Refresh complete ==="
  "${SCRIPT_DIR}/demo-bake.sh" --list
}

main "$@"
