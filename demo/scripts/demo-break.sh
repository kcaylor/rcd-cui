#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

VAGRANT_CWD="${VAGRANT_CWD:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../vagrant" && pwd)}"
ANSIBLE_CONFIG="${ANSIBLE_CONFIG:-${VAGRANT_CWD}/ansible.cfg}"
DEMO_PROVIDER="${DEMO_PROVIDER:-}"
INVENTORY_FILE="${INVENTORY_FILE:-${VAGRANT_CWD}/inventory/hosts.yml}"
QEMU_INVENTORY_GENERATOR="${QEMU_INVENTORY_GENERATOR:-${VAGRANT_CWD}/inventory/gen-qemu-inventory.sh}"

log_info() {
  printf "%b[INFO]%b %s\n" "${BLUE}" "${NC}" "$*"
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
  if ! command -v vagrant >/dev/null 2>&1; then
    echo "virtualbox"
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

if ! command -v ansible-playbook >/dev/null 2>&1; then
  log_error "ansible-playbook is required"
  exit 1
fi

export ANSIBLE_CONFIG
DEMO_PROVIDER="$(detect_provider)"
if [[ "${DEMO_PROVIDER}" == "qemu" ]]; then
  INVENTORY_FILE="${VAGRANT_CWD}/inventory/hosts-qemu-runtime.yml"
  "${QEMU_INVENTORY_GENERATOR}" "${INVENTORY_FILE}" >/dev/null
fi

log_info "Introducing demo compliance violations (V001-V004) with provider=${DEMO_PROVIDER}"
if ! ansible-playbook "${VAGRANT_CWD}/../playbooks/scenario-b-drift.yml" -i "${INVENTORY_FILE}" --tags break; then
  log_error "Failed to introduce demo violations"
  exit 1
fi

log_success "Demo violations introduced"
