#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"
ENV_FILE="${REPO_ROOT}/infra/.env"
MANIFEST_PATH="${TF_DIR}/snapshot-manifest.json"
INVENTORY_PATH="${TF_DIR}/inventory.yml"
HEALTH_SCRIPT="${REPO_ROOT}/infra/scripts/demo-cloud-health.sh"
POST_RESTORE_PLAYBOOK="${REPO_ROOT}/demo/playbooks/post-restore.yml"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

SET_LABEL=""
RESTORE_SET=""
SSH_PUBLIC_KEY=""
SSH_PRIVATE_KEY=""
SSH_KEY_NAME=""
NETWORK_ID=""
COST_PER_HOUR_EUR="0.0296"
PARTIAL_RESTORE=1

info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--set SET_LABEL]

Options:
  --set SET_LABEL   Restore a specific snapshot set label
  --help            Show this help
USAGE
}

cleanup_notice() {
  if [[ "${PARTIAL_RESTORE}" -eq 1 ]]; then
    warn "Partial restore may exist. Use 'make demo-cool -- ARGS=--no-snapshot' or run ./infra/scripts/demo-cloud-cool.sh --no-snapshot for cleanup."
  fi
}
# shellcheck disable=SC2154  # rc is assigned inside trap string via $?
trap 'rc=$?; if [[ $rc -ne 0 ]]; then cleanup_notice; fi' EXIT

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

resolve_private_key() {
  local key="$1"
  if [[ "${key}" == *.pub ]]; then
    printf '%s\n' "${key%.pub}"
  else
    printf '%s\n' "${key}"
  fi
}

load_snapshot_set() {
  if [[ ! -f "${MANIFEST_PATH}" ]]; then
    error "No snapshot manifest found at ${MANIFEST_PATH}. Run 'make demo-snapshot' first."
    exit 3
  fi

  if [[ -n "${SET_LABEL}" ]]; then
    if ! jq -e --arg set "${SET_LABEL}" '.sets[$set] != null' "${MANIFEST_PATH}" >/dev/null; then
      error "Snapshot set not found in manifest: ${SET_LABEL}"
      exit 3
    fi
    RESTORE_SET="${SET_LABEL}"
  else
    RESTORE_SET="$(jq -r '
      .sets
      | to_entries
      | sort_by(.value.created_at)
      | reverse
      | .[0].key // empty
    ' "${MANIFEST_PATH}")"
    if [[ -z "${RESTORE_SET}" ]]; then
      error "No snapshot sets found. Run 'make demo-snapshot' first."
      exit 3
    fi
  fi

  if ! jq -e --arg set "${RESTORE_SET}" '
    .sets[$set] != null
    and (.sets[$set].snapshots | length == 4)
  ' "${MANIFEST_PATH}" >/dev/null; then
    error "Snapshot set ${RESTORE_SET} is invalid (must contain 4 snapshots)."
    exit 3
  fi

  info "Using snapshot set: ${RESTORE_SET}"
}

check_network_conflict() {
  local conflict_count
  conflict_count="$(hcloud network list -o json 2>/dev/null | jq '
    [
      .[]
      | select(
          .ip_range == "10.0.0.0/8"
          or ((.subnets // []) | map(.ip_range) | index("10.0.0.0/24") != null)
        )
    ] | length
  ' 2>/dev/null)" || conflict_count="0"
  if [[ "${conflict_count}" -gt 0 ]]; then
    error "Detected existing Hetzner network/subnet using 10.0.0.0/8 or 10.0.0.0/24. Resolve conflict before warm-start."
    exit 1
  fi
}

create_ssh_key() {
  local created_at
  created_at="$(date -u +%Y%m%dT%H%M%SZ)"
  SSH_KEY_NAME="rcd-demo-key-$(date +%s)"

  if ! hcloud ssh-key create \
    --name "${SSH_KEY_NAME}" \
    --public-key-from-file "${SSH_PUBLIC_KEY}" \
    --label "cluster=rcd-demo" \
    --label "created_at=${created_at}" >/dev/null 2>&1; then
    error "Failed to create SSH key in Hetzner."
    exit 1
  fi
}

create_network() {
  local created_at ttl_hours network_name
  created_at="$(date -u +%Y%m%dT%H%M%SZ)"
  ttl_hours="${TF_VAR_ttl_hours:-4}"
  network_name="rcd-demo-network-$(date +%s)"

  if ! hcloud network create \
    --name "${network_name}" \
    --ip-range "10.0.0.0/8" \
    --label "cluster=rcd-demo" \
    --label "snapshot-set=${RESTORE_SET}" \
    --label "created_at=${created_at}" \
    --label "ttl=${ttl_hours}h" \
    --label "managed_by=warm-restore" >/dev/null 2>&1; then
    error "Failed to create Hetzner network."
    exit 1
  fi

  NETWORK_ID="$(hcloud network list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq -r '.[0].id // empty')"
  if [[ -z "${NETWORK_ID}" ]]; then
    error "Could not find network ID after creation."
    exit 1
  fi

  hcloud network add-subnet "${NETWORK_ID}" --network-zone "us-west" --type "cloud" --ip-range "10.0.0.0/24" >/dev/null
}

create_servers_from_snapshots() {
  local location ttl_hours created_at
  location="${TF_VAR_location:-hil}"
  ttl_hours="${TF_VAR_ttl_hours:-4}"
  created_at="$(date -u +%Y%m%dT%H%M%SZ)"

  while IFS=$'\t' read -r snapshot_id node_name node_role server_type private_ip; do
    local server_id

    info "Restoring ${node_name} from snapshot ${snapshot_id}..."

    if ! hcloud server create \
      --name "${node_name}" \
      --type "${server_type}" \
      --image "${snapshot_id}" \
      --ssh-key "${SSH_KEY_NAME}" \
      --location "${location}" \
      --label "cluster=rcd-demo" \
      --label "snapshot-set=${RESTORE_SET}" \
      --label "node_role=${node_role}" \
      --label "private_ip=${private_ip}" \
      --label "created_at=${created_at}" \
      --label "ttl=${ttl_hours}h" \
      --label "managed_by=warm-restore" >/dev/null 2>&1; then
      error "Failed to create server ${node_name}."
      exit 1
    fi

    server_id="$(hcloud server list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq -r --arg name "${node_name}" '.[] | select(.name == $name) | .id' 2>/dev/null)"
    if [[ -z "${server_id}" ]]; then
      error "Could not find server ID for ${node_name} after creation."
      exit 1
    fi

    hcloud server attach-to-network "${server_id}" --network "${NETWORK_ID}" --ip "${private_ip}" >/dev/null
  done < <(
    jq -r --arg set "${RESTORE_SET}" '
      .sets[$set].snapshots
      | sort_by(.node_name)
      | .[]
      | [
          (.snapshot_id|tostring),
          .node_name,
          .node_role,
          .server_type,
          .private_ip
        ]
      | @tsv
    ' "${MANIFEST_PATH}"
  )
}

wait_for_ssh() {
  local timeout_s=300
  local start
  local remaining=0

  start="$(date +%s)"

  while true; do
    local all_up=1
    remaining=0

    while IFS=$'\t' read -r node_name public_ip; do
      [[ -n "${public_ip}" ]] || continue
      if ssh -n \
        -i "${SSH_PRIVATE_KEY}" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=5 \
        -o BatchMode=yes \
        "root@${public_ip}" \
        "true" >/dev/null 2>&1; then
        :
      else
        all_up=0
        remaining=$((remaining + 1))
      fi
    done < <(hcloud server list --selector "cluster=rcd-demo" -o json | jq -r 'sort_by(.name)[] | [.name, (.public_net.ipv4.ip // .public_net.ipv4 // .ipv4_address // "")] | @tsv')

    if [[ "${all_up}" -eq 1 ]]; then
      return 0
    fi

    if (( $(date +%s) - start >= timeout_s )); then
      error "Timed out waiting for SSH readiness."
      return 1
    fi

    info "Waiting for SSH on ${remaining} node(s)..."
    sleep 5
  done
}

generate_inventory() {
  local key_path
  local server_json

  key_path="${SSH_PRIVATE_KEY}"
  if [[ "${key_path}" == "${REPO_ROOT}"/* ]]; then
    :
  elif [[ -d /workspace && -f /workspace/infra/.ssh/demo_ed25519 ]]; then
    key_path="/workspace/infra/.ssh/demo_ed25519"
  fi

  server_json="$(hcloud server list --selector "cluster=rcd-demo" -o json)"

  cat > "${INVENTORY_PATH}" <<YAML
all:
  vars:
    ansible_ssh_private_key_file: ${key_path}
  children:
    mgmt:
      hosts:
        mgmt01:
          ansible_host: $(printf '%s\n' "${server_json}" | jq -r '.[] | select(.name=="mgmt01") | (.public_net.ipv4.ip // .public_net.ipv4 // .ipv4_address // "")')
          ansible_user: root
          private_ip: $(printf '%s\n' "${server_json}" | jq -r '.[] | select(.name=="mgmt01") | (.labels.private_ip // (.private_net[0].ip // "10.0.0.10"))')
          node_role: mgmt
          zone: management
    login:
      hosts:
        login01:
          ansible_host: $(printf '%s\n' "${server_json}" | jq -r '.[] | select(.name=="login01") | (.public_net.ipv4.ip // .public_net.ipv4 // .ipv4_address // "")')
          ansible_user: root
          private_ip: $(printf '%s\n' "${server_json}" | jq -r '.[] | select(.name=="login01") | (.labels.private_ip // (.private_net[0].ip // "10.0.0.20"))')
          node_role: login
          zone: internal
    compute:
      hosts:
        compute01:
          ansible_host: $(printf '%s\n' "${server_json}" | jq -r '.[] | select(.name=="compute01") | (.public_net.ipv4.ip // .public_net.ipv4 // .ipv4_address // "")')
          ansible_user: root
          private_ip: $(printf '%s\n' "${server_json}" | jq -r '.[] | select(.name=="compute01") | (.labels.private_ip // (.private_net[0].ip // "10.0.0.31"))')
          node_role: compute
          zone: restricted
        compute02:
          ansible_host: $(printf '%s\n' "${server_json}" | jq -r '.[] | select(.name=="compute02") | (.public_net.ipv4.ip // .public_net.ipv4 // .ipv4_address // "")')
          ansible_user: root
          private_ip: $(printf '%s\n' "${server_json}" | jq -r '.[] | select(.name=="compute02") | (.labels.private_ip // (.private_net[0].ip // "10.0.0.32"))')
          node_role: compute
          zone: restricted
YAML
}

run_post_restore() {
  info "Running post-restore playbook..."
  (
    cd "${REPO_ROOT}/demo/vagrant"
    ANSIBLE_CONFIG="${REPO_ROOT}/demo/vagrant/ansible.cfg" \
    ANSIBLE_HOST_KEY_CHECKING=False \
    ansible-playbook -i "${INVENTORY_PATH}" "${POST_RESTORE_PLAYBOOK}"
  )
}

run_health_check() {
  info "Running post-restore health check..."
  if ! "${HEALTH_SCRIPT}" --inventory "${INVENTORY_PATH}"; then
    error "Post-restore health check failed after remediation."
    exit 2
  fi
}

print_summary() {
  local mgmt_ip login_ip
  mgmt_ip="$(hcloud server list --selector "cluster=rcd-demo" -o json | jq -r '.[] | select(.name=="mgmt01") | (.public_net.ipv4.ip // .public_net.ipv4 // .ipv4_address // "")')"
  login_ip="$(hcloud server list --selector "cluster=rcd-demo" -o json | jq -r '.[] | select(.name=="login01") | (.public_net.ipv4.ip // .public_net.ipv4 // .ipv4_address // "")')"

  printf '\nWarm restore complete.\n'
  printf 'Snapshot set: %s\n' "${RESTORE_SET}"
  printf 'Estimated compute cost: EUR %s/hour\n' "${COST_PER_HOUR_EUR}"
  printf 'Inventory: %s\n' "${INVENTORY_PATH}"
  printf 'SSH access:\n'
  printf '  ssh root@%s\n' "${mgmt_ip}"
  printf '  ssh root@%s\n' "${login_ip}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --set)
        if [[ $# -lt 2 ]]; then
          error "--set requires a snapshot set label"
          exit 2
        fi
        SET_LABEL="$2"
        shift 2
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
  require_command ansible-playbook
  require_command terraform

  if cluster_exists; then
    error "Existing cluster resources detected. Tear down first before warm-starting."
    error "Run: make demo-cloud-down or ./infra/scripts/demo-cloud-cool.sh --no-snapshot"
    exit 3
  fi

  load_snapshot_set
  check_network_conflict

  SSH_PUBLIC_KEY="$(detect_ssh_key)"
  SSH_PRIVATE_KEY="$(resolve_private_key "${SSH_PUBLIC_KEY}")"
  if [[ ! -f "${SSH_PRIVATE_KEY}" ]]; then
    error "SSH private key not found: ${SSH_PRIVATE_KEY}"
    exit 3
  fi

  create_ssh_key
  create_network
  create_servers_from_snapshots

  info "Waiting for restored nodes to accept SSH..."
  wait_for_ssh

  generate_inventory
  run_post_restore
  run_health_check

  print_summary
  PARTIAL_RESTORE=0
}

main "$@"
