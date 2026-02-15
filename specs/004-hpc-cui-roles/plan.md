# Implementation Plan: HPC-Specific CUI Compliance Roles

**Branch**: `004-hpc-cui-roles` | **Date**: 2026-02-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-hpc-cui-roles/spec.md`

## Summary

Implement five HPC-specific Ansible roles and two automation playbooks that integrate CUI compliance with research computing operations. The roles address Slurm job scheduling security (prolog/epilog scripts), container runtime restrictions (Apptainer), parallel filesystem ACLs and monitoring (Lustre/BeeGFS), node lifecycle management (PXE, sanitization), and interconnect security documentation (InfiniBand RDMA exceptions). Researcher onboarding/offboarding automation ties these together with FreeIPA, Duo, and Slurm account management.

## Technical Context

**Language/Version**: Python 3.9+, Bash (POSIX-compliant for Slurm scripts)
**Primary Dependencies**: Ansible 2.15+, Slurm 23.x+, Apptainer 1.2+, FreeIPA client, Lustre/BeeGFS client tools
**Storage**: Lustre or BeeGFS parallel filesystem, local /tmp and /dev/shm for job scratch
**Testing**: Molecule (Ansible role testing), pytest (Python scripts), Slurm test partition
**Target Platform**: RHEL 9 / Rocky Linux 9 compute nodes, Slurm controller
**Project Type**: Ansible collection (roles + playbooks + plugins)
**Performance Goals**: Prolog overhead <30 seconds, epilog sanitization <60 seconds, ACL sync <5 minutes
**Constraints**: Must integrate with existing Specs 001-003 infrastructure, FIPS 140-2 compliant
**Scale/Scope**: 50-500 compute nodes, 10-50 concurrent CUI projects, 100-1000 researchers

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Plain Language First | PASS | FR-014, FR-020, FR-042 require plain language READMEs and PI welcome packets |
| II. Data Model as Source of Truth | PASS | FR-046 updates hpc_tailoring.yml; roles consume existing control_mapping.yml |
| III. Compliance as Code | PASS | All roles implement verifiable controls with Ansible tags; FR-013 integrates with evidence collection |
| IV. HPC-Aware | PASS | Entire spec addresses HPC-specific tailoring; FR-029-031 document interconnect exceptions |
| V. Multi-Framework | PASS | Roles map to NIST 800-171 controls via Spec 001 data model |
| VI. Audience-Aware Documentation | PASS | Separate docs for researchers (FR-020), PIs (FR-042), admins (role READMEs) |
| VII. Idempotent and Auditable | PASS | All roles follow main.yml/verify.yml/evidence.yml pattern from constitution |
| VIII. Prefer Established Tools | PASS | Uses Slurm, Apptainer, FreeIPA, Lustre, nvidia-smi - no custom security tooling |

**Gate Result**: PASS - All 8 principles satisfied. Proceeding to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/004-hpc-cui-roles/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── README.md        # Internal contracts (no external APIs)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
roles/
├── hpc_slurm_cui/
│   ├── tasks/
│   │   ├── main.yml           # Configure Slurm partition, deploy prolog/epilog
│   │   ├── verify.yml         # Verify partition config and script deployment
│   │   └── evidence.yml       # Collect job accounting evidence
│   ├── templates/
│   │   ├── slurm_prolog.sh.j2      # Authorization check, audit logging
│   │   ├── slurm_epilog.sh.j2      # Memory scrub, GPU reset, health check
│   │   └── cui_partition.conf.j2   # Slurm partition configuration
│   ├── files/
│   │   └── README_researchers.md   # Plain language CUI partition guide
│   ├── defaults/main.yml
│   ├── vars/main.yml
│   └── meta/main.yml
│
├── hpc_container_security/
│   ├── tasks/
│   │   ├── main.yml           # Configure Apptainer security
│   │   ├── verify.yml         # Verify container restrictions
│   │   └── evidence.yml       # Collect container execution logs
│   ├── templates/
│   │   ├── apptainer.conf.j2       # Security configuration
│   │   └── container_wrapper.sh.j2 # Execution logging wrapper
│   ├── files/
│   │   └── README_containers.md    # Researcher container guide
│   ├── defaults/main.yml
│   ├── vars/main.yml
│   └── meta/main.yml
│
├── hpc_storage_security/
│   ├── tasks/
│   │   ├── main.yml           # Configure filesystem security
│   │   ├── verify.yml         # Verify ACLs and quotas
│   │   └── evidence.yml       # Collect changelog evidence
│   ├── templates/
│   │   ├── lustre_changelog.conf.j2  # Changelog monitoring config
│   │   └── sanitize_project.sh.j2    # Data sanitization script
│   ├── files/
│   │   └── acl_sync.py             # ACL-FreeIPA sync script
│   ├── defaults/main.yml
│   ├── vars/main.yml
│   └── meta/main.yml
│
├── hpc_interconnect/
│   ├── tasks/
│   │   ├── main.yml           # Generate exception documentation
│   │   ├── verify.yml         # Verify compensating controls
│   │   └── evidence.yml       # Collect boundary evidence
│   ├── templates/
│   │   ├── rdma_exception.md.j2    # Exception document template
│   │   └── compensating_controls.md.j2
│   ├── defaults/main.yml
│   ├── vars/main.yml
│   └── meta/main.yml
│
└── hpc_node_lifecycle/
    ├── tasks/
    │   ├── main.yml           # Configure node lifecycle
    │   ├── verify.yml         # Verify node compliance
    │   └── evidence.yml       # Collect node state evidence
    ├── templates/
    │   ├── first_boot.sh.j2        # Post-PXE compliance scan
    │   ├── health_check.sh.j2      # Inter-job health check
    │   └── sanitize_node.sh.j2     # NIST 800-88 sanitization
    ├── defaults/main.yml
    ├── vars/main.yml
    └── meta/main.yml

playbooks/
├── onboard_project.yml        # CUI project onboarding automation
├── offboard_project.yml       # CUI project offboarding automation
└── vars/
    └── onboarding_defaults.yml

templates/
└── pi_welcome_packet.md.j2    # Plain language PI instructions

docs/
├── hpc_tailoring.yml          # Updated with implementation details (FR-046)
└── researcher_quickstart.md   # Updated with HPC instructions (FR-047)

tests/
├── integration/
│   ├── test_slurm_prolog.py
│   ├── test_container_security.py
│   └── test_storage_acls.py
└── molecule/
    ├── hpc_slurm_cui/
    ├── hpc_container_security/
    ├── hpc_storage_security/
    ├── hpc_interconnect/
    └── hpc_node_lifecycle/
```

**Structure Decision**: Ansible collection structure with 5 HPC-specific roles following the existing pattern from Specs 001-002. Each role has main/verify/evidence task files per Constitution Principle VII. Playbooks for onboarding/offboarding are separate from roles to allow flexible composition.

## Complexity Tracking

> No violations to justify - all constitution principles satisfied.

| Aspect | Complexity Level | Justification |
|--------|-----------------|---------------|
| Role count | 5 new roles | Each maps to distinct HPC subsystem; cannot be combined without violating separation of concerns |
| Script languages | Bash + Python | Bash required for Slurm prolog/epilog; Python for complex ACL sync logic |
| Filesystem support | Lustre + BeeGFS | Spec requires both; abstraction layer handles differences |
