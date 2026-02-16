# Cloud Demo Infrastructure (Spec 007)

This directory provides on-demand cloud infrastructure for the 4-node demo lab using Terraform + Hetzner Cloud.

## What It Provisions

- `mgmt01` (`cpx21`, public + private IP)
- `login01` (`cpx11`, public + private IP)
- `compute01` (`cpx11`, private IP only)
- `compute02` (`cpx11`, private IP only)
- private network `10.0.0.0/24` (within `10.0.0.0/8`)
- generated Ansible inventory at `infra/terraform/inventory.yml`

## Prerequisites

- Terraform `1.5+`
- Ansible `2.15+`
- Python `3` (used by TTL helper script)
- Hetzner Cloud API token
- SSH public key at one of:
  - `~/.ssh/id_ed25519.pub`
  - `~/.ssh/id_rsa.pub`
  - or set `DEMO_SSH_KEY=/path/to/key.pub`

## Hetzner Setup

1. Create a project in [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Generate an API token
3. Export the token:

```bash
export HCLOUD_TOKEN="<your-token>"
```

Optional overrides:

```bash
export TF_VAR_location="hil"          # default: hil (Hillsboro)
export TF_VAR_ttl_hours="4"           # default: 4
export DEMO_SSH_KEY="$HOME/.ssh/id_ed25519.pub"
```

## Commands

From repo root (`/Users/kellycaylor/dev/rcd-cui`):

```bash
make demo-cloud-up
make demo-cloud-status
make demo-cloud-down
```

Behavior:

- `demo-cloud-up`
  - blocks if an existing cluster is in Terraform state
  - runs `terraform init` + `terraform apply`
  - runs `demo/playbooks/provision.yml` against generated cloud inventory
  - prints SSH connection details
- `demo-cloud-down`
  - prints resources to destroy
  - prompts for confirmation
  - runs `terraform destroy`
  - prints runtime + cost estimate
- `demo-cloud-status`
  - prints cluster age, TTL status, and estimated cost

## Cost Model

Approximate Hetzner cost (Hillsboro):

- `cpx21`: `EUR 0.0119/hour`
- `cpx11` x3: `EUR 0.0177/hour`
- total: about `EUR 0.0296/hour` (`~EUR 0.71/day`)

TTL warning is set to `4h` by default and is shown on subsequent cloud commands when exceeded.

## Running Existing Demo Scenarios

Use the generated cloud inventory while keeping existing playbooks unchanged:

```bash
cd /Users/kellycaylor/dev/rcd-cui/demo/vagrant
export ANSIBLE_INVENTORY=../../infra/terraform/inventory.yml

ansible-playbook ../playbooks/scenario-a-onboard.yml
ansible-playbook ../playbooks/scenario-b-drift.yml
ansible-playbook ../playbooks/scenario-c-audit.yml
ansible-playbook ../playbooks/scenario-d-lifecycle.yml
```

Inventory details:

- `ansible_user: root` for all cloud hosts
- compute nodes use ProxyJump through `mgmt01`

## Workshop Attendee Access

After cluster provisioning:

1. Collect attendee public keys
2. Append keys on `login01`

```bash
ssh root@<login01-public-ip>
cat >> /root/.ssh/authorized_keys <<'EOF_KEYS'
ssh-ed25519 AAAA... attendee1
ssh-ed25519 AAAA... attendee2
EOF_KEYS
```

3. Share login node IP with attendees

Compute nodes remain private-only and are reached through management/login workflow.

## Troubleshooting

### `HCLOUD_TOKEN is not set`

```bash
export HCLOUD_TOKEN="<your-token>"
```

### `No SSH public key found`

```bash
ls ~/.ssh/id_ed25519.pub ~/.ssh/id_rsa.pub
# or
export DEMO_SSH_KEY=/path/to/key.pub
```

### `Cluster already exists`

```bash
make demo-cloud-down
```

### Terraform command not found

Install Terraform and verify:

```bash
terraform version
```

### Ansible provisioning fails

Re-run just the provisioning step:

```bash
cd /Users/kellycaylor/dev/rcd-cui/demo/vagrant
ANSIBLE_INVENTORY=../../infra/terraform/inventory.yml \
  ansible-playbook ../playbooks/provision.yml
```

### Compute nodes are unreachable directly

They do not have public IPs by design. Use ProxyJump:

```bash
ssh -J root@<mgmt01-public-ip> root@10.0.0.31
ssh -J root@<mgmt01-public-ip> root@10.0.0.32
```
