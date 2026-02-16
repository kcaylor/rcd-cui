# Implementation Plan: Vagrant Demo Lab Environment

**Branch**: `006-vagrant-demo-lab` | **Date**: 2026-02-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/006-vagrant-demo-lab/spec.md`

## Summary

Create a reproducible multi-VM demonstration environment using Vagrant with Rocky Linux 9 VMs that simulates an HPC cluster with FreeIPA, Wazuh, Slurm, and NFS. The lab enables interactive demonstrations of project onboarding, compliance drift detection/remediation, auditor package generation, and node lifecycle management without requiring production infrastructure.

## Technical Context

**Language/Version**: Bash (orchestration scripts), Ansible 2.15+ (provisioning), Ruby (Vagrantfile)
**Primary Dependencies**: Vagrant 2.3+, VirtualBox 7.0+ / libvirt / vagrant-qemu, Ansible
**Storage**: NFS shared storage on mgmt01, local VM disks via Vagrant
**Testing**: Manual verification via demo scripts, Ansible `--check` mode
**Target Platform**: macOS (Apple Silicon via QEMU x86 emulation, Intel via VirtualBox), Linux (libvirt/VirtualBox)
**Project Type**: Infrastructure/DevOps - demo environment with playbooks and scripts
**Performance Goals**: `vagrant up` < 30 minutes, `demo-reset.sh` < 5 minutes
**Constraints**: 16GB host RAM minimum, 100GB disk, air-gapped operation after initial setup
**Scale/Scope**: 4 VMs (mgmt01, login01, compute01, compute02), 4 demonstration scenarios

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Plain Language First | PASS | Demo narratives include talking points for non-technical audiences |
| II. Data Model as Source of Truth | PASS | Lab uses existing control_mapping.yml and glossary; no data duplication |
| III. Compliance as Code | PASS | All compliance controls implemented via Ansible roles with tags |
| IV. HPC-Aware | PASS | Lab simulates HPC environment with Slurm; demonstrates HPC-specific tailoring |
| V. Multi-Framework | PASS | Lab exercises existing multi-framework mappings via assessment playbooks |
| VI. Audience-Aware Documentation | PASS | Scenario narratives target presenter audience; lab generates auditor packages |
| VII. Idempotent and Auditable | PASS | All scenario playbooks are idempotent; demo-reset.sh returns to baseline |
| VIII. Prefer Established Tools | PASS | Uses FreeIPA, Wazuh, Slurm, auditd per approved tooling list |

**Gate Status**: PASS - All 8 principles satisfied

## Project Structure

### Documentation (this feature)

```text
specs/006-vagrant-demo-lab/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal contracts)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
demo/
├── vagrant/
│   ├── Vagrantfile              # Multi-VM lab definition
│   ├── ansible.cfg              # Ansible config for lab
│   └── inventory/
│       └── hosts.yml            # Dynamic/static inventory for VMs
├── scripts/
│   ├── demo-setup.sh            # Bring up lab, run provisioning
│   ├── demo-reset.sh            # Reset to baseline state
│   ├── demo-break.sh            # Introduce compliance violations
│   └── demo-fix.sh              # Run remediation playbooks
├── playbooks/
│   ├── provision.yml            # Initial VM provisioning
│   ├── scenario-a-onboard.yml   # Project Helios onboarding
│   ├── scenario-b-drift.yml     # Break/detect/fix cycle
│   ├── scenario-c-audit.yml     # Generate auditor package
│   └── scenario-d-lifecycle.yml # Node add/remove demonstration
└── narratives/
    ├── scenario-a.md            # Onboarding talking points
    ├── scenario-b.md            # Drift detection talking points
    ├── scenario-c.md            # Audit package talking points
    └── scenario-d.md            # Lifecycle management talking points
```

**Structure Decision**: Infrastructure demo project using demo/ directory tree isolated from main rcd-cui codebase. Playbooks leverage existing roles from roles/ directory.

## Complexity Tracking

No constitution violations requiring justification.
