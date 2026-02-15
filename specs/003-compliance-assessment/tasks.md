# Tasks: Compliance Assessment and Reporting Layer

**Input**: Design documents from `/specs/003-compliance-assessment/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Tests are included as this is compliance-critical infrastructure requiring validation.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This project extends an Ansible collection with Python tooling:
- **Playbooks**: `playbooks/`
- **Filter plugins**: `plugins/filter/`
- **Scripts**: `scripts/`
- **Data files**: `data/`
- **Templates**: `templates/`
- **Tests**: `tests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Directory structure, data files, and dependencies

- [ ] T001 Create plugins directory structure with `plugins/__init__.py` and `plugins/filter/__init__.py`
- [ ] T002 [P] Create data directory structure with `data/assessment_history/.gitkeep`
- [ ] T003 [P] Create templates directory structure: `templates/dashboard/`, `templates/narratives/`, `templates/reports/`
- [ ] T004 [P] Create docs output directory: `docs/auditor_packages/.gitkeep`
- [ ] T005 Create DoD SPRS control weights data file in `data/sprs_weights.yml` with all 110 control weights (1, 3, or 5 points per control)
- [ ] T006 [P] Create empty POA&M template file in `data/poam.yml` with schema example
- [ ] T007 [P] Add Chart.js library (minified, offline-capable) to `templates/dashboard/assets/chart.min.js`
- [ ] T008 [P] Create base CSS stylesheet in `templates/dashboard/assets/dashboard.css`
- [ ] T009 Update `requirements.txt` to add Jinja2, PyYAML dependencies for scripts
- [ ] T010 Update `requirements-ee.txt` to ensure filter plugin dependencies in execution environment

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core utilities and filter plugin that ALL user stories depend on

**CRITICAL**: Assessment, scoring, and reporting all depend on SPRS filter plugin and redaction utility

- [ ] T011 Create SPRS filter plugin skeleton in `plugins/filter/sprs.py` with FilterModule class
- [ ] T012 Implement `load_control_weights()` function in `plugins/filter/sprs.py` to read `data/sprs_weights.yml`
- [ ] T013 Implement `sprs_score()` filter function in `plugins/filter/sprs.py` - calculates score from assessment results
- [ ] T014 Implement `sprs_breakdown()` filter function in `plugins/filter/sprs.py` - returns detailed deduction breakdown
- [ ] T015 Implement `control_weight()` filter function in `plugins/filter/sprs.py` - returns weight for single control
- [ ] T016 Implement `format_deduction()` filter function in `plugins/filter/sprs.py` - returns plain-language deduction explanation
- [ ] T017 Add POA&M credit calculation logic to `sprs_score()` - 50% reduction for documented POA&M items
- [ ] T018 [P] Create `scripts/redact_secrets.py` with REDACTION_PATTERNS list from research.md
- [ ] T019 Implement `redact_file()` function in `scripts/redact_secrets.py` - pattern-based replacement with [REDACTED]
- [ ] T020 Implement `redact_directory()` function in `scripts/redact_secrets.py` - recursive directory processing
- [ ] T021 [P] Create test file `tests/test_sprs_filter.py` with known test vectors
- [ ] T022 Implement SPRS calculation unit tests in `tests/test_sprs_filter.py` - verify score matches manual calculation
- [ ] T023 [P] Create test file `tests/test_redaction.py` with pattern matching tests
- [ ] T024 Implement redaction unit tests in `tests/test_redaction.py` - verify secrets redacted, structure preserved

**Checkpoint**: SPRS filter and redaction utility ready - user story implementation can begin

---

## Phase 3: User Story 1 - Comprehensive Compliance Assessment (Priority: P1) MVP

**Goal**: Run assessment across all systems, produce structured JSON with control pass/fail status

**Independent Test**: Run `ansible-playbook playbooks/assess.yml --check` against test inventory, verify JSON output with correct schema

### Tests for User Story 1

- [ ] T025 [P] [US1] Create `tests/test_assessment_schema.py` with JSON schema validation tests
- [ ] T026 [P] [US1] Create `tests/playbooks/test_assess.yml` for playbook syntax validation

### Implementation for User Story 1

- [ ] T027 [US1] Create main assessment playbook in `playbooks/assess.yml` with play structure for all zones
- [ ] T028 [US1] Add variable initialization tasks to `playbooks/assess.yml` - assessment_id (UUID), timestamp, enclave_name
- [ ] T029 [US1] Add role verification loop in `playbooks/assess.yml` - include verify.yml from each deployed role
- [ ] T030 [US1] Add result aggregation tasks in `playbooks/assess.yml` - combine per-role results into control-level results
- [ ] T031 [US1] Add OpenSCAP integration tasks in `playbooks/assess.yml` - run oscap with CUI profile, capture results
- [ ] T032 [US1] Add coverage summary calculation in `playbooks/assess.yml` - assessed vs not_assessed systems
- [ ] T033 [US1] Add unreachable system handling in `playbooks/assess.yml` - mark as "not assessed" with reason
- [ ] T034 [US1] Add binary pass/fail logic in `playbooks/assess.yml` - control passes only if ALL systems pass
- [ ] T035 [US1] Add SPRS score calculation task in `playbooks/assess.yml` using sprs_score filter
- [ ] T036 [US1] Add JSON output task in `playbooks/assess.yml` - write to `data/assessment_history/YYYY-MM-DD.json`
- [ ] T037 [US1] Add metadata collection in `playbooks/assess.yml` - tool versions, duration, initiated_by
- [ ] T038 [US1] Verify playbook runs in --check mode without errors

**Checkpoint**: Assessment playbook functional - can run compliance assessment and produce JSON results

---

## Phase 4: User Story 2 - SPRS Score Calculation and Reporting (Priority: P1)

**Goal**: Calculate SPRS score with breakdown, prioritized remediation recommendations

**Independent Test**: Run SPRS script with test assessment JSON, verify score matches manual calculation

### Tests for User Story 2

- [ ] T039 [P] [US2] Add manual calculation test case to `tests/test_sprs_filter.py` - 10 passing, 5 failing controls
- [ ] T040 [P] [US2] Create `tests/test_sprs_report.py` for report generation validation

### Implementation for User Story 2

- [ ] T041 [US2] Create SPRS report template in `templates/reports/sprs_breakdown.md.j2`
- [ ] T042 [US2] Add family breakdown section to SPRS template - controls per family, deduction points
- [ ] T043 [US2] Add deductions list section to SPRS template - control ID, weight, plain-language explanation
- [ ] T044 [US2] Add recommendations section to SPRS template - prioritized by weight, effort estimate
- [ ] T045 [US2] Add POA&M adjustments section to SPRS template - items with credit, total saved points
- [ ] T046 [US2] Create `scripts/generate_sprs_report.py` script for standalone SPRS report generation
- [ ] T047 [US2] Implement CLI argument parsing in `scripts/generate_sprs_report.py` - input JSON, output path
- [ ] T048 [US2] Implement report rendering in `scripts/generate_sprs_report.py` using Jinja2 template
- [ ] T049 [US2] Add historical trend data loading to SPRS script - read previous assessments
- [ ] T050 [US2] Verify SPRS score exactly matches manual calculation (SC-002)

**Checkpoint**: SPRS scoring complete - can calculate and report scores with plain-language breakdown

---

## Phase 5: User Story 3 - SSP Evidence Package Generation (Priority: P1)

**Goal**: Collect evidence artifacts, generate control narratives, package for auditors

**Independent Test**: Run evidence playbook, verify all evidence types collected, narratives pass glossary validation

### Tests for User Story 3

- [ ] T051 [P] [US3] Create `tests/test_narratives.py` with glossary validation tests
- [ ] T052 [P] [US3] Create `tests/test_evidence_structure.py` with directory structure validation

### Implementation for User Story 3

- [ ] T053 [US3] Create SSP evidence playbook in `playbooks/ssp_evidence.yml`
- [ ] T054 [US3] Add system inventory collection tasks in `playbooks/ssp_evidence.yml` - hostname, zone, OS version
- [ ] T055 [US3] Add package list collection tasks in `playbooks/ssp_evidence.yml` - rpm -qa output
- [ ] T056 [US3] Add network configuration collection in `playbooks/ssp_evidence.yml` - ip addr, ip route
- [ ] T057 [US3] Add firewall rules collection in `playbooks/ssp_evidence.yml` - nft list ruleset
- [ ] T058 [US3] Add SELinux status collection in `playbooks/ssp_evidence.yml` - sestatus, semanage
- [ ] T059 [US3] Add FIPS status collection in `playbooks/ssp_evidence.yml` - fips-mode-setup --check
- [ ] T060 [US3] Add audit rules collection in `playbooks/ssp_evidence.yml` - auditctl -l
- [ ] T061 [US3] Add SSH configuration collection in `playbooks/ssp_evidence.yml` - sshd -T
- [ ] T062 [US3] Add PAM configuration collection in `playbooks/ssp_evidence.yml` - /etc/pam.d/ contents
- [ ] T063 [US3] Add user/group listings collection in `playbooks/ssp_evidence.yml` - getent passwd/group
- [ ] T064 [US3] Add Slurm configuration collection in `playbooks/ssp_evidence.yml` - scontrol show config
- [ ] T065 [US3] Add encryption status collection in `playbooks/ssp_evidence.yml` - lsblk, cryptsetup status
- [ ] T066 [US3] Add evidence organization tasks in `playbooks/ssp_evidence.yml` - by_family/, by_system/ structure
- [ ] T067 [US3] Add secret redaction task in `playbooks/ssp_evidence.yml` - call redact_secrets.py
- [ ] T068 [US3] Create narrative template in `templates/narratives/control_narrative.md.j2`
- [ ] T069 [US3] Add control context section to narrative template - control ID, title, family
- [ ] T070 [US3] Add implementation description section to narrative template - plain-language how control is met
- [ ] T071 [US3] Add evidence references section to narrative template - file paths, descriptions
- [ ] T072 [US3] Create `scripts/generate_narratives.py` script for bulk narrative generation
- [ ] T073 [US3] Implement control mapping loading in `scripts/generate_narratives.py` - read control_mapping.yml
- [ ] T074 [US3] Implement narrative rendering in `scripts/generate_narratives.py` using Jinja2
- [ ] T075 [US3] Add glossary validation call in `scripts/generate_narratives.py` - invoke validate_glossary.py
- [ ] T076 [US3] Add evidence packaging task in `playbooks/ssp_evidence.yml` - tar.gz with timestamp
- [ ] T077 [US3] Add metadata.json generation in `playbooks/ssp_evidence.yml` - timestamps, checksums, tool versions
- [ ] T078 [US3] Verify narratives pass validate_glossary.py (SC-003)

**Checkpoint**: Evidence collection complete - can generate full SSP evidence package with narratives

---

## Phase 6: User Story 4 - POA&M Tracking and Reporting (Priority: P2)

**Goal**: Track remediation items, generate PM-friendly reports in Markdown and CSV

**Independent Test**: Create sample POA&M items, generate reports, verify PM can understand status

### Tests for User Story 4

- [ ] T079 [P] [US4] Create `tests/test_poam_model.py` with YAML schema validation tests
- [ ] T080 [P] [US4] Create `tests/test_poam_report.py` with report generation tests

### Implementation for User Story 4

- [ ] T081 [US4] Create POA&M markdown report template in `templates/reports/poam_report.md.j2`
- [ ] T082 [US4] Add status grouping to POA&M template - overdue, in progress, completed sections
- [ ] T083 [US4] Add days overdue calculation display in POA&M template
- [ ] T084 [US4] Add plain-language weakness descriptions in POA&M template
- [ ] T085 [US4] Add milestone timeline view in POA&M template
- [ ] T086 [US4] Create POA&M CSV report template in `templates/reports/poam_report.csv.j2`
- [ ] T087 [US4] Add all tracking fields to CSV template - control, weakness, milestone, target_date, status, resources, risk
- [ ] T088 [US4] Create `scripts/generate_poam_report.py` script
- [ ] T089 [US4] Implement YAML loading in `scripts/generate_poam_report.py` - read data/poam.yml
- [ ] T090 [US4] Implement days overdue calculation in `scripts/generate_poam_report.py`
- [ ] T091 [US4] Implement status grouping logic in `scripts/generate_poam_report.py`
- [ ] T092 [US4] Implement markdown report rendering in `scripts/generate_poam_report.py`
- [ ] T093 [US4] Implement CSV report rendering in `scripts/generate_poam_report.py`
- [ ] T094 [US4] Add CLI arguments in `scripts/generate_poam_report.py` - input file, output directory
- [ ] T095 [US4] Verify POA&M plain-language descriptions pass glossary validation
- [ ] T096 [US4] Update SPRS filter to read POA&M data for credit calculation integration (FR-021)

**Checkpoint**: POA&M tracking complete - can track and report remediation items

---

## Phase 7: User Story 5 - Compliance Dashboard (Priority: P2)

**Goal**: Generate HTML dashboard with audience-specific views (leadership, CISO, auditor)

**Independent Test**: Generate dashboard, open in browser, verify gauge renders and all views function

### Tests for User Story 5

- [ ] T097 [P] [US5] Create `tests/test_dashboard.py` with HTML structure validation tests

### Implementation for User Story 5

- [ ] T098 [US5] Create leadership dashboard template in `templates/dashboard/leadership.html.j2`
- [ ] T099 [US5] Add SPRS gauge visualization to leadership template using Chart.js
- [ ] T100 [US5] Add compliance percentage display to leadership template
- [ ] T101 [US5] Add family status indicators (red/yellow/green) to leadership template
- [ ] T102 [US5] Create CISO dashboard template in `templates/dashboard/ciso.html.j2`
- [ ] T103 [US5] Add family breakdown table to CISO template - controls per family, status
- [ ] T104 [US5] Add control detail drill-down to CISO template - verification output, remediation links
- [ ] T105 [US5] Add remediation priority list to CISO template - sorted by weight
- [ ] T106 [US5] Create auditor dashboard template in `templates/dashboard/auditor.html.j2`
- [ ] T107 [US5] Add control narrative display to auditor template
- [ ] T108 [US5] Add evidence file links to auditor template - clickable paths
- [ ] T109 [US5] Add verification output display to auditor template
- [ ] T110 [US5] Create base dashboard template in `templates/dashboard/base.html.j2` with navigation
- [ ] T111 [US5] Add tab switching JavaScript to base template - vanilla JS, no dependencies
- [ ] T112 [US5] Add historical trend chart to dashboard - SPRS over time using Chart.js
- [ ] T113 [US5] Add POA&M timeline visualization to dashboard
- [ ] T114 [US5] Handle first-run case in templates - show snapshot only when no history (FR-025)
- [ ] T115 [US5] Create `scripts/generate_dashboard.py` script
- [ ] T116 [US5] Implement assessment data loading in `scripts/generate_dashboard.py`
- [ ] T117 [US5] Implement historical data loading in `scripts/generate_dashboard.py` - scan assessment_history/
- [ ] T118 [US5] Implement dashboard rendering in `scripts/generate_dashboard.py` - all three views
- [ ] T119 [US5] Add CLI arguments in `scripts/generate_dashboard.py` - output directory
- [ ] T120 [US5] Verify dashboard renders correctly in Chrome, Firefox, Safari (SC-005)

**Checkpoint**: Dashboard complete - can generate and view compliance status for all audiences

---

## Phase 8: User Story 6 - Auditor Package Generator (Priority: P3)

**Goal**: Bundle all compliance artifacts into CMMC assessment-ready package

**Independent Test**: Generate auditor package, verify all required artifacts present per CMMC guide

### Tests for User Story 6

- [ ] T121 [P] [US6] Create `tests/test_auditor_package.py` with artifact completeness validation

### Implementation for User Story 6

- [ ] T122 [US6] Create `scripts/generate_auditor_package.py` script
- [ ] T123 [US6] Implement crosswalk CSV generation in `scripts/generate_auditor_package.py` - controls to evidence mapping
- [ ] T124 [US6] Implement narrative collection in `scripts/generate_auditor_package.py` - copy from generated/narratives/
- [ ] T125 [US6] Implement evidence archive inclusion in `scripts/generate_auditor_package.py`
- [ ] T126 [US6] Implement SPRS report inclusion in `scripts/generate_auditor_package.py`
- [ ] T127 [US6] Implement POA&M report inclusion in `scripts/generate_auditor_package.py`
- [ ] T128 [US6] Implement HPC tailoring documentation inclusion in `scripts/generate_auditor_package.py` - copy docs/hpc_tailoring.yml
- [ ] T129 [US6] Implement ODP values inclusion in `scripts/generate_auditor_package.py` - copy docs/odp_values.yml
- [ ] T130 [US6] Implement CMMC assessment guide directory structure in `scripts/generate_auditor_package.py`
- [ ] T131 [US6] Add package manifest generation in `scripts/generate_auditor_package.py` - contents listing
- [ ] T132 [US6] Add package compression in `scripts/generate_auditor_package.py` - tar.gz output
- [ ] T133 [US6] Add CLI arguments in `scripts/generate_auditor_package.py` - output directory
- [ ] T134 [US6] Verify package contains all CMMC Level 2 artifacts (SC-006)

**Checkpoint**: Auditor package complete - can generate full C3PAO-ready documentation bundle

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Makefile integration, documentation, validation

- [ ] T135 Add `assess` target to `Makefile` - run assessment playbook in execution environment
- [ ] T136 Add `evidence` target to `Makefile` - run SSP evidence playbook
- [ ] T137 Add `sprs` target to `Makefile` - run SPRS report generation script
- [ ] T138 Add `poam` target to `Makefile` - run POA&M report generation script
- [ ] T139 Add `dashboard` target to `Makefile` - run dashboard generation script
- [ ] T140 Add `report` target to `Makefile` - run sprs, poam, dashboard in sequence
- [ ] T141 Add `auditor-package` target to `Makefile` - run complete auditor package generation
- [ ] T142 [P] Update `ansible.cfg` to include plugins/filter/ in filter_plugins path
- [ ] T143 [P] Run ansible-lint on all new playbooks - verify lint passes
- [ ] T144 [P] Run yamllint on all new YAML files - verify lint passes
- [ ] T145 Run pytest on all test files - verify all tests pass
- [ ] T146 Verify assess playbook runs in --check mode across all zones (SC-001)
- [ ] T147 Verify evidence collection completes within 30 minutes for 50 systems (SC-007)
- [ ] T148 [P] Update README.md with new make targets and usage documentation

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-8)**: All depend on Foundational phase completion
  - US1 (Assessment): No dependencies on other stories
  - US2 (SPRS): Depends on US1 for assessment results
  - US3 (Evidence): No dependencies on other stories (can run parallel with US2)
  - US4 (POA&M): No dependencies on other stories
  - US5 (Dashboard): Depends on US1 (assessment), US2 (SPRS), US4 (POA&M) for data
  - US6 (Auditor Package): Depends on US1, US2, US3, US4 - bundles all outputs
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

```text
Phase 2 (Foundational)
        │
        ├──────────────────────┬──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
    US1 (P1)               US3 (P1)               US4 (P2)
   Assessment              Evidence               POA&M
        │                      │                      │
        ├───────────┐          │                      │
        ▼           │          │                      │
    US2 (P1)        │          │                      │
     SPRS           │          │                      │
        │           │          │                      │
        ├───────────┴──────────┴──────────────────────┤
        ▼                                             │
    US5 (P2)                                          │
   Dashboard                                          │
        │                                             │
        └─────────────────────────────────────────────┤
                                                      ▼
                                                  US6 (P3)
                                               Auditor Package
```

### Within Each User Story

- Tests written and FAIL before implementation
- Data models/templates before scripts
- Scripts before playbook integration
- Core implementation before validation

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- Within Foundational: T018-T20 (redaction) parallel with T11-T17 (SPRS filter)
- Within Foundational: T21-T22 (SPRS tests) parallel with T23-T24 (redaction tests)
- US1 and US3 can run in parallel (both depend only on Foundational)
- US4 can run in parallel with US1, US2, US3
- Within each story: Tasks marked [P] can run in parallel

---

## Parallel Example: Foundational Phase

```bash
# Launch SPRS filter and redaction utility in parallel:
Task: "Create SPRS filter plugin skeleton in plugins/filter/sprs.py"
Task: "Create scripts/redact_secrets.py with REDACTION_PATTERNS list"

# After skeleton complete, implement in parallel:
Task: "Implement sprs_score() filter function"
Task: "Implement redact_file() function"
Task: "Implement sprs_breakdown() filter function"
Task: "Implement redact_directory() function"

# Tests can run in parallel:
Task: "tests/test_sprs_filter.py with known test vectors"
Task: "tests/test_redaction.py with pattern matching tests"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (SPRS filter, redaction utility)
3. Complete Phase 3: User Story 1 (Assessment)
4. **STOP and VALIDATE**: Run `make assess` and verify JSON output
5. Deploy/demo assessment capability

### Incremental Delivery

1. Complete Setup + Foundational → Core utilities ready
2. Add US1 (Assessment) → Can measure compliance state (MVP!)
3. Add US2 (SPRS) → Can calculate and explain score
4. Add US3 (Evidence) → Can generate auditor evidence
5. Add US4 (POA&M) → Can track remediation
6. Add US5 (Dashboard) → Can visualize compliance
7. Add US6 (Auditor Package) → Can bundle for C3PAO

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: US1 (Assessment) → US2 (SPRS)
   - Developer B: US3 (Evidence)
   - Developer C: US4 (POA&M)
3. After US1, US2, US4 complete:
   - Developer A: US5 (Dashboard)
4. After all complete:
   - Any developer: US6 (Auditor Package)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Verify tests fail before implementing
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All scripts should use Jinja2 for template rendering (consistent with project)
- All generated content must pass validate_glossary.py for plain-language compliance
