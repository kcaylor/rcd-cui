#!/usr/bin/env bash
set -euo pipefail

VAGRANT_CWD="${VAGRANT_CWD:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
OUTPUT_PATH="${1:-${VAGRANT_CWD}/inventory/hosts-qemu-runtime.yml}"

nodes=(mgmt01 login01 compute01 compute02)

declare -A hosts
declare -A ports
declare -A users
declare -A keys

for node in "${nodes[@]}"; do
  cfg="$(cd "${VAGRANT_CWD}" && vagrant ssh-config "${node}")"

  hosts["${node}"]="$(awk '/^  HostName / {print $2}' <<<"${cfg}")"
  ports["${node}"]="$(awk '/^  Port / {print $2}' <<<"${cfg}")"
  users["${node}"]="$(awk '/^  User / {print $2}' <<<"${cfg}")"
  keys["${node}"]="$(awk '/^  IdentityFile / {print $2; exit}' <<<"${cfg}")"

  if [[ -z "${hosts[${node}]}" || -z "${ports[${node}]}" || -z "${users[${node}]}" || -z "${keys[${node}]}" ]]; then
    echo "Failed to parse vagrant ssh-config for ${node}" >&2
    exit 1
  fi

done

cat > "${OUTPUT_PATH}" <<YAML
all:
  children:
    mgmt:
      hosts:
        mgmt01:
          ansible_host: ${hosts[mgmt01]}
          ansible_port: ${ports[mgmt01]}
          ansible_user: ${users[mgmt01]}
          ansible_ssh_private_key_file: ${keys[mgmt01]}
          node_role: mgmt
          zone: management
    login:
      hosts:
        login01:
          ansible_host: ${hosts[login01]}
          ansible_port: ${ports[login01]}
          ansible_user: ${users[login01]}
          ansible_ssh_private_key_file: ${keys[login01]}
          node_role: login
          zone: internal
    compute:
      hosts:
        compute01:
          ansible_host: ${hosts[compute01]}
          ansible_port: ${ports[compute01]}
          ansible_user: ${users[compute01]}
          ansible_ssh_private_key_file: ${keys[compute01]}
          node_role: compute
          zone: restricted
        compute02:
          ansible_host: ${hosts[compute02]}
          ansible_port: ${ports[compute02]}
          ansible_user: ${users[compute02]}
          ansible_ssh_private_key_file: ${keys[compute02]}
          node_role: compute
          zone: restricted
YAML

echo "Generated ${OUTPUT_PATH}"
