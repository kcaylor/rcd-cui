#!/usr/bin/env bash
# demo-bake.sh — Package provisioned demo VMs as reusable Vagrant boxes.
#
# Usage:
#   demo-bake.sh              # Package all 4 VMs into a new box set
#   demo-bake.sh --list       # List available box sets
#   demo-bake.sh --delete <label>   # Delete a specific box set
#   demo-bake.sh --delete-all       # Delete all box sets
#   demo-bake.sh --help       # Show usage
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export REPO_ROOT

VAGRANT_CWD="${VAGRANT_CWD:-${REPO_ROOT}/demo/vagrant}"
BOXES_DIR="${REPO_ROOT}/demo/vagrant/boxes"

# shellcheck source=lib-demo-common.sh
source "${SCRIPT_DIR}/lib-demo-common.sh"

# ---------- Exit codes ----------
EXIT_OK=0
EXIT_CLUSTER_NOT_RUNNING=1
EXIT_PACKAGING_FAILED=2
EXIT_MANIFEST_ERROR=3
EXIT_USAGE=4

# ---------- VM list (the 4 core demo VMs) ----------
DEMO_VMS=("mgmt01" "login01" "compute01" "compute02")

# ---------- Trap / cleanup (T012) ----------
CURRENT_PACKAGING_FILE=""

cleanup_on_interrupt() {
  log_warn "Interrupted — cleaning up partial artifacts"
  if [[ -n "${CURRENT_PACKAGING_FILE}" && -f "${CURRENT_PACKAGING_FILE}" ]]; then
    log_warn "Removing partial box file: ${CURRENT_PACKAGING_FILE}"
    rm -f "${CURRENT_PACKAGING_FILE}"
  fi
  exit 130
}

trap cleanup_on_interrupt SIGINT SIGTERM

# ---------- T007: verify_cluster_running ----------
verify_cluster_running() {
  log_info "Checking that all demo VMs are running"
  local not_running
  not_running="$(cd "${VAGRANT_CWD}" && vagrant status --machine-readable \
    | awk -F, '$3=="state" && ($2=="mgmt01" || $2=="login01" || $2=="compute01" || $2=="compute02") && $4!="running" {print $2}' \
    | sort -u || true)"

  if [[ -n "${not_running}" ]]; then
    log_error "These VMs are not running: ${not_running//$'\n'/, }"
    log_error "A fully provisioned, running cluster is required before baking."
    log_error "Run './demo/scripts/demo-setup.sh' first."
    return ${EXIT_CLUSTER_NOT_RUNNING}
  fi
  log_success "All 4 demo VMs are running"
}

# ---------- T008: package_vm ----------
# Package a single VM into a .box file.
# Args: $1 = vm_name, $2 = output_path
package_vm() {
  local vm_name="${1:?Usage: package_vm <vm_name> <output_path>}"
  local output_path="${2:?Usage: package_vm <vm_name> <output_path>}"
  local provider
  provider="$(detect_provider)"

  CURRENT_PACKAGING_FILE="${output_path}"
  log_info "Packaging '${vm_name}' (provider=${provider}) → ${output_path}"

  case "${provider}" in
    virtualbox)
      (cd "${VAGRANT_CWD}" && vagrant package "${vm_name}" --output "${output_path}") || {
        log_error "Failed to package ${vm_name} (VirtualBox)"
        return ${EXIT_PACKAGING_FAILED}
      }
      ;;
    libvirt)
      # Preserve FreeIPA/Munge/SSH state by excluding destructive virt-sysprep ops
      (cd "${VAGRANT_CWD}" && \
        VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir,-ssh-hostkeys,-lvm-uuids" \
        vagrant package "${vm_name}" --output "${output_path}") || {
        log_error "Failed to package ${vm_name} (libvirt)"
        return ${EXIT_PACKAGING_FAILED}
      }
      ;;
    qemu)
      _package_vm_qemu "${vm_name}" "${output_path}" || {
        log_error "Failed to package ${vm_name} (QEMU)"
        return ${EXIT_PACKAGING_FAILED}
      }
      ;;
    *)
      log_error "Unsupported provider: ${provider}"
      return ${EXIT_PACKAGING_FAILED}
      ;;
  esac

  CURRENT_PACKAGING_FILE=""
  log_success "Packaged ${vm_name} ($(human_size "$(stat -f%z "${output_path}" 2>/dev/null || stat --printf="%s" "${output_path}" 2>/dev/null || echo 0)"))"
}

# QEMU: manual disk export (best-effort)
_package_vm_qemu() {
  local vm_name="$1" output_path="$2"

  command -v qemu-img >/dev/null 2>&1 || {
    log_error "qemu-img is required for QEMU box packaging"
    return 1
  }

  # Halt the VM first (graceful shutdown)
  log_info "Halting ${vm_name} for disk export"
  (cd "${VAGRANT_CWD}" && vagrant halt "${vm_name}") || true

  # Locate the disk image
  local machine_dir="${VAGRANT_CWD}/.vagrant/machines/${vm_name}/qemu"
  local disk_img
  disk_img="$(find "${machine_dir}" -name "linked-box.img" -o -name "*.qcow2" 2>/dev/null | head -1)"

  if [[ -z "${disk_img}" || ! -f "${disk_img}" ]]; then
    log_error "Cannot find QEMU disk image for ${vm_name} in ${machine_dir}"
    return 1
  fi

  # Create a temp dir for box contents
  local tmp_dir
  tmp_dir="$(mktemp -d)"
  trap "rm -rf '${tmp_dir}'" RETURN

  # Convert and compress disk image
  log_info "Converting disk image (this may take a while)"
  qemu-img convert -O qcow2 -c "${disk_img}" "${tmp_dir}/box.img" || {
    log_error "qemu-img convert failed for ${vm_name}"
    return 1
  }

  # Create metadata.json
  cat > "${tmp_dir}/metadata.json" << JSON
{
  "provider": "qemu",
  "format": "qcow2",
  "virtual_size": $(qemu-img info --output=json "${tmp_dir}/box.img" | jq '.["virtual-size"]')
}
JSON

  # Create Vagrantfile stub
  cat > "${tmp_dir}/Vagrantfile" << 'RUBY'
Vagrant.configure("2") do |config|
  config.vm.provider "qemu" do |qemu|
    qemu.arch = "x86_64"
    qemu.machine = "q35"
    qemu.cpu = "max"
  end
end
RUBY

  # Tar into .box
  (cd "${tmp_dir}" && tar czf "${output_path}" metadata.json Vagrantfile box.img) || {
    log_error "Failed to create .box archive for ${vm_name}"
    return 1
  }

  # Bring the VM back up
  log_info "Restarting ${vm_name} after disk export"
  (cd "${VAGRANT_CWD}" && vagrant up "${vm_name}" --no-provision) || true
}

# ---------- T009: bake_all ----------
bake_all() {
  local provider
  provider="$(detect_provider)"

  # Check disk space (warn if < 20 GB free)
  local free_kb
  free_kb="$(df -k "${BOXES_DIR}" | awk 'NR==2 {print $4}')"
  local free_gb=$(( free_kb / 1024 / 1024 ))
  if (( free_gb < 20 )); then
    log_warn "Low disk space: ${free_gb} GB free (recommend >= 20 GB for baking)"
  fi

  verify_cluster_running || return $?
  init_manifest

  local set_label
  set_label="$(generate_set_label)"
  log_info "Baking box set: ${set_label} (provider=${provider})"

  # 2-set rotation: delete previous, relabel current → previous
  local previous_label current_label
  previous_label="$(get_previous_set)"
  current_label="$(get_current_set)"

  if [[ -n "${previous_label}" ]]; then
    log_info "Removing previous set: ${previous_label}"
    _delete_set_files "${previous_label}"
    read_manifest | jq --arg label "${previous_label}" 'del(.sets[$label])' | write_manifest
  fi

  if [[ -n "${current_label}" ]]; then
    log_info "Demoting current set '${current_label}' to previous"
    read_manifest | jq --arg label "${current_label}" '.sets[$label].status = "previous"' | write_manifest
  fi

  # Package each VM
  local total_size=0
  local boxes_json="{}"
  mkdir -p "${BOXES_DIR}"

  for vm_name in "${DEMO_VMS[@]}"; do
    local box_filename="${set_label}-${vm_name}.box"
    local box_path="${BOXES_DIR}/${box_filename}"

    package_vm "${vm_name}" "${box_path}" || return $?

    local box_size
    box_size="$(stat -f%z "${box_path}" 2>/dev/null || stat --printf="%s" "${box_path}" 2>/dev/null || echo 0)"
    total_size=$(( total_size + box_size ))

    boxes_json="$(echo "${boxes_json}" | jq \
      --arg name "${vm_name}" \
      --arg filename "${box_filename}" \
      --argjson size "${box_size}" \
      --arg vagrant_box_name "rcd-cui-${vm_name}" \
      '. + {($name): {vm_name: $name, filename: $filename, size_bytes: $size, vagrant_box_name: $vagrant_box_name}}')"
  done

  # Write new set to manifest
  local git_commit git_branch vagrant_version created_at
  git_commit="$(git -C "${REPO_ROOT}" rev-parse --short HEAD 2>/dev/null || echo "unknown")"
  git_branch="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")"
  vagrant_version="$(vagrant --version 2>/dev/null | awk '{print $2}' || echo "unknown")"
  created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  read_manifest | jq \
    --arg label "${set_label}" \
    --arg created_at "${created_at}" \
    --arg git_commit "${git_commit}" \
    --arg git_branch "${git_branch}" \
    --arg provider "${provider}" \
    --arg vagrant_version "${vagrant_version}" \
    --argjson boxes "${boxes_json}" \
    '.sets[$label] = {
      created_at: $created_at,
      git_commit: $git_commit,
      git_branch: $git_branch,
      provider: $provider,
      vagrant_version: $vagrant_version,
      status: "current",
      boxes: $boxes
    }' | write_manifest

  log_success "Bake complete: ${set_label}"
  log_info "  VMs packaged: ${#DEMO_VMS[@]}"
  log_info "  Total size:   $(human_size "${total_size}")"
  log_info "  Provider:     ${provider}"
  log_info "  Commit:       ${git_commit}"
}

# ---------- T010: list_sets ----------
list_sets() {
  init_manifest
  local manifest
  manifest="$(read_manifest)"
  local count
  count="$(echo "${manifest}" | jq '.sets | length')"

  if (( count == 0 )); then
    log_info "No baked box sets found"
    return ${EXIT_OK}
  fi

  printf "\n%-28s %-22s %-12s %-6s %-10s %-10s %s\n" \
    "Label" "Created" "Provider" "Age" "Commit" "Status" "Total Size"
  printf "%s\n" "$(printf '%.0s-' {1..110})"

  echo "${manifest}" | jq -r '.sets | to_entries | sort_by(.value.created_at) | reverse[] |
    [.key, .value.created_at, .value.provider, .value.git_commit, .value.status,
     (.value.boxes | to_entries | map(.value.size_bytes) | add // 0 | tostring)] | @tsv' |
  while IFS=$'\t' read -r label created_at provider git_commit status total_bytes; do
    # Calculate age
    local age_days="?"
    local now_epoch created_epoch
    now_epoch="$(date +%s)"
    if date --version >/dev/null 2>&1; then
      created_epoch="$(date -d "${created_at}" +%s 2>/dev/null || echo "${now_epoch}")"
    else
      created_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${created_at}" +%s 2>/dev/null || echo "${now_epoch}")"
    fi
    age_days="$(( (now_epoch - created_epoch) / 86400 ))d"

    printf "%-28s %-22s %-12s %-6s %-10s %-10s %s\n" \
      "${label}" "${created_at}" "${provider}" "${age_days}" "${git_commit}" "${status}" \
      "$(human_size "${total_bytes}")"
  done

  printf "\n"
}

# ---------- T011: delete_set / delete_all ----------
_delete_set_files() {
  local label="${1:?Usage: _delete_set_files <label>}"
  local manifest
  manifest="$(read_manifest)"
  local filenames
  filenames="$(echo "${manifest}" | jq -r --arg label "${label}" '.sets[$label].boxes // {} | to_entries[].value.filename')"

  local reclaimed=0
  while IFS= read -r filename; do
    [[ -z "${filename}" ]] && continue
    local filepath="${BOXES_DIR}/${filename}"
    if [[ -f "${filepath}" ]]; then
      local fsize
      fsize="$(stat -f%z "${filepath}" 2>/dev/null || stat --printf="%s" "${filepath}" 2>/dev/null || echo 0)"
      reclaimed=$(( reclaimed + fsize ))
      rm -f "${filepath}"
    fi
  done <<< "${filenames}"

  # Deregister from Vagrant
  for vm_name in "${DEMO_VMS[@]}"; do
    vagrant box remove "rcd-cui-${vm_name}" --provider "$(detect_provider)" 2>/dev/null || true
  done

  echo "${reclaimed}"
}

delete_set() {
  local label="${1:?Usage: delete_set <label>}"
  init_manifest

  local manifest
  manifest="$(read_manifest)"
  local exists
  exists="$(echo "${manifest}" | jq --arg label "${label}" '.sets[$label] // empty')"

  if [[ -z "${exists}" ]]; then
    log_error "Box set '${label}' not found"
    return ${EXIT_MANIFEST_ERROR}
  fi

  local reclaimed
  reclaimed="$(_delete_set_files "${label}")"
  read_manifest | jq --arg label "${label}" 'del(.sets[$label])' | write_manifest

  log_success "Deleted box set '${label}' — reclaimed $(human_size "${reclaimed}")"
}

delete_all() {
  init_manifest
  local manifest
  manifest="$(read_manifest)"
  local labels
  labels="$(echo "${manifest}" | jq -r '.sets | keys[]')"

  if [[ -z "${labels}" ]]; then
    log_info "No box sets to delete"
    return ${EXIT_OK}
  fi

  local total_reclaimed=0
  while IFS= read -r label; do
    [[ -z "${label}" ]] && continue
    local reclaimed
    reclaimed="$(_delete_set_files "${label}")"
    total_reclaimed=$(( total_reclaimed + reclaimed ))
    log_info "Deleted: ${label}"
  done <<< "${labels}"

  # Reset manifest to empty
  init_manifest
  echo '{"version": 1, "staleness_days": 7, "sets": {}}' | write_manifest

  log_success "Deleted all box sets — reclaimed $(human_size "${total_reclaimed}")"
}

# ---------- T006: usage / argument parsing ----------
usage() {
  cat << 'USAGE'
Usage: demo-bake.sh [COMMAND]

Commands:
  (none)                Package all 4 demo VMs into a new box set
  --list                List available baked box sets
  --delete <label>      Delete a specific box set
  --delete-all          Delete all box sets
  --help                Show this help message

Environment:
  DEMO_PROVIDER         Override provider detection (virtualbox|libvirt|qemu)

Examples:
  ./demo/scripts/demo-bake.sh
  ./demo/scripts/demo-bake.sh --list
  ./demo/scripts/demo-bake.sh --delete rcd-demo-20260302-01
USAGE
}

main() {
  case "${1:-}" in
    --list)
      list_sets
      ;;
    --delete-all)
      delete_all
      ;;
    --delete)
      if [[ -z "${2:-}" ]]; then
        log_error "Missing label for --delete"
        usage
        exit ${EXIT_USAGE}
      fi
      delete_set "$2"
      ;;
    --help|-h)
      usage
      ;;
    "")
      bake_all
      ;;
    *)
      log_error "Unknown command: $1"
      usage
      exit ${EXIT_USAGE}
      ;;
  esac
}

main "$@"
