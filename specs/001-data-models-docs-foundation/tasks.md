# Tasks: Data Models and Documentation Generation Foundation

**Input**: Design documents from `/specs/001-data-models-docs-foundation/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, quickstart.md

**Tests**: Tests are NOT explicitly requested in the feature specification. Test tasks are included for YAML schema validation and integration testing as they are necessary for data integrity and CI/CD validation gates.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story. Note that User Stories 1-3 are all P1 (critical foundation) and form the core data models. They can be worked on in parallel once the foundational infrastructure is in place.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This is an Ansible project structure with Python tooling. All paths are from repository root (`rcd-cui/`).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [X] T001 Create Ansible project directory structure (inventory/, roles/, docs/, scripts/, templates/, tests/)
- [X] T002 Create requirements.txt with dependencies (pyyaml>=6.0, pydantic>=2.0, jinja2>=3.1, pytest>=7.0)
- [X] T003 [P] Create ansible.cfg with project configuration
- [X] T004 [P] Create inventory/hosts.yml for Ansible inventory structure
- [X] T005 [P] Create inventory/group_vars/ directory with skeleton YAML files (all.yml, management.yml, internal.yml, restricted.yml)
- [X] T006 [P] Create .gitignore to exclude docs/generated/ and Python cache files
- [X] T007 [P] Create roles/common/vars/ directory structure for control mapping
- [X] T008 [P] Create docs/glossary/ directory for glossary YAML
- [X] T009 [P] Create docs/generated/ directory for generated documentation outputs
- [X] T010 [P] Create scripts/models/ directory for Pydantic data models
- [X] T011 [P] Create templates/_partials/ directory for Jinja2 template partials
- [X] T012 [P] Create tests/ directory for pytest tests

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T013 Create scripts/models/__init__.py with shared imports and utilities
- [X] T014 [P] Create Pydantic model for FrameworkMapping in scripts/models/control_mapping.py
- [X] T015 [P] Create Pydantic model for GlossaryTerm and AudienceContext in scripts/models/glossary.py
- [X] T016 [P] Create Pydantic model for HPCTailoringEntry in scripts/models/hpc_tailoring.py
- [X] T017 [P] Create Pydantic model for ODPValue in scripts/models/odp_values.py
- [X] T018 Implement YAML loader utility with caching in scripts/models/__init__.py (functools.lru_cache for load_yaml_cached function)
- [X] T019 Create pytest configuration in tests/conftest.py with fixtures for loading test YAML data
- [X] T020 [P] Create Jinja2 template partial for glossary hyperlinking in templates/_partials/glossary_link.j2
- [X] T021 [P] Create Jinja2 template partial for control table formatting in templates/_partials/control_table.j2
- [X] T022 [P] Create Jinja2 template partial for standard header in templates/_partials/header.j2

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Establish Single Source of Truth for Control Mappings (Priority: P1) 🎯 MVP

**Goal**: Create canonical YAML file mapping all 110 NIST 800-171 Rev 2 controls to Rev 3, CMMC Level 2, and NIST 800-53 Rev 5 with complete metadata

**Independent Test**: Load the control mapping YAML file, verify all 110 NIST 800-171 Rev 2 controls are present with complete metadata, and confirm accurate crosswalk mappings to Rev 3, CMMC Level 2, and 800-53 Rev 5 controls

### Implementation for User Story 1

- [X] T023 [US1] Complete SecurityControl Pydantic model in scripts/models/control_mapping.py with all required fields (control_id, title, family, plain_language, assessment_objectives, sprs_weight, automatable, zones, framework_mapping, ansible_roles, hpc_tailoring_ref)
- [X] T024 [US1] Add field validators to SecurityControl model for "N/A" mappings requiring rationale (validate_na_has_rationale method)
- [X] T025 [US1] Complete ControlMappingData root model in scripts/models/control_mapping.py with version, last_updated, description, controls fields
- [X] T026 [US1] Add validator to ControlMappingData to ensure minimum 110 Rev 2 controls present
- [X] T027 [US1] Create control_mapping.yml YAML file structure in roles/common/vars/control_mapping.yml with metadata header (version, last_updated, description)
- [X] T028 [US1] Populate control_mapping.yml with all 14 Access Control (AC) family controls (3.1.1 through 3.1.22) with complete metadata
- [X] T029 [US1] Populate control_mapping.yml with all 4 Awareness and Training (AT) family controls (3.2.1 through 3.2.3) with complete metadata
- [X] T030 [US1] Populate control_mapping.yml with all 9 Audit and Accountability (AU) family controls (3.3.1 through 3.3.9) with complete metadata
- [X] T031 [US1] Populate control_mapping.yml with all 2 Security Assessment (CA) family controls (3.12.1 through 3.12.4) with complete metadata
- [X] T032 [US1] Populate control_mapping.yml with all 9 Configuration Management (CM) family controls (3.4.1 through 3.4.9) with complete metadata
- [X] T033 [US1] Populate control_mapping.yml with all 11 Identification and Authentication (IA) family controls (3.5.1 through 3.5.11) with complete metadata
- [X] T034 [US1] Populate control_mapping.yml with all 5 Incident Response (IR) family controls (3.6.1 through 3.6.3) with complete metadata
- [X] T035 [US1] Populate control_mapping.yml with all 6 Maintenance (MA) family controls (3.7.1 through 3.7.6) with complete metadata
- [X] T036 [US1] Populate control_mapping.yml with all 8 Media Protection (MP) family controls (3.8.1 through 3.8.9) with complete metadata
- [X] T037 [US1] Populate control_mapping.yml with all 3 Physical Protection (PE) family controls (3.10.1 through 3.10.6) with complete metadata
- [X] T038 [US1] Populate control_mapping.yml with all 2 Personnel Security (PS) family controls (3.9.1 through 3.9.2) with complete metadata
- [X] T039 [US1] Populate control_mapping.yml with all 4 Risk Assessment (RA) family controls (3.11.1 through 3.11.3) with complete metadata
- [X] T040 [US1] Populate control_mapping.yml with all 5 System and Services Acquisition (SA) family controls (3.13.1 through 3.13.4) with complete metadata
- [X] T041 [US1] Populate control_mapping.yml with all 22 System and Communications Protection (SC) family controls (3.13.1 through 3.13.16) with complete metadata
- [X] T042 [US1] Populate control_mapping.yml with all 7 System and Information Integrity (SI) family controls (3.14.1 through 3.14.7) with complete metadata
- [X] T043 [US1] Create pytest test in tests/test_yaml_schemas.py to validate control_mapping.yml schema against ControlMappingData model
- [X] T044 [US1] Create pytest test in tests/test_yaml_schemas.py to verify exactly 110 Rev 2 controls present in control_mapping.yml
- [X] T045 [US1] Create pytest test in tests/test_yaml_schemas.py to verify all controls have complete framework mappings (no missing required fields)
- [X] T046 [US1] Create pytest test in tests/test_yaml_schemas.py to verify "N/A" framework mappings have rationale fields

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently. Control mapping is the canonical data source for all 110 controls.

---

## Phase 4: User Story 2 - Create Plain-Language Glossary for All Stakeholders (Priority: P1)

**Goal**: Create machine-readable YAML glossary with 60+ terms, each with plain-language explanations and role-specific context for all 5 audience types

**Independent Test**: Select any acronym or technical term from compliance documents, look it up in the glossary, and verify that a non-technical reader can understand what it means and why it matters to their role

### Implementation for User Story 2

- [X] T047 [US2] Complete GlossaryTerm Pydantic model in scripts/models/glossary.py with term, full_name, plain_language, who_cares (5 audiences), see_also, context fields
- [X] T048 [US2] Complete AudienceContext Pydantic model with pi, researcher, sysadmin, ciso, leadership fields
- [X] T049 [US2] Complete GlossaryData root model in scripts/models/glossary.py with version, last_updated, description, terms dictionary
- [X] T050 [US2] Add validator to GlossaryData to ensure minimum 60 terms present
- [X] T051 [US2] Create terms.yml YAML file structure in docs/glossary/terms.yml with metadata header
- [X] T052 [US2] Populate terms.yml with all 15 NIST control family acronyms (AC, AT, AU, CA, CM, IA, IR, MA, MP, PE, PS, RA, SA, SC, SI) with plain-language explanations
- [X] T053 [US2] Populate terms.yml with key technical concepts (CUI, FIPS, MFA, SIEM, Enclave, SSP, POA&M, RBAC, Least Privilege) - minimum 10 terms
- [X] T054 [US2] Populate terms.yml with regulatory instruments (NIST 800-171, CMMC, DFARS, SPRS, FAR, ITAR) - minimum 6 terms
- [X] T055 [US2] Populate terms.yml with HPC concepts (Slurm, InfiniBand, Parallel Filesystem, MPI, Batch Job, Compute Node, Login Node, FIPS on InfiniBand) - minimum 8 terms
- [X] T056 [US2] Populate terms.yml with compliance process terms (C3PAO, Assessment, Self-Assessment, System Security Plan, Continuous Monitoring, Plan of Action & Milestones) - minimum 6 terms
- [X] T057 [US2] Add context-tagged glossary entries for ambiguous acronyms (e.g., "AC (compliance)" vs "AC (hardware)") - minimum 2 examples
- [X] T058 [US2] Validate all see_also references point to existing glossary terms
- [X] T059 [US2] Create pytest test in tests/test_yaml_schemas.py to validate terms.yml schema against GlossaryData model
- [X] T060 [US2] Create pytest test in tests/test_yaml_schemas.py to verify minimum 60 terms present in glossary
- [X] T061 [US2] Create pytest test in tests/test_yaml_schemas.py to verify all terms have complete who_cares fields for all 5 audiences
- [X] T062 [US2] Create pytest test in tests/test_yaml_schemas.py to verify see_also references integrity (all referenced terms exist)

**Checkpoint**: At this point, User Story 2 should be fully functional. Glossary provides plain-language definitions for all stakeholders.

---

## Phase 5: User Story 3 - Document HPC-Specific Tailoring Decisions (Priority: P1)

**Goal**: Create structured YAML documenting 10+ HPC/security control conflicts with tailored implementations and compensating controls

**Independent Test**: Select an HPC-specific scenario (e.g., "session timeout on compute nodes"), find it in the tailoring document, and verify it explains the standard requirement, why HPC conflicts, the tailored implementation, and any compensating controls

### Implementation for User Story 3

- [X] T063 [US3] Complete HPCTailoringEntry Pydantic model in scripts/models/hpc_tailoring.py with all required fields (tailoring_id, control_r2, control_r3, title, standard_requirement, hpc_challenge, tailored_implementation, compensating_controls, risk_acceptance, nist_800_223_reference, performance_impact)
- [X] T064 [US3] Complete HPCTailoringData root model in scripts/models/hpc_tailoring.py with version, last_updated, description, tailoring_decisions list
- [X] T065 [US3] Add validator to HPCTailoringData to ensure minimum 10 tailoring entries present
- [X] T066 [US3] Create hpc_tailoring.yml YAML file structure in docs/hpc_tailoring.yml with metadata header
- [X] T067 [US3] Add HPC tailoring entry for session timeout on compute nodes (AC-12 / 03.13.11) in docs/hpc_tailoring.yml
- [X] T068 [US3] Add HPC tailoring entry for FIPS cryptography on InfiniBand (SC-13 / 03.13.08) in docs/hpc_tailoring.yml
- [X] T069 [US3] Add HPC tailoring entry for audit volume on compute nodes (AU-2 / 03.03.01) in docs/hpc_tailoring.yml
- [X] T070 [US3] Add HPC tailoring entry for MFA for batch jobs (IA-2(1) / 03.05.03) in docs/hpc_tailoring.yml
- [X] T071 [US3] Add HPC tailoring entry for multi-tenancy isolation (SC-3 / 03.13.02) in docs/hpc_tailoring.yml
- [X] T072 [US3] Add HPC tailoring entry for container security (CM-7 / 03.04.08) in docs/hpc_tailoring.yml
- [X] T073 [US3] Add HPC tailoring entry for parallel filesystem ACLs (AC-3 / 03.01.03) in docs/hpc_tailoring.yml
- [X] T074 [US3] Add HPC tailoring entry for long-running job management (AC-12 / 03.13.11) in docs/hpc_tailoring.yml
- [X] T075 [US3] Add HPC tailoring entry for GPU memory sanitization (MP-6 / 03.08.03) in docs/hpc_tailoring.yml
- [X] T076 [US3] Add HPC tailoring entry for node provisioning via PXE (CM-2 / 03.04.01) in docs/hpc_tailoring.yml
- [X] T077 [US3] Link HPC tailoring entries back to control_mapping.yml (update hpc_tailoring_ref fields for relevant controls)
- [X] T078 [US3] Create pytest test in tests/test_yaml_schemas.py to validate hpc_tailoring.yml schema against HPCTailoringData model
- [X] T079 [US3] Create pytest test in tests/test_yaml_schemas.py to verify minimum 10 tailoring decisions present
- [X] T080 [US3] Create pytest test in tests/test_yaml_schemas.py to verify all tailoring entries have at least one compensating control

**Checkpoint**: At this point, User Story 3 should be fully functional. HPC tailoring decisions are documented with compensating controls.

---

## Phase 6: User Story 4 - Define Organization-Defined Parameters for Rev 3 (Priority: P2)

**Goal**: Assign specific values to all 49 Organization-Defined Parameters in NIST 800-171 Rev 3, aligned with DoD guidance and adapted for university research computing

**Independent Test**: Verify all 49 ODPs from NIST 800-171 Rev 3 have assigned values in the YAML file, each with the ODP ID, control reference, parameter description, assigned value, and rationale

### Implementation for User Story 4

- [X] T081 [US4] Complete ODPValue Pydantic model in scripts/models/odp_values.py with odp_id, control, parameter_description, assigned_value, rationale, dod_guidance, deviation_rationale fields
- [X] T082 [US4] Complete ODPValuesData root model in scripts/models/odp_values.py with version, last_updated, description, odp_values list
- [X] T083 [US4] Add validator to ODPValuesData to ensure exactly 49 ODP entries present
- [X] T084 [US4] Create odp_values.yml YAML file structure in docs/odp_values.yml with metadata header
- [X] T085 [US4] Populate odp_values.yml with ODP-01 through ODP-10 (Identity and Authentication parameters: password length, complexity, lifetime, etc.)
- [X] T086 [US4] Populate odp_values.yml with ODP-11 through ODP-20 (Access Control parameters: session timeouts, account review periods, etc.)
- [X] T087 [US4] Populate odp_values.yml with ODP-21 through ODP-30 (Audit and Accountability parameters: audit retention, review frequency, etc.)
- [X] T088 [US4] Populate odp_values.yml with ODP-31 through ODP-40 (Configuration Management and System Protection parameters)
- [X] T089 [US4] Populate odp_values.yml with ODP-41 through ODP-49 (Incident Response, Media Protection, and other parameters)
- [X] T090 [US4] Add deviation_rationale fields for ODPs that differ from DoD guidance (e.g., password rotation period, audit retention)
- [X] T091 [US4] Create pytest test in tests/test_yaml_schemas.py to validate odp_values.yml schema against ODPValuesData model
- [X] T092 [US4] Create pytest test in tests/test_yaml_schemas.py to verify exactly 49 ODP entries present
- [X] T093 [US4] Create pytest test in tests/test_yaml_schemas.py to verify ODPs with assigned_value != dod_guidance have deviation_rationale

**Checkpoint**: At this point, User Story 4 should be fully functional. All 49 ODPs are defined with rationale.

---

## Phase 7: User Story 5 - Generate Audience-Specific Documentation (Priority: P2)

**Goal**: Implement Python documentation generator that produces 7 distinct outputs from YAML data sources using Jinja2 templates

**Independent Test**: Run the documentation generator script and verify it produces all 7 output files (pi_guide.md, researcher_quickstart.md, sysadmin_reference.md, ciso_compliance_map.md, leadership_briefing.md, glossary_full.md, crosswalk.csv) with no errors, and confirm that technical jargon is hyperlinked to glossary entries

### Implementation for User Story 5

- [X] T094 [P] [US5] Create Jinja2 template for PI guide in templates/pi_guide.md.j2 with plain-language control explanations and data handling responsibilities
- [X] T095 [P] [US5] Create Jinja2 template for researcher quickstart in templates/researcher_quickstart.md.j2 with researcher onboarding and system access procedures
- [X] T096 [P] [US5] Create Jinja2 template for sysadmin reference in templates/sysadmin_reference.md.j2 with operations manual and implementation procedures
- [X] T097 [P] [US5] Create Jinja2 template for CISO compliance map in templates/ciso_compliance_map.md.j2 with complete control implementation matrix
- [X] T098 [P] [US5] Create Jinja2 template for leadership briefing in templates/leadership_briefing.md.j2 with executive summary and compliance posture
- [X] T099 [P] [US5] Create Jinja2 template for glossary in templates/glossary_full.md.j2 with alphabetical term listing and cross-references
- [X] T100 [P] [US5] Create Jinja2 template for CSV crosswalk in templates/crosswalk.csv.j2 with Excel-compatible control mappings
- [X] T101 [US5] Implement main documentation generator script in scripts/generate_docs.py with YAML loading, Pydantic validation, and template rendering
- [X] T102 [US5] Implement CLI argument parsing in scripts/generate_docs.py (--output-dir, --validate-only flags)
- [X] T103 [US5] Implement YAML data loading with Pydantic validation in scripts/generate_docs.py (load all 4 YAML files, fail-fast on validation errors)
- [X] T104 [US5] Implement Jinja2 environment setup in scripts/generate_docs.py with template directory and custom filters
- [X] T105 [US5] Implement individual doc generation functions (generate_pi_guide, generate_researcher_quickstart, generate_sysadmin_reference, generate_ciso_compliance_map, generate_leadership_briefing, generate_glossary_full, generate_crosswalk_csv)
- [X] T106 [US5] Implement error handling in scripts/generate_docs.py to report file path, entry ID, and missing field for validation errors (per clarification answer #1)
- [X] T107 [US5] Add deterministic output verification (same YAML input always produces identical output)
- [X] T108 [US5] Create pytest integration test in tests/test_generate_docs.py to verify all 7 outputs are generated without errors
- [X] T109 [US5] Create pytest integration test in tests/test_generate_docs.py to verify generated Markdown contains glossary hyperlinks
- [X] T110 [US5] Create pytest integration test in tests/test_generate_docs.py to verify CSV crosswalk is Excel-compatible (UTF-8 with BOM)
- [X] T111 [US5] Create pytest integration test in tests/test_generate_docs.py to verify generated docs contain no unexpanded Jinja2 variables

**Checkpoint**: At this point, User Story 5 should be fully functional. Documentation generator produces all 7 audience-specific outputs.

---

## Phase 8: User Story 6 - Validate Glossary Coverage Across All Project Files (Priority: P3)

**Goal**: Implement Python glossary validator that scans all project files for undefined acronyms and returns non-zero exit code on violations

**Independent Test**: Create a test document with a known undefined acronym, run the glossary validator, and verify it flags the undefined term and returns a non-zero exit code

### Implementation for User Story 6

- [X] T112 [US6] Implement main glossary validator script in scripts/validate_glossary.py with file scanning and acronym detection
- [X] T113 [US6] Implement CLI argument parsing in scripts/validate_glossary.py (--glossary, --scan-dirs, --file-types flags)
- [X] T114 [US6] Implement glossary loading and validation in scripts/validate_glossary.py (load terms.yml with Pydantic validation)
- [X] T115 [US6] Implement file scanning logic in scripts/validate_glossary.py (recursively scan .md, .yml, .j2 files in specified directories)
- [X] T116 [US6] Implement acronym extraction using regex in scripts/validate_glossary.py (detect uppercase acronyms 2+ letters)
- [X] T117 [US6] Implement context-aware glossary matching in scripts/validate_glossary.py (handle "AC (compliance)" vs "AC (hardware)" per clarification answer #3)
- [X] T118 [US6] Implement violation reporting in scripts/validate_glossary.py (output file path, line number, undefined term to STDERR)
- [X] T119 [US6] Implement exit code logic in scripts/validate_glossary.py (0 = success, 1 = undefined terms found, 2 = glossary file error)
- [X] T120 [US6] Create pytest unit test in tests/test_glossary_validator.py to verify acronym extraction regex works correctly
- [X] T121 [US6] Create pytest unit test in tests/test_glossary_validator.py to verify context-tagged term matching
- [X] T122 [US6] Create pytest integration test in tests/test_glossary_validator.py to verify undefined terms are flagged with correct exit code
- [X] T123 [US6] Create pytest integration test in tests/test_glossary_validator.py to verify validator succeeds when all terms are defined

**Checkpoint**: At this point, User Story 6 should be fully functional. Glossary validator enforces "Plain Language First" principle.

---

## Phase 9: User Story 7 - Establish Project Skeleton and Build System (Priority: P2)

**Goal**: Create complete Ansible project structure, Makefile, and README for operational usability

**Independent Test**: Clone the repository, run `make docs`, `make validate`, and `make crosswalk`, and verify all commands execute successfully and produce expected outputs

### Implementation for User Story 7

- [X] T124 [P] [US7] Create Makefile with 'docs' target that runs scripts/generate_docs.py and outputs to docs/generated/
- [X] T125 [P] [US7] Add 'validate' target to Makefile that runs scripts/validate_glossary.py and reports results
- [X] T126 [P] [US7] Add 'crosswalk' target to Makefile that generates only the CSV crosswalk file
- [X] T127 [P] [US7] Add 'clean' target to Makefile that removes all generated documentation files from docs/generated/
- [X] T128 [P] [US7] Add 'test' target to Makefile that runs pytest tests/ with coverage reporting
- [X] T129 [P] [US7] Add 'validate-schemas' target to Makefile that runs pytest tests/test_yaml_schemas.py
- [X] T130 [US7] Create comprehensive README.md with project overview, purpose, usage instructions, and phased implementation plan
- [X] T131 [US7] Add installation instructions to README.md (Python 3.9+, pip install -r requirements.txt)
- [X] T132 [US7] Add quick start section to README.md (make docs, make validate, make crosswalk commands)
- [X] T133 [US7] Add directory structure explanation to README.md (canonical data vs generated artifacts vs tooling)
- [X] T134 [US7] Add constitution principles alignment section to README.md (reference to .specify/memory/constitution.md)
- [X] T135 [US7] Add contributing guidelines to README.md (how to edit YAML files, validation workflow, CI/CD integration)
- [X] T136 [US7] Create pytest integration test in tests/test_makefile_targets.py to verify `make docs` produces all 7 outputs
- [X] T137 [US7] Create pytest integration test in tests/test_makefile_targets.py to verify `make validate` runs successfully
- [X] T138 [US7] Create pytest integration test in tests/test_makefile_targets.py to verify `make crosswalk` produces CSV file

**Checkpoint**: All user stories should now be independently functional. Project skeleton provides operational scaffolding.

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories

- [X] T139 [P] Add comprehensive docstrings to all Pydantic models in scripts/models/
- [X] T140 [P] Add type hints to all functions in scripts/generate_docs.py and scripts/validate_glossary.py
- [X] T141 [P] Create CONTRIBUTING.md with guidelines for editing YAML files and running validation
- [X] T142 [P] Create .github/workflows/validate.yml or .gitlab-ci.yml for CI/CD integration (run pytest tests on every PR)
- [X] T143 Optimize documentation generator performance (verify <30 second completion time per SC-004)
- [X] T144 Add logging to scripts/generate_docs.py with progress indicators for each doc generation step
- [X] T145 Add logging to scripts/validate_glossary.py with scan progress and summary statistics
- [X] T146 Create comprehensive error messages for common validation failures (missing fields, invalid values, cross-reference errors)
- [X] T147 Verify all generated documentation follows GitHub-flavored Markdown spec
- [X] T148 Verify CSV crosswalk opens correctly in Excel and LibreOffice Calc (UTF-8 encoding, comma delimiters)
- [X] T149 Run complete test suite and achieve >90% code coverage
- [X] T150 Create quickstart validation checklist (verify all quickstart.md instructions work for new team members)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup (Phase 1) completion - BLOCKS all user stories
- **User Stories (Phase 3-9)**: All depend on Foundational (Phase 2) completion
  - User Story 1 (P1): Can start after Foundational - No dependencies on other stories
  - User Story 2 (P1): Can start after Foundational - No dependencies on other stories
  - User Story 3 (P1): Can start after Foundational - References User Story 1 controls (but doesn't block)
  - User Story 4 (P2): Can start after Foundational - References User Story 1 controls (but doesn't block)
  - User Story 5 (P2): Depends on User Stories 1, 2, 3, 4 completion (reads all 4 YAML files)
  - User Story 6 (P3): Depends on User Story 2 completion (reads glossary)
  - User Story 7 (P2): Can start in parallel with other stories (project scaffolding)
- **Polish (Phase 10)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 2 (P1)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **User Story 3 (P1)**: Can start after Foundational (Phase 2) - Soft dependency on User Story 1 (references controls)
- **User Story 4 (P2)**: Can start after Foundational (Phase 2) - Soft dependency on User Story 1 (references controls)
- **User Story 5 (P2)**: **HARD DEPENDENCY** on User Stories 1, 2, 3, 4 completion (needs all 4 YAML files)
- **User Story 6 (P3)**: Depends on User Story 2 completion (needs glossary)
- **User Story 7 (P2)**: Can start in parallel with User Stories 1-4 (project structure)

### Within Each User Story

- **Tests** (if included): Can be written in parallel with implementation (TDD optional)
- **Pydantic Models**: Must complete before YAML file creation (defines schema)
- **YAML Data Files**: Populate after Pydantic models complete
- **Pytest Tests**: Can write in parallel with YAML population
- **Story Complete**: All tasks in phase done before moving to next priority

### Parallel Opportunities

- **Setup Phase (Phase 1)**: All T002-T012 can run in parallel (marked [P])
- **Foundational Phase (Phase 2)**: T014-T017, T020-T022 can run in parallel (different files)
- **User Story 1 (Phase 3)**: T028-T042 can run in parallel if divided by control family (different YAML sections)
- **User Story 2 (Phase 4)**: T052-T057 can run in parallel if divided by term category (different YAML sections)
- **User Story 3 (Phase 5)**: T067-T076 can run in parallel (independent tailoring entries)
- **User Story 4 (Phase 6)**: T085-T089 can run in parallel if divided by ODP ranges (different YAML sections)
- **User Story 5 (Phase 7)**: T094-T100 can run in parallel (independent Jinja2 templates)
- **User Story 7 (Phase 9)**: T124-T129, T131-T135 can run in parallel (independent documentation/config files)
- **Polish Phase (Phase 10)**: T139-T142 can run in parallel (different files)
- **User Stories 1, 2, 3, 4, 7**: Can all start in parallel after Foundational phase (independent data models)

---

## Parallel Example: Foundational Phase

```bash
# Launch all Pydantic model tasks together:
Task: "Create Pydantic model for FrameworkMapping in scripts/models/control_mapping.py"
Task: "Create Pydantic model for GlossaryTerm in scripts/models/glossary.py"
Task: "Create Pydantic model for HPCTailoringEntry in scripts/models/hpc_tailoring.py"
Task: "Create Pydantic model for ODPValue in scripts/models/odp_values.py"

# Launch all Jinja2 partial tasks together:
Task: "Create Jinja2 template partial for glossary hyperlinking in templates/_partials/glossary_link.j2"
Task: "Create Jinja2 template partial for control table formatting in templates/_partials/control_table.j2"
Task: "Create Jinja2 template partial for standard header in templates/_partials/header.j2"
```

---

## Parallel Example: User Story 1 (Control Mapping)

```bash
# Divide control families across multiple developers:
Developer A: T028-T031 (AC, AT, AU, CA families)
Developer B: T032-T035 (CM, IA, IR, MA families)
Developer C: T036-T039 (MP, PE, PS, RA families)
Developer D: T040-T042 (SA, SC, SI families)

# All work on same file (roles/common/vars/control_mapping.yml) but different sections
# Merge when all complete
```

---

## Implementation Strategy

### MVP First (User Stories 1, 2, 3 Only - All P1)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Control Mapping)
4. Complete Phase 4: User Story 2 (Glossary)
5. Complete Phase 5: User Story 3 (HPC Tailoring)
6. **STOP and VALIDATE**: Test all 3 P1 user stories independently
7. Deploy/demo if ready (core data models complete)

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Stories 1, 2, 3 (P1) → Test independently → Core data models complete (MVP!)
3. Add User Story 4 (P2 - ODPs) → Test independently → All 4 YAML files ready
4. Add User Story 5 (P2 - Doc Generator) → Test independently → Documentation automation complete
5. Add User Story 7 (P2 - Project Skeleton) → Test independently → Operational scaffolding complete
6. Add User Story 6 (P3 - Glossary Validator) → Test independently → Quality gate complete
7. Complete Phase 10 (Polish) → Production-ready

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Control Mapping - 110 controls)
   - Developer B: User Story 2 (Glossary - 60+ terms)
   - Developer C: User Story 3 (HPC Tailoring - 10+ entries)
   - Developer D: User Story 7 (Project Skeleton - Makefile, README)
3. When US 1-4 complete:
   - Developer E: User Story 5 (Doc Generator - needs all 4 YAML files)
   - Developer F: User Story 4 (ODPs - 49 parameters)
4. When US 2 complete:
   - Developer G: User Story 6 (Glossary Validator - needs glossary)
5. Stories complete and integrate independently

---

## Notes

- [P] tasks = different files, no dependencies, can run in parallel
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Stop at any checkpoint to validate story independently
- Avoid: vague tasks, same file conflicts, cross-story dependencies that break independence
- Commit after each logical task group or phase completion
- YAML data files are canonical source of truth, generated docs are ephemeral
- **Performance Budget**: Documentation generator must complete in <30 seconds (SC-004)
- **Test Coverage Target**: >90% code coverage for scripts/ directory
- **CI/CD Integration**: All pytest tests must pass before merge

---

## Task Summary

**Total Tasks**: 150
- Phase 1 (Setup): 12 tasks
- Phase 2 (Foundational): 10 tasks
- Phase 3 (US1 - Control Mapping): 24 tasks
- Phase 4 (US2 - Glossary): 16 tasks
- Phase 5 (US3 - HPC Tailoring): 18 tasks
- Phase 6 (US4 - ODPs): 13 tasks
- Phase 7 (US5 - Doc Generator): 18 tasks
- Phase 8 (US6 - Glossary Validator): 12 tasks
- Phase 9 (US7 - Project Skeleton): 15 tasks
- Phase 10 (Polish): 12 tasks

**Parallel Opportunities**: 67 tasks marked [P] can run in parallel

**Independent Test Criteria**:
- US1: Load YAML, verify 110 controls with complete metadata
- US2: Lookup any term, verify plain-language explanation for all 5 audiences
- US3: Find HPC scenario, verify tailoring with compensating controls
- US4: Verify all 49 ODPs have assigned values with rationale
- US5: Run generator, verify 7 outputs with glossary hyperlinks
- US6: Run validator with undefined term, verify non-zero exit code
- US7: Run `make docs`/`make validate`/`make crosswalk`, verify success

**Suggested MVP Scope**: User Stories 1, 2, 3 (all P1) = Core data models (control mapping, glossary, HPC tailoring)
