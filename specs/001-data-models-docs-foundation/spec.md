# Feature Specification: Data Models and Documentation Generation Foundation

**Feature Branch**: `001-data-models-docs-foundation`
**Created**: 2026-02-14
**Status**: Draft
**Input**: User description: "Build the foundational data models and documentation generation system for a CUI compliance Ansible framework. This spec produces NO Ansible roles — only the structured data and tooling that all subsequent specs depend on."

## Clarifications

### Session 2026-02-14

- Q: How does the documentation generator handle missing or incomplete data in YAML files? → A: Fail immediately with clear error message specifying which file, entry, and required field is missing
- Q: What happens when a NIST control has no direct mapping in another framework (e.g., Rev 3 control with no Rev 2 equivalent)? → A: Use explicit "N/A" value with a rationale field explaining why no mapping exists
- Q: How does the system handle acronyms that have multiple meanings in different contexts (e.g., "AC" = Access Control vs Alternating Current)? → A: Create separate glossary entries with context tags (e.g., "AC (compliance)", "AC (hardware)") and validator checks context
- Q: What happens when DoD ODP guidance conflicts with university policy requirements? → A: Use university policy value and document deviation with university-specific rationale explaining the conflict and risk acceptance

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Establish Single Source of Truth for Control Mappings (Priority: P1)

A compliance officer needs to understand which security controls apply to the research computing environment and how they map across multiple compliance frameworks (NIST 800-171 Rev 2, Rev 3, CMMC Level 2, and NIST 800-53 Rev 5). They need a single, authoritative source that prevents inconsistencies when regulations change or when generating reports for different audiences.

**Why this priority**: Without a canonical control mapping, every document, script, and Ansible role would contain duplicate, potentially inconsistent control information. This is the foundational data structure that all other components depend on. No other feature can proceed without this.

**Independent Test**: Can be fully tested by loading the control mapping YAML file, verifying all 110 NIST 800-171 Rev 2 controls are present with complete metadata, and confirming accurate crosswalk mappings to Rev 3, CMMC Level 2, and 800-53 Rev 5 controls.

**Acceptance Scenarios**:

1. **Given** the control mapping YAML file exists, **When** a compliance officer opens it, **Then** they can find any NIST 800-171 Rev 2 control by ID and see its Rev 3 equivalent, CMMC practice ID, and 800-53 source control
2. **Given** a specific control like AC-1 (Access Control Policy), **When** reviewing the mapping, **Then** the entry includes control ID, title, plain-language description, assessment objectives, SPRS weight, automation capability flag, applicable zones, and placeholders for future Ansible role assignments
3. **Given** the need to generate a compliance report, **When** scripts read the control mapping, **Then** all four framework identifiers are present and accurate for every applicable control
4. **Given** an HPC-specific control with tailoring needs, **When** examining the control entry, **Then** it includes a reference to the HPC tailoring document (even if null initially)

---

### User Story 2 - Create Plain-Language Glossary for All Stakeholders (Priority: P1)

A Principal Investigator (PI) with no security background receives a compliance document filled with acronyms like FIPS, MFA, SIEM, SSP, POA&M, and technical terms. They need a plain-language glossary that explains each term in 2-4 sentences that anyone can understand, plus context for why it matters to their specific role.

**Why this priority**: The constitution mandates "Plain Language First" - every stakeholder must understand compliance requirements. Without the glossary, generated documentation will be incomprehensible to non-technical audiences (PIs, VCR, researchers). This is foundational infrastructure that enables all audience-aware documentation.

**Independent Test**: Can be fully tested by selecting any acronym or technical term from compliance documents (e.g., "CMMC", "enclave", "POA&M"), looking it up in the glossary, and verifying that a non-technical reader can understand what it means and why it matters to their role.

**Acceptance Scenarios**:

1. **Given** a researcher encounters the term "MFA" in a security document, **When** they look it up in the glossary, **Then** they see the full name (Multi-Factor Authentication), a 2-4 sentence plain-language explanation, and specific explanations of why it matters to PIs, researchers, sysadmins, CISO staff, and leadership
2. **Given** the need to validate completeness, **When** examining the glossary, **Then** it contains at least 60 terms covering all NIST control families, key technical concepts, regulatory instruments, HPC concepts, and compliance process terms
3. **Given** related concepts like "NIST 800-171" and "CUI", **When** viewing a glossary entry, **Then** the entry includes a "see also" list linking to related terms
4. **Given** generated documentation uses a technical acronym, **When** scripts process the documentation, **Then** the glossary validator can verify that every acronym has a corresponding glossary entry

---

### User Story 3 - Document HPC-Specific Tailoring Decisions (Priority: P1)

A system administrator needs to understand why standard enterprise security controls cannot be applied as-written to High-Performance Computing environments and what compensating controls are in place. For example, they need to know why session timeouts don't apply to long-running batch jobs and what alternative controls protect those sessions.

**Why this priority**: Per the constitution's "HPC-Aware" principle, conflicts between enterprise security and HPC operations must be explicitly documented with tailored implementations and compensating controls. This prevents auditors from flagging apparent non-compliance and documents due diligence. Required for audit readiness.

**Independent Test**: Can be fully tested by selecting an HPC-specific scenario (e.g., "session timeout on compute nodes"), finding it in the tailoring document, and verifying it explains the standard requirement, why HPC conflicts, the tailored implementation, and any compensating controls.

**Acceptance Scenarios**:

1. **Given** a control like AC-12 (Session Termination), **When** reviewing the HPC tailoring document, **Then** it explains the standard enterprise requirement (e.g., "terminate sessions after 15 minutes idle"), describes the HPC challenge (e.g., "batch jobs run for days/weeks"), documents the tailored implementation, and lists compensating controls
2. **Given** the need to justify tailoring to an auditor, **When** examining a tailoring entry, **Then** it includes the risk acceptance level (e.g., low/medium/high) and references relevant NIST 800-223 (HPC security) guidance
3. **Given** at least 10 common HPC/security conflicts, **When** reviewing the tailoring document, **Then** it covers session timeout on compute nodes, FIPS on InfiniBand, audit volume on compute nodes, MFA for batch jobs, multi-tenancy isolation, container security, parallel filesystem ACLs, long-running job management, GPU memory sanitization, and node provisioning via PXE
4. **Given** a tailoring decision is made, **When** it's added to the document, **Then** it includes both the Rev 2 and Rev 3 control identifiers for forward compatibility

---

### User Story 4 - Define Organization-Defined Parameters for Rev 3 (Priority: P2)

A compliance officer needs to assign specific values to all 49 Organization-Defined Parameters (ODPs) in NIST 800-171 Revision 3, aligning with DoD guidance while adapting for university research computing context. For example, they need to specify password complexity requirements, session timeout values, and audit log retention periods.

**Why this priority**: NIST 800-171 Rev 3 uses ODPs extensively to allow organizations to tailor controls. Without defined ODP values, controls cannot be implemented. This is required before any Ansible role can be configured, but can proceed in parallel with documentation generation (P2 vs P1).

**Independent Test**: Can be fully tested by verifying all 49 ODPs from NIST 800-171 Rev 3 have assigned values in the YAML file, each with the ODP ID, control reference, parameter description, assigned value, and rationale.

**Acceptance Scenarios**:

1. **Given** the ODP values YAML file, **When** a compliance officer reviews it, **Then** every ODP includes the ODP ID, associated control, parameter description, assigned value, and rationale for that value
2. **Given** DoD ODP guidance (April 2025), **When** assigning ODP values, **Then** values align with DoD recommendations where applicable, and when university policy conflicts with DoD guidance, the university policy value is used with deviation rationale documenting the conflict and risk acceptance
3. **Given** the need to implement a control like IA-5(1) (password-based authentication), **When** reviewing ODPs, **Then** the assigned values for password length, complexity, and change frequency are clearly defined
4. **Given** all 49 ODPs, **When** validating completeness, **Then** no ODP is left undefined or marked as "TBD"

---

### User Story 5 - Generate Audience-Specific Documentation (Priority: P2)

A researcher, PI, system administrator, CISO, and VCR all need to understand the compliance program, but each requires different information presented differently. The documentation generator must produce 7 distinct outputs from the same source data: PI guide, researcher quickstart, sysadmin reference, CISO compliance map, leadership briefing, full glossary, and machine-readable crosswalk.

**Why this priority**: Per the constitution's "Audience-Aware Documentation" principle, stakeholders need role-specific views of compliance data. Generating all documentation from YAML sources ensures consistency. This enables stakeholder communication but depends on user stories 1-4 being complete (P2 priority).

**Independent Test**: Can be fully tested by running the documentation generator script and verifying it produces all 7 output files (pi_guide.md, researcher_quickstart.md, sysadmin_reference.md, ciso_compliance_map.md, leadership_briefing.md, glossary_full.md, crosswalk.csv) with no errors, and confirming that technical jargon is hyperlinked to glossary entries.

**Acceptance Scenarios**:

1. **Given** all YAML data models are complete, **When** running the documentation generator, **Then** it produces all 7 output files without errors
2. **Given** the PI guide output, **When** a non-technical PI reads it, **Then** they understand their data handling responsibilities without encountering unexplained jargon
3. **Given** the CISO compliance map, **When** security staff review it, **Then** they see a complete control implementation matrix mapping all controls across all four frameworks
4. **Given** the crosswalk CSV output, **When** importing into Excel, **Then** it displays a complete table mapping NIST 800-171 Rev 2/3, CMMC Level 2, and NIST 800-53 Rev 5 controls
5. **Given** any generated Markdown document, **When** scripts process it, **Then** all technical terms and acronyms are either hyperlinked to glossary entries or defined inline

---

### User Story 6 - Validate Glossary Coverage Across All Project Files (Priority: P3)

A documentation maintainer needs to ensure that all acronyms and technical terms used throughout the project (in YAML files, Markdown docs, Jinja2 templates) have corresponding glossary entries. The validator should scan all project files and flag any undefined terms, failing CI builds if violations are found.

**Why this priority**: This enforces the "Plain Language First" principle at the tooling level, preventing undefined jargon from entering documentation. However, this is a quality gate rather than foundational infrastructure (P3 vs P1), and can be implemented after core documentation generation.

**Independent Test**: Can be fully tested by creating a test document with a known undefined acronym (e.g., "XYZ-999"), running the glossary validator, and verifying it flags the undefined term and returns a non-zero exit code.

**Acceptance Scenarios**:

1. **Given** project files containing acronyms, **When** running the glossary validator, **Then** it scans all .md, .yml, and .j2 files for acronyms and technical terms
2. **Given** an undefined acronym in a document, **When** the validator runs, **Then** it flags the violation with the file path and term, and returns a non-zero exit code
3. **Given** all terms are defined in the glossary, **When** the validator runs, **Then** it returns success (exit code 0) and reports "All terms validated"
4. **Given** the validator is integrated into CI/CD, **When** a pull request introduces undefined jargon, **Then** the build fails and blocks the merge

---

### User Story 7 - Establish Project Skeleton and Build System (Priority: P2)

A new team member needs to understand the project structure, how to generate documentation, validate glossary coverage, and produce compliance crosswalks. The project needs a complete directory structure, configuration files, and a Makefile with standard targets (docs, validate, crosswalk).

**Why this priority**: This provides the operational scaffolding for the project, but the structure can be established in parallel with documentation generation tooling (P2). It's essential for usability but not blocking other data model work.

**Independent Test**: Can be fully tested by cloning the repository, running `make docs`, `make validate`, and `make crosswalk`, and verifying all commands execute successfully and produce expected outputs.

**Acceptance Scenarios**:

1. **Given** the project skeleton, **When** examining the directory structure, **Then** it includes organized directories for roles, docs, scripts, inventory, group_vars, and specs
2. **Given** the Makefile, **When** running `make docs`, **Then** the documentation generator executes and produces all 7 output files in docs/generated/
3. **Given** the Makefile, **When** running `make validate`, **Then** the glossary validator scans all project files and reports validation results
4. **Given** the Makefile, **When** running `make crosswalk`, **Then** the CSV crosswalk file is generated from the control mapping data
5. **Given** a new team member reads the README, **When** they follow the setup instructions, **Then** they understand what the project does, how to use it, and the phased implementation plan

---

### Edge Cases

- **Controls without cross-framework mappings**: When a control exists in one framework but has no direct equivalent in another (e.g., Rev 3 control with no Rev 2 equivalent), the mapping MUST use explicit "N/A" value with a rationale field explaining why no mapping exists (ensures audit trail clarity)
- **Ambiguous acronyms with multiple meanings**: When an acronym has multiple valid meanings in different contexts (e.g., "AC" = Access Control vs Alternating Current), the glossary MUST create separate entries with context tags (e.g., "AC (compliance)", "AC (hardware)") and the validator MUST check context appropriately
- What if an HPC tailoring decision references a control that doesn't exist in the control mapping?
- **Missing/incomplete YAML data**: Documentation generator MUST fail immediately with clear error message specifying which file, entry, and required field is missing (prevents incomplete documentation generation)
- **DoD ODP guidance conflicts with university policy**: When DoD ODP guidance recommends a value that conflicts with existing university policy (e.g., different password rotation periods), use the university policy value and document the deviation with university-specific rationale explaining the conflict and risk acceptance
- How are deprecated controls from older framework versions handled in the crosswalk?
- What if a glossary term references another term in its "see also" list that doesn't exist?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a control mapping data structure containing all 110 NIST 800-171 Rev 2 controls with complete metadata (id, title, plain_language description, assessment_objectives, sprs_weight, automatable flag, applicable zones)
- **FR-002**: System MUST map each NIST 800-171 Rev 2 control to its Rev 3 equivalent, CMMC Level 2 practice ID, and NIST 800-53 Rev 5 source control
- **FR-003**: System MUST provide a glossary containing at least 60 terms with full_name, plain_language explanation (2-4 sentences), and role-specific "who_cares" explanations for PIs, researchers, sysadmins, CISO staff, and leadership
- **FR-004**: System MUST document HPC tailoring decisions for at least 10 common HPC/security conflicts, each including standard requirement, HPC challenge, tailored implementation, compensating controls, risk acceptance level, and NIST 800-223 reference
- **FR-005**: System MUST define all 49 Organization-Defined Parameters from NIST 800-171 Rev 3 with assigned values and rationale aligned with DoD guidance
- **FR-006**: System MUST provide a documentation generator that produces 7 distinct outputs: PI guide, researcher quickstart, sysadmin reference, CISO compliance map, leadership briefing, full glossary, and CSV crosswalk
- **FR-007**: System MUST ensure all generated documentation uses plain language with technical terms hyperlinked to glossary entries
- **FR-008**: System MUST provide a glossary validator that scans project files (.md, .yml, .j2) for undefined acronyms and returns non-zero exit code on violations
- **FR-009**: System MUST provide a complete Ansible project skeleton with directory structure, ansible.cfg, inventory structure, and group_vars with documented variables
- **FR-010**: System MUST provide a Makefile with targets for docs (generate documentation), validate (run glossary validator), and crosswalk (generate CSV)
- **FR-011**: System MUST include a README explaining the project purpose, usage instructions, and phased implementation plan
- **FR-012**: Control mapping entries MUST include placeholders for future Ansible role assignments (initially empty) and HPC tailoring references (initially null)
- **FR-013**: Glossary entries MUST include "see also" lists linking to related terms
- **FR-014**: HPC tailoring entries MUST include both Rev 2 and Rev 3 control identifiers for forward compatibility
- **FR-015**: CSV crosswalk MUST be importable into Excel and display accurate mappings across all four frameworks
- **FR-016**: Documentation generator MUST validate YAML data completeness before generation and fail with clear error messages specifying file path, entry identifier, and missing required field when incomplete data is detected
- **FR-017**: Control mapping entries MUST use explicit "N/A" value with accompanying rationale field when a control has no direct equivalent in another framework (e.g., Rev 3 control with no Rev 2 mapping)
- **FR-018**: Glossary MUST support context-tagged entries for acronyms with multiple meanings (e.g., "AC (compliance)" vs "AC (hardware)"), and the glossary validator MUST distinguish between different contexts when validating usage
- **FR-019**: When DoD ODP guidance conflicts with university policy requirements, ODP values MUST use the university policy value and include a deviation rationale field documenting the conflict, university-specific justification, and risk acceptance decision

### Key Entities

- **Control Mapping Entry**: Represents a single security control with its ID, title, plain-language description, assessment objectives, SPRS weight, automation capability, applicable zones, framework crosswalk mappings (Rev 2, Rev 3, CMMC L2, 800-53 R5) with "N/A" and rationale when no direct equivalent exists, Ansible role assignments (empty initially), and HPC tailoring reference
- **Glossary Term**: Represents a technical term or acronym with its full name, plain-language explanation, role-specific "who_cares" context for each of 5 audiences, related terms list, and optional context tag for disambiguating acronyms with multiple meanings
- **HPC Tailoring Decision**: Represents a documented deviation from standard control implementation with control identifiers (Rev 2 & Rev 3), title, standard requirement, HPC operational challenge, tailored implementation approach, compensating controls list, risk acceptance level, and NIST 800-223 reference
- **Organization-Defined Parameter**: Represents a configurable control parameter with ODP ID, associated control reference, parameter description, assigned value, rationale, and optional deviation rationale when university policy conflicts with DoD guidance
- **Generated Document**: Represents audience-specific documentation output (PI guide, researcher quickstart, sysadmin reference, CISO compliance map, leadership briefing, full glossary, or CSV crosswalk) produced from YAML sources

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A non-technical Principal Investigator can read the generated PI guide and understand their CUI data handling responsibilities without encountering unexplained jargon
- **SC-002**: All 110 NIST 800-171 Rev 2 controls and 97 Rev 3 requirements are present in the control mapping with accurate crosswalk to CMMC Level 2 and NIST 800-53 Rev 5
- **SC-003**: The glossary contains at least 60 terms, each with complete plain-language explanations and role-specific context for all 5 audience types (PI, researcher, sysadmin, CISO, leadership)
- **SC-004**: The documentation generator executes without errors and produces all 7 output files in under 30 seconds
- **SC-005**: The glossary validator successfully identifies undefined acronyms when introduced into project files and fails CI builds appropriately
- **SC-006**: The CSV crosswalk can be opened in Excel and displays a complete, human-readable mapping of all controls across all four frameworks
- **SC-007**: All 49 NIST 800-171 Rev 3 ODPs have assigned values with documented rationale
- **SC-008**: At least 10 HPC-specific tailoring decisions are documented with complete justification and compensating controls
- **SC-009**: A new team member can run `make docs`, `make validate`, and `make crosswalk` successfully within 5 minutes of cloning the repository
- **SC-010**: Generated documentation correctly hyperlinks at least 95% of technical terms to glossary entries

## Assumptions

- NIST 800-171 Rev 2, Rev 3, CMMC Level 2, and NIST 800-53 Rev 5 control lists and mappings are publicly available for reference
- DoD ODP guidance (April 2025) provides sufficient direction for assigning organization-defined parameter values
- NIST SP 800-223 (High-Performance Computing Security) provides adequate guidance for HPC tailoring decisions
- The project will use standard YAML 1.2 format for all data models
- Generated documentation will use GitHub-flavored Markdown
- CSV crosswalk will use UTF-8 encoding with comma delimiters
- Python 3.9 or higher is available for running documentation generator and validator scripts
- The Ansible project will target RHEL 9 / Rocky Linux 9 as documented in the constitution
- Future specs (002+) will populate the Ansible role assignments in the control mapping

## Constraints

- No Ansible roles are implemented in this feature - only data models and tooling
- All data must be stored in YAML format to serve as machine-readable single source of truth
- All generated documentation must comply with the constitution's "Plain Language First" principle
- Control mappings must support all four frameworks simultaneously (Rev 2, Rev 3, CMMC L2, 800-53 R5)
- Documentation generator must be deterministic - same YAML input always produces identical output
- Glossary validator must be CI-friendly (exit codes, parseable output)
- CSV crosswalk must be compatible with Microsoft Excel and LibreOffice Calc

## Out of Scope

- Implementation of Ansible roles for security controls (covered in future specs)
- Automated SPRS score calculation (may be added in future enhancement)
- Web-based UI for browsing control mappings (command-line/file-based only)
- Integration with external compliance management platforms
- Automated assessment procedures or evidence collection (covered by Ansible verify/evidence tasks in future specs)
- Migration scripts for importing existing SSP content
- Multi-language support (English only)
