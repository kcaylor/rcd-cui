#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"
ENV_FILE="${REPO_ROOT}/infra/.env"
MANIFEST_PATH="${TF_DIR}/snapshot-manifest.json"
HEALTH_SCRIPT="${REPO_ROOT}/infra/scripts/demo-cloud-health.sh"

if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

MODE="create"
DELETE_SET_LABEL=""
COST_PER_GB_MONTH_EUR="0.011"
SSH_PRIVATE_KEY=""

info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
error() { printf 'ERROR: %s\n' "$*" >&2; }

usage() {
  cat <<USAGE
Usage: $(basename "$0") [--list] [--delete SET_LABEL]

Modes:
  (default)           Create snapshot set from running cluster
  --list              List available snapshot sets
  --delete SET_LABEL  Delete snapshot set and remove manifest entry
  --help              Show this help
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

resolve_private_key() {
  local key
  key="$(detect_ssh_key)"
  if [[ "${key}" == *.pub ]]; then
    key="${key%.pub}"
  fi
  printf '%s\n' "${key}"
}

init_manifest() {
  mkdir -p "${TF_DIR}"
  if [[ ! -f "${MANIFEST_PATH}" ]]; then
    cat > "${MANIFEST_PATH}" <<JSON
{
  "version": 1,
  "sets": {}
}
JSON
  fi
}

servers_json() {
  hcloud server list --selector "cluster=rcd-demo" -o json
}

server_rows() {
  servers_json | jq -r '
    sort_by(.name)[]
    | [
        (.id|tostring),
        .name,
        (.labels.node_role // "unknown"),
        (.server_type.name // .server_type // "unknown"),
        (.labels.private_ip // (.private_net[0].ip // "")),
        (.public_net.ipv4.ip // .public_net.ipv4 // .ipv4_address // "")
      ]
    | @tsv
  '
}

ssh_cmd() {
  local host="$1"
  local command="$2"
  ssh \
    -i "${SSH_PRIVATE_KEY}" \
    -o StrictHostKeyChecking=no \
    -o UserKnownHostsFile=/dev/null \
    -o ConnectTimeout=8 \
    -o BatchMode=yes \
    "root@${host}" \
    "${command}"
}

stop_services_for_snapshot() {
  info "Stopping critical services for snapshot consistency..."

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" == "compute" ]]; then
      ssh_cmd "${public_ip}" "systemctl stop slurmd.service >/dev/null 2>&1 || true"
    elif [[ "${role}" == "mgmt" ]]; then
      ssh_cmd "${public_ip}" "systemctl stop slurmctld.service >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" == "mgmt" ]]; then
      ssh_cmd "${public_ip}" "systemctl stop wazuh-manager.service >/dev/null 2>&1 || true"
    else
      ssh_cmd "${public_ip}" "systemctl stop wazuh-agent.service >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" != "mgmt" ]]; then
      ssh_cmd "${public_ip}" "umount /shared >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" == "mgmt" ]]; then
      ssh_cmd "${public_ip}" "systemctl stop nfs-server.service >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name _role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    ssh_cmd "${public_ip}" "systemctl stop munge.service >/dev/null 2>&1 || true"
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" == "mgmt" ]]; then
      ssh_cmd "${public_ip}" "ipactl stop >/dev/null 2>&1 || systemctl stop ipa.service >/dev/null 2>&1 || true"
    else
      ssh_cmd "${public_ip}" "systemctl stop sssd.service >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)
}

restart_services_after_snapshot() {
  info "Restarting services after snapshot creation..."

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" == "mgmt" ]]; then
      ssh_cmd "${public_ip}" "ipactl start >/dev/null 2>&1 || systemctl start ipa.service >/dev/null 2>&1 || true"
    else
      ssh_cmd "${public_ip}" "systemctl start sssd.service >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name _role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    ssh_cmd "${public_ip}" "systemctl start munge.service >/dev/null 2>&1 || true"
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" == "mgmt" ]]; then
      ssh_cmd "${public_ip}" "systemctl start nfs-server.service >/dev/null 2>&1 || true"
    else
      ssh_cmd "${public_ip}" "mkdir -p /shared; mountpoint -q /shared || mount /shared >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" == "mgmt" ]]; then
      ssh_cmd "${public_ip}" "systemctl start wazuh-manager.service >/dev/null 2>&1 || true"
    else
      ssh_cmd "${public_ip}" "systemctl start wazuh-agent.service >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)

  while IFS=$'\t' read -r _id _name role _type _private_ip public_ip; do
    [[ -n "${public_ip}" ]] || continue
    if [[ "${role}" == "compute" ]]; then
      ssh_cmd "${public_ip}" "systemctl start slurmd.service >/dev/null 2>&1 || true"
    elif [[ "${role}" == "mgmt" ]]; then
      ssh_cmd "${public_ip}" "systemctl start slurmctld.service >/dev/null 2>&1 || true"
    fi
  done < <(server_rows)
}

existing_set_suffixes() {
  local today_base="$1"
  {
    hcloud image list --type snapshot --selector "cluster=rcd-demo" -o json 2>/dev/null \
      | jq -r --arg base "${today_base}" '.[] | .labels["snapshot-set"] // empty | select(startswith($base + "-")) | capture("(?<n>[0-9]{2})$").n' \
      || true

    if [[ -f "${MANIFEST_PATH}" ]]; then
      jq -r --arg base "${today_base}" '.sets | keys[] | select(startswith($base + "-")) | capture("(?<n>[0-9]{2})$").n' "${MANIFEST_PATH}" 2>/dev/null || true
    fi
  } | awk 'NF>0' | sort -n | uniq
}

generate_set_label() {
  local base
  local max=0
  local suffix

  base="rcd-demo-$(date +%Y%m%d)"
  while IFS= read -r suffix; do
    [[ -n "${suffix}" ]] || continue
    if [[ "${suffix}" =~ ^[0-9]{2}$ ]] && ((10#${suffix} > max)); then
      max=$((10#${suffix}))
    fi
  done < <(existing_set_suffixes "${base}")

  printf '%s-%02d\n' "${base}" $((max + 1))
}

create_snapshot_with_retry() {
  local server_id="$1"
  local description="$2"
  local -a labels=("${@:3}")
  local out
  local try

  for try in 1 2; do
    if out="$(hcloud server create-image "${server_id}" --type snapshot --description "${description}" "${labels[@]}" 2>&1)"; then
      return 0
    fi

    if [[ "${try}" -eq 1 ]]; then
      warn "Snapshot API call failed for server ${server_id}; retrying in 10 seconds..."
      sleep 10
    fi
  done

  printf '%s\n' "${out}" >&2
  return 1
}

lookup_snapshot_id() {
  local set_label="$1"
  local node_name="$2"

  hcloud image list --type snapshot \
    --selector "cluster=rcd-demo,snapshot-set=${set_label},node-name=${node_name}" \
    -o json 2>/dev/null \
    | jq -r '.[0].id // empty'
}

update_manifest_set() {
  local set_label="$1"
  local snapshots_json="$2"
  local created_at="$3"
  local commit

  commit="$(git rev-parse --short HEAD 2>/dev/null || printf 'unknown')"

  jq \
    --arg set "${set_label}" \
    --arg created_at "${created_at}" \
    --arg source_cluster "rcd-demo" \
    --arg source_commit "${commit}" \
    --argjson snapshots "${snapshots_json}" \
    '
      .version = 1
      | .sets[$set] = {
          created_at: $created_at,
          source_cluster: $source_cluster,
          source_commit: $source_commit,
          snapshots: $snapshots
        }
    ' "${MANIFEST_PATH}" > "${MANIFEST_PATH}.tmp"

  mv "${MANIFEST_PATH}.tmp" "${MANIFEST_PATH}"
}

validate_manifest_set() {
  local set_label="$1"
  jq -e --arg set "${set_label}" '
    .sets[$set] as $entry
    | $entry != null
    and ($entry.snapshots | length == 4)
    and (($entry.snapshots | map(.node_name) | sort) == ["compute01","compute02","login01","mgmt01"])
  ' "${MANIFEST_PATH}" >/dev/null
}

run_create_mode() {
  local set_label
  local created_at
  local tmp_snapshots
  local failed=0
  local row_count

  if [[ ! -x "${HEALTH_SCRIPT}" ]]; then
    error "Health check script not executable: ${HEALTH_SCRIPT}"
    exit 3
  fi

  if ! cluster_exists; then
    error "No running cluster detected. Run 'make demo-cloud-up' first."
    exit 3
  fi

  info "Running health check before snapshot..."
  if ! "${HEALTH_SCRIPT}" --inventory "${TF_DIR}/inventory.yml"; then
    error "Health check failed. Refusing to snapshot an unhealthy cluster."
    exit 1
  fi

  SSH_PRIVATE_KEY="$(resolve_private_key)"
  if [[ ! -f "${SSH_PRIVATE_KEY}" ]]; then
    error "SSH private key not found: ${SSH_PRIVATE_KEY}"
    exit 3
  fi

  row_count="$(server_rows | wc -l | tr -d ' ')"
  if [[ "${row_count}" -ne 4 ]]; then
    error "Expected 4 servers in running cluster, found ${row_count}."
    exit 1
  fi

  init_manifest
  set_label="$(generate_set_label)"
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tmp_snapshots="$(mktemp)"
  trap 'rm -f "${RESULTS_FILE:-}" "${tmp_snapshots:-}"' EXIT

  info "Creating snapshot set: ${set_label}"

  stop_services_for_snapshot

  while IFS=$'\t' read -r server_id node_name node_role server_type private_ip _public_ip; do
    local snapshot_id

    info "Snapshotting ${node_name} (${server_type})..."
    if ! create_snapshot_with_retry "${server_id}" "${set_label}-${node_name}" \
      --label "cluster=rcd-demo" \
      --label "snapshot-set=${set_label}" \
      --label "node-name=${node_name}" \
      --label "node-role=${node_role}" \
      --label "server-type=${server_type}" \
      --label "private-ip=${private_ip}"; then
      failed=1
      warn "Failed to snapshot ${node_name}."
      continue
    fi

    snapshot_id="$(lookup_snapshot_id "${set_label}" "${node_name}")"
    if [[ -z "${snapshot_id}" ]]; then
      failed=1
      warn "Could not find snapshot ID for ${node_name} after creation."
      continue
    fi

    jq -nc \
      --argjson snapshot_id "${snapshot_id}" \
      --arg node_name "${node_name}" \
      --arg node_role "${node_role}" \
      --arg server_type "${server_type}" \
      --arg private_ip "${private_ip}" \
      '{snapshot_id:$snapshot_id,node_name:$node_name,node_role:$node_role,server_type:$server_type,private_ip:$private_ip}' \
      >> "${tmp_snapshots}"
  done < <(server_rows)

  restart_services_after_snapshot

  if [[ "${failed}" -ne 0 ]]; then
    if [[ -s "${tmp_snapshots}" ]]; then
      while IFS= read -r sid; do
        [[ -n "${sid}" ]] || continue
        hcloud image update "${sid}" --label "snapshot-state=incomplete" >/dev/null 2>&1 || true
      done < <(jq -r '.snapshot_id' "${tmp_snapshots}" 2>/dev/null || true)
    fi
    error "Snapshot set ${set_label} is incomplete due to one or more failures."
    warn "Clean up partial snapshots with: ./infra/scripts/demo-cloud-snapshot.sh --delete ${set_label}"
    exit 1
  fi

  local snapshots_json
  snapshots_json="$(jq -s '.' "${tmp_snapshots}")"
  update_manifest_set "${set_label}" "${snapshots_json}" "${created_at}"

  if ! validate_manifest_set "${set_label}"; then
    error "Manifest validation failed for set ${set_label}."
    exit 1
  fi

  local total_size_gb est_cost
  total_size_gb="$(printf '%s\n' "${snapshots_json}" | jq '[.[] | (.snapshot_id|tostring)] | length * 20')"
  est_cost="$(awk -v gb="${total_size_gb}" -v rate="${COST_PER_GB_MONTH_EUR}" 'BEGIN { printf "%.2f", gb * rate }')"

  printf '\nSnapshot set created: %s\n' "${set_label}"
  printf 'Snapshots: 4/4\n'
  printf 'Manifest: %s\n' "${MANIFEST_PATH}"
  printf 'Estimated storage cost: ~EUR %s/month\n' "${est_cost}"
}

run_list_mode() {
  init_manifest

  local images_json
  images_json="$(hcloud image list --type snapshot --selector "cluster=rcd-demo" -o json 2>/dev/null || printf '[]')"

  printf 'Set Label                  Created                   Snapshots  Est. Storage  Manifest\n'
  printf '-----------------------------------------------------------------------------------------\n'

  printf '%s\n' "${images_json}" \
    | jq -r --arg rate "${COST_PER_GB_MONTH_EUR}" '
      group_by(.labels["snapshot-set"] // "unlabeled")
      | map({
          set: (.[0].labels["snapshot-set"] // "unlabeled"),
          created: (map(.created // "") | sort | reverse | .[0]),
          count: length,
          size_gb: (map(.image_size // .disk_size // 20) | add)
        })
      | sort_by(.created)
      | reverse
      | .[]
      | [.set, .created, (.count|tostring), ((.size_gb * ($rate|tonumber))|tostring)]
      | @tsv
    ' \
    | while IFS=$'\t' read -r set created count est; do
        local manifest_marker="no"
        if jq -e --arg set "${set}" '.sets[$set] != null' "${MANIFEST_PATH}" >/dev/null 2>&1; then
          manifest_marker="yes"
        fi
        printf '%-26s %-25s %s/4        EUR %-10s %s\n' "${set}" "${created}" "${count}" "${est}" "${manifest_marker}"
      done

  local manifest_only
  manifest_only="$(jq -r '.sets | keys[]' "${MANIFEST_PATH}" 2>/dev/null | sort || true)"
  if [[ -n "${manifest_only}" ]]; then
    while IFS= read -r set; do
      [[ -n "${set}" ]] || continue
      if ! printf '%s\n' "${images_json}" | jq -e --arg set "${set}" 'map(select(.labels["snapshot-set"] == $set)) | length > 0' >/dev/null; then
        local created
        created="$(jq -r --arg set "${set}" '.sets[$set].created_at // "unknown"' "${MANIFEST_PATH}")"
        printf '%-26s %-25s %s\n' "${set}" "${created}" "(manifest-only entry)"
      fi
    done <<< "${manifest_only}"
  fi
}

run_delete_mode() {
  local set_label="$1"
  local ids
  local manifest_exists=0
  local reply

  if [[ -z "${set_label}" ]]; then
    error "--delete requires a set label"
    exit 2
  fi

  init_manifest

  if jq -e --arg set "${set_label}" '.sets[$set] != null' "${MANIFEST_PATH}" >/dev/null 2>&1; then
    manifest_exists=1
  fi

  ids="$(hcloud image list --type snapshot --selector "cluster=rcd-demo,snapshot-set=${set_label}" -o json 2>/dev/null | jq -r '.[].id' || true)"

  if [[ -z "${ids}" && "${manifest_exists}" -eq 0 ]]; then
    error "Snapshot set not found: ${set_label}"
    exit 2
  fi

  printf 'Delete snapshot set %s? [y/N] ' "${set_label}"
  read -r reply
  case "${reply}" in
    y|Y|yes|YES) ;;
    *)
      printf 'Delete cancelled.\n'
      exit 0
      ;;
  esac

  if [[ -n "${ids}" ]]; then
    while IFS= read -r id; do
      [[ -n "${id}" ]] || continue
      info "Deleting snapshot image ${id}..."
      hcloud image delete "${id}" >/dev/null
    done <<< "${ids}"
  fi

  if [[ "${manifest_exists}" -eq 1 ]]; then
    jq --arg set "${set_label}" 'del(.sets[$set])' "${MANIFEST_PATH}" > "${MANIFEST_PATH}.tmp"
    mv "${MANIFEST_PATH}.tmp" "${MANIFEST_PATH}"
  fi

  printf 'Deleted snapshot set: %s\n' "${set_label}"
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --list)
        MODE="list"
        shift
        ;;
      --delete)
        MODE="delete"
        if [[ $# -lt 2 ]]; then
          error "--delete requires a set label"
          exit 2
        fi
        DELETE_SET_LABEL="$2"
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
  require_command terraform

  case "${MODE}" in
    create)
      run_create_mode
      ;;
    list)
      run_list_mode
      ;;
    delete)
      run_delete_mode "${DELETE_SET_LABEL}"
      ;;
  esac
}

main "$@"
