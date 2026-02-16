#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TF_DIR="${REPO_ROOT}/infra/terraform"
INVENTORY_PATH="${TF_DIR}/inventory.yml"
TTL_CHECK_SCRIPT="${REPO_ROOT}/infra/scripts/check-ttl.sh"
ENV_FILE="${REPO_ROOT}/infra/.env"
DEMO_SSH_DIR="${REPO_ROOT}/infra/.ssh"
DEMO_SSH_KEY_PATH="${DEMO_SSH_DIR}/demo_ed25519"
DEMO_SSH_PUBKEY_PATH="${DEMO_SSH_KEY_PATH}.pub"

# Source .env if present (fallback to environment variables)
if [[ -f "${ENV_FILE}" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "${ENV_FILE}"
  set +a
fi

COST_PER_HOUR_EUR="0.0296"
COST_PER_DAY_EUR="0.7104"

info() {
  printf '==> %s\n' "$*"
}

warn() {
  printf 'WARNING: %s\n' "$*" >&2
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

generate_demo_ssh_key() {
  # Generate a dedicated SSH key for cloud demo infrastructure
  # This key is gitignored and never committed to the repository

  printf '\n'
  printf '┌─────────────────────────────────────────────────────────────────┐\n'
  printf '│                    SSH Key Generation                          │\n'
  printf '├─────────────────────────────────────────────────────────────────┤\n'
  printf '│ No SSH key found for cloud demo infrastructure.                │\n'
  printf '│                                                                 │\n'
  printf '│ This will generate a NEW Ed25519 SSH keypair:                  │\n'
  printf '│   Private key: infra/.ssh/demo_ed25519                         │\n'
  printf '│   Public key:  infra/.ssh/demo_ed25519.pub                     │\n'
  printf '│                                                                 │\n'
  printf '│ SECURITY NOTES:                                                 │\n'
  printf '│   - Keys are stored locally in this repository                 │\n'
  printf '│   - Keys are gitignored and will NEVER be committed            │\n'
  printf '│   - Keys are used ONLY for demo cloud VMs                      │\n'
  printf '│   - Delete infra/.ssh/demo_* to remove them                    │\n'
  printf '└─────────────────────────────────────────────────────────────────┘\n'
  printf '\n'

  local reply
  printf 'Generate dedicated demo SSH key? [Y/n] '
  read -r reply

  case "${reply}" in
    n|N|no|NO)
      return 1
      ;;
  esac

  # Ensure directory exists
  mkdir -p "${DEMO_SSH_DIR}"

  info "Generating Ed25519 SSH keypair..."

  # Generate key with no passphrase, minimal output
  # The -q flag suppresses the randomart and other output
  if ! ssh-keygen -t ed25519 -f "${DEMO_SSH_KEY_PATH}" -N "" -C "rcd-demo-cloud" -q; then
    error "Failed to generate SSH key"
    return 1
  fi

  # Set restrictive permissions on private key
  chmod 600 "${DEMO_SSH_KEY_PATH}"
  chmod 644 "${DEMO_SSH_PUBKEY_PATH}"

  printf '\n'
  printf 'SSH keypair generated successfully.\n'
  printf '  Private key: %s\n' "${DEMO_SSH_KEY_PATH}"
  printf '  Public key:  %s\n' "${DEMO_SSH_PUBKEY_PATH}"
  printf '\n'
  printf 'The private key contents are NOT displayed for security.\n'
  printf '\n'

  return 0
}

detect_ssh_key() {
  local key_path="${TF_VAR_ssh_key_path:-}"

  # 1. Check explicit override via TF_VAR_ssh_key_path
  if [[ -n "${key_path}" && -f "${key_path}" ]]; then
    printf '%s\n' "${key_path}"
    return 0
  fi

  # 2. Check legacy DEMO_SSH_KEY variable
  if [[ -n "${DEMO_SSH_KEY:-}" && -f "${DEMO_SSH_KEY}" ]]; then
    printf '%s\n' "${DEMO_SSH_KEY}"
    return 0
  fi

  # 3. Check for dedicated demo key (preferred)
  if [[ -f "${DEMO_SSH_PUBKEY_PATH}" ]]; then
    printf '%s\n' "${DEMO_SSH_PUBKEY_PATH}"
    return 0
  fi

  # 4. No demo key exists - offer to generate one
  if generate_demo_ssh_key; then
    printf '%s\n' "${DEMO_SSH_PUBKEY_PATH}"
    return 0
  fi

  # 5. User declined - fall back to system keys
  info "Falling back to system SSH keys..."

  if [[ -f "${HOME}/.ssh/id_ed25519.pub" ]]; then
    printf '%s\n' "${HOME}/.ssh/id_ed25519.pub"
    return 0
  fi

  if [[ -f "${HOME}/.ssh/id_rsa.pub" ]]; then
    printf '%s\n' "${HOME}/.ssh/id_rsa.pub"
    return 0
  fi

  error "No SSH public key found."
  error "Options:"
  error "  1. Run this command again and accept SSH key generation"
  error "  2. Create a key manually: ssh-keygen -t ed25519"
  error "  3. Set TF_VAR_ssh_key_path=/path/to/key.pub in infra/.env"
  exit 3
}

validate_hcloud_token() {
  if [[ -z "${HCLOUD_TOKEN:-}" ]]; then
    error "HCLOUD_TOKEN is not set."
    printf '%s\n' "Set it with: export HCLOUD_TOKEN=your-api-token" >&2
    printf '%s\n' "Create token at: https://console.hetzner.cloud/" >&2
    exit 3
  fi
}

cluster_exists() {
  local resources
  resources="$(terraform -chdir="${TF_DIR}" state list 2>/dev/null || true)"
  [[ -n "${resources}" ]]
}

show_cost_estimate() {
  printf '\nEstimated cost:\n'
  printf '  - 4 VMs: EUR %s/hour (~EUR %s/day)\n' "${COST_PER_HOUR_EUR}" "${COST_PER_DAY_EUR}"
  printf '  - Network: EUR 0.00 (included)\n'
  printf '  - Total: EUR %s/hour\n\n' "${COST_PER_HOUR_EUR}"
}

run_ansible_provision() {
  (
    cd "${REPO_ROOT}/demo/vagrant"
    ANSIBLE_CONFIG="${REPO_ROOT}/demo/vagrant/ansible.cfg" \
    ANSIBLE_HOST_KEY_CHECKING=False \
    ansible-playbook -i "${INVENTORY_PATH}" ../playbooks/provision.yml
  )
}

main() {
  local ssh_key_path
  local start_epoch
  local end_epoch
  local elapsed
  local mgmt_ip
  local login_ip

  require_command terraform
  require_command ansible-playbook

  validate_hcloud_token
  ssh_key_path="$(detect_ssh_key)"

  export TF_VAR_ssh_key_path="${ssh_key_path}"
  export TF_VAR_location="${TF_VAR_location:-hil}"

  if [[ -x "${TTL_CHECK_SCRIPT}" ]]; then
    "${TTL_CHECK_SCRIPT}" --warn || true
  fi

  printf 'Starting cloud demo cluster provisioning...\n'
  show_cost_estimate

  info "Initializing Terraform..."
  terraform -chdir="${TF_DIR}" init -input=false >/dev/null

  if cluster_exists; then
    error "An existing cloud demo cluster is already tracked in Terraform state."
    printf '%s\n' "Run 'make demo-cloud-down' before provisioning a new cluster." >&2
    exit 3
  fi

  start_epoch="$(date +%s)"

  info "Applying Terraform configuration..."
  if ! terraform -chdir="${TF_DIR}" apply -auto-approve; then
    error "Terraform apply failed."
    exit 1
  fi

  if [[ ! -f "${INVENTORY_PATH}" ]]; then
    error "Generated inventory file not found at ${INVENTORY_PATH}."
    exit 1
  fi

  info "Running Ansible provisioning (expected 15-20 minutes)..."
  if ! run_ansible_provision; then
    error "Ansible provisioning failed."
    exit 2
  fi

  end_epoch="$(date +%s)"
  elapsed="$((end_epoch - start_epoch))"

  mgmt_ip="$(terraform -chdir="${TF_DIR}" output -raw mgmt01_ip 2>/dev/null || true)"
  login_ip="$(terraform -chdir="${TF_DIR}" output -raw login01_ip 2>/dev/null || true)"

  printf '\nCloud demo cluster is ready.\n'
  printf 'Provisioning time: %ss\n\n' "${elapsed}"
  printf 'SSH access:\n'
  printf '  ssh root@%s\n' "${mgmt_ip}"
  printf '  ssh root@%s\n' "${login_ip}"
  printf '\nInventory: %s\n' "${INVENTORY_PATH}"
  printf 'Next: run scenario playbooks from demo/playbooks/\n'
}

main "$@"
