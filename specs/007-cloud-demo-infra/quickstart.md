# Quickstart: Cloud Demo Infrastructure

**Feature**: 007-cloud-demo-infra
**Date**: 2026-02-15

## Prerequisites

### Local Tools

| Tool | Version | Installation |
|------|---------|--------------|
| Terraform | 1.5+ | `brew install terraform` |
| Ansible | 2.15+ | `brew install ansible` |
| hcloud CLI | latest | `brew install hcloud` (optional, for debugging) |

### Hetzner Cloud Account

1. Create account at https://console.hetzner.cloud/
2. Create a new project (e.g., "rcd-demo")
3. Generate API token: Security → API Tokens → Generate API Token
4. Save token securely (shown only once)

### SSH Key

Ensure you have an SSH keypair:

```bash
# Check for existing key
ls ~/.ssh/id_ed25519.pub || ls ~/.ssh/id_rsa.pub

# Generate if needed (Ed25519 recommended)
ssh-keygen -t ed25519 -C "your@email.com"
```

## Setup

### 1. Configure Hetzner Token

```bash
# Option A: Environment variable (session)
export HCLOUD_TOKEN="your-api-token-here"

# Option B: Add to shell profile (persistent)
echo 'export HCLOUD_TOKEN="your-api-token-here"' >> ~/.zshrc
source ~/.zshrc
```

### 2. Initialize Terraform

```bash
cd /Users/kellycaylor/dev/rcd-cui
cd infra/terraform
terraform init
```

## Usage

### Spin Up Demo Cluster

```bash
cd /Users/kellycaylor/dev/rcd-cui
make demo-cloud-up
```

This will:
1. Create 4 VMs in Hetzner US West (Hillsboro)
2. Configure private network (10.0.0.0/24)
3. Generate Ansible inventory
4. Run provisioning playbook (FreeIPA, Slurm, Wazuh, NFS)
5. Display SSH connection info

**Expected output:**

```text
🚀 Starting demo cluster provisioning...

📊 Estimated cost:
   - 4 VMs: €0.030/hour (~€0.72/day)
   - Network: €0.00 (included)

⏳ Creating infrastructure... (2-3 minutes)
✅ Terraform apply complete

⏳ Running Ansible provisioning... (15-20 minutes)
✅ Provisioning complete

🎉 Demo cluster ready!

SSH access:
  ssh root@<mgmt01-ip>    # Management node
  ssh root@<login01-ip>   # Login node

Run scenarios from: demo/playbooks/
```

### Tear Down Demo Cluster

```bash
make demo-cloud-down
```

This will:
1. Show resource count
2. Prompt for confirmation
3. Destroy all VMs and network
4. Confirm billing stopped

**Expected output:**

```text
🗑️  Preparing to destroy demo cluster...

Resources to destroy:
  - 4 servers (mgmt01, login01, compute01, compute02)
  - 1 network (demo-network)
  - 1 SSH key (demo-key)

⚠️  This action cannot be undone.
Continue? [y/N] y

⏳ Destroying resources...
✅ All resources destroyed

💰 Billing stopped. Cluster ran for 2h 15m (estimated cost: €0.07)
```

### Check Cluster Status

```bash
make demo-cloud-status
```

## Running Demo Scenarios

After cluster is up, run scenarios exactly as with Vagrant:

```bash
cd /Users/kellycaylor/dev/rcd-cui/demo/vagrant

# Use cloud inventory instead of local
export ANSIBLE_INVENTORY=../../infra/terraform/inventory.yml

# Scenario A: Project Onboarding
ansible-playbook ../playbooks/scenario-a-onboard.yml

# Scenario B: Compliance Drift
ansible-playbook ../playbooks/scenario-b-drift.yml --tags detect

# Scenario C: Auditor Package
ansible-playbook ../playbooks/scenario-c-audit.yml

# Scenario D: Node Lifecycle
ansible-playbook ../playbooks/scenario-d-lifecycle.yml --tags add
```

## Cost Reference

| Duration | Estimated Cost |
|----------|---------------|
| 1 hour | €0.03 |
| Half day (4h) | €0.12 |
| Full day (8h) | €0.24 |
| Forgot overnight (12h) | €0.36 |
| Left running 1 week | ~€5.00 |

**Tip**: TTL warnings appear after 4 hours. Always run `make demo-cloud-down` when finished.

## Troubleshooting

### "HCLOUD_TOKEN not set"

```bash
export HCLOUD_TOKEN="your-api-token-here"
```

### "No SSH key found"

```bash
# Check key exists
ls ~/.ssh/id_ed25519.pub

# Or specify custom path
export DEMO_SSH_KEY=/path/to/your/key.pub
```

### "Cluster already exists"

A cluster is already running. Tear it down first:

```bash
make demo-cloud-down
```

### Terraform state corrupted

```bash
cd infra/terraform
rm -rf .terraform terraform.tfstate*
terraform init
```

### Ansible provisioning fails

Check connectivity first:

```bash
# Get IPs from Terraform
cd infra/terraform
terraform output

# Test SSH
ssh root@<mgmt01-ip>
```

Re-run provisioning only:

```bash
cd demo/vagrant
ANSIBLE_INVENTORY=../../infra/terraform/inventory.yml \
  ansible-playbook ../playbooks/provision.yml
```

### Compute nodes unreachable

Compute nodes don't have public IPs. Access via ProxyJump:

```bash
ssh -J root@<mgmt01-ip> root@10.0.0.31  # compute01
ssh -J root@<mgmt01-ip> root@10.0.0.32  # compute02
```

## Workshop Mode (Multiple Attendees)

To give workshop attendees SSH access:

1. Collect their public SSH keys
2. Add to login01:

```bash
ssh root@<login01-ip>
cat >> /root/.ssh/authorized_keys << 'EOF'
<attendee1-public-key>
<attendee2-public-key>
EOF
```

3. Share the login01 IP with attendees
4. They can then interact with Slurm and shared storage

**Note**: All access is revoked when you run `make demo-cloud-down`.
