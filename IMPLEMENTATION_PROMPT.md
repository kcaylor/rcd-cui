# Implementation Prompt: CUI Compliance Data Models and Documentation Foundation

## Project Overview

Build the foundational data models and documentation generation system for a production-grade Ansible framework that deploys and audits CUI (Controlled Unclassified Information) compliant research computing infrastructure at a university. This implementation creates **NO Ansible roles** — only the structured data and tooling that all subsequent compliance implementations depend on.

**Key Deliverables**:
1. 4 YAML data models (control mapping, glossary, HPC tailoring, ODP values)
2. Python documentation generator producing 7 audience-specific outputs
3. Glossary validator for enforcing plain-language requirements
4. Complete Ansible project skeleton with Makefile and README

**Critical Context**: This is a university research computing environment serving Principal Investigators (PIs), researchers, system administrators, CISO staff, and university leadership. The system must handle sensitive federal research data (CUI) while supporting High-Performance Computing (HPC) workloads that conflict with standard enterprise security controls.

---

## Constitutional Principles (MANDATORY - Read First)

All implementation decisions MUST align with these 8 core principles:

### I. Plain Language First
Every artifact produced—code comments, configuration files, documentation, compliance reports—MUST be understandable by non-security-experts. Use 2-4 sentence explanations for all technical concepts. The glossary enforces this via validation tooling.

### II. Data Model as Source of Truth
The control mapping YAML, glossary, HPC tailoring decisions, and ODP values are the authoritative structured data sources. Everything else—documentation, reports, crosswalks—is **generated** from these files. Never duplicate data.

### III. Compliance as Code
Security controls are implemented via declarative Ansible roles with verify and evidence tasks. The data models you're building establish the foundation for this approach (though Ansible role implementation comes in future specs).

### IV. HPC-Aware
High-Performance Computing environments have unique constraints (long-running batch jobs, InfiniBand networks, parallel filesystems, GPUs). Standard enterprise security controls often conflict with HPC operations. All HPC deviations MUST be documented in the HPC tailoring YAML with compensating controls.

### V. Multi-Framework
Support NIST 800-171 Rev 2, NIST 800-171 Rev 3, CMMC Level 2, and NIST 800-53 Rev 5 simultaneously. The control mapping provides crosswalk across all four frameworks with explicit "N/A" + rationale when no mapping exists.

### VI. Audience-Aware Documentation
Produce distinct documentation for 5 audiences: PIs (minimal technical jargon), researchers (practical procedures), sysadmins (operational details), CISO (compliance matrices), and leadership (executive summaries). Same source data, different perspectives.

### VII. Idempotent and Auditable
All operations must be repeatable with identical results. Documentation generator MUST be deterministic (same YAML → same output). All changes are version-controlled and auditable.

### VIII. Prefer Established Tools
Use PyYAML (YAML parsing), Pydantic v2 (validation), Jinja2 (templating), pytest (testing). No custom parsers or framework-specific abstractions where established tools exist.

---

## Technology Stack

**Required Versions**:
- Python: 3.9 or higher
- Target OS: RHEL 9 / Rocky Linux 9
- Ansible: 2.15+ (for future roles, skeleton only in this spec)

**Python Dependencies** (requirements.txt):
```
pyyaml>=6.0
pydantic>=2.0
jinja2>=3.1
pytest>=7.0
```

**Key Technology Decisions**:
1. **Pydantic v2**: YAML schema validation (5-50x faster than v1, superior error messages)
2. **PyYAML**: YAML parsing with `safe_load()` for security
3. **Jinja2**: Template-based documentation generation
4. **pytest**: Testing with schema validation and integration tests

**Performance Requirements**:
- YAML load time: <200ms for <650KB data
- Documentation generation: <30 seconds for all 7 outputs
- Pydantic validation: ~0.110 seconds for 110 controls

---

## Project Structure

Create this complete directory structure:

```
rcd-cui/
├── ansible.cfg                    # Ansible configuration
├── inventory/                     # Ansible inventory
│   ├── hosts.yml
│   └── group_vars/
│       ├── all.yml
│       ├── management.yml
│       ├── internal.yml
│       └── restricted.yml
├── roles/                         # Ansible roles (empty initially)
│   └── common/
│       └── vars/
│           └── control_mapping.yml  # CANONICAL DATA MODEL (110+ controls)
├── docs/                          # Documentation source and generated output
│   ├── glossary/
│   │   └── terms.yml              # CANONICAL GLOSSARY (60+ terms)
│   ├── hpc_tailoring.yml          # HPC-specific control tailoring (10+ entries)
│   ├── odp_values.yml             # Organization-Defined Parameters (49 ODPs)
│   └── generated/                 # Generated documentation (ephemeral)
│       ├── pi_guide.md
│       ├── researcher_quickstart.md
│       ├── sysadmin_reference.md
│       ├── ciso_compliance_map.md
│       ├── leadership_briefing.md
│       ├── glossary_full.md
│       └── crosswalk.csv
├── scripts/                       # Python automation scripts
│   ├── generate_docs.py           # Documentation generator
│   ├── validate_glossary.py       # Glossary coverage validator
│   └── models/                    # Pydantic data models
│       ├── __init__.py
│       ├── control_mapping.py
│       ├── glossary.py
│       ├── hpc_tailoring.py
│       └── odp_values.py
├── templates/                     # Jinja2 templates for doc generation
│   ├── pi_guide.md.j2
│   ├── researcher_quickstart.md.j2
│   ├── sysadmin_reference.md.j2
│   ├── ciso_compliance_map.md.j2
│   ├── leadership_briefing.md.j2
│   ├── glossary_full.md.j2
│   ├── crosswalk.csv.j2
│   └── _partials/
│       ├── glossary_link.j2
│       ├── control_table.j2
│       └── header.j2
├── tests/                         # Pytest tests
│   ├── conftest.py
│   ├── test_yaml_schemas.py       # Validate all YAML data models
│   ├── test_generate_docs.py     # Doc generator integration tests
│   └── test_glossary_validator.py # Glossary validator unit tests
├── Makefile                       # Build targets (docs, validate, crosswalk, clean)
├── requirements.txt               # Python dependencies
├── README.md                      # Project overview and usage
├── .gitignore                     # Exclude docs/generated/ and Python cache
└── .specify/                      # Specify framework artifacts
    └── memory/
        └── constitution.md        # Project constitution
```

---

## Complete Data Model Schemas

### File 1: Control Mapping (`roles/common/vars/control_mapping.yml`)

**Purpose**: Canonical mapping of all NIST 800-171 Rev 2/3 controls to CMMC Level 2 and NIST 800-53 Rev 5.

**Pydantic Models**:
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

**YAML Example**:
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
    ansible_roles: []
    hpc_tailoring_ref: null
```

**Validation Rules**:
- Minimum 110 controls (all Rev 2 requirements)
- If framework mapping is "N/A", rationale MUST be populated
- Family codes must be one of 15 valid NIST families
- SPRS weight: integer 1-5 inclusive
- Plain language: minimum 100 characters

---

### File 2: Glossary (`docs/glossary/terms.yml`)

**Purpose**: Plain-language definitions of all technical terms with role-specific context for 5 audience types.

**Pydantic Models**:
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

**YAML Example**:
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

  "AC (compliance)":
    term: "AC (compliance)"
    full_name: "Access Control"
    plain_language: |
      Policies and technologies that determine who can access which systems and data.
      Access control includes user authentication, authorization, and auditing.
    who_cares:
      pi: "Defines which researchers can access your data and what they can do with it."
      researcher: "Determines your ability to log into systems and access datasets."
      sysadmin: "Implements user management, permissions, session controls via FreeIPA."
      ciso: "First line of defense against unauthorized data access."
      leadership: "Primary risk mitigation area for data breaches."
    see_also:
      - "RBAC"
      - "MFA"
    context: "compliance"
```

**Validation Rules**:
- Minimum 60 terms
- All 5 `who_cares` fields required
- Plain language: 50-1000 characters
- `see_also` references must exist in glossary

---

### File 3: HPC Tailoring (`docs/hpc_tailoring.yml`)

**Purpose**: Document deviations from standard security controls due to HPC requirements.

**Pydantic Models**:
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
        description="Quantified performance impact if baseline applied"
    )

class HPCTailoringData(BaseModel):
    """Root data structure for hpc_tailoring.yml."""
    version: str
    last_updated: str
    description: str
    tailoring_decisions: List[HPCTailoringEntry] = Field(min_length=10)
```

**YAML Example**:
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
      Automatically terminate user sessions after 15 minutes of inactivity.
    hpc_challenge: |
      Batch jobs run for days or weeks without interactive user activity.
      Standard timeout would kill scientific computations.
    tailored_implementation: |
      Session timeouts apply only to interactive login nodes (15-minute idle).
      Compute node sessions (batch jobs) exempt but subject to:
      1. Job time limits enforced by Slurm scheduler
      2. Automatic cleanup when job completes
      3. Mandatory job accounting and audit logging
    compensating_controls:
      - "Slurm enforces maximum wall-time limits (default: 7 days)"
      - "Batch jobs require authenticated submission with Kerberos tickets"
      - "All compute node activity logged to centralized Wazuh SIEM"
      - "Compute nodes isolated on restricted VLAN, no direct external access"
    risk_acceptance: "low"
    nist_800_223_reference: "Section 3.3.2 - Job Scheduling and Resource Management"
    performance_impact: "N/A - baseline would prevent HPC operations entirely"
```

**Validation Rules**:
- Minimum 10 tailoring entries
- At least 1 compensating control per entry
- Risk acceptance must be low/medium/high

---

### File 4: ODP Values (`docs/odp_values.yml`)

**Purpose**: Organization-Defined Parameter values for NIST 800-171 Rev 3.

**Pydantic Models**:
```python
from pydantic import BaseModel, Field, field_validator
from typing import List

class ODPValue(BaseModel):
    """Organization-Defined Parameter value."""
    odp_id: str = Field(description="ODP identifier (e.g., 'ODP-01')")
    control: str = Field(description="Associated NIST 800-171 Rev 3 control")
    parameter_description: str = Field(description="What this parameter controls")
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

**YAML Example**:
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
      Aligns with DoD guidance and NIST SP 800-63B recommendations for CUI.
    dod_guidance: "15 characters"
    deviation_rationale: null

  - odp_id: "ODP-02"
    control: "03.05.01"
    parameter_description: "Password maximum lifetime"
    assigned_value: "365 days (1 year)"
    rationale: |
      University policy mandates annual password rotation for all accounts.
    dod_guidance: "90 days"
    deviation_rationale: |
      Deviation justified by:
      1. University-wide policy standardization
      2. Mandatory MFA requirement mitigates password compromise risk
      3. Research continuity - 90-day rotation disrupts long-running experiments
      4. NIST SP 800-63B no longer recommends frequent rotation
```

**Validation Rules**:
- Exactly 49 ODP entries
- If assigned_value != dod_guidance, deviation_rationale required

---

## User Stories and Priorities

### User Story 1 (P1): Control Mappings
**Goal**: Single source of truth for all 110 NIST 800-171 Rev 2 controls across 4 frameworks.

**Acceptance Criteria**:
- All 110 controls present with complete metadata
- Framework mappings to Rev 3, CMMC L2, 800-53 R5
- "N/A" mappings include rationale
- Plain-language descriptions (2-4 sentences)

---

### User Story 2 (P1): Glossary
**Goal**: 60+ plain-language terms with 5-audience context.

**Acceptance Criteria**:
- Minimum 60 terms (NIST families, technical concepts, regulations, HPC terms)
- All 5 `who_cares` audiences explained
- Context tags for ambiguous acronyms
- `see_also` cross-references

---

### User Story 3 (P1): HPC Tailoring
**Goal**: 10+ documented HPC/security conflicts with compensating controls.

**Acceptance Criteria**:
- Session timeout, FIPS on InfiniBand, audit volume, MFA for batch jobs, etc.
- Each entry: standard requirement, HPC challenge, tailored implementation, compensating controls
- Risk acceptance levels
- NIST 800-223 references

---

### User Story 4 (P2): ODP Values
**Goal**: All 49 Rev 3 ODPs assigned with rationale.

**Acceptance Criteria**:
- Exactly 49 ODPs defined
- DoD guidance alignment (with deviation rationale when university policy conflicts)
- Complete rationale for each value

---

### User Story 5 (P2): Documentation Generator
**Goal**: 7 audience-specific outputs from YAML sources.

**Acceptance Criteria**:
- Generates: pi_guide.md, researcher_quickstart.md, sysadmin_reference.md, ciso_compliance_map.md, leadership_briefing.md, glossary_full.md, crosswalk.csv
- All technical terms hyperlinked to glossary
- Completes in <30 seconds
- Deterministic output (same input → same output)

---

### User Story 6 (P3): Glossary Validator
**Goal**: Scan project files for undefined acronyms.

**Acceptance Criteria**:
- Scans .md, .yml, .j2 files
- Flags undefined terms with file path and line number
- Exit code 0 (success) or 1 (violations found)
- Context-aware matching for ambiguous acronyms

---

### User Story 7 (P2): Project Skeleton
**Goal**: Complete Ansible structure with Makefile.

**Acceptance Criteria**:
- Directory structure (roles/, docs/, scripts/, templates/, tests/, inventory/)
- Makefile targets: docs, validate, crosswalk, clean, test
- README with usage instructions
- ansible.cfg and inventory structure

---

## Implementation Tasks (150 Total)

### Phase 1: Setup (12 tasks)
```
T001: Create directory structure (inventory/, roles/, docs/, scripts/, templates/, tests/)
T002: Create requirements.txt with dependencies
T003: Create ansible.cfg
T004: Create inventory/hosts.yml
T005: Create inventory/group_vars/ skeleton files
T006: Create .gitignore (exclude docs/generated/, __pycache__)
T007: Create roles/common/vars/ directory
T008: Create docs/glossary/ directory
T009: Create docs/generated/ directory
T010: Create scripts/models/ directory
T011: Create templates/_partials/ directory
T012: Create tests/ directory
```

### Phase 2: Foundational (10 tasks) - BLOCKS ALL USER STORIES
```
T013: Create scripts/models/__init__.py with shared imports
T014: Create Pydantic model for FrameworkMapping
T015: Create Pydantic model for GlossaryTerm and AudienceContext
T016: Create Pydantic model for HPCTailoringEntry
T017: Create Pydantic model for ODPValue
T018: Implement YAML loader utility with caching (functools.lru_cache)
T019: Create pytest configuration in tests/conftest.py
T020: Create Jinja2 partial for glossary hyperlinking
T021: Create Jinja2 partial for control table formatting
T022: Create Jinja2 partial for standard header
```

### Phase 3: User Story 1 - Control Mapping (24 tasks, P1)
```
T023: Complete SecurityControl Pydantic model
T024: Add field validators for "N/A" rationale enforcement
T025: Complete ControlMappingData root model
T026: Add validator for minimum 110 controls
T027: Create control_mapping.yml structure
T028-T042: Populate all 15 control families (AC, AT, AU, CA, CM, IA, IR, MA, MP, PE, PS, RA, SA, SC, SI)
T043-T046: Create pytest tests for schema validation, control count, completeness
```

### Phase 4: User Story 2 - Glossary (16 tasks, P1)
```
T047-T049: Complete GlossaryTerm, AudienceContext, GlossaryData Pydantic models
T050: Add validator for minimum 60 terms
T051: Create terms.yml structure
T052-T057: Populate 60+ terms (NIST families, technical concepts, regulations, HPC terms, compliance process, context-tagged ambiguous acronyms)
T058: Validate see_also references
T059-T062: Create pytest tests
```

### Phase 5: User Story 3 - HPC Tailoring (18 tasks, P1)
```
T063-T065: Complete HPCTailoringEntry, HPCTailoringData models
T066: Create hpc_tailoring.yml structure
T067-T076: Add 10+ tailoring entries (session timeout, FIPS on InfiniBand, audit volume, MFA, multi-tenancy, containers, parallel FS ACLs, long jobs, GPU memory, PXE provisioning)
T077: Link tailoring entries to control_mapping.yml
T078-T080: Create pytest tests
```

### Phase 6: User Story 4 - ODPs (13 tasks, P2)
```
T081-T083: Complete ODPValue, ODPValuesData models
T084: Create odp_values.yml structure
T085-T089: Populate all 49 ODPs in ranges (ODP-01 to ODP-49)
T090: Add deviation_rationale for DoD conflicts
T091-T093: Create pytest tests
```

### Phase 7: User Story 5 - Documentation Generator (18 tasks, P2)
```
T094-T100: Create 7 Jinja2 templates (can run in parallel)
T101-T107: Implement generate_docs.py (main script, CLI args, YAML loading, Pydantic validation, Jinja2 environment, generation functions, error handling, deterministic output)
T108-T111: Create pytest integration tests
```

### Phase 8: User Story 6 - Glossary Validator (12 tasks, P3)
```
T112-T119: Implement validate_glossary.py (main script, CLI args, glossary loading, file scanning, acronym extraction regex, context-aware matching, violation reporting, exit codes)
T120-T123: Create pytest unit and integration tests
```

### Phase 9: User Story 7 - Project Skeleton (15 tasks, P2)
```
T124-T129: Create Makefile targets (docs, validate, crosswalk, clean, test, validate-schemas)
T130-T135: Create comprehensive README.md
T136-T138: Create pytest tests for Makefile targets
```

### Phase 10: Polish (12 tasks)
```
T139-T150: Docstrings, type hints, CONTRIBUTING.md, CI/CD workflow, performance optimization, logging, error messages, Markdown/CSV validation, test coverage >90%, quickstart validation
```

---

## Implementation Workflow

### MVP First (User Stories 1, 2, 3 Only)
1. Complete Phase 1 (Setup)
2. Complete Phase 2 (Foundational) - CRITICAL BLOCKER
3. Implement User Stories 1, 2, 3 in parallel (all P1)
4. Test independently
5. Deploy core data models

### Incremental Delivery
1. Setup + Foundational → Foundation ready
2. US1, US2, US3 (P1) → MVP complete
3. US4 (P2) → All YAML files ready
4. US5 (P2) → Documentation automation
5. US7 (P2) → Operational scaffolding
6. US6 (P3) → Quality gate
7. Polish → Production-ready

### Parallel Opportunities (67 [P] tasks)
- Phase 1: T003-T012 (9 tasks)
- Phase 2: T014-T017, T020-T022 (7 tasks)
- User Stories 1-4: Control families, glossary categories, HPC entries, ODP ranges (divide work)
- User Story 5: All 7 Jinja2 templates (T094-T100)
- User Story 7: Makefile targets, README sections (T124-T129, T131-T135)

---

## Critical Implementation Notes

### Error Handling (Per Clarification #1)
When YAML validation fails, the documentation generator MUST:
- Fail immediately (no partial generation)
- Report: file path, entry identifier, missing field name
- Example: `ERROR: Missing required field 'plain_language' in control '3.1.5' in roles/common/vars/control_mapping.yml`

### "N/A" Mappings (Per Clarification #2)
When a control has no direct framework equivalent:
- Use explicit "N/A" value in mapping field
- MUST populate corresponding rationale field
- Example: `rev3_id: "N/A"` requires `rev3_rationale: "Consolidated into 03.01.17 in Rev 3"`

### Ambiguous Acronyms (Per Clarification #3)
For terms with multiple meanings:
- Create separate glossary entries with context tags
- Example: `"AC (compliance)"` and `"AC (hardware)"`
- Validator must check context when matching usage

### DoD ODP Conflicts (Per Clarification #4)
When university policy differs from DoD guidance:
- Use university policy value in `assigned_value`
- Document DoD recommendation in `dod_guidance`
- Explain conflict in `deviation_rationale` with risk acceptance

---

## Testing Requirements

### Test Coverage Target: >90%

**Schema Validation Tests** (`tests/test_yaml_schemas.py`):
- Validate all 4 YAML files against Pydantic models
- Verify control count (exactly 110 Rev 2 controls)
- Verify term count (minimum 60)
- Verify ODP count (exactly 49)
- Verify "N/A" mappings have rationale
- Verify `see_also` references exist
- Verify cross-file references (hpc_tailoring_ref, ODP controls)

**Integration Tests** (`tests/test_generate_docs.py`):
- Verify all 7 outputs generated
- Verify glossary hyperlinks present
- Verify CSV is Excel-compatible
- Verify no unexpanded Jinja2 variables

**Unit Tests** (`tests/test_glossary_validator.py`):
- Verify acronym extraction regex
- Verify context-tagged matching
- Verify exit codes (0 = success, 1 = violations)

**Makefile Tests** (`tests/test_makefile_targets.py`):
- Verify `make docs` produces outputs
- Verify `make validate` runs successfully
- Verify `make crosswalk` produces CSV

---

## Success Criteria

You will know this implementation is complete when:

1. **SC-001**: A non-technical PI can read generated PI guide without encountering unexplained jargon
2. **SC-002**: All 110 NIST 800-171 Rev 2 controls present with accurate crosswalk to 4 frameworks
3. **SC-003**: Glossary contains 60+ terms, each with complete plain-language + 5-audience context
4. **SC-004**: Documentation generator completes all 7 outputs in <30 seconds
5. **SC-005**: Glossary validator identifies undefined acronyms and fails CI builds appropriately
6. **SC-006**: CSV crosswalk opens in Excel with complete, readable control mappings
7. **SC-007**: All 49 NIST 800-171 Rev 3 ODPs have assigned values with rationale
8. **SC-008**: 10+ HPC tailoring decisions documented with compensating controls
9. **SC-009**: New team member can run `make docs`, `make validate`, `make crosswalk` within 5 minutes
10. **SC-010**: Generated docs hyperlink 95%+ of technical terms to glossary

---

## Performance Targets

- **YAML Load Time**: <200ms for ~645KB data
- **Documentation Generation**: <30 seconds for all 7 outputs
- **Pydantic Validation**: ~0.110 seconds for 110 controls
- **Glossary Validation**: <5 seconds for entire project

---

## Code Quality Standards

1. **Type Hints**: All functions must have type hints
2. **Docstrings**: All modules, classes, functions documented
3. **PEP 8**: Follow Python style guide
4. **Deterministic Output**: Same YAML input MUST produce identical output
5. **Exit Codes**: 0 = success, 1 = validation error, 2 = missing files
6. **Error Messages**: Clear, actionable, specify file/entry/field
7. **Logging**: Progress indicators for long-running operations

---

## Next Steps After Implementation

This spec produces the **foundation only**. Future specs will:
- Spec 002: Implement Ansible roles for Access Control (AC) family
- Spec 003: Implement Ansible roles for Identification and Authentication (IA) family
- Spec 004: Implement Ansible roles for System and Communications Protection (SC) family
- Spec 005+: Remaining control families, automated testing, evidence collection

---

## Reference Documentation

- NIST 800-171 Rev 2: https://csrc.nist.gov/publications/detail/sp/800-171/rev-2/final
- NIST 800-171 Rev 3: https://csrc.nist.gov/publications/detail/sp/800-171/rev-3/final
- CMMC Level 2: https://www.acq.osd.mil/cmmc/
- NIST 800-53 Rev 5: https://csrc.nist.gov/publications/detail/sp/800-53/rev-5/final
- NIST SP 800-223 (HPC Security): https://csrc.nist.gov/publications/detail/sp/800-223/draft
- DoD ODP Guidance: https://www.acq.osd.mil/dpap/pdi/cyber/strategically_manage_SPRS_scores.html
- Pydantic v2 Docs: https://docs.pydantic.dev/latest/
- PyYAML Docs: https://pyyaml.org/wiki/PyYAMLDocumentation
- Jinja2 Docs: https://jinja.palletsprojects.com/

---

## START IMPLEMENTATION NOW

Begin with Phase 1 (Setup), then Phase 2 (Foundational), then implement User Stories 1, 2, 3 in parallel for MVP. Use the Pydantic models exactly as specified above. Follow the 8 constitutional principles in all decisions. Validate frequently with pytest. Aim for >90% test coverage. Make the documentation generator deterministic. Enforce plain language everywhere.

**Your first task**: Create the directory structure (T001) and requirements.txt (T002).
