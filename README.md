# RCD-CUI: Research Computing CUI Compliance Automation

[![CI](https://github.com/kcaylor/rcd-cui/actions/workflows/ci.yml/badge.svg)](https://github.com/kcaylor/rcd-cui/actions/workflows/ci.yml)
![SPRS Score](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fkcaylor.github.io%2Frcd-cui%2Fbadge-data.json&query=%24.sprs_score&label=SPRS&color=auto)
![Last Assessment](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fkcaylor.github.io%2Frcd-cui%2Fbadge-data.json&query=%24.last_assessment&label=Last%20Assessment&color=blue)

An Ansible-based framework for deploying and auditing NIST 800-171 compliant research computing infrastructure with CUI (Controlled Unclassified Information) protection.

## Overview

RCD-CUI provides:

- **35+ Ansible roles** implementing NIST 800-171 Rev 2/3 security controls
- **Multi-framework compliance** mappings to CMMC Level 2 and NIST 800-53 Rev 5
- **HPC-aware security** with tailored controls for high-performance computing environments
- **Automated assessment and reporting** including SPRS scoring and POA&M tracking
- **Audience-specific documentation** for PIs, researchers, sysadmins, CISO, and leadership

## Target Environment

- **OS**: RHEL 9 / Rocky Linux 9
- **Identity**: FreeIPA centralized authentication
- **HPC**: Slurm job scheduler, InfiniBand interconnect, Lustre/BeeGFS parallel filesystems
- **Containers**: Apptainer/Singularity with signed image verification

## Security Zones

The framework implements three security zones:

| Zone | Purpose | Controls Applied |
|------|---------|------------------|
| `management` | Infrastructure services, identity management | Full control set |
| `internal` | General research computing | Standard controls |
| `restricted` | CUI data processing (HPC clusters) | Enhanced controls + HPC tailoring |

## Role Categories

### Access Control (AC)
- `ac_login_banner` - Legal notice banners
- `ac_pam_access` - PAM-based access control lists
- `ac_rbac` - Role-based access control via sudoers
- `ac_selinux` - SELinux enforcement
- `ac_session_timeout` - Idle session termination
- `ac_ssh_hardening` - SSH daemon hardening
- `ac_usbguard` - USB device whitelisting

### Audit and Accountability (AU)
- `au_auditd` - Linux audit daemon configuration
- `au_chrony` - Time synchronization (NTP)
- `au_log_protection` - Audit log integrity
- `au_rsyslog` - Centralized logging
- `au_wazuh_agent` - SIEM agent deployment

### Configuration Management (CM)
- `cm_aide` - File integrity monitoring
- `cm_fips_mode` - FIPS 140-2 cryptographic mode
- `cm_kernel_hardening` - Kernel security parameters
- `cm_minimal_packages` - Package minimization
- `cm_openscap_baseline` - OpenSCAP remediation profiles
- `cm_service_hardening` - Systemd service security

### Identification and Authentication (IA)
- `ia_account_lifecycle` - Account provisioning/deprovisioning
- `ia_breakglass` - Emergency access procedures
- `ia_duo_mfa` - Multi-factor authentication
- `ia_freeipa_client` - FreeIPA enrollment
- `ia_password_policy` - Password complexity requirements
- `ia_ssh_ca` - SSH certificate authority

### System and Communications Protection (SC)
- `sc_luks_verification` - Disk encryption verification
- `sc_network_segmentation` - VLAN/zone isolation
- `sc_nftables` - Host-based firewall
- `sc_tls_enforcement` - TLS 1.2+ enforcement

### System and Information Integrity (SI)
- `si_clamav` - Malware scanning
- `si_dnf_automatic` - Automated patching
- `si_openscap_oval` - Vulnerability scanning

### HPC-Specific Controls
- `hpc_slurm_cui` - CUI-aware Slurm partitions with prolog/epilog authorization
- `hpc_container_security` - Apptainer signed image verification
- `hpc_storage_security` - Parallel filesystem ACL synchronization
- `hpc_interconnect` - RDMA/InfiniBand compensating controls
- `hpc_node_lifecycle` - Compute node provisioning and sanitization

## Quick Start

### Prerequisites

- Python 3.9+
- Container runtime: `podman` (preferred) or `docker`
- `make`

### Setup

```bash
# Create local development environment
make env
source .venv/bin/activate

# Build the Ansible Execution Environment
make ee-build

# Install required Ansible collections
make collections
```

### Validation

```bash
# Run linting inside the execution environment
make ee-syntax-check
make ee-lint
make ee-yamllint
```

### Deployment

```bash
# Run playbooks via execution environment
make ee-shell
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

## Compliance Workflow

### Assessment and Reporting

```bash
# Run compliance assessment
make assess

# Generate SPRS score breakdown
make sprs

# Generate POA&M status report
make poam

# Generate HTML compliance dashboard
make dashboard

# Bundle auditor-ready package
make auditor-package
```

### Evidence Collection

```bash
# Collect compliance evidence
make evidence
```

### Documentation Generation

```bash
# Generate audience-specific documentation
make docs

# Generate framework crosswalk (CSV)
make crosswalk

# Validate all YAML schemas
make validate-schemas
```

## Project Onboarding/Offboarding

For CUI projects, automated onboarding and offboarding playbooks manage:

- FreeIPA project groups and user membership
- Slurm CUI partition access (QOS associations)
- Storage ACLs on parallel filesystems
- Container registry namespace permissions

```bash
# Onboard a new CUI project
ansible-playbook playbooks/onboard_project.yml -e project_name=myproject

# Offboard with 24-hour grace period
ansible-playbook playbooks/offboard_project.yml -e project_name=myproject
```

## Key Files

| Path | Purpose |
|------|---------|
| `roles/common/vars/control_mapping.yml` | NIST 800-171 control definitions and crosswalk |
| `docs/glossary/terms.yml` | Plain-language glossary (60+ terms) |
| `docs/hpc_tailoring.yml` | HPC-specific control modifications |
| `docs/odp_values.yml` | Organization-Defined Parameters (49 ODPs) |
| `execution-environment.yml` | Ansible Builder container definition |
| `inventory/group_vars/` | Zone-specific variables |

## Constitutional Principles

All implementations follow these core principles:

1. **Plain Language First** - All documentation understandable by non-experts
2. **Data Model as Source of Truth** - YAML data models generate all outputs
3. **Compliance as Code** - Security controls implemented as declarative Ansible
4. **HPC-Aware** - Tailored controls for research computing constraints
5. **Multi-Framework** - Support NIST 800-171 Rev 2/3, CMMC L2, NIST 800-53 R5
6. **Audience-Aware** - Documentation for 5 stakeholder types
7. **Idempotent and Auditable** - Repeatable operations with audit trails
8. **Prefer Established Tools** - Standard tooling (PyYAML, Pydantic, Jinja2)

## License

See LICENSE file for details.
