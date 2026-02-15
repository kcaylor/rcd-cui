# RCD-CUI Constitution

<!--
SYNC IMPACT REPORT - Constitution v1.0.0
Created: 2026-02-14

Version Change: [NEW] → 1.0.0
Reason: Initial constitution creation for Research Computing CUI compliance framework

Principles Established:
1. Plain Language First - Communication accessibility for all stakeholders
2. Data Model as Source of Truth - Single source structured data
3. Compliance as Code - Verifiable, auditable Ansible implementations
4. HPC-Aware - Explicit handling of HPC/security conflicts
5. Multi-Framework - NIST 800-171 Rev 2/3, CMMC Level 2, NIST 800-53 Rev 5
6. Audience-Aware Documentation - Per-audience generated documentation
7. Idempotent and Auditable - Three-mode Ansible roles (implement/verify/evidence)
8. Prefer Established Tools - Leverage proven security tooling ecosystem

Tech Stack Section: Defined Ansible, Python, YAML, Jinja2, Markdown stack with target platforms

Governance Section: Defined amendment process, version policy, and compliance review expectations

Templates Requiring Updates:
✅ plan-template.md - Constitution Check section uses this file
✅ spec-template.md - No specific changes required (generic requirements framework)
✅ tasks-template.md - No specific changes required (generic task organization)

Follow-up Items: None - all placeholders resolved
-->

## Core Principles

### I. Plain Language First

Every artifact produced by this framework—code comments, configuration files, role READMEs, compliance reports, system security plans—MUST be understandable by non-security-experts. Our stakeholders include Principal Investigators (PIs), the Vice Chancellor for Research (VCR), system administrators, CISO/security staff, researchers, and external auditors.

**Requirements:**
- No jargon without a corresponding glossary definition
- No acronym without expansion on first use in each document
- Technical controls must include plain-language explanations of purpose and impact
- Audit reports must summarize compliance posture in executive-friendly language

**Rationale**: CUI compliance requires organizational buy-in across technical and non-technical stakeholders. If a PI cannot understand what controls protect their research data and why, they cannot make informed decisions about data handling. If the VCR cannot understand compliance posture, they cannot allocate resources effectively.

### II. Data Model as Source of Truth

The control mapping YAML (`control_mapping.yml`), glossary (`terms.yml`), HPC tailoring decisions, and Organization-Defined Parameter (ODP) values are the authoritative structured data sources. Everything else—documentation, Ansible tags, compliance reports, framework crosswalks—is generated from these files.

**Requirements:**
- MUST NOT duplicate control text, mappings, or ODP values across multiple files
- All documentation generation scripts MUST consume structured YAML sources
- Changes to control implementations or mappings MUST be made in YAML, not in generated artifacts
- Version control applies to data model files; generated artifacts are ephemeral

**Rationale**: Duplicated data leads to inconsistency, especially across multiple compliance frameworks. A single change to an ODP value (e.g., password complexity requirements) must propagate to NIST 800-171 Rev 2, Rev 3, CMMC Level 2, and 800-53 Rev 5 mappings, SSP documentation, and Ansible role parameters. The data model enforces this single source of truth.

### III. Compliance as Code

Security controls are expressed as Ansible roles with verifiable, auditable implementations. Every role maps to specific NIST controls via tags and metadata. Every task is tagged with control identifiers. Compliance posture is measurable at any time by running Ansible playbooks.

**Requirements:**
- Every Ansible role MUST declare which NIST 800-171/800-53 controls it implements
- Every Ansible task MUST be tagged with control identifiers (e.g., `tags: ['AC-2', '800-171-3.1.1']`)
- Playbooks MUST support `--check` mode for validation without changes
- Roles MUST be idempotent: running twice produces identical state
- Control implementation status MUST be machine-readable from playbook runs

**Rationale**: "Compliance as Code" enables continuous compliance monitoring, automated evidence collection, and auditable change history via version control. Traditional manual compliance processes cannot scale to the dynamic nature of research computing environments.

### IV. HPC-Aware

Standard enterprise security controls often conflict with High-Performance Computing (HPC) performance and operational requirements. When conflicts arise, they MUST be explicitly documented with the tailored implementation and any compensating controls—never silently ignored or glossed over.

**Requirements:**
- MUST document every deviation from baseline security controls
- MUST provide technical justification for HPC-specific tailoring (e.g., performance impact, operational necessity)
- MUST specify compensating controls when baseline controls cannot be fully implemented
- MUST quantify impact where possible (e.g., "Full disk encryption reduces I/O throughput by 40% on parallel filesystems")

**Examples of HPC conflicts:**
- Audit logging on high-throughput parallel filesystems
- Interactive shell restrictions vs. interactive compute node access
- Session timeout policies vs. long-running batch jobs
- Full disk encryption vs. I/O performance on /scratch filesystems

**Rationale**: Research computing serves a unique mission. Blindly applying enterprise security controls can render HPC systems unusable for scientific workloads. Equally, ignoring security requirements puts CUI data at risk. Explicit tailoring and compensating controls demonstrate due diligence to auditors while maintaining operational effectiveness.

### V. Multi-Framework

This framework maps across NIST 800-171 Revision 2, NIST 800-171 Revision 3, CMMC Level 2, and NIST 800-53 Revision 5 simultaneously. NIST 800-171 Rev 2 is the current contractual compliance requirement for CUI protection. NIST 800-171 Rev 3 is the future state.

**Requirements:**
- Build for NIST 800-171 Rev 3 as the primary framework
- Maintain backward-compatible mappings to Rev 2 for current contract compliance
- Provide crosswalk mappings to CMMC Level 2 and NIST 800-53 Rev 5
- Control mapping YAML MUST include all four framework identifiers where applicable
- Reports MUST be generatable for any framework independently

**Rationale**: The transition from 800-171 Rev 2 to Rev 3 is inevitable but not yet mandated. Building for Rev 3 ensures forward compatibility while maintaining Rev 2 mappings ensures current contract compliance. CMMC and 800-53 mappings support reciprocity with other compliance regimes and provide additional implementation guidance.

### VI. Audience-Aware Documentation

The system serves multiple stakeholder groups with different needs: Principal Investigators (researchers), system administrators, CISO/security staff, university leadership (VCR), and external auditors. Documentation is generated per-audience from shared source data, not manually duplicated.

**Requirements:**
- MUST generate audience-specific views from single source data model
- PI documentation: Plain-language data handling requirements, researcher responsibilities
- Sys admin documentation: Implementation procedures, troubleshooting, operational playbooks
- CISO documentation: Control implementation status, risk register, audit evidence
- VCR documentation: Executive summary, compliance posture, resource requirements
- Auditor documentation: Control narratives, evidence artifacts, test procedures

**Rationale**: Each audience needs the same underlying compliance information presented differently. PIs need to understand their responsibilities without wading through technical implementation details. Auditors need evidence traceability without researcher-facing plain-language summaries. Generating all views from shared data ensures consistency while optimizing comprehension per audience.

### VII. Idempotent and Auditable

Every Ansible role has three task files: `main.yml` (implement controls), `verify.yml` (audit compliance without making changes), and `evidence.yml` (collect artifacts for System Security Plan). All three are idempotent. All work in `--check` mode.

**Requirements:**
- `main.yml`: Implements security controls, brings system into compliant state
- `verify.yml`: Checks compliance status, reports deviations, makes NO changes to system
- `evidence.yml`: Collects evidence artifacts (logs, config files, reports) for SSP and audits
- All task files MUST be idempotent: running N times = same result as running once
- All task files MUST support `--check` mode (dry-run)
- All task files MUST produce structured output for reporting (JSON/YAML)

**Rationale**: Separation of implementation, verification, and evidence collection enables multiple operational modes: initial deployment, continuous compliance scanning, audit preparation, and change validation. Idempotency ensures roles can be run repeatedly (e.g., via cron or CI/CD) without unintended side effects. `--check` mode support enables safe pre-flight validation.

### VIII. Prefer Established Tools

Use ComplianceAsCode/OpenSCAP, Red Hat official Ansible roles, FreeIPA, Wazuh, auditd, and other well-established, actively-maintained security tooling. Do not reinvent capabilities that already exist in trusted, audited implementations.

**Requirements:**
- MUST evaluate existing tools before building custom implementations
- MUST prefer upstream security-focused projects (ComplianceAsCode, DISA STIGs, Red Hat roles)
- MUST document why custom implementation chosen if established tool rejected
- MUST contribute upstream where feasible (bug reports, patches, content)

**Approved tooling:**
- ComplianceAsCode (OpenSCAP content for RHEL)
- Red Hat/Ansible official security roles
- FreeIPA (identity management)
- Duo (multi-factor authentication)
- Wazuh (SIEM, file integrity monitoring, vulnerability detection)
- auditd (kernel-level audit logging)
- Slurm job scheduler (with security-focused configuration)

**Rationale**: Security tooling is complex and error-prone. Using established, audited, widely-deployed tools reduces risk and increases auditor confidence. Upstream projects benefit from broad community review and often have pre-built compliance mappings. Custom implementations should be rare and well-justified.

## Tech Stack

**Automation**: Ansible (roles, playbooks, dynamic inventory)
**Scripting**: Python 3.9+ (documentation generation, SPRS scoring, reporting)
**Data Models**: YAML (control mappings, glossary, ODP values, configuration)
**Templating**: Jinja2 (documentation, configuration generation)
**Documentation**: Markdown (generated from YAML sources)
**Target OS**: RHEL 9 / Rocky Linux 9 (FIPS-compliant base)
**Job Scheduler**: Slurm Workload Manager
**Identity Management**: FreeIPA (LDAP, Kerberos, certificate authority)
**Multi-Factor Authentication**: Duo Security
**SIEM**: Wazuh (centralized logging, file integrity monitoring, vulnerability scanning)
**Compliance Scanning**: OpenSCAP with ComplianceAsCode content

## Governance

**Amendment Process:**
- Proposed changes to this constitution MUST be documented as pull requests
- Changes MUST include impact analysis on existing roles, playbooks, and documentation
- Changes MUST include migration plan if breaking changes introduced
- Approval requires review by technical lead and security lead

**Version Policy:**
- MAJOR version: Backward-incompatible governance changes, principle removals, framework redefinitions
- MINOR version: New principles added, materially expanded guidance, new framework support
- PATCH version: Clarifications, wording improvements, typo fixes, non-semantic refinements

**Compliance Review:**
- All pull requests MUST verify compliance with constitution principles
- All new Ansible roles MUST map to control identifiers and include verify/evidence task files
- All new documentation MUST be generated from data model sources, not manually duplicated
- Complexity additions MUST be justified against "Prefer Established Tools" principle

**Version**: 1.0.0 | **Ratified**: 2026-02-14 | **Last Amended**: 2026-02-14
