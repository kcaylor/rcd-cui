# Research: Vagrant Demo Lab Environment

**Feature**: 006-vagrant-demo-lab
**Date**: 2026-02-15

## Technology Decisions

### 1. Rocky Linux 9 Vagrant Box

**Decision**: Use `generic/rocky9` box from Vagrant Cloud

**Rationale**:
- Maintained by roboxes project with regular updates
- Available for multiple providers (VirtualBox, libvirt, VMware)
- Rocky Linux 9 matches production target OS per constitution
- Box includes guest additions for better performance

**Alternatives Considered**:
- `rockylinux/9` (official but less frequently updated)
- Building custom box (unnecessary complexity, slower setup)

### 2. Multi-Provider Vagrantfile

**Decision**: Single Vagrantfile with provider-specific blocks for VirtualBox, libvirt, and QEMU

**Rationale**:
- Vagrant supports provider detection and conditional configuration
- Same VM definitions work across all platforms
- Provider blocks handle virtualization-specific settings (nested virt, memory balloon, etc.)
- QEMU provider uses x86 emulation for Apple Silicon compatibility (per clarification)

**Alternatives Considered**:
- Separate Vagrantfiles per provider (harder to maintain, drift risk)
- Docker-based lab (doesn't simulate real VM behavior for compliance demos)

### 3. FreeIPA Installation

**Decision**: Use `freeipa-server` package with Ansible `community.general.ipa_*` modules

**Rationale**:
- FreeIPA is already in constitution's approved tooling
- Ansible modules provide idempotent installation and configuration
- Single-server deployment sufficient for demo (no HA complexity)
- DNS integrated with FreeIPA for hostname resolution

**Alternatives Considered**:
- External LDAP (doesn't demonstrate integrated identity management)
- Manual installation (not reproducible, violates Compliance as Code principle)

### 4. Slurm Minimal Configuration

**Decision**: Single slurmctld on mgmt01, slurmd on compute01/compute02, no database backend

**Rationale**:
- Minimal viable Slurm cluster for job submission demos
- SlurmDBD not required for basic scheduling demonstrations
- QOS can be configured via sacctmgr without database
- Reduces mgmt01 resource requirements

**Alternatives Considered**:
- Full Slurm with SlurmDBD/MariaDB (overkill for demo, adds 1GB+ RAM)
- PBS Pro (not as common in HPC, doesn't match production environment)

### 5. NFS Shared Storage

**Decision**: NFS server on mgmt01 exporting /shared, mounted on all nodes at /shared

**Rationale**:
- Simulates parallel filesystem behavior (Lustre/BeeGFS) for ACL demos
- Simple to configure and troubleshoot
- Supports POSIX ACLs for project directory permissions
- Works reliably across all Vagrant providers

**Alternatives Considered**:
- GlusterFS (complex for 4-node demo, slow provisioning)
- Local directories only (can't demonstrate shared storage ACLs)

### 6. Wazuh Minimal Deployment

**Decision**: Wazuh manager + agents (no Wazuh indexer/dashboard for MVP)

**Rationale**:
- Demonstrates log aggregation and file integrity monitoring
- Single-node manager fits on mgmt01 with other services
- Agents on all nodes send data to manager
- Indexer/dashboard can be added later but not required for core demos

**Alternatives Considered**:
- Full Wazuh stack (Wazuh + OpenSearch + Dashboard) - requires 8GB+ RAM
- OSSEC only (lacks modern features, harder to configure)

### 7. Ansible Provisioning Strategy

**Decision**: Vagrant Ansible provisioner with inventory generated from Vagrantfile

**Rationale**:
- Vagrant auto-generates inventory from VM definitions
- Single `provision.yml` playbook calls role-based configuration
- Roles from main rcd-cui project are reused directly
- `ansible.cfg` in demo/vagrant sets paths correctly

**Alternatives Considered**:
- Shell provisioners (not idempotent, violates constitution)
- External Ansible controller (adds complexity, requires extra setup)

### 8. Demo Script Architecture

**Decision**: Bash wrapper scripts that call Ansible playbooks with appropriate tags/variables

**Rationale**:
- Simple, portable, no additional dependencies
- Scripts handle Vagrant status checks before running playbooks
- Colored output and progress indicators for presenter experience
- Error handling with clear messages

**Alternatives Considered**:
- Python CLI (overkill for 4 scripts)
- Makefile targets (less clear error handling, harder to debug)

### 9. Baseline State for Reset

**Decision**: Vagrant snapshots via `vagrant snapshot` for fast reset

**Rationale**:
- VirtualBox and libvirt both support snapshots
- Push baseline snapshot after initial provisioning
- Pop snapshot restores exact state in seconds
- More reliable than Ansible rollback playbooks

**Alternatives Considered**:
- Ansible rollback playbook (slower, may miss state)
- Full vagrant destroy/up (violates 5-minute reset requirement)

### 10. Air-Gapped Operation

**Decision**: Cache RPM packages and container images during initial `vagrant up`

**Rationale**:
- Initial provisioning downloads all required packages
- Subsequent operations use cached packages
- Vagrant box itself is cached after first download
- Demo scenarios don't require internet access

**Alternatives Considered**:
- Local RPM mirror (complex setup, large storage)
- Pre-baked custom box (harder to maintain, less transparent)
