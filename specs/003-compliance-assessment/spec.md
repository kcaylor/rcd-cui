# Feature Specification: Compliance Assessment and Reporting Layer

**Feature Branch**: `003-compliance-assessment`
**Created**: 2026-02-14
**Status**: Draft
**Input**: User description: "Build the compliance assessment, evidence collection, and reporting layer. Depends on Specs 001 and 002."

## Clarifications

### Session 2026-02-14

- Q: How does SPRS calculation handle controls that are "partially implemented" (some systems compliant, others not)? → A: Binary pass/fail - all applicable systems must pass for the control to receive credit
- Q: How does evidence collection handle systems that are offline during assessment? → A: Continue assessment, mark offline systems as "not assessed" with clear notation in results
- Q: How are secrets/credentials redacted from evidence files before packaging? → A: Pattern-based redaction replacing secret values with "[REDACTED]" while preserving configuration structure

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Run Comprehensive Compliance Assessment Across Enclave (Priority: P1)

A compliance officer needs to run a single assessment that evaluates all NIST 800-171 controls across every system in the research computing enclave, collecting structured results that show which controls pass, which fail, and why. The assessment must be non-destructive (read-only verification), zone-aware, and produce machine-readable output that feeds into scoring and reporting tools.

**Why this priority**: Assessment is the foundation for all other compliance activities. Without the ability to measure current compliance state, organizations cannot calculate SPRS scores, generate evidence for auditors, or track improvement over time. This is the "single source of truth" that drives all downstream reports and decisions.

**Independent Test**: Can be fully tested by running the assessment playbook against a test enclave with known compliance gaps, verifying that the JSON output correctly identifies passing and failing controls, and confirming that the playbook runs without errors in --check mode across all zone types.

**Acceptance Scenarios**:

1. **Given** a research computing enclave with systems in all four zones (management, internal, restricted, public), **When** the assessment playbook runs, **Then** it executes verify.yml from every deployed role on every applicable system and produces structured JSON results
2. **Given** a system where some controls pass and some fail, **When** the assessment completes, **Then** the JSON output includes control ID, pass/fail status, timestamp, evidence file references, and plain-language explanation of any failures
3. **Given** the assessment playbook, **When** run with --check mode, **Then** it completes without errors and without making any changes to target systems
4. **Given** an enclave with OpenSCAP deployed (from Spec 002), **When** the assessment runs, **Then** it also executes OpenSCAP scans using the CUI tailoring profile and incorporates those results into the unified assessment output
5. **Given** role evidence.yml tasks (from Spec 002), **When** the assessment runs with evidence collection enabled, **Then** it collects all evidence artifacts and stores them in a timestamped directory structure

---

### User Story 2 - Calculate and Understand SPRS Score (Priority: P1)

A university research compliance director needs to calculate the organization's Supplier Performance Risk System (SPRS) score and understand exactly which control gaps are causing point deductions. The score must match DoD's official weighting methodology, and the breakdown must be understandable by non-technical leadership who need to prioritize remediation investments.

**Why this priority**: SPRS score is the single number that determines whether an organization can bid on DoD contracts requiring CUI handling. A score of -203 (all controls failed) versus 110 (all controls passed) represents the difference between contract eligibility and exclusion. Leadership needs this number and needs to understand which investments will improve it most.

**Independent Test**: Can be fully tested by providing a known set of control statuses (some passed, some failed with known weights), calculating the SPRS score manually per DoD methodology, then comparing against the tool's output. The tool must produce identical results.

**Acceptance Scenarios**:

1. **Given** assessment results showing control compliance status, **When** the SPRS calculator processes the results, **Then** it produces a numeric score between -203 and 110 using DoD's official control weighting
2. **Given** a calculated SPRS score, **When** a compliance officer views the breakdown, **Then** they see deductions grouped by control family with each deduction explained in plain language (e.g., "MFA not enforced for remote access: -5 points")
3. **Given** POA&M data indicating controls under remediation, **When** the SPRS calculator includes POA&M adjustments, **Then** controls with active POA&M items are scored according to DoD POA&M allowances
4. **Given** the SPRS calculation, **When** leadership asks "what would improve our score the most?", **Then** the output includes a prioritized list of unmet controls sorted by point value and estimated remediation effort
5. **Given** historical SPRS calculations stored over time, **When** generating trend reports, **Then** the system can show score progression across multiple assessment dates

---

### User Story 3 - Generate SSP Evidence Package for Auditors (Priority: P1)

An information security analyst preparing for a CMMC Level 2 assessment needs to generate a complete System Security Plan (SSP) evidence package that demonstrates how each NIST 800-171 control is implemented. The package must include system configuration evidence, narrative descriptions in plain language, and organized artifacts that a C3PAO assessor can easily navigate.

**Why this priority**: C3PAO assessments require documented evidence of control implementation. Generating this evidence manually is extremely time-consuming (hundreds of hours for 110 controls). Automated evidence collection with plain-language narratives dramatically reduces assessment preparation time and improves consistency.

**Independent Test**: Can be fully tested by running the evidence generator against a hardened enclave, verifying that all specified evidence types are collected (inventory, packages, configs, etc.), and confirming that generated narrative paragraphs pass the glossary validator for plain-language compliance.

**Acceptance Scenarios**:

1. **Given** a deployed enclave, **When** the SSP evidence generator runs, **Then** it collects: system inventory, installed packages, network configuration, firewall rules, SELinux status, FIPS status, audit rules, SSH configuration, PAM configuration, user/group listings, Slurm configuration, and encryption status
2. **Given** collected evidence artifacts, **When** the generator completes, **Then** all artifacts are packaged in a timestamped archive with consistent directory structure matching CMMC assessment guide organization
3. **Given** the control mapping from Spec 001, **When** generating control narratives, **Then** each implemented control has a one-paragraph narrative explaining HOW the control is met, referencing specific evidence files that prove implementation
4. **Given** generated narratives, **When** validated against validate_glossary.py from Spec 001, **Then** all narratives pass plain-language validation (no unexplained jargon, consistent terminology)
5. **Given** an SSP evidence package, **When** an auditor navigates to a specific control (e.g., 3.5.3 MFA), **Then** they find the narrative, referenced evidence files, and configuration snippets proving implementation

---

### User Story 4 - Track and Report POA&M Items (Priority: P2)

A project manager responsible for compliance remediation needs to track Plan of Action and Milestones (POA&M) items for controls that aren't yet fully implemented. They need a system that tracks weakness descriptions, milestones, target dates, status, and resources—all in language that a PM without security background can understand and act upon.

**Why this priority**: POA&M is required by NIST 800-171 and CMMC for any controls not fully implemented. Organizations need to demonstrate continuous improvement and track remediation progress. This is P2 because POA&M tracking can be done manually while assessment and evidence collection are foundational automation needs.

**Independent Test**: Can be fully tested by creating POA&M items for several controls with different statuses (open, in progress, completed, delayed), generating reports, and verifying that a PM unfamiliar with NIST can understand the report and identify overdue items.

**Acceptance Scenarios**:

1. **Given** a YAML data file containing POA&M items, **When** the POA&M script processes it, **Then** it generates both markdown and CSV status reports with all tracked fields (control, weakness, milestone, target date, status, resources, risk level)
2. **Given** POA&M items with various statuses, **When** generating the report, **Then** items are grouped by status (overdue, in progress, completed) with clear visual indicators
3. **Given** a POA&M weakness description, **When** displayed in reports, **Then** the description uses plain language explaining what's missing and why it matters (not just "control 3.5.3 not implemented")
4. **Given** POA&M items with target dates, **When** viewing the report, **Then** overdue items are highlighted and days overdue is calculated automatically
5. **Given** POA&M data, **When** calculating SPRS score, **Then** controls with documented POA&M items receive appropriate credit per DoD guidelines

---

### User Story 5 - View Compliance Dashboard for Different Audiences (Priority: P2)

Leadership, the CISO, and auditors each need different views of compliance status. Leadership wants a high-level summary with the SPRS score gauge and trend. The CISO wants detailed breakdown by control family with drill-down capability. Auditors want direct links to evidence artifacts. A single dashboard generator must produce audience-appropriate views.

**Why this priority**: Different stakeholders make different decisions based on compliance data. Leadership approves budgets, CISO prioritizes remediation, auditors verify claims. Generating audience-appropriate views from a single data source ensures consistency while meeting different information needs. This is P2 because the underlying data (from P1 stories) must exist first.

**Independent Test**: Can be fully tested by generating dashboards from assessment data, opening each audience view in a browser, and verifying that leadership sees the summary gauge, CISO sees family breakdown, and auditors see evidence links.

**Acceptance Scenarios**:

1. **Given** assessment results and SPRS calculation, **When** generating the leadership view, **Then** the dashboard shows: SPRS score gauge (visual 0-110 scale with current position), overall compliance percentage, and high-level status by control family (green/yellow/red)
2. **Given** the CISO view, **When** drilling into a control family, **Then** the view shows each control's status, verification command results, and links to remediation guidance
3. **Given** the auditor view, **When** clicking on a control, **Then** the view shows the control narrative, evidence file links, and verification output
4. **Given** historical assessment data, **When** viewing trend charts, **Then** the dashboard shows SPRS score over time and control compliance percentage by family over time
5. **Given** a generated dashboard, **When** opened in a modern browser (Chrome, Firefox, Safari), **Then** it renders correctly with all visualizations functional

---

### User Story 6 - Generate Complete Auditor Package for C3PAO Assessment (Priority: P3)

A compliance coordinator preparing for a CMMC Level 2 certification assessment needs to generate a complete auditor package containing all artifacts that a C3PAO assessor will request. The package must be organized per CMMC assessment guide structure and include everything needed for the assessment without additional manual compilation.

**Why this priority**: Pre-assessment preparation is extremely time-consuming. Having a single command that generates everything an auditor needs reduces preparation time from weeks to hours. This is P3 because it depends on all other stories being complete—it's the final integration that bundles everything together.

**Independent Test**: Can be fully tested by generating an auditor package, reviewing against the CMMC Level 2 assessment guide requirements checklist, and verifying that all required artifacts are present and correctly organized.

**Acceptance Scenarios**:

1. **Given** a compliant enclave with all assessments run, **When** generating the auditor package, **Then** it bundles: crosswalk CSV (controls to evidence), control narratives, evidence archive, SPRS calculation with breakdown, POA&M report, HPC tailoring documentation, and ODP values
2. **Given** the CMMC Level 2 assessment guide structure, **When** organizing the package, **Then** artifacts are organized in a directory structure matching assessment guide sections (e.g., by control family, by assessment objective)
3. **Given** HPC tailoring decisions from Spec 001, **When** including in the auditor package, **Then** each tailoring decision includes: the baseline control, the deviation, the justification, and the compensating control
4. **Given** ODP values from Spec 001, **When** including in the auditor package, **Then** organization-defined parameters are clearly documented with their selected values and justifications
5. **Given** a complete auditor package, **When** reviewed by a compliance expert, **Then** it contains all artifacts a C3PAO would request for CMMC Level 2 certification

---

### Edge Cases

- What happens if assessment runs against a partially deployed enclave where some roles are missing?
- How does SPRS calculation handle controls that are "partially implemented" (some systems compliant, others not)? → Binary pass/fail: all applicable systems must pass for the control to receive SPRS credit; partial compliance results in zero credit for that control
- What if OpenSCAP scan fails on some systems but succeeds on others?
- How does evidence collection handle systems that are offline during assessment? → Continue assessment for reachable systems; mark unreachable systems as "not assessed" with timestamp and reason; include coverage summary showing assessed vs. total systems
- What happens if POA&M target dates are in the past but status is still "in progress"?
- How does the dashboard handle the first assessment when no historical data exists?
- What if evidence files exceed reasonable size limits (multi-gigabyte audit logs)?
- How are secrets/credentials redacted from evidence files before packaging? → Pattern-based redaction using regex to identify secrets (API keys, passwords, private keys) and replace values with "[REDACTED]" while preserving configuration structure for auditor review

## Requirements *(mandatory)*

### Functional Requirements

**Assessment Playbook**:
- **FR-001**: System MUST provide an assess.yml playbook that executes verify.yml tasks from every deployed role across the enclave
- **FR-002**: Assessment playbook MUST run OpenSCAP scans using the CUI tailoring profile from Spec 002
- **FR-003**: Assessment playbook MUST collect evidence artifacts from every role's evidence.yml tasks
- **FR-004**: Assessment results MUST be output as structured JSON with control ID, status, timestamp, and evidence references
- **FR-005**: Assessment playbook MUST complete without errors in Ansible --check mode
- **FR-006**: Assessment MUST be non-destructive and make no changes to target systems
- **FR-006a**: Assessment MUST continue when systems are unreachable, marking them as "not assessed" with timestamp and reason, and include a coverage summary (assessed vs. total systems) in output

**SPRS Score Calculator**:
- **FR-007**: System MUST calculate SPRS score using DoD's official weighting for each NIST 800-171 control
- **FR-008**: SPRS calculator MUST accept assessment results and POA&M data as input
- **FR-009**: SPRS output MUST include total score, breakdown by control family, and list of deductions with plain-language explanations
- **FR-010**: SPRS calculator MUST be implemented as an Ansible filter plugin (plugins/filter/sprs.py) for integration with playbooks
- **FR-011**: SPRS calculation MUST match manual calculation when verified against known test scenarios
- **FR-011a**: SPRS calculator MUST use binary pass/fail logic: a control receives credit only when ALL applicable systems pass verification; partial compliance yields zero credit

**SSP Evidence Generator**:
- **FR-012**: Evidence generator MUST collect: system inventory, installed packages, network configuration, firewall rules, SELinux status, FIPS status, audit rules, SSH configuration, PAM configuration, user/group listings, Slurm configuration, and encryption status
- **FR-013**: Evidence MUST be packaged as a timestamped archive with consistent directory structure
- **FR-014**: Generator MUST produce markdown narratives for each control explaining how it is met with references to specific evidence files
- **FR-015**: Generated narratives MUST pass validate_glossary.py plain-language validation from Spec 001
- **FR-016**: Evidence generator MUST redact secrets and credentials from collected artifacts using pattern-based detection (API keys, passwords, private key blocks) and replace values with "[REDACTED]" while preserving configuration structure

**POA&M Tracker**:
- **FR-017**: System MUST define a YAML data model for POA&M items including: control ID, weakness description, milestones, target date, status, assigned resources, and risk level
- **FR-018**: POA&M script MUST generate status reports in both markdown and CSV formats
- **FR-019**: POA&M reports MUST use plain-language descriptions understandable by project managers without security background
- **FR-020**: POA&M reports MUST calculate and display days overdue for items past target date
- **FR-021**: POA&M data MUST integrate with SPRS calculation per DoD POA&M credit guidelines

**Compliance Dashboard**:
- **FR-022**: Dashboard MUST produce HTML output showing SPRS score gauge, controls met/unmet by family, POA&M timeline, and trend over time
- **FR-023**: Dashboard MUST provide audience-specific views: leadership (summary), CISO (detail), auditor (evidence links)
- **FR-024**: Dashboard MUST render correctly in modern browsers (Chrome, Firefox, Safari)
- **FR-025**: Dashboard MUST handle first-time generation when no historical data exists (show current snapshot only)

**Auditor Package Generator**:
- **FR-026**: Generator MUST bundle: crosswalk CSV, control narratives, evidence archive, SPRS calculation, POA&M report, HPC tailoring documentation, ODP values
- **FR-027**: Package MUST be organized per CMMC Level 2 assessment guide structure
- **FR-028**: Package MUST include all artifacts a C3PAO would request for certification assessment

**Makefile Integration**:
- **FR-029**: Makefile MUST include targets: assess, report, sprs, poam, evidence, dashboard
- **FR-030**: Make targets MUST use execution environment for consistent tooling

### Key Entities

- **Assessment Result**: Structured output from running verification tasks; includes control ID, compliance status (pass/fail/partial), timestamp, target system, evidence file references, and failure explanation
- **SPRS Score**: Numeric value (-203 to 110) representing overall compliance posture; includes breakdown by control family and list of deductions with point values
- **Evidence Artifact**: File or command output collected to prove control implementation; includes collection timestamp, source system, artifact type, and file path
- **Control Narrative**: Plain-language paragraph explaining how a specific control is implemented; references evidence files and configuration details
- **POA&M Item**: Record of a compliance gap under remediation; includes control ID, weakness description, milestones, target date, current status, assigned resources, and risk level
- **Auditor Package**: Complete bundle of compliance documentation for external assessment; organized per CMMC assessment guide structure

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Assessment playbook runs without errors in --check mode against systems in all four zone types (management, internal, restricted, public)
- **SC-002**: SPRS score calculation matches manual calculation within +/- 0 points for a test scenario with 10 passing controls and 5 failing controls
- **SC-003**: 100% of generated SSP narratives pass validate_glossary.py plain-language validation
- **SC-004**: POA&M status report is rated as "understandable" by 3 out of 3 project managers with no security background (informal user test)
- **SC-005**: Compliance dashboard renders correctly in Chrome, Firefox, and Safari browsers on both desktop and tablet screen sizes
- **SC-006**: Auditor package contains all artifacts listed in CMMC Level 2 assessment guide (verified against checklist)
- **SC-007**: Evidence collection completes within 30 minutes for an enclave of 50 systems
- **SC-008**: SPRS breakdown shows 100% of point deductions with plain-language explanations (no unexplained deductions)
- **SC-009**: Assessment and evidence collection are fully automated with no manual steps required
- **SC-010**: Dashboard historical trend displays correctly after 3 or more assessment runs

## Assumptions

- Spec 001 (Data Models) is complete with control_mapping.yml, ODP values, HPC tailoring decisions, and glossary
- Spec 002 (Ansible Roles) is complete with verify.yml and evidence.yml tasks for all 31 roles
- OpenSCAP with CUI tailoring profile is deployed per Spec 002 cm_openscap_baseline role
- Target systems are accessible via Ansible with appropriate credentials
- Python 3.9+ is available in the execution environment for filter plugins and scripts
- DoD SPRS weighting methodology is publicly documented and can be implemented
- Historical assessment data will be stored in a structured format (JSON files) in a designated directory
- Wazuh SIEM integration exists for centralized log collection (per Spec 002)
- C3PAO assessors follow the standard CMMC Level 2 assessment guide structure
- Browser-based dashboard will be served locally (no external hosting requirements)

## Constraints

- Assessment playbook must be completely non-destructive (read-only operations only)
- Evidence collection must redact secrets (API keys, passwords, private keys) before packaging
- All generated content must use plain language per constitution requirements
- SPRS calculation must exactly match DoD's official methodology (no approximations)
- Dashboard must work offline without external CDN dependencies
- Evidence archive must be reasonably sized (< 100MB for typical enclave)
- All reports must be generatable from command line without GUI dependencies
- Narratives must reference the glossary terms defined in Spec 001
- Package structure must be stable across assessment runs for auditability

## Out of Scope

- Real-time continuous monitoring (this is point-in-time assessment)
- Automated remediation of findings (Spec 002 handles implementation; this spec only assesses)
- Integration with external GRC platforms (Archer, ServiceNow, RSA)
- Cloud-hosted dashboard or SaaS deployment
- Multi-organization assessment aggregation
- Automated C3PAO scheduling or communication
- Legal review of SSP narratives
- Training content generation for end users
- Penetration testing or vulnerability scanning beyond OpenSCAP
- Compliance with frameworks other than NIST 800-171 / CMMC Level 2
