# Data Model: CUI Compliance Data Structures

**Feature**: 001-data-models-docs-foundation
**Date**: 2026-02-14
**Phase**: 1 - Design & Contracts

## Purpose

This document defines the complete data model for all YAML data structures in the CUI compliance framework. These YAML files are the single source of truth for control mappings, glossary terms, HPC tailoring decisions, and organization-defined parameters. All documentation, reports, and Ansible roles derive from these structures.

---

## File 1: Control Mapping (`roles/common/vars/control_mapping.yml`)

### Purpose
Canonical mapping of all NIST 800-171 Rev 2/3 controls to CMMC Level 2 and NIST 800-53 Rev 5, with metadata for automation, SPRS scoring, and HPC tailoring.

### Schema

#### Pydantic Model Definition
```python
from pydantic import BaseModel, Field, field_validator
from typing import List, Literal

class FrameworkMapping(BaseModel):
    """Cross-framework control mapping."""
    rev2_id: str = Field(description="NIST 800-171 Rev 2 control ID (e.g., '3.1.1')")
    rev3_id: str | None = Field(
        description="NIST 800-171 Rev 3 control ID or 'N/A'",
        default=None
    )
    rev3_rationale: str | None = Field(
        description="Required if rev3_id is 'N/A'",
        default=None
    )
    cmmc_l2_id: str | None = Field(
        description="CMMC Level 2 practice ID or 'N/A'",
        default=None
    )
    cmmc_l2_rationale: str | None = Field(
        description="Required if cmmc_l2_id is 'N/A'",
        default=None
    )
    nist_800_53_r5_id: List[str] = Field(
        description="NIST 800-53 Rev 5 source control IDs",
        default_factory=list
    )

    @field_validator('rev3_id', 'cmmc_l2_id')
    @classmethod
    def validate_na_has_rationale(cls, v, info):
        """Ensure 'N/A' mappings have rationale."""
        if v == "N/A":
            rationale_field = f"{info.field_name}_rationale"
            if not info.data.get(rationale_field):
                raise ValueError(
                    f"'{info.field_name}' is 'N/A' but '{rationale_field}' is missing"
                )
        return v

class SecurityControl(BaseModel):
    """Individual security control entry."""
    control_id: str = Field(description="Primary control identifier (Rev 2 format)")
    title: str = Field(description="Official control title")
    family: Literal[
        "AC", "AT", "AU", "CA", "CM", "IA", "IR", "MA",
        "MP", "PE", "PS", "RA", "SA", "SC", "SI"
    ] = Field(description="NIST control family")
    plain_language: str = Field(
        description="2-4 sentence explanation understandable by non-experts"
    )
    assessment_objectives: List[str] = Field(
        description="From NIST 800-171A assessment procedures"
    )
    sprs_weight: int = Field(
        ge=1, le=5,
        description="SPRS scoring weight (1=basic, 5=critical)"
    )
    automatable: bool = Field(
        description="Can this control be automated via Ansible?"
    )
    zones: List[Literal["management", "internal", "restricted", "public"]] = Field(
        description="Which security zones this control applies to"
    )
    framework_mapping: FrameworkMapping
    ansible_roles: List[str] = Field(
        default_factory=list,
        description="Ansible roles implementing this control (empty initially)"
    )
    hpc_tailoring_ref: str | None = Field(
        default=None,
        description="Reference to hpc_tailoring.yml entry if control requires HPC-specific implementation"
    )

class ControlMappingData(BaseModel):
    """Root data structure for control_mapping.yml."""
    version: str = Field(description="Data model version (semver)")
    last_updated: str = Field(description="ISO 8601 date")
    description: str = Field(description="Purpose of this file")
    controls: List[SecurityControl] = Field(min_length=110)

    @field_validator('controls')
    @classmethod
    def validate_control_count(cls, v):
        """Ensure all 110 Rev 2 controls present."""
        rev2_controls = [c for c in v if c.framework_mapping.rev2_id]
        if len(rev2_controls) < 110:
            raise ValueError(f"Expected 110 Rev 2 controls, found {len(rev2_controls)}")
        return v
```

#### YAML Example
```yaml
version: "1.0.0"
last_updated: "2026-02-14"
description: "Canonical mapping of NIST 800-171 Rev 2/3, CMMC L2, and 800-53 R5 controls"

controls:
  - control_id: "3.1.1"
    title: "Access Control Policy and Procedures"
    family: "AC"
    plain_language: |
      Establish and maintain formal policies and procedures for controlling who can
      access your systems and data. This includes documenting access control rules,
      reviewing them regularly, and training staff on proper access management.
    assessment_objectives:
      - "Access control policy addresses purpose, scope, roles, responsibilities"
      - "Access control procedures facilitate implementation of policy"
      - "Policy and procedures reviewed and updated at least annually"
    sprs_weight: 3
    automatable: false
    zones:
      - management
      - internal
      - restricted
    framework_mapping:
      rev2_id: "3.1.1"
      rev3_id: "03.01.01"
      rev3_rationale: null
      cmmc_l2_id: "AC.L2-3.1.1"
      cmmc_l2_rationale: null
      nist_800_53_r5_id:
        - "AC-1"
    ansible_roles: []  # Populated in future specs
    hpc_tailoring_ref: null

  - control_id: "3.1.2"
    title: "Account Management"
    family: "AC"
    plain_language: |
      Create, enable, modify, disable, and remove accounts according to documented
      procedures. Ensure accounts are only created when there is a valid business need,
      approved by management, and disabled when no longer required.
    assessment_objectives:
      - "Identify account types (individual, group, system, service)"
      - "Assign account managers for each account type"
      - "Establish conditions for group and role membership"
      - "Specify authorized users, access rights, and privileges"
    sprs_weight: 5
    automatable: true
    zones:
      - internal
      - restricted
    framework_mapping:
      rev2_id: "3.1.2"
      rev3_id: "03.01.02"
      rev3_rationale: null
      cmmc_l2_id: "AC.L2-3.1.2"
      cmmc_l2_rationale: null
      nist_800_53_r5_id:
        - "AC-2"
    ansible_roles: []
    hpc_tailoring_ref: null

  # ... (108 more controls) ...

  - control_id: "3.14.7"
    title: "Session Termination"
    family: "SC"
    plain_language: |
      Automatically terminate user sessions after a defined period of inactivity
      to prevent unauthorized access if a user walks away from their workstation
      without logging out.
    assessment_objectives:
      - "Automatically terminates network session after defined period of inactivity"
      - "Session lock distinct from screen lock (requires reauthentication)"
    sprs_weight: 4
    automatable: true
    zones:
      - internal
      - restricted
    framework_mapping:
      rev2_id: "3.14.7"
      rev3_id: "03.13.11"
      rev3_rationale: null
      cmmc_l2_id: "AC.L2-3.1.11"
      cmmc_l2_rationale: null
      nist_800_53_r5_id:
        - "AC-12"
    ansible_roles: []
    hpc_tailoring_ref: "session-timeout-compute-nodes"  # HPC conflict - batch jobs run for days

  # Example of control with no Rev 3 equivalent
  - control_id: "3.4.5"
    title: "Wireless Access Authentication and Encryption (Rev 2 only)"
    family: "CM"
    plain_language: |
      Protect wireless access by requiring authentication and encryption.
      Use WPA2 or WPA3 with strong passwords or certificate-based authentication.
    assessment_objectives:
      - "Wireless access to the system is authenticated"
      - "Wireless access to the system is encrypted"
    sprs_weight: 4
    automatable: true
    zones:
      - internal
      - restricted
    framework_mapping:
      rev2_id: "3.4.5"
      rev3_id: "N/A"
      rev3_rationale: "Consolidated into 03.01.17 (Wireless Access Authorization) in Rev 3"
      cmmc_l2_id: "AC.L2-3.1.16"
      cmmc_l2_rationale: null
      nist_800_53_r5_id:
        - "AC-18"
        - "SC-8(1)"
    ansible_roles: []
    hpc_tailoring_ref: null
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | ✅ | Semantic version of data model (e.g., "1.0.0") |
| `last_updated` | string (ISO 8601) | ✅ | Date of last update (YYYY-MM-DD) |
| `description` | string | ✅ | Human-readable purpose statement |
| `controls` | list | ✅ | Array of 110+ control entries |
| `control_id` | string | ✅ | Primary identifier (Rev 2 format: "3.X.Y") |
| `title` | string | ✅ | Official NIST control title |
| `family` | enum | ✅ | Control family (AC, AT, AU, CA, CM, IA, IR, MA, MP, PE, PS, RA, SA, SC, SI) |
| `plain_language` | string | ✅ | 2-4 sentence non-technical explanation |
| `assessment_objectives` | list[string] | ✅ | From NIST 800-171A assessment procedures |
| `sprs_weight` | integer (1-5) | ✅ | SPRS scoring weight (1=basic, 5=critical) |
| `automatable` | boolean | ✅ | Can be automated via Ansible? |
| `zones` | list[enum] | ✅ | Applicable zones (management, internal, restricted, public) |
| `framework_mapping.rev2_id` | string | ✅ | NIST 800-171 Rev 2 ID |
| `framework_mapping.rev3_id` | string | ❓ | NIST 800-171 Rev 3 ID or "N/A" |
| `framework_mapping.rev3_rationale` | string | ⚠️ | Required if rev3_id is "N/A" |
| `framework_mapping.cmmc_l2_id` | string | ❓ | CMMC Level 2 practice ID or "N/A" |
| `framework_mapping.cmmc_l2_rationale` | string | ⚠️ | Required if cmmc_l2_id is "N/A" |
| `framework_mapping.nist_800_53_r5_id` | list[string] | ✅ | Source controls from 800-53 R5 |
| `ansible_roles` | list[string] | ❌ | Ansible roles (empty initially, populated in future specs) |
| `hpc_tailoring_ref` | string | ❌ | Reference to hpc_tailoring.yml entry |

### Validation Rules
1. **Completeness**: Minimum 110 controls (all Rev 2 requirements)
2. **"N/A" Rationale**: If any framework mapping is "N/A", corresponding rationale field MUST be populated
3. **Family Codes**: Must be one of 15 valid NIST families
4. **SPRS Weight**: Integer 1-5 inclusive
5. **Zones**: At least one zone, all values from allowed set
6. **Plain Language**: Minimum 100 characters, maximum 1000 characters

---

## File 2: Glossary (`docs/glossary/terms.yml`)

### Purpose
Plain-language definitions of all technical terms and acronyms, with role-specific context for 5 audience types. Enables audience-aware documentation and glossary validation.

### Schema

#### Pydantic Model Definition
```python
from pydantic import BaseModel, Field
from typing import List

class AudienceContext(BaseModel):
    """Role-specific explanation of why term matters."""
    pi: str = Field(description="Why this matters to Principal Investigators")
    researcher: str = Field(description="Why this matters to researchers")
    sysadmin: str = Field(description="Why this matters to system administrators")
    ciso: str = Field(description="Why this matters to CISO/security staff")
    leadership: str = Field(description="Why this matters to university leadership (VCR)")

class GlossaryTerm(BaseModel):
    """Individual glossary term entry."""
    term: str = Field(description="Display name (may include context tag)")
    full_name: str = Field(description="Expanded acronym or full term name")
    plain_language: str = Field(
        min_length=50,
        max_length=1000,
        description="2-4 sentence explanation understandable by anyone"
    )
    who_cares: AudienceContext
    see_also: List[str] = Field(
        default_factory=list,
        description="Related terms (must reference other glossary entries)"
    )
    context: str | None = Field(
        default=None,
        description="Optional context tag for ambiguous acronyms (e.g., 'compliance', 'hardware')"
    )

class GlossaryData(BaseModel):
    """Root data structure for terms.yml."""
    version: str
    last_updated: str
    description: str
    terms: dict[str, GlossaryTerm] = Field(min_length=60)

    @field_validator('terms')
    @classmethod
    def validate_term_count(cls, v):
        """Ensure at least 60 terms."""
        if len(v) < 60:
            raise ValueError(f"Expected minimum 60 terms, found {len(v)}")
        return v
```

#### YAML Example
```yaml
version: "1.0.0"
last_updated: "2026-02-14"
description: "Plain-language glossary for CUI compliance framework stakeholders"

terms:
  "CUI":
    term: "CUI"
    full_name: "Controlled Unclassified Information"
    plain_language: |
      Sensitive government or research data that isn't classified (like Top Secret)
      but still needs protection. Examples include export-controlled research data,
      personally identifiable information (PII), or data covered by ITAR regulations.
      If you're working with federal contracts or grants, your data might be CUI.
    who_cares:
      pi: "Determines if your research requires special data handling procedures and which systems you can use."
      researcher: "Affects which computers and networks you can access for your work, and whether you need additional training."
      sysadmin: "Requires implementing specific security controls and maintaining audit logs for compliance."
      ciso: "Primary driver for NIST 800-171 compliance program and security control implementation."
      leadership: "Impacts federal contract eligibility, liability exposure, and institutional compliance posture."
    see_also:
      - "NIST 800-171"
      - "Enclave"
      - "DFARS"

  "MFA":
    term: "MFA"
    full_name: "Multi-Factor Authentication"
    plain_language: |
      Logging in with two or more different types of proof of identity. Usually
      something you know (password) plus something you have (phone app, security key)
      or something you are (fingerprint). Makes it much harder for attackers to
      access your account even if they steal your password.
    who_cares:
      pi: "Required for accessing CUI systems - your researchers will need to use Duo or similar tools."
      researcher: "You'll need to authenticate with your phone or security key in addition to your password."
      sysadmin: "Must implement and maintain MFA infrastructure (Duo, FreeIPA) for all CUI system access."
      ciso: "Critical control for meeting NIST 800-171 IA-2(1) requirement and reducing account compromise risk."
      leadership: "Demonstrates due diligence for protecting sensitive research data and federal compliance."
    see_also:
      - "Duo"
      - "FreeIPA"
      - "IA (Identity and Authentication)"

  "AC (compliance)":
    term: "AC (compliance)"
    full_name: "Access Control"
    plain_language: |
      Policies and technologies that determine who can access which systems and data.
      Access control includes user authentication (proving who you are), authorization
      (what you're allowed to do), and auditing (recording what you did). The goal is
      to ensure only authorized people can access CUI data.
    who_cares:
      pi: "Defines which researchers can access your data and what they can do with it."
      researcher: "Determines your ability to log into systems and access datasets for your work."
      sysadmin: "Largest control family - implements user management, permissions, session controls via FreeIPA and Ansible roles."
      ciso: "First line of defense against unauthorized data access - 22 controls in NIST 800-171."
      leadership: "Primary risk mitigation area for data breaches and insider threats."
    see_also:
      - "RBAC"
      - "Least Privilege"
      - "MFA"
    context: "compliance"

  "AC (hardware)":
    term: "AC (hardware)"
    full_name: "Alternating Current"
    plain_language: |
      Electrical current that reverses direction periodically, used to power computers
      and data center equipment. Standard electrical outlet power in North America is
      120V AC at 60Hz. Data centers often use higher voltage AC (208V or 480V) for
      efficiency.
    who_cares:
      pi: "Usually not relevant to research operations unless planning physical lab space."
      researcher: "Background knowledge for understanding data center power requirements."
      sysadmin: "Critical for capacity planning, PDU selection, and understanding power budgets for HPC hardware."
      ciso: "Relevant for physical security controls (PE family) and facility protection."
      leadership: "Infrastructure planning for research computing expansion and facility costs."
    see_also:
      - "PE (Physical and Environmental Protection)"
      - "UPS"
    context: "hardware"

  # ... (56+ more terms covering all NIST families, technical concepts, regulations, HPC terms, process terms) ...

  "SPRS":
    term: "SPRS"
    full_name: "Supplier Performance Risk System"
    plain_language: |
      DoD database where contractors self-report their cybersecurity compliance score
      based on NIST 800-171 controls. Score ranges from -203 (no controls) to +110
      (all controls fully implemented). Required for DoD contracts involving CUI.
    who_cares:
      pi: "Determines eligibility for certain DoD-funded research - low scores can disqualify proposals."
      researcher: "May affect which projects you can work on if SPRS score is too low."
      sysadmin: "Your security control implementations directly impact institutional SPRS score."
      ciso: "Quantifiable compliance metric - must track and improve score to maintain DoD contract eligibility."
      leadership: "Competitive advantage for securing federal contracts - higher scores improve proposal success rate."
    see_also:
      - "NIST 800-171"
      - "CMMC"
      - "POA&M"
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `version` | string | ✅ | Semantic version (e.g., "1.0.0") |
| `last_updated` | string (ISO 8601) | ✅ | Date of last update |
| `description` | string | ✅ | Purpose statement |
| `terms` | dict | ✅ | Dictionary with term keys (60+ entries) |
| `term` | string | ✅ | Display name (matches dict key) |
| `full_name` | string | ✅ | Expanded acronym or full name |
| `plain_language` | string | ✅ | 2-4 sentence explanation (50-1000 chars) |
| `who_cares.pi` | string | ✅ | Why PIs care (1-2 sentences) |
| `who_cares.researcher` | string | ✅ | Why researchers care |
| `who_cares.sysadmin` | string | ✅ | Why sysadmins care |
| `who_cares.ciso` | string | ✅ | Why CISO/security staff care |
| `who_cares.leadership` | string | ✅ | Why leadership (VCR) cares |
| `see_also` | list[string] | ❌ | Related terms (must exist in glossary) |
| `context` | string | ❌ | Context tag for ambiguous acronyms |

### Validation Rules
1. **Completeness**: Minimum 60 terms
2. **Audience Coverage**: All 5 `who_cares` fields required
3. **Plain Language Length**: 50-1000 characters
4. **See Also Integrity**: All referenced terms must exist in glossary
5. **Context Tags**: If multiple entries share acronym, context required

---

## File 3: HPC Tailoring (`docs/hpc_tailoring.yml`)

### Purpose
Documents deviations from standard security control implementations due to HPC operational requirements, with compensating controls and risk acceptance decisions.

### Schema

#### Pydantic Model Definition
```python
from pydantic import BaseModel, Field
from typing import List, Literal

class HPCTailoringEntry(BaseModel):
    """HPC-specific control tailoring decision."""
    tailoring_id: str = Field(description="Unique identifier (kebab-case)")
    control_r2: str = Field(description="NIST 800-171 Rev 2 control ID")
    control_r3: str = Field(description="NIST 800-171 Rev 3 control ID")
    title: str = Field(description="Short descriptive title")
    standard_requirement: str = Field(
        description="What the baseline control requires"
    )
    hpc_challenge: str = Field(
        description="Why baseline conflicts with HPC operations"
    )
    tailored_implementation: str = Field(
        description="How control is actually implemented in HPC context"
    )
    compensating_controls: List[str] = Field(
        description="Alternative controls that mitigate risk"
    )
    risk_acceptance: Literal["low", "medium", "high"] = Field(
        description="Residual risk level after tailoring"
    )
    nist_800_223_reference: str | None = Field(
        default=None,
        description="Reference to NIST SP 800-223 (HPC Security) guidance"
    )
    performance_impact: str | None = Field(
        default=None,
        description="Quantified performance impact if baseline applied (e.g., '40% I/O reduction')"
    )

class HPCTailoringData(BaseModel):
    """Root data structure for hpc_tailoring.yml."""
    version: str
    last_updated: str
    description: str
    tailoring_decisions: List[HPCTailoringEntry] = Field(min_length=10)
```

#### YAML Example
```yaml
version: "1.0.0"
last_updated: "2026-02-14"
description: "HPC-specific control tailoring decisions with compensating controls"

tailoring_decisions:
  - tailoring_id: "session-timeout-compute-nodes"
    control_r2: "3.14.7"
    control_r3: "03.13.11"
    title: "Session Termination on Compute Nodes"
    standard_requirement: |
      Automatically terminate user sessions after 15 minutes of inactivity to
      prevent unauthorized access if user walks away from workstation.
    hpc_challenge: |
      Batch jobs submitted via Slurm run for days or weeks without interactive user
      activity. Standard 15-minute session timeout would kill long-running scientific
      computations, rendering the HPC system unusable for its primary mission.
    tailored_implementation: |
      Session timeouts apply only to interactive login nodes (15-minute idle timeout).
      Compute node sessions (batch jobs) are exempt from timeout but are subject to:
      1. Job time limits enforced by Slurm scheduler
      2. Automatic cleanup when job completes or wall-time limit reached
      3. Mandatory job accounting and audit logging for all compute node access
    compensating_controls:
      - "Slurm enforces maximum wall-time limits (default: 7 days)"
      - "Batch jobs require authenticated submission with Kerberos tickets"
      - "All compute node activity logged to centralized Wazuh SIEM"
      - "Compute nodes isolated on restricted VLAN, no direct external access"
      - "Job accounting tracks user, start time, duration, resource usage"
    risk_acceptance: "low"
    nist_800_223_reference: "Section 3.3.2 - Job Scheduling and Resource Management"
    performance_impact: "N/A - baseline control would prevent HPC operations entirely"

  - tailoring_id: "fips-on-infiniband"
    control_r2: "3.13.11"
    control_r3: "03.13.08"
    title: "FIPS 140-2 Cryptography on InfiniBand"
    standard_requirement: |
      Use only FIPS 140-2 validated cryptographic modules for protecting
      sensitive data in transit and at rest.
    hpc_challenge: |
      InfiniBand high-speed interconnect (200 Gbps) does not support FIPS-validated
      encryption without 60-70% throughput reduction. Scientific applications using
      MPI over InfiniBand require maximum bandwidth for parallel computing workloads.
    tailored_implementation: |
      InfiniBand traffic remains unencrypted within the compute enclave. Network-level
      controls provide defense-in-depth:
      1. InfiniBand isolated to air-gapped compute VLAN (no routing to external networks)
      2. Physical security: compute nodes in locked data center with access controls
      3. Compute enclave designated as "restricted zone" - no CUI data at rest
      4. Data encrypted with FIPS modules before entering compute enclave (storage tier)
    compensating_controls:
      - "InfiniBand isolated on dedicated VLAN with no external routing"
      - "Physical access controls to data center (badge + biometric)"
      - "CUI data encrypted at rest on storage tier (FIPS-validated LUKS)"
      - "Network IDS monitors InfiniBand traffic for anomalies"
      - "Compute nodes re-imaged after each job (no persistent CUI storage)"
    risk_acceptance: "medium"
    nist_800_223_reference: "Section 4.2.1 - High-Speed Interconnect Security"
    performance_impact: "FIPS on InfiniBand reduces MPI bandwidth by 60-70% (unacceptable for scientific workloads)"

  # ... (8+ more tailoring decisions covering audit volume, MFA for batch jobs, etc.) ...
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `tailoring_id` | string | ✅ | Unique identifier (kebab-case, e.g., "session-timeout-compute-nodes") |
| `control_r2` | string | ✅ | NIST 800-171 Rev 2 control ID |
| `control_r3` | string | ✅ | NIST 800-171 Rev 3 control ID |
| `title` | string | ✅ | Short descriptive title |
| `standard_requirement` | string | ✅ | Baseline control requirement |
| `hpc_challenge` | string | ✅ | Why HPC conflicts with baseline |
| `tailored_implementation` | string | ✅ | Actual HPC implementation |
| `compensating_controls` | list[string] | ✅ | Alternative risk mitigations |
| `risk_acceptance` | enum (low/medium/high) | ✅ | Residual risk level |
| `nist_800_223_reference` | string | ❌ | NIST SP 800-223 section reference |
| `performance_impact` | string | ❌ | Quantified performance impact |

### Validation Rules
1. **Completeness**: Minimum 10 tailoring entries
2. **Control References**: All control_r2 and control_r3 must exist in control_mapping.yml
3. **Compensating Controls**: At least 1 compensating control per entry
4. **Risk Acceptance**: Must be "low", "medium", or "high"

---

## File 4: ODP Values (`docs/odp_values.yml`)

### Purpose
Organization-Defined Parameter values for NIST 800-171 Rev 3, aligned with DoD guidance and adapted for university research computing context.

### Schema

#### Pydantic Model Definition
```python
from pydantic import BaseModel, Field
from typing import List

class ODPValue(BaseModel):
    """Organization-Defined Parameter value."""
    odp_id: str = Field(description="ODP identifier (e.g., 'ODP-01')")
    control: str = Field(description="Associated NIST 800-171 Rev 3 control")
    parameter_description: str = Field(
        description="What this parameter controls"
    )
    assigned_value: str = Field(description="Actual value assigned by organization")
    rationale: str = Field(description="Why this value was chosen")
    dod_guidance: str | None = Field(
        default=None,
        description="DoD recommended value (if applicable)"
    )
    deviation_rationale: str | None = Field(
        default=None,
        description="Required if assigned_value differs from dod_guidance"
    )

class ODPValuesData(BaseModel):
    """Root data structure for odp_values.yml."""
    version: str
    last_updated: str
    description: str
    odp_values: List[ODPValue] = Field(min_length=49)

    @field_validator('odp_values')
    @classmethod
    def validate_odp_count(cls, v):
        """Ensure all 49 ODPs defined."""
        if len(v) != 49:
            raise ValueError(f"Expected exactly 49 ODPs, found {len(v)}")
        return v
```

#### YAML Example
```yaml
version: "1.0.0"
last_updated: "2026-02-14"
description: "Organization-Defined Parameter values for NIST 800-171 Rev 3"

odp_values:
  - odp_id: "ODP-01"
    control: "03.05.01"
    parameter_description: "Password minimum length"
    assigned_value: "15 characters"
    rationale: |
      Aligns with DoD guidance and NIST SP 800-63B recommendations for passwords
      protecting CUI. Longer than many industry standards (12 chars) to account
      for higher sensitivity of research data.
    dod_guidance: "15 characters"
    deviation_rationale: null

  - odp_id: "ODP-02"
    control: "03.05.01"
    parameter_description: "Password maximum lifetime"
    assigned_value: "365 days (1 year)"
    rationale: |
      University policy mandates annual password rotation for all accounts.
      Longer than DoD guidance to reduce password fatigue and encourage use
      of password managers. Compensated by mandatory MFA for CUI system access.
    dod_guidance: "90 days"
    deviation_rationale: |
      Deviation from DoD 90-day guidance justified by:
      1. University-wide policy standardization (all systems use 365-day rotation)
      2. Mandatory MFA requirement mitigates password compromise risk
      3. Research continuity - 90-day rotation disrupts long-running experiments
      4. Password manager adoption reduces weak password risk
      5. NIST SP 800-63B no longer recommends frequent rotation

  - odp_id: "ODP-03"
    control: "03.01.12"
    parameter_description: "Session lock inactivity period"
    assigned_value: "15 minutes"
    rationale: |
      Balances security (prevent unauthorized access if user walks away) with
      usability (researchers analyzing data without constant re-authentication).
      Applies only to interactive sessions, not batch jobs.
    dod_guidance: "15 minutes"
    deviation_rationale: null

  # ... (46 more ODPs) ...

  - odp_id: "ODP-49"
    control: "03.14.06"
    parameter_description: "Audit record retention period"
    assigned_value: "3 years"
    rationale: |
      Exceeds DoD minimum to support long-term research data provenance and
      federal contract audit requirements. Many research grants require
      record retention for life of project plus 3 years post-closeout.
    dod_guidance: "1 year"
    deviation_rationale: |
      Exceeds DoD guidance for research continuity and federal compliance.
      University policy requires 3-year retention for all grant-related records.

```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `odp_id` | string | ✅ | Unique ODP identifier (ODP-01 through ODP-49) |
| `control` | string | ✅ | Associated NIST 800-171 Rev 3 control ID |
| `parameter_description` | string | ✅ | What this parameter controls |
| `assigned_value` | string | ✅ | Actual value assigned by organization |
| `rationale` | string | ✅ | Why this value was chosen |
| `dod_guidance` | string | ❌ | DoD recommended value (if available) |
| `deviation_rationale` | string | ⚠️ | Required if assigned_value != dod_guidance |

### Validation Rules
1. **Completeness**: Exactly 49 ODP entries (all Rev 3 ODPs)
2. **Deviation Rationale**: Required if assigned_value differs from dod_guidance
3. **Control References**: All controls must exist in control_mapping.yml

---

## Entity Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                      control_mapping.yml                        │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ SecurityControl                                          │  │
│  │ - control_id: "3.14.7"                                  │  │
│  │ - hpc_tailoring_ref: "session-timeout-compute-nodes"   │──┼──┐
│  │ - ansible_roles: []                                     │  │  │
│  └──────────────────────────────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────┘  │
                                                                     │
        ┌────────────────────────────────────────────────────────────┘
        │ References
        ↓
┌─────────────────────────────────────────────────────────────────┐
│                      hpc_tailoring.yml                          │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ HPCTailoringEntry                                        │  │
│  │ - tailoring_id: "session-timeout-compute-nodes"        │  │
│  │ - control_r2: "3.14.7"                                  │  │
│  │ - control_r3: "03.13.11"                                │  │
│  │ - compensating_controls: [...]                          │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                         terms.yml                               │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ GlossaryTerm: "MFA"                                      │  │
│  │ - see_also: ["Duo", "FreeIPA", "IA"]                    │──┼──┐
│  └──────────────────────────────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────┘  │
        ↑                                                            │
        │ References                                                 │
        └────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                       odp_values.yml                            │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │ ODPValue                                                 │  │
│  │ - odp_id: "ODP-02"                                       │  │
│  │ - control: "03.05.01"  ──────────────────────────────┐  │  │
│  │ - assigned_value: "365 days"                         │  │  │
│  │ - dod_guidance: "90 days"                            │  │  │
│  │ - deviation_rationale: "..."                         │  │  │
│  └──────────────────────────────────────────────────────┼───┘  │
└─────────────────────────────────────────────────────────┼───────┘
                                                           │
                References control in control_mapping.yml │
                                                           ↓
```

---

## File Size Estimates

| File | Entries | Avg Entry Size | Estimated Total |
|------|---------|----------------|-----------------|
| `control_mapping.yml` | 110 controls | ~4.5 KB | ~495 KB |
| `terms.yml` | 60+ terms | ~1.5 KB | ~90 KB |
| `hpc_tailoring.yml` | 10+ entries | ~2 KB | ~20 KB |
| `odp_values.yml` | 49 ODPs | ~800 B | ~40 KB |
| **Total** | - | - | **~645 KB** |

**Load Performance**: PyYAML can load ~10 MB in ~200ms, so <650 KB should load in <15ms.

---

## Validation Strategy

### Layer 1: Pydantic Runtime Validation
- Documentation generator validates on load
- Fails immediately with clear error messages
- Enforces type constraints, required fields, value ranges

### Layer 2: CI/CD pytest Tests
- `tests/test_yaml_schemas.py` validates all 4 files
- Checks completeness (110 controls, 60 terms, 49 ODPs)
- Validates cross-references (hpc_tailoring_ref, see_also, control IDs)
- Runs on every commit, blocks merge if validation fails

### Layer 3: Cross-File Integrity
- HPC tailoring refs in control_mapping.yml must exist in hpc_tailoring.yml
- Glossary see_also references must exist in terms.yml
- ODP controls must exist in control_mapping.yml

---

## Next Steps

1. ✅ **Phase 1 Complete**: Data model defined with Pydantic schemas
2. **Phase 1**: Generate quickstart.md with usage examples
3. **Phase 1**: Update agent context with Python 3.9+, PyYAML, Pydantic v2, Jinja2
4. **Phase 2**: NOT PART OF THIS COMMAND - Use `/speckit.tasks` to generate implementation tasks
