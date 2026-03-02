#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"
ENV_FILE="${REPO_ROOT}/infra/.env"
DEFAULT_INVENTORY="${TF_DIR}/inventory.yml"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

RESULTS_FILE="$(mktemp)"
trap 'rm -f "${RESULTS_FILE}"' EXIT

INVENTORY_PATH="${DEFAULT_INVENTORY}"
JSON_OUTPUT=0
SSH_KEY_PATH=""
SSH_UNREACHABLE=0
PASS_COUNT=0
FAIL_COUNT=0

info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--inventory PATH] [--json]

Options:
  --inventory PATH   Inventory file path (default: infra/terraform/inventory.yml)
  --json             Emit JSON instead of table output
  --help             Show this help
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
  local inventory_count="0"

  api_count="$(hcloud server list --selector "cluster=rcd-demo" -o json 2>/dev/null | jq 'length' 2>/dev/null)" || api_count="0"
  state_count="$(terraform -chdir="${TF_DIR}" state list 2>/dev/null | wc -l | tr -d ' ')" || state_count="0"
  inventory_count="$(awk '/^        [a-zA-Z0-9_-]+:$/ {count++} END {print count+0}' "${INVENTORY_PATH}" 2>/dev/null)" || inventory_count="0"

  [[ "${api_count}" -gt 0 || "${state_count}" -gt 0 || "${inventory_count}" -gt 0 ]]
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

resolve_inventory_private_key() {
  local key
  key="$(awk '/^[[:space:]]*ansible_ssh_private_key_file:[[:space:]]*/ {print $2; exit}' "${INVENTORY_PATH}" | tr -d '"' || true)"
  if [[ -n "${key}" ]]; then
    printf '%s\n' "${key}"
    return 0
  fi

  key="$(detect_ssh_key)"
  if [[ "${key}" == *.pub ]]; then
    key="${key%.pub}"
  fi
  printf '%s\n' "${key}"
}

add_result() {
  local node="$1"
  local service="$2"
  local status="$3"
  local remediated="$4"
  local message="$5"

  if [[ "${status}" == "PASS" ]]; then
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    FAIL_COUNT=$((FAIL_COUNT + 1))
  fi

  printf '%s\t%s\t%s\t%s\t%s\n' "${node}" "${service}" "${status}" "${remediated}" "${message}" >> "${RESULTS_FILE}"
}

ssh_cmd() {
  local host="$1"
  local command="$2"

  ssh -n \
    -i "${SSH_KEY_PATH}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=8 \
    -o BatchMode=yes \
    "root@${host}" \
    "${command}"
}

inventory_nodes() {
  awk '
    /^        [a-zA-Z0-9_-]+:$/ {
      if (node != "" && host != "") {
        printf "%s|%s|%s\n", node, host, role
      }
      node=$1
      sub(":", "", node)
      host=""
      role=""
      next
    }
    node != "" && /^          ansible_host:[[:space:]]+/ {
      host=$2
      gsub(/"/, "", host)
      next
    }
    node != "" && /^          node_role:[[:space:]]+/ {
      role=$2
      gsub(/"/, "", role)
      next
    }
    END {
      if (node != "" && host != "") {
        printf "%s|%s|%s\n", node, host, role
      }
    }
  ' "${INVENTORY_PATH}"
}

check_service() {
  local node="$1"
  local host="$2"
  local service="$3"
  local status_out

  status_out="$(ssh_cmd "${host}" "systemctl is-active ${service} 2>/dev/null || true" 2>/dev/null || true)"
  if [[ "${status_out}" == "active" ]]; then
    add_result "${node}" "${service}" "PASS" "0" ""
    return 0
  fi

  status_out="$(ssh_cmd "${host}" "systemctl restart ${service} >/dev/null 2>&1 || true; sleep 5; systemctl is-active ${service} 2>/dev/null || true" 2>/dev/null || true)"
  if [[ "${status_out}" == "active" ]]; then
    add_result "${node}" "${service}" "PASS" "1" "restarted"
    return 0
  fi

  add_result "${node}" "${service}" "FAIL" "0" "inactive"
  return 1
}

check_command() {
  local node="$1"
  local host="$2"
  local label="$3"
  local cmd="$4"

  if ssh_cmd "${host}" "${cmd}" >/dev/null 2>&1; then
    add_result "${node}" "${label}" "PASS" "0" ""
  else
    add_result "${node}" "${label}" "FAIL" "0" "check failed"
  fi
}

run_node_checks() {
  local node="$1"
  local host="$2"
  local role="$3"

  if ! ssh_cmd "${host}" "true" >/dev/null 2>&1; then
    SSH_UNREACHABLE=$((SSH_UNREACHABLE + 1))
    add_result "${node}" "ssh_connection" "FAIL" "0" "unreachable"
    return 0
  fi

  if [[ "${role}" == "mgmt" ]]; then
    check_service "${node}" "${host}" "ipa.service"
    check_service "${node}" "${host}" "slurmctld.service"
    check_service "${node}" "${host}" "wazuh-manager.service"
    check_service "${node}" "${host}" "nfs-server.service"
    check_service "${node}" "${host}" "munge.service"
    check_service "${node}" "${host}" "chronyd.service"

    check_command "${node}" "${host}" "/shared export" "exportfs -v | grep -q '/shared'"
    check_command "${node}" "${host}" "FreeIPA server" "ipactl status >/dev/null 2>&1"
    return 0
  fi

  if [[ "${role}" == "login" ]]; then
    check_service "${node}" "${host}" "sssd.service"
    check_service "${node}" "${host}" "munge.service"
    check_service "${node}" "${host}" "wazuh-agent.service"
    check_service "${node}" "${host}" "chronyd.service"

    check_command "${node}" "${host}" "/shared mount" "mountpoint -q /shared"
    check_command "${node}" "${host}" "FreeIPA client" "test -f /etc/ipa/default.conf || test -f /etc/sssd/sssd.conf"
    return 0
  fi

  check_service "${node}" "${host}" "sssd.service"
  check_service "${node}" "${host}" "slurmd.service"
  check_service "${node}" "${host}" "munge.service"
  check_service "${node}" "${host}" "wazuh-agent.service"
  check_service "${node}" "${host}" "chronyd.service"

  check_command "${node}" "${host}" "/shared mount" "mountpoint -q /shared"
  check_command "${node}" "${host}" "FreeIPA client" "test -f /etc/ipa/default.conf || test -f /etc/sssd/sssd.conf"
}

print_table() {
  printf '%s\n' 'Node         Service                 Status'
  printf '%s\n' '--------------------------------------------'
  while IFS=$'\t' read -r node service status remediated message; do
    local pretty
    if [[ "${status}" == "PASS" ]]; then
      pretty='✓ pass'
      if [[ "${remediated}" == "1" ]]; then
        pretty='✓ pass (restarted)'
      fi
    else
      pretty='✗ FAIL'
    fi
    printf '%-12s %-23s %s\n' "${node}" "${service}" "${pretty}"
  done < "${RESULTS_FILE}"
  printf '%s\n' '--------------------------------------------'
  printf 'Result: %s/%s checks passed, %s failed\n' "${PASS_COUNT}" "$((PASS_COUNT + FAIL_COUNT))" "${FAIL_COUNT}"
}

print_json() {
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  jq -Rn \
    --arg ts "${ts}" \
    --argjson ssh_unreachable "${SSH_UNREACHABLE}" \
    '
      [inputs | split("\t") | {
        node: .[0],
        service: .[1],
        status: .[2],
        remediated: (.[3] == "1"),
        message: .[4]
      }] as $rows
      | {
          timestamp: $ts,
          total_checks: ($rows | length),
          pass_count: ($rows | map(select(.status == "PASS")) | length),
          fail_count: ($rows | map(select(.status != "PASS")) | length),
          ssh_unreachable: $ssh_unreachable,
          results: $rows
        }
    ' < "${RESULTS_FILE}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --inventory)
        if [[ $# -lt 2 ]]; then
          error "--inventory requires a path"
          exit 2
        fi
        INVENTORY_PATH="$2"
        shift 2
        ;;
      --json)
        JSON_OUTPUT=1
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
  require_command awk
  require_command grep

  if [[ ! -f "${INVENTORY_PATH}" ]]; then
    error "Inventory not found: ${INVENTORY_PATH}"
    exit 3
  fi

  SSH_KEY_PATH="$(resolve_inventory_private_key)"
  if [[ ! -f "${SSH_KEY_PATH}" ]]; then
    error "SSH private key not found: ${SSH_KEY_PATH}"
    exit 3
  fi

  if ! cluster_exists; then
    error "No running cluster detected."
    exit 3
  fi

  while IFS='|' read -r node host role; do
    run_node_checks "${node}" "${host}" "${role}"
  done < <(inventory_nodes)

  if [[ "${JSON_OUTPUT}" -eq 1 ]]; then
    print_json
  else
    print_table
  fi

  if [[ "${SSH_UNREACHABLE}" -gt 0 ]]; then
    exit 3
  fi

  if [[ "${FAIL_COUNT}" -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
