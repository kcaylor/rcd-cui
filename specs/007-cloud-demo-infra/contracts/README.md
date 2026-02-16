# Internal Contracts: Cloud Demo Infrastructure

**Feature**: 007-cloud-demo-infra
**Date**: 2026-02-15

This feature is infrastructure provisioning. Instead of API contracts, this document defines internal contracts between components.

## 1. Terraform ↔ Wrapper Scripts Contract

**Provider**: Terraform CLI
**Consumer**: demo-cloud-up.sh, demo-cloud-down.sh

### Commands Used

| Script | Terraform Commands | Expected Behavior |
|--------|-------------------|-------------------|
| demo-cloud-up.sh | `terraform init`, `terraform apply -auto-approve` | Create all resources, exit 0 on success |
| demo-cloud-down.sh | `terraform destroy` | Prompt for confirmation, destroy all resources |
| (both) | `terraform state list` | Return empty if no cluster exists |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Terraform error (apply/destroy failed) |

### Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| HCLOUD_TOKEN | Hetzner Cloud API token | Yes |
| TF_VAR_ssh_key_path | Override SSH key path | No (default: auto-detect) |
| TF_VAR_location | Override region | No (default: hil) |

---

## 2. Terraform ↔ Ansible Inventory Contract

**Provider**: Terraform outputs + templatefile()
**Consumer**: Ansible playbooks

### Generated Inventory Format

```yaml
# infra/terraform/inventory.yml (generated, gitignored)
all:
  children:
    mgmt:
      hosts:
        mgmt01:
          ansible_host: <public_ip>
          ansible_user: root
          node_role: mgmt
          zone: management
    login:
      hosts:
        login01:
          ansible_host: <public_ip>
          ansible_user: root
          node_role: login
          zone: internal
    compute:
      hosts:
        compute01:
          ansible_host: 10.0.0.31
          ansible_user: root
          ansible_ssh_common_args: '-o ProxyJump=root@<mgmt01_public_ip>'
          node_role: compute
          zone: restricted
        compute02:
          ansible_host: 10.0.0.32
          ansible_user: root
          ansible_ssh_common_args: '-o ProxyJump=root@<mgmt01_public_ip>'
          node_role: compute
          zone: restricted
```

### Key Differences from Vagrant Inventory

| Aspect | Vagrant (spec 006) | Cloud (spec 007) |
|--------|-------------------|------------------|
| ansible_user | vagrant | root |
| Compute access | Direct (private network) | ProxyJump via mgmt01 |
| IP addresses | Static (192.168.56.x) | Dynamic (Terraform outputs) |

---

## 3. Wrapper Scripts ↔ Ansible Contract

**Provider**: Ansible CLI
**Consumer**: demo-cloud-up.sh

### Playbook Interface

| Playbook | Inventory Path | Expected Behavior |
|----------|---------------|-------------------|
| demo/playbooks/provision.yml | infra/terraform/inventory.yml | Configure all services (FreeIPA, Slurm, etc.) |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| ANSIBLE_CONFIG | Config path | demo/vagrant/ansible.cfg |
| ANSIBLE_HOST_KEY_CHECKING | Skip host key check | false (first run) |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success (all tasks ok or changed) |
| 2 | Playbook error (any task failed) |
| 4 | Unreachable hosts |

---

## 4. Makefile ↔ Scripts Contract

**Provider**: Wrapper scripts in infra/scripts/
**Consumer**: Root Makefile

### Make Targets

| Target | Script Called | Description |
|--------|--------------|-------------|
| demo-cloud-up | infra/scripts/demo-cloud-up.sh | Provision and configure cluster |
| demo-cloud-down | infra/scripts/demo-cloud-down.sh | Destroy cluster |
| demo-cloud-status | (inline) | Show cluster status and TTL |

### Script Location

Scripts must be at:
- `infra/scripts/demo-cloud-up.sh`
- `infra/scripts/demo-cloud-down.sh`

Scripts must be executable (`chmod +x`).

---

## 5. SSH Key Detection Contract

**Provider**: Local filesystem
**Consumer**: Terraform variables, wrapper scripts

### Detection Order

1. Check `$DEMO_SSH_KEY` environment variable
2. Check `~/.ssh/id_ed25519.pub`
3. Check `~/.ssh/id_rsa.pub`
4. Error with instructions if none found

### Error Message

```text
ERROR: No SSH public key found.
Expected locations:
  - ~/.ssh/id_ed25519.pub
  - ~/.ssh/id_rsa.pub
Or set DEMO_SSH_KEY=/path/to/key.pub
```

---

## 6. TTL Warning Contract

**Provider**: Hetzner resource labels
**Consumer**: Wrapper scripts

### Label Format

```text
created_at = "2026-02-15T14:30:00Z"
ttl = "4h"
```

### Warning Logic

1. On any make target, query Hetzner API: `hcloud server list --selector cluster=rcd-demo -o json`
2. Parse `created_at` label from first server
3. Calculate elapsed time
4. If elapsed > TTL threshold, print warning to stderr:

```text
⚠️  WARNING: Demo cluster has been running for 5h 23m (TTL: 4h)
   Estimated cost so far: €0.16
   Run 'make demo-cloud-down' when finished to stop billing.
```

### No Warning Conditions

- No cluster exists (empty response)
- Elapsed time < TTL threshold
- TTL check disabled via `DEMO_SKIP_TTL_CHECK=1`

---

## 7. Cost Estimation Contract

**Provider**: Hardcoded rates in script
**Consumer**: demo-cloud-up.sh output

### Display Format (on spin-up)

```text
📊 Estimated cost:
   - 4 VMs: €0.030/hour (~€0.72/day)
   - Network: €0.00 (included)
   - Total: €0.030/hour

💡 Remember to run 'make demo-cloud-down' when finished!
```

### Rates (as of 2026-02)

| Resource | Rate |
|----------|------|
| CPX21 (4GB) | €0.0119/hr |
| CPX11 (2GB) | €0.0059/hr |
| Private Network | €0.00 |
| Public IPv4 | Included with server |
