#!/usr/bin/env bash
set -euo pipefail

EXIT_VAGRANT_FAILED=1
EXIT_VMS_NOT_RUNNING=2
EXIT_ANSIBLE_FAILED=3

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

main() {
  log_info "Starting demo lab setup"
  check_prerequisites
  log_info "Selected provider: ${DEMO_PROVIDER}"
  log_info "Using inventory: ${INVENTORY_FILE}"

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
}

main "$@"
