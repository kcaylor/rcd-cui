#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"
TTL_CHECK_SCRIPT="${REPO_ROOT}/infra/scripts/check-ttl.sh"

COST_PER_HOUR_EUR="0.0296"

info() {
  printf '==> %s\n' "$*"
}

error() {
  printf 'ERROR: %s\n' "$*" >&2
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    error "Required command not found: ${cmd}"
    exit 3
  fi
}

cluster_exists() {
  local resources
  resources="$(terraform -chdir="${TF_DIR}" state list 2>/dev/null || true)"
  [[ -n "${resources}" ]]
}

read_cluster_created_at() {
  terraform -chdir="${TF_DIR}" output -raw cluster_created_at 2>/dev/null || true
}

cluster_elapsed_seconds() {
  local created_at="$1"

  if [[ -z "${created_at}" ]]; then
    printf '0\n'
    return 0
  fi

  python3 - "${created_at}" <<'PY'
from datetime import datetime
import time
import sys

value = sys.argv[1]
try:
    dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    elapsed = int(time.time() - dt.timestamp())
    print(max(elapsed, 0))
except Exception:
    print(0)
PY
}

estimate_cost() {
  local seconds="$1"
  awk -v secs="${seconds}" -v rate="${COST_PER_HOUR_EUR}" 'BEGIN { printf "%.2f", (secs / 3600) * rate }'
}

format_duration() {
  local seconds="$1"
  local hours
  local minutes

  hours=$((seconds / 3600))
  minutes=$(((seconds % 3600) / 60))

  if (( hours > 0 )); then
    printf '%sh %sm' "${hours}" "${minutes}"
    return 0
  fi

  printf '%sm' "${minutes}"
}

show_resource_summary() {
  local resources="$1"
  local server_count
  local network_count
  local ssh_key_count

  server_count="$(printf '%s\n' "${resources}" | awk '/^hcloud_server\./ {c++} END {print c+0}')"
  network_count="$(printf '%s\n' "${resources}" | awk '/^hcloud_network\./ {c++} END {print c+0}')"
  ssh_key_count="$(printf '%s\n' "${resources}" | awk '/^hcloud_ssh_key\./ {c++} END {print c+0}')"

  printf 'Resources to destroy:\n'
  printf '  - %s servers\n' "${server_count}"
  printf '  - %s networks\n' "${network_count}"
  printf '  - %s SSH keys\n' "${ssh_key_count}"
}

confirm_destroy() {
  local reply

  printf '\nThis action cannot be undone. Continue? [y/N] '
  read -r reply

  case "${reply}" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      printf 'Teardown cancelled.\n'
      return 1
      ;;
  esac
}

main() {
  local resources
  local created_at
  local cluster_seconds
  local cluster_cost
  local start_epoch
  local end_epoch
  local destroy_elapsed

  require_command terraform
  require_command python3

  info "Initializing Terraform..."
  terraform -chdir="${TF_DIR}" init -input=false >/dev/null

  resources="$(terraform -chdir="${TF_DIR}" state list 2>/dev/null || true)"
  if [[ -z "${resources}" ]]; then
    printf 'No cloud demo cluster is currently tracked in Terraform state.\n'
    exit 0
  fi

  if [[ -x "${TTL_CHECK_SCRIPT}" ]]; then
    "${TTL_CHECK_SCRIPT}" --warn || true
  fi

  created_at="$(read_cluster_created_at)"
  cluster_seconds="$(cluster_elapsed_seconds "${created_at}")"
  cluster_cost="$(estimate_cost "${cluster_seconds}")"

  printf 'Preparing to destroy cloud demo cluster...\n\n'
  show_resource_summary "${resources}"

  if ! confirm_destroy; then
    exit 0
  fi

  start_epoch="$(date +%s)"

  info "Destroying Terraform-managed resources..."
  if ! terraform -chdir="${TF_DIR}" destroy -auto-approve; then
    error "Terraform destroy failed."
    exit 1
  fi

  end_epoch="$(date +%s)"
  destroy_elapsed="$((end_epoch - start_epoch))"

  printf '\nAll resources destroyed.\n'
  printf 'Teardown time: %ss\n' "${destroy_elapsed}"
  printf 'Billing stopped. Cluster runtime: %s (estimated cost: EUR %s)\n' "$(format_duration "${cluster_seconds}")" "${cluster_cost}"
}

main "$@"
