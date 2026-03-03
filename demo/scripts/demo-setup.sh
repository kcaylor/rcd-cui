#!/usr/bin/env bash
set -euo pipefail

EXIT_VAGRANT_FAILED=1
EXIT_VMS_NOT_RUNNING=2
EXIT_ANSIBLE_FAILED=3
EXIT_BAKED_NOT_FOUND=4

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
export REPO_ROOT

# shellcheck source=lib-demo-common.sh
source "${SCRIPT_DIR}/lib-demo-common.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

VAGRANT_CWD="${VAGRANT_CWD:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../vagrant" && pwd)}"
ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-${VAGRANT_CWD}/ansible.cfg}"
BASELINE_SNAPSHOT_NAME="${BASELINE_SNAPSHOT_NAME:-baseline}"
DEMO_PROVIDER="${DEMO_PROVIDER:-${1:-}}"
INVENTORY_FILE="${INVENTORY_FILE:-${VAGRANT_CWD}/inventory/hosts.yml}"
QEMU_INVENTORY_GENERATOR="${QEMU_INVENTORY_GENERATOR:-${VAGRANT_CWD}/inventory/gen-qemu-inventory.sh}"
QEMU_VDE_DIR="${QEMU_VDE_DIR:-/tmp/rcd-demo-vde}"
QEMU_VDE_PIDFILE="${QEMU_VDE_PIDFILE:-${QEMU_VDE_DIR}/pid}"

log_info() {
  printf "%b[INFO]%b %s\n" "${BLUE}" "${NC}" "$*"
}

log_warn() {
  printf "%b[WARN]%b %s\n" "${YELLOW}" "${NC}" "$*"
}

log_success() {
  printf "%b[OK]%b %s\n" "${GREEN}" "${NC}" "$*"
}

log_error() {
  printf "%b[ERROR]%b %s\n" "${RED}" "${NC}" "$*" >&2
}

detect_provider() {
  local os arch plugins
  os="$(uname -s)"
  arch="$(uname -m)"
  plugins="$(vagrant plugin list 2>/dev/null || true)"

  if [[ -n "${DEMO_PROVIDER}" ]]; then
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

check_ram_gb() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    local bytes
    bytes="$(sysctl -n hw.memsize 2>/dev/null || echo 0)"
    echo $((bytes / 1024 / 1024 / 1024))
  else
    local kb
    kb="$(awk '/MemTotal:/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
    echo $((kb / 1024 / 1024))
  fi
}

run_vagrant() {
  if ! (cd "${VAGRANT_CWD}" && vagrant "$@"); then
    return ${EXIT_VAGRANT_FAILED}
  fi
}

ensure_qemu_vde_switch() {
  if [[ "${DEMO_PROVIDER}" != "qemu" ]]; then
    return 0
  fi

  command -v vde_switch >/dev/null 2>&1 || {
    log_error "Missing required command for QEMU networking: vde_switch"
    return 1
  }

  mkdir -p "${QEMU_VDE_DIR}"

  if [[ -f "${QEMU_VDE_PIDFILE}" ]]; then
    local pid
    pid="$(cat "${QEMU_VDE_PIDFILE}" 2>/dev/null || true)"
    if [[ -n "${pid}" ]] && ps -p "${pid}" >/dev/null 2>&1; then
      return 0
    fi
  fi

  # Daemonize a user-space switch that QEMU net1 can attach to.
  # vde_switch will create a control socket at ${QEMU_VDE_DIR}/ctl.
  if ! vde_switch -d --nostdin -p "${QEMU_VDE_PIDFILE}" -s "${QEMU_VDE_DIR}" >/dev/null 2>&1; then
    log_error "Failed to start vde_switch (dir=${QEMU_VDE_DIR})"
    return 1
  fi

  return 0
}

run_ansible_provision() {
  local extra=()
  # QEMU inventory is generated from `vagrant ssh-config` and already includes
  # correct host/port/key settings (including auto-corrected ports).
  if [[ "${DEMO_PROVIDER}" != "qemu" ]]; then
    extra+=(-e "ansible_ssh_private_key_file=${HOME}/.vagrant.d/insecure_private_key")
  else
    extra+=(-e "demo_provider=qemu")
  fi

  if ! ansible-playbook "${VAGRANT_CWD}/../playbooks/provision.yml" -i "${INVENTORY_FILE}" -f 1 "${extra[@]}"; then
    return ${EXIT_ANSIBLE_FAILED}
  fi
}

refresh_qemu_inventory() {
  if [[ ! -x "${QEMU_INVENTORY_GENERATOR}" ]]; then
    log_error "Missing QEMU inventory generator: ${QEMU_INVENTORY_GENERATOR}"
    return 1
  fi

  INVENTORY_FILE="${VAGRANT_CWD}/inventory/hosts-qemu-runtime.yml"
  if ! "${QEMU_INVENTORY_GENERATOR}" "${INVENTORY_FILE}" >/dev/null; then
    log_error "Failed to generate runtime QEMU inventory"
    return 1
  fi
}

verify_running() {
  local not_running
  not_running="$(cd "${VAGRANT_CWD}" && vagrant status --machine-readable | awk -F, '$3=="state" && ($2=="mgmt01" || $2=="login01" || $2=="compute01" || $2=="compute02") && $4!="running" {print $2}' | sort -u || true)"

  if [[ -n "${not_running}" ]]; then
    log_error "These VMs are not running: ${not_running//$'\n'/, }"
    return ${EXIT_VMS_NOT_RUNNING}
  fi

  return 0
}

check_prerequisites() {
  command -v vagrant >/dev/null 2>&1 || {
    log_error "Vagrant is not installed or not in PATH"
    exit ${EXIT_VAGRANT_FAILED}
  }

  DEMO_PROVIDER="$(detect_provider)"

  if [[ "${DEMO_PROVIDER}" == "qemu" ]]; then
    INVENTORY_FILE="${VAGRANT_CWD}/inventory/hosts-qemu-runtime.yml"
  fi

  if ! vagrant plugin list | grep -Eq "${DEMO_PROVIDER}|vagrant-${DEMO_PROVIDER}"; then
    log_warn "Provider plugin for '${DEMO_PROVIDER}' not explicitly detected; continuing"
  fi

  local ram_gb
  ram_gb="$(check_ram_gb)"
  if (( ram_gb < 16 )); then
    log_error "Host RAM ${ram_gb}GB detected; at least 16GB required"
    exit ${EXIT_VAGRANT_FAILED}
  fi

  export ANSIBLE_CONFIG
  log_success "Prerequisites check passed (provider=${DEMO_PROVIDER}, RAM=${ram_gb}GB)"
}

# ---------- T013: check_baked_boxes ----------
check_baked_boxes() {
  init_manifest 2>/dev/null || return 1

  local current_label
  current_label="$(get_current_set)"
  if [[ -z "${current_label}" ]]; then
    return 1  # no current set
  fi

  local set_info provider vagrant_ver
  set_info="$(get_set_info "${current_label}")"
  provider="$(echo "${set_info}" | jq -r '.provider')"
  vagrant_ver="$(echo "${set_info}" | jq -r '.vagrant_version')"

  # Provider mismatch check
  if [[ "${provider}" != "${DEMO_PROVIDER}" ]]; then
    log_error "Baked boxes were created with provider '${provider}' but current provider is '${DEMO_PROVIDER}'"
    log_error "Provider mismatch — cannot boot from these boxes. Re-bake with the correct provider."
    return 1
  fi

  # Vagrant version mismatch warning
  local current_vagrant_ver
  current_vagrant_ver="$(vagrant --version 2>/dev/null | awk '{print $2}' || echo "unknown")"
  if [[ "${vagrant_ver}" != "${current_vagrant_ver}" && "${vagrant_ver}" != "unknown" ]]; then
    log_warn "Baked boxes created with Vagrant ${vagrant_ver}, current version is ${current_vagrant_ver}"
  fi

  # Staleness warning (non-blocking)
  if check_staleness; then
    log_warn "Consider running './demo/scripts/demo-refresh.sh' to update"
  fi

  # Verify all box files exist
  local boxes_dir="${REPO_ROOT}/demo/vagrant/boxes"
  local missing=0
  for vm_name in mgmt01 login01 compute01 compute02; do
    local filename
    filename="$(echo "${set_info}" | jq -r --arg vm "${vm_name}" '.boxes[$vm].filename // empty')"
    if [[ -z "${filename}" || ! -f "${boxes_dir}/${filename}" ]]; then
      log_error "Missing box file for ${vm_name}: ${filename:-<not in manifest>}"
      missing=1
    fi
  done
  (( missing )) && return 1

  return 0
}

# ---------- T015: baked_boot ----------
baked_boot() {
  local current_label set_info boxes_dir
  current_label="$(get_current_set)"
  set_info="$(get_set_info "${current_label}")"
  boxes_dir="${REPO_ROOT}/demo/vagrant/boxes"

  log_info "Booting from baked box set: ${current_label}"

  # Register boxes with Vagrant
  for vm_name in mgmt01 login01 compute01 compute02; do
    local filename box_path
    filename="$(echo "${set_info}" | jq -r --arg vm "${vm_name}" '.boxes[$vm].filename')"
    box_path="${boxes_dir}/${filename}"
    log_info "Adding box rcd-cui-${vm_name} from ${filename}"
    vagrant box add --force --name "rcd-cui-${vm_name}" "${box_path}" || {
      log_error "Failed to add box for ${vm_name}"
      return ${EXIT_VAGRANT_FAILED}
    }
  done

  # Boot VMs from baked boxes (no provisioning)
  export RCD_PREBAKED=1
  log_info "Bringing up VMs from baked boxes (no provisioning)"
  if [[ "${DEMO_PROVIDER}" == "qemu" ]]; then
    ensure_qemu_vde_switch || return ${EXIT_VAGRANT_FAILED}
    run_vagrant up --provider "${DEMO_PROVIDER}" --no-provision || return $?
    refresh_qemu_inventory || return ${EXIT_VAGRANT_FAILED}
  else
    run_vagrant up --provider "${DEMO_PROVIDER}" --no-provision || return $?
  fi

  log_info "Verifying all VMs are running"
  verify_running || return $?
}

# ---------- T016: post_restore_and_health_check ----------
post_restore_and_health_check() {
  log_info "Running post-restore service reconciliation"

  local playbook="${REPO_ROOT}/demo/playbooks/post-restore.yml"
  local extra=()
  if [[ "${DEMO_PROVIDER}" == "qemu" ]]; then
    extra+=(-e "demo_provider=qemu")
  else
    extra+=(-e "ansible_ssh_private_key_file=${HOME}/.vagrant.d/insecure_private_key")
  fi

  if ! ansible-playbook "${playbook}" -i "${INVENTORY_FILE}" -f 1 "${extra[@]}"; then
    log_error "Post-restore reconciliation failed"
    return ${EXIT_ANSIBLE_FAILED}
  fi

  log_info "Verifying critical services"
  local failed=0

  # Helper to check a service on a host via SSH
  _check_service() {
    local host="$1" service="$2"
    local ssh_opts="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR"
    local key="${HOME}/.vagrant.d/insecure_private_key"
    if [[ "${DEMO_PROVIDER}" == "qemu" ]]; then
      # For QEMU, use vagrant ssh
      if ! (cd "${VAGRANT_CWD}" && vagrant ssh "${host}" -c "systemctl is-active ${service}" 2>/dev/null | grep -q "^active$"); then
        log_error "Service ${service} is not active on ${host}"
        return 1
      fi
    else
      if ! ssh ${ssh_opts} -i "${key}" vagrant@"${host}.demo.lab" "systemctl is-active ${service}" 2>/dev/null | grep -q "^active$"; then
        log_error "Service ${service} is not active on ${host}"
        return 1
      fi
    fi
    return 0
  }

  # mgmt01: FreeIPA, slurmctld, wazuh-manager, nfs-server
  for svc in ipa slurmctld nfs-server; do
    _check_service mgmt01 "${svc}" || failed=1
  done
  # wazuh-manager may be named differently
  _check_service mgmt01 "wazuh-manager" 2>/dev/null || \
    _check_service mgmt01 "wazuh-manager.service" 2>/dev/null || true

  # compute nodes: slurmd
  for node in compute01 compute02; do
    _check_service "${node}" slurmd || failed=1
  done

  # all nodes: munge, chronyd
  for node in mgmt01 login01 compute01 compute02; do
    _check_service "${node}" munge || failed=1
    _check_service "${node}" chronyd || failed=1
  done

  if (( failed )); then
    log_warn "Some services are not running — demo scenarios may not work correctly"
  else
    log_success "All critical services verified"
  fi

  return 0
}

main() {
  log_info "Starting demo lab setup"
  check_prerequisites
  log_info "Selected provider: ${DEMO_PROVIDER}"
  log_info "Using inventory: ${INVENTORY_FILE}"

  local use_baked=false

  # ---------- T013/T014: Baked-box detection and prompt ----------
  if [[ "${DEMO_USE_BAKED:-}" == "1" ]]; then
    # T020: Force baked boot
    if ! check_baked_boxes; then
      log_error "No baked boxes found. Run './demo/scripts/demo-bake.sh' after a successful provision to create them."
      exit ${EXIT_BAKED_NOT_FOUND}
    fi
    use_baked=true
  elif [[ "${DEMO_USE_BAKED:-}" == "0" ]]; then
    # T021: Force fresh provisioning
    use_baked=false
  else
    # Interactive mode: check for baked boxes and offer to use them
    if check_baked_boxes 2>/dev/null; then
      local current_label set_info created_at git_commit age_str
      current_label="$(get_current_set)"
      set_info="$(get_set_info "${current_label}")"
      created_at="$(echo "${set_info}" | jq -r '.created_at')"
      git_commit="$(echo "${set_info}" | jq -r '.git_commit')"

      # Calculate age
      local now_epoch created_epoch age_days
      now_epoch="$(date +%s)"
      if date --version >/dev/null 2>&1; then
        created_epoch="$(date -d "${created_at}" +%s 2>/dev/null || echo "${now_epoch}")"
      else
        created_epoch="$(date -j -f "%Y-%m-%dT%H:%M:%SZ" "${created_at}" +%s 2>/dev/null || echo "${now_epoch}")"
      fi
      age_days="$(( (now_epoch - created_epoch) / 86400 ))"

      printf "\n"
      log_info "Baked boxes found: ${current_label} (${age_days} days old, commit ${git_commit})"
      printf "Use baked boxes for fast start? [Y/n] "
      read -r reply
      if [[ "${reply}" =~ ^[Nn] ]]; then
        use_baked=false
      else
        use_baked=true
      fi
    fi
  fi

  if [[ "${use_baked}" == "true" ]]; then
    # ---------- T015/T016: Baked boot flow ----------
    baked_boot || exit $?
    post_restore_and_health_check || exit $?

    log_info "Creating baseline snapshot '${BASELINE_SNAPSHOT_NAME}'"
    run_vagrant snapshot push "${BASELINE_SNAPSHOT_NAME}" --no-provision || exit $?

    log_success "Demo lab setup complete (from baked boxes)"
  else
    # ---------- T018: Original fresh provision flow (unchanged) ----------
    log_info "Bringing up VMs via Vagrant"
    if [[ "${DEMO_PROVIDER}" == "qemu" ]]; then
      ensure_qemu_vde_switch || exit ${EXIT_VAGRANT_FAILED}
      run_vagrant up --provider "${DEMO_PROVIDER}" --no-provision || exit $?
      refresh_qemu_inventory || exit ${EXIT_VAGRANT_FAILED}
    else
      run_vagrant up --provider "${DEMO_PROVIDER}" || exit $?
    fi

    log_info "Running provisioning"
    if [[ "${DEMO_PROVIDER}" == "qemu" ]]; then
      run_ansible_provision || {
        log_error "Provisioning failed"
        exit ${EXIT_ANSIBLE_FAILED}
      }
    else
      if ! run_vagrant provision; then
        log_error "Provisioning failed"
        exit ${EXIT_ANSIBLE_FAILED}
      fi
    fi

    log_info "Verifying all VMs are running"
    verify_running || exit $?

    log_info "Creating baseline snapshot '${BASELINE_SNAPSHOT_NAME}'"
    run_vagrant snapshot push "${BASELINE_SNAPSHOT_NAME}" --no-provision || exit $?

    log_success "Demo lab setup complete"

    # ---------- T017: Auto-bake prompt after fresh provision ----------
    if [[ "${DEMO_USE_BAKED:-}" != "0" ]]; then
      printf "\nBake this cluster for future fast starts? [Y/n] "
      read -r reply
      if [[ ! "${reply}" =~ ^[Nn] ]]; then
        log_info "Baking boxes for future use"
        "${SCRIPT_DIR}/demo-bake.sh" || log_warn "Baking failed (non-fatal)"
      fi
    fi
  fi
}

main "$@"
