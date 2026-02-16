# Research: Cloud Demo Infrastructure

**Feature**: 007-cloud-demo-infra
**Date**: 2026-02-15

## Technology Decisions

### 1. Hetzner Cloud Provider

**Decision**: Use Hetzner Cloud with official Terraform provider

**Rationale**:
- 5x cheaper than DigitalOcean/Vultr for equivalent specs (~€0.007/hr vs $0.036/hr per VM)
- US West (Hillsboro) datacenter available for west coast latency
- Rocky Linux 9 available as base image (matches spec 006 Vagrant demo)
- Terraform provider is mature and well-documented (hetznercloud/hcloud)
- API supports all required features: VMs, private networks, SSH keys, labels

**Alternatives Considered**:
- DigitalOcean: Excellent Terraform support but 5x more expensive
- Vultr: Similar pricing to DO, less mature Terraform provider
- AWS/GCP: Overkill for demo use case, complex IAM setup

### 2. Terraform for Infrastructure

**Decision**: Use Terraform with local state (optional Terraform Cloud)

**Rationale**:
- Industry standard IaC tool, aligns with constitution principle VIII
- Hetzner provider is first-party maintained
- Local state is sufficient for single-user demo workflow
- State file enables cluster detection (FR-006a: block duplicate spin-up)
- Terraform Cloud option for team usage without additional complexity

**Alternatives Considered**:
- Pulumi: More complex, requires additional runtime
- Ansible cloud modules: Less idiomatic for provisioning, better for config
- Hetzner CLI (hcloud): Not declarative, harder to ensure idempotency

### 3. Dynamic Inventory Generation

**Decision**: Terraform template file generates Ansible inventory YAML

**Rationale**:
- Terraform `local_file` resource with `templatefile()` function
- Inventory format matches spec 006 structure (groups: mgmt, login, compute)
- IPs injected from Terraform outputs, no manual editing
- Inventory file path: `infra/terraform/inventory.yml` (gitignored)

**Alternatives Considered**:
- Ansible dynamic inventory script: Additional complexity, another tool
- Manual inventory: Error-prone, defeats automation purpose
- Terraform output JSON + jq: Extra step in workflow

### 4. SSH Key Auto-Detection

**Decision**: Check for `~/.ssh/id_ed25519.pub` first, fall back to `~/.ssh/id_rsa.pub`

**Rationale**:
- Ed25519 is modern, recommended default
- RSA fallback for legacy key users
- Error with clear message if neither exists
- Environment variable override: `DEMO_SSH_KEY` for non-standard paths

**Alternatives Considered**:
- Require explicit path: More friction for common case
- Generate ephemeral key: Security concern, key management burden
- Use Hetzner-managed SSH keys: Requires pre-registration in console

### 5. TTL Warning Implementation

**Decision**: Check creation timestamp on each make target, warn if exceeded

**Rationale**:
- Terraform resource labels store creation timestamp
- Each wrapper script checks `hcloud server list --selector` for TTL
- Warning printed to stderr, does not block operation
- No external services required (no Slack/email webhooks)

**Alternatives Considered**:
- Background daemon: Complex, may not be running when user returns
- Email/webhook notification: External dependency, setup friction
- Auto-teardown: Too aggressive, could interrupt active demo

### 6. Cluster Detection (Single Cluster Enforcement)

**Decision**: Check Terraform state for existing resources before spin-up

**Rationale**:
- `terraform state list` returns empty if no cluster exists
- Non-empty state blocks spin-up with clear message
- User must run teardown to proceed
- Prevents orphaned resources and billing surprises

**Alternatives Considered**:
- Allow multiple clusters with unique names: Increases cost risk, complexity
- Auto-teardown before spin-up: Could destroy active demo accidentally
- Hetzner API check only: State file is more reliable for our workflow

### 7. VM Sizing

**Decision**: Use Hetzner CPX series (shared vCPU, cost-optimized)

**Rationale**:
- mgmt01: CPX21 (3 vCPU, 4GB) - FreeIPA, Wazuh, Slurm controller, NFS
- login01: CPX11 (2 vCPU, 2GB) - SSH gateway, Slurm submit
- compute01/02: CPX11 (2 vCPU, 2GB) - Slurm workers

**Cost breakdown** (US West, per hour):
- CPX21: €0.0119/hr
- CPX11: €0.0059/hr × 3 = €0.0177/hr
- Network: €0.00 (private network free)
- **Total: ~€0.03/hr** (~$0.03/hr)

**Alternatives Considered**:
- Dedicated vCPU (CCX): 3x more expensive, not needed for demos
- Smaller instances: FreeIPA needs 4GB minimum for stability
- Larger instances: Unnecessary for demo workloads

### 8. Network Architecture

**Decision**: Private network 10.0.0.0/24, public IPs on mgmt01 and login01 only

**Rationale**:
- Private network for inter-node communication (NFS, Slurm, FreeIPA)
- Public IP on mgmt01 for admin access
- Public IP on login01 for workshop attendee SSH access
- Compute nodes internal-only (realistic HPC topology)
- Matches spec 006 Vagrant network design

**Alternatives Considered**:
- All public IPs: Unnecessary exposure, additional cost
- Single public IP + bastion: Extra hop, latency for demos
- IPv6 only: Not universally accessible from all networks

### 9. OS Image

**Decision**: Rocky Linux 9 (Hetzner standard image)

**Rationale**:
- Matches spec 006 Vagrant demo for consistency
- RHEL-compatible, required for FreeIPA, Wazuh, compliance roles
- Hetzner maintains official Rocky 9 image
- Aligns with constitution target OS (RHEL 9 / Rocky Linux 9)

**Alternatives Considered**:
- AlmaLinux 9: Equivalent, but Rocky is spec 006 standard
- Fedora: Not enterprise-stable, shorter support lifecycle
- Ubuntu: Different package ecosystem, would require playbook changes

### 10. Wrapper Script Design

**Decision**: Bash scripts calling Terraform and Ansible with progress output

**Rationale**:
- `demo-cloud-up.sh`: terraform apply → generate inventory → ansible-playbook provision.yml
- `demo-cloud-down.sh`: confirm prompt → terraform destroy
- Colored output with status messages (matching spec 006 demo scripts)
- Exit codes: 0=success, 1=terraform fail, 2=ansible fail, 3=validation fail

**Alternatives Considered**:
- Makefile only: Less flexibility for progress output and validation
- Python wrapper: Overkill for simple orchestration
- Direct terraform/ansible: User must remember multiple commands
