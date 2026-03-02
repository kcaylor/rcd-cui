#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"
ENV_FILE="${REPO_ROOT}/infra/.env"
SNAPSHOT_SCRIPT="${REPO_ROOT}/infra/scripts/demo-cloud-snapshot.sh"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

NO_SNAPSHOT=0
COST_PER_HOUR_EUR="0.0296"

info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--no-snapshot]

Options:
  --no-snapshot   Skip pre-teardown snapshot prompt
  --help          Show this help
USAGE
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    error "Required command not found: ${cmd}"
    exit 3
  fi
}

cluster_exists() {
  local api_count="0"
  local state_count="0"

  api_count="$(hcloud server list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq 'length' 2>/dev/null)" || api_count="0"
  state_count="$(terraform -chdir="${TF_DIR}" state list 2>/dev/null | wc -l | tr -d ' ')" || state_count="0"

  [[ "${api_count}" -gt 0 || "${state_count}" -gt 0 ]]
}

detect_ssh_key() {
  local key_path="${TF_VAR_ssh_key_path:-}"

  if [[ -n "${key_path}" && -f "${key_path}" ]]; then
    printf '%s\n' "${key_path}"
    return 0
  fi
  if [[ -n "${DEMO_SSH_KEY:-}" && -f "${DEMO_SSH_KEY}" ]]; then
    printf '%s\n' "${DEMO_SSH_KEY}"
    return 0
  fi
  if [[ -f "${REPO_ROOT}/infra/.ssh/demo_ed25519.pub" ]]; then
    printf '%s\n' "${REPO_ROOT}/infra/.ssh/demo_ed25519.pub"
    return 0
  fi
  if [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    printf '%s\n' "${HOME}/.ssh/id_ed25519.pub"
    return 0
  fi
  if [[ -f "${HOME}/.ssh/id_rsa.pub" ]]; then
    printf '%s\n' "${HOME}/.ssh/id_rsa.pub"
    return 0
  fi

  error "No SSH public key found."
  exit 3
}

cluster_servers_json() {
  hcloud server list --selector "cluster=rcd-demo" -o json
}

cluster_networks_json() {
  hcloud network list --selector "cluster=rcd-demo" -o json
}

cluster_keys_json() {
  hcloud ssh-key list --selector "cluster=rcd-demo" -o json
}

to_epoch() {
  local value="$1"
  python3 - "${value}" <<'PY'
from datetime import datetime
import sys

value = sys.argv[1].strip()
if not value:
    print(0)
    raise SystemExit(0)
try:
    if value.isdigit():
        print(int(value))
    else:
        dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
        print(int(dt.timestamp()))
except Exception:
    print(0)
PY
}

format_duration() {
  local seconds="$1"
  local h m
  h=$((seconds / 3600))
  m=$(((seconds % 3600) / 60))
  if (( h > 0 )); then
    printf '%sh %sm' "${h}" "${m}"
  else
    printf '%sm' "${m}"
  fi
}

estimate_cost() {
  local seconds="$1"
  awk -v secs="${seconds}" -v rate="${COST_PER_HOUR_EUR}" 'BEGIN { printf "%.2f", (secs/3600) * rate }'
}

session_seconds() {
  local servers_json="$1"
  local created
  local now
  local epoch

  created="$(printf '%s\n' "${servers_json}" | jq -r 'map(.labels.created_at // .created // "") | map(select(length > 0)) | sort | .[0] // ""')"
  if [[ -z "${created}" ]]; then
    printf '0\n'
    return 0
  fi

  epoch="$(to_epoch "${created}")"
  now="$(date +%s)"

  if [[ "${epoch}" -eq 0 ]]; then
    printf '0\n'
    return 0
  fi

  if (( now < epoch )); then
    printf '0\n'
    return 0
  fi

  printf '%s\n' "$((now - epoch))"
}

show_resource_summary() {
  local servers_json="$1"
  local networks_json="$2"
  local keys_json="$3"
  local server_count network_count key_count

  server_count="$(printf '%s\n' "${servers_json}" | jq 'length')"
  network_count="$(printf '%s\n' "${networks_json}" | jq 'length')"
  key_count="$(printf '%s\n' "${keys_json}" | jq 'length')"

  printf 'Resources to destroy:\n'
  printf '  - %s servers\n' "${server_count}"
  printf '  - %s networks\n' "${network_count}"
  printf '  - %s SSH keys\n' "${key_count}"
}

confirm_or_exit() {
  local prompt="$1"
  local reply
  printf '%s' "${prompt}"
  read -r reply
  case "${reply}" in
    y|Y|yes|YES) return 0 ;;
    *)
      printf 'Cancelled.\n'
      exit 0
      ;;
  esac
}

delete_resources() {
  local servers_json="$1"
  local networks_json="$2"
  local keys_json="$3"

  while IFS= read -r sid; do
    [[ -n "${sid}" ]] || continue
    info "Deleting server ${sid}..."
    hcloud server delete "${sid}" >/dev/null || true
  done < <(printf '%s\n' "${servers_json}" | jq -r '.[].id')

  while IFS= read -r nid; do
    [[ -n "${nid}" ]] || continue
    info "Deleting network ${nid}..."
    hcloud network delete "${nid}" >/dev/null || true
  done < <(printf '%s\n' "${networks_json}" | jq -r '.[].id')

  while IFS= read -r kid; do
    [[ -n "${kid}" ]] || continue
    info "Deleting SSH key ${kid}..."
    hcloud ssh-key delete "${kid}" >/dev/null || true
  done < <(printf '%s\n' "${keys_json}" | jq -r '.[].id')
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-snapshot)
        NO_SNAPSHOT=1
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        error "Unknown argument: $1"
        usage >&2
        exit 2
        ;;
    esac
  done
}

main() {
  parse_args "$@"

  require_command hcloud
  require_command jq
  require_command ssh
  require_command terraform
  require_command python3

  if ! cluster_exists; then
    error "No running cluster found."
    exit 3
  fi

  local servers_json networks_json keys_json elapsed cost
  servers_json="$(cluster_servers_json)"
  networks_json="$(cluster_networks_json)"
  keys_json="$(cluster_keys_json)"

  elapsed="$(session_seconds "${servers_json}")"
  cost="$(estimate_cost "${elapsed}")"

  printf 'Session duration: %s\n' "$(format_duration "${elapsed}")"
  printf 'Estimated session cost: EUR %s\n\n' "${cost}"

  show_resource_summary "${servers_json}" "${networks_json}" "${keys_json}"

  if [[ "${NO_SNAPSHOT}" -eq 0 ]]; then
    confirm_or_exit $'\nSnapshot current state before teardown? [y/N] '
    if [[ -x "${SNAPSHOT_SCRIPT}" ]]; then
      "${SNAPSHOT_SCRIPT}"
    else
      error "Snapshot script is not executable: ${SNAPSHOT_SCRIPT}"
      exit 1
    fi
  fi

  confirm_or_exit $'\nDestroy all listed resources now? [y/N] '

  delete_resources "${servers_json}" "${networks_json}" "${keys_json}"

  printf '\nSession wind-down complete.\n'
  printf 'Cluster runtime: %s\n' "$(format_duration "${elapsed}")"
  printf 'Estimated total cost: EUR %s\n' "${cost}"
}

main "$@"
