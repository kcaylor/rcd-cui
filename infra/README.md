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

- **Docker** (only requirement - all tools run inside a container)
- Hetzner Cloud API token

All other tools (Terraform, Ansible, hcloud CLI) are bundled in a Docker image that builds automatically on first run.

## Hetzner Setup

1. Create a project in [Hetzner Cloud Console](https://console.hetzner.cloud/)
2. Generate an API token (Security → API Tokens → Generate API Token)
3. Configure credentials using `.env` file (recommended):

```bash
cd infra
cp .env.example .env
# Edit .env and add your HCLOUD_TOKEN
```

Or export directly:

```bash
export HCLOUD_TOKEN="<your-token>"
```

Optional overrides (in `.env` or environment):

```bash
TF_VAR_location="hil"          # default: hil (Hillsboro)
TF_VAR_ttl_hours="4"           # default: 4
TF_VAR_ssh_key_path="~/.ssh/id_ed25519.pub"
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

## Docker Image

All tools run inside a Docker container. The image builds automatically on first `make demo-cloud-*` command.

Rebuild the image manually (after Dockerfile changes):

```bash
make demo-docker-build
```

Image contents:

- Terraform 1.7.5
- Ansible 9.x (ansible-core 2.16.x)
- hcloud CLI 1.42.0
- Python 3.12
- ssh-keygen, jq, git

## Troubleshooting

### `Docker is not installed` or `Docker daemon is not running`

Install and start Docker Desktop, then retry.

### `HCLOUD_TOKEN is not set`

Add token to `infra/.env`:

```bash
cp infra/.env.example infra/.env
# Edit .env and add your HCLOUD_TOKEN
```

### `No SSH public key found`

On first run, you'll be prompted to generate a dedicated demo SSH key.
Accept the prompt, or provide your own key:

```bash
# Option 1: Accept the prompt to generate infra/.ssh/demo_ed25519
# Option 2: Set in .env
TF_VAR_ssh_key_path=~/.ssh/id_ed25519.pub
```

### `Cluster already exists`

```bash
make demo-cloud-down
```

### Ansible provisioning fails

Re-run just the provisioning step:

```bash
./infra/scripts/docker-run.sh ansible-playbook \
  -i infra/terraform/inventory.yml \
  demo/playbooks/provision.yml
```

### Compute nodes are unreachable directly

They do not have public IPs by design. Use ProxyJump:

```bash
ssh -J root@<mgmt01-public-ip> root@10.0.0.31
ssh -J root@<mgmt01-public-ip> root@10.0.0.32
```
