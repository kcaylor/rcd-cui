# Implementation Plan: Core Ansible Roles for NIST 800-171 Controls

**Branch**: `002-ansible-roles-core-controls` | **Date**: 2026-02-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/002-ansible-roles-core-controls/spec.md`
**Depends On**: [Spec 001 - Data Models and Documentation Foundation](../001-data-models-docs-foundation/spec.md)

## Summary

Implement core Ansible roles covering 6 NIST 800-171 control families (AU, IA, AC, CM, SC, SI) for a CUI-compliant research computing enclave. Each role follows the three-mode pattern (main.yml for implementation, verify.yml for compliance checking, evidence.yml for SSP artifact collection) with zone-aware configurations supporting management, internal, restricted, and public security zones. Roles integrate with infrastructure established by Spec 001 data models and leverage established tools (auditd, FreeIPA, Duo, Wazuh, OpenSCAP, nftables) per constitution principles.

## Technical Context

**Language/Version**: Ansible 2.15+ / YAML 1.2 / Jinja2 3.x (per constitution tech stack)
**Primary Dependencies**: ansible-core, ansible-lint, yamllint, ComplianceAsCode/scap-security-guide, Wazuh agent, Duo PAM, FreeIPA client
**Storage**: N/A (configuration management, no persistent data storage)
**Testing**: ansible-lint, yamllint, Molecule (role testing), OpenSCAP CUI profile assessment
**Target Platform**: RHEL 9 / Rocky Linux 9 (per constitution)
**Project Type**: Ansible roles within existing project structure from Spec 001
**Performance Goals**: Deploy all roles to fresh RHEL 9 VM in <20 minutes, verify.yml completes in <2 minutes per host, >85% OpenSCAP CUI compliance on first run
**Constraints**: Zone-aware (4 zones), HPC-compatible (no session timeout on compute nodes, minimal audit overhead), FIPS mode required, --check mode support for all tasks, idempotent execution
**Scale/Scope**: 24 Ansible roles across 6 control families, ~47 functional requirements, 4 security zones

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Plain Language First
✅ **PASS** - FR-042 requires every Ansible task include plain-language comment explaining WHY (not what). FR-040 requires README.md with "What This Does" section. FR-039 requires templates with plain-language header blocks.

### Principle II: Data Model as Source of Truth
✅ **PASS** - FR-044 requires roles update control_mapping.yml from Spec 001. Roles consume ODP values and HPC tailoring decisions from YAML data models. No duplicated control text.

### Principle III: Compliance as Code
✅ **PASS** - FR-035 requires all tasks tagged with control identifiers (r2_X.X.X, r3_XX.XX.XX, cmmc_XX, family_XX, zone_XX). FR-043 requires --check mode support. FR-045/FR-046 require ansible-lint and yamllint validation.

### Principle IV: HPC-Aware
✅ **PASS** - FR-050 requires OpenSCAP skip HPC-conflicting remediations. User Story 2 explicitly addresses MFA without breaking batch jobs. User Story 3 addresses session timeout exemptions for compute nodes. Audit rules zone-aware per FR-002.

### Principle V: Multi-Framework
✅ **PASS** - FR-035 requires task tags include all framework identifiers (NIST 800-171 Rev 2/3, CMMC L2, 800-53 R5). Roles map to control_mapping.yml which contains all four frameworks per Spec 001.

### Principle VI: Audience-Aware Documentation
✅ **PASS** - FR-040 requires README.md per audience-aware template. evidence.yml tasks (FR-037) produce artifacts for auditor audience. verify.yml tasks (FR-036) produce output for sysadmin audience.

### Principle VII: Idempotent and Auditable
✅ **PASS** - Three-mode roles explicitly required: main.yml (FR-035), verify.yml (FR-036), evidence.yml (FR-037). Idempotency requirement implicit in Ansible role design. FR-043 requires --check mode.

### Principle VIII: Prefer Established Tools
✅ **PASS** - Spec explicitly requires: auditd, rsyslog, Wazuh, FreeIPA, Duo, OpenSCAP/ComplianceAsCode, nftables, ClamAV, AIDE. No custom security tooling. All tools from constitution approved list.

**Gate Status**: ✅ ALL PRINCIPLES SATISFIED - Proceed to Phase 0 Research

## Project Structure

### Documentation (this feature)

```text
specs/002-ansible-roles-core-controls/
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0 output (technology decisions)
├── data-model.md        # Phase 1 output (role variable schemas)
├── quickstart.md        # Phase 1 output (deployment guide)
├── contracts/           # Phase 1 output (N/A - no APIs, role interfaces documented in data-model.md)
│   └── README.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

This feature adds Ansible roles to the existing project structure from Spec 001:

```text
rcd-cui/
├── roles/                                # Ansible roles directory
│   ├── common/
│   │   └── vars/
│   │       └── control_mapping.yml       # FROM SPEC 001 - updated with role references
│   │
│   ├── au_auditd/                        # Audit & Accountability roles
│   │   ├── defaults/main.yml
│   │   ├── tasks/
│   │   │   ├── main.yml
│   │   │   ├── verify.yml
│   │   │   └── evidence.yml
│   │   ├── handlers/main.yml
│   │   ├── templates/
│   │   │   └── audit.rules.j2
│   │   ├── meta/main.yml
│   │   └── README.md
│   ├── au_rsyslog/
│   ├── au_chrony/
│   ├── au_wazuh_agent/
│   ├── au_log_protection/
│   │
│   ├── ia_freeipa_client/                # Identification & Authentication roles
│   ├── ia_duo_mfa/
│   ├── ia_ssh_ca/
│   ├── ia_password_policy/
│   ├── ia_account_lifecycle/
│   ├── ia_breakglass/
│   │
│   ├── ac_pam_access/                    # Access Control roles
│   ├── ac_rbac/
│   ├── ac_ssh_hardening/
│   ├── ac_session_timeout/
│   ├── ac_login_banner/
│   ├── ac_usbguard/
│   ├── ac_selinux/
│   │
│   ├── cm_openscap_baseline/             # Configuration Management roles
│   ├── cm_fips_mode/
│   ├── cm_minimal_packages/
│   ├── cm_service_hardening/
│   ├── cm_kernel_hardening/
│   ├── cm_aide/
│   │
│   ├── sc_nftables/                      # System & Communications Protection roles
│   ├── sc_tls_enforcement/
│   ├── sc_fips_crypto_policies/
│   ├── sc_luks_verification/
│   ├── sc_network_segmentation/
│   │
│   ├── si_dnf_automatic/                 # System & Information Integrity roles
│   ├── si_clamav/
│   ├── si_aide/
│   └── si_openscap_oval/
│
├── playbooks/                            # Site playbooks
│   ├── site.yml                          # Full deployment
│   ├── verify.yml                        # Compliance verification
│   ├── evidence.yml                      # SSP artifact collection
│   └── zone_specific/
│       ├── management.yml
│       ├── internal.yml
│       ├── restricted.yml
│       └── public.yml
│
├── inventory/                            # FROM SPEC 001 - updated with zone groups
│   ├── hosts.yml
│   └── group_vars/
│       ├── all.yml                       # Common variables
│       ├── management.yml                # Management zone overrides
│       ├── internal.yml                  # Internal zone overrides
│       ├── restricted.yml                # Restricted zone (compute nodes)
│       └── public.yml                    # Public zone
│
├── docs/                                 # FROM SPEC 001
│   ├── hpc_tailoring.yml                 # Referenced for HPC conflict handling
│   └── odp_values.yml                    # Consumed for password policy, timeouts, etc.
│
└── tests/                                # FROM SPEC 001 - extended
    ├── molecule/                         # Molecule role tests
    │   ├── default/
    │   │   ├── molecule.yml
    │   │   ├── converge.yml
    │   │   └── verify.yml
    │   └── openscap/
    │       └── verify.yml                # OpenSCAP CUI profile validation
    └── lint/
        ├── ansible-lint.yml
        └── yamllint.yml
```

**Structure Decision**: Extend existing Ansible project structure from Spec 001. Roles organized by control family prefix (au_, ia_, ac_, cm_, sc_, si_) for clear NIST mapping. Each role follows standard Ansible structure with three-mode task files (main.yml, verify.yml, evidence.yml) per constitution Principle VII. Zone-specific playbooks and group_vars enable zone-aware deployment without duplicating role logic.

## Complexity Tracking

No constitution violations. All principles satisfied:
- ✅ Established tools (auditd, FreeIPA, Duo, Wazuh, OpenSCAP, nftables, ClamAV, AIDE)
- ✅ Data model as source of truth (roles reference control_mapping.yml, odp_values.yml, hpc_tailoring.yml)
- ✅ Plain language first (README.md, task comments, template headers)
- ✅ HPC-aware (zone-specific configurations, tailoring respect)
- ✅ Three-mode roles (main/verify/evidence)
- ✅ Multi-framework tagging (r2_, r3_, cmmc_, family_, zone_)

No complexity justification required.
