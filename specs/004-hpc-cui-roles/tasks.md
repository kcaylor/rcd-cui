# Tasks: HPC-Specific CUI Compliance Roles

**Input**: Design documents from `/specs/004-hpc-cui-roles/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

This project uses Ansible collection structure:
- **Roles**: `roles/{role_name}/tasks/`, `roles/{role_name}/templates/`, `roles/{role_name}/files/`
- **Playbooks**: `playbooks/`
- **Tests**: `tests/molecule/{role_name}/`, `tests/integration/`
- **Docs**: `docs/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Role scaffolding and shared infrastructure

- [x] T001 Create role directory structure for roles/hpc_slurm_cui/ per plan.md
- [x] T002 [P] Create role directory structure for roles/hpc_container_security/ per plan.md
- [x] T003 [P] Create role directory structure for roles/hpc_storage_security/ per plan.md
- [x] T004 [P] Create role directory structure for roles/hpc_interconnect/ per plan.md
- [x] T005 [P] Create role directory structure for roles/hpc_node_lifecycle/ per plan.md
- [x] T006 [P] Create playbooks/vars/onboarding_defaults.yml with default variable definitions
- [x] T007 [P] Create tests/molecule/ directory structure for all 5 HPC roles
- [x] T008 Add HPC role dependencies to requirements.yml
- [x] T009 [P] Create templates/pi_welcome_packet.md.j2 placeholder template
- [x] T010 Update .ansible-lint to include new roles

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T011 Create roles/hpc_slurm_cui/meta/main.yml with role metadata and dependencies
- [x] T012 [P] Create roles/hpc_container_security/meta/main.yml with role metadata and dependencies
- [x] T013 [P] Create roles/hpc_storage_security/meta/main.yml with role metadata and dependencies
- [x] T014 [P] Create roles/hpc_interconnect/meta/main.yml with role metadata and dependencies
- [x] T015 [P] Create roles/hpc_node_lifecycle/meta/main.yml with role metadata and dependencies
- [x] T016 [P] Create roles/hpc_slurm_cui/defaults/main.yml with default variables (partition name, QOS, paths)
- [x] T017 [P] Create roles/hpc_container_security/defaults/main.yml with default variables (bind paths, signing key)
- [x] T018 [P] Create roles/hpc_storage_security/defaults/main.yml with default variables (filesystem type, paths)
- [x] T019 [P] Create roles/hpc_interconnect/defaults/main.yml with default variables (compensating controls)
- [x] T020 [P] Create roles/hpc_node_lifecycle/defaults/main.yml with default variables (scan timeout, quarantine path)
- [x] T021 Add HPC control mappings to docs/control_mapping.yml for controls implemented by these roles
- [x] T022 Add HPC-specific terms to docs/glossary/terms.yml (prolog, epilog, RDMA, MPI, etc.)

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Slurm CUI Partition Operations (Priority: P1) 🎯 MVP

**Goal**: Enable secure CUI job submission with authorization verification, memory sanitization, and audit logging

**Independent Test**: Submit jobs to CUI partition with authorized/unauthorized users, verify prolog blocks unauthorized access, epilog clears memory, and audit logs capture all events

### Implementation for User Story 1

- [x] T023 [US1] Create roles/hpc_slurm_cui/templates/cui_partition.conf.j2 with EXCLUSIVE, AllowAccounts, QOS settings (FR-001, FR-002, FR-003)
- [x] T024 [US1] Create roles/hpc_slurm_cui/templates/slurm_prolog.sh.j2 with LDAP authorization check (FR-004)
- [x] T025 [US1] Add training status verification to slurm_prolog.sh.j2 (FR-005)
- [x] T026 [US1] Add timeout handling with retry-friendly error to slurm_prolog.sh.j2 (FR-005a)
- [x] T027 [US1] Add audit logging with CUI tags to slurm_prolog.sh.j2 (FR-006)
- [x] T028 [US1] Create roles/hpc_slurm_cui/templates/slurm_epilog.sh.j2 with /dev/shm clearing (FR-007)
- [x] T029 [US1] Add /tmp cleanup to slurm_epilog.sh.j2 (FR-008)
- [x] T030 [US1] Add GPU memory reset with nvidia-smi to slurm_epilog.sh.j2 (FR-009)
- [x] T031 [US1] Add node drain on GPU reset failure to slurm_epilog.sh.j2 (FR-009a)
- [x] T032 [US1] Add audit log flush to slurm_epilog.sh.j2 (FR-010)
- [x] T033 [US1] Add health check call to slurm_epilog.sh.j2 (FR-011)
- [x] T034 [US1] Create roles/hpc_slurm_cui/tasks/main.yml to deploy partition config and scripts
- [x] T035 [US1] Add sacct field configuration to main.yml (FR-012)
- [x] T036 [US1] Create roles/hpc_slurm_cui/tasks/verify.yml to validate partition config and scripts
- [x] T037 [US1] Create roles/hpc_slurm_cui/tasks/evidence.yml to collect job accounting data (FR-013)
- [x] T038 [US1] Create roles/hpc_slurm_cui/files/README_researchers.md with plain language CUI partition guide (FR-014)
- [x] T039 [US1] Create roles/hpc_slurm_cui/vars/main.yml with internal variables

**Checkpoint**: At this point, User Story 1 should be fully functional - researchers can submit authorized jobs to CUI partition with memory sanitization

---

## Phase 4: User Story 2 - Container Security in CUI Enclave (Priority: P1)

**Goal**: Enable secure container execution with signed images, network isolation, and execution logging

**Independent Test**: Attempt to run signed/unsigned containers, access restricted paths, attempt network connections, verify restrictions work

### Implementation for User Story 2

- [x] T040 [P] [US2] Create roles/hpc_container_security/templates/apptainer.conf.j2 with security settings (FR-015)
- [x] T041 [US2] Add signed container verification to apptainer.conf.j2 (FR-016)
- [x] T042 [US2] Add bind mount restrictions to apptainer.conf.j2 (FR-017)
- [x] T043 [US2] Add network isolation (--net --network=none) to apptainer.conf.j2 (FR-018)
- [x] T044 [US2] Add InfiniBand passthrough configuration for MPI workloads (FR-018a)
- [x] T045 [US2] Create roles/hpc_container_security/templates/container_wrapper.sh.j2 for execution logging (FR-019)
- [x] T046 [US2] Create roles/hpc_container_security/tasks/main.yml to deploy Apptainer config and wrapper
- [x] T047 [US2] Create roles/hpc_container_security/tasks/verify.yml to validate container restrictions
- [x] T048 [US2] Create roles/hpc_container_security/tasks/evidence.yml to collect execution logs
- [x] T049 [US2] Create roles/hpc_container_security/files/README_containers.md with researcher container guide (FR-020)
- [x] T050 [US2] Add workflow testing section to README_containers.md for Python, R, GROMACS, VASP (FR-021)
- [x] T051 [US2] Create roles/hpc_container_security/vars/main.yml with internal variables

**Checkpoint**: At this point, User Story 2 should be fully functional - researchers can run signed containers with proper isolation

---

## Phase 5: User Story 3 - Parallel Filesystem Security (Priority: P1)

**Goal**: Enable secure CUI project storage with ACL management, changelog monitoring, quotas, and sanitization

**Independent Test**: Create project directories, verify ACLs match FreeIPA groups, test changelog events, quota enforcement, and sanitization

### Implementation for User Story 3

- [x] T052 [P] [US3] Create roles/hpc_storage_security/templates/lustre_changelog.conf.j2 for Lustre monitoring (FR-022)
- [x] T053 [P] [US3] Create roles/hpc_storage_security/templates/beegfs_changelog.conf.j2 for BeeGFS monitoring
- [x] T054 [US3] Create roles/hpc_storage_security/files/acl_sync.py daemon for FreeIPA-ACL sync (FR-023)
- [x] T055 [US3] Add systemd service template for acl_sync daemon
- [x] T056 [US3] Create encryption at rest verification task (FR-024)
- [x] T057 [US3] Create quota enforcement configuration (FR-025)
- [x] T058 [US3] Add quota exceeded handling with read-only mode (FR-025a)
- [x] T059 [US3] Create roles/hpc_storage_security/templates/sanitize_project.sh.j2 for data sanitization (FR-026)
- [x] T060 [US3] Add backup encryption verification task (FR-027)
- [x] T061 [US3] Create roles/hpc_storage_security/tasks/main.yml with filesystem type detection (FR-028)
- [x] T062 [US3] Create roles/hpc_storage_security/tasks/verify.yml to validate ACLs and quotas
- [x] T063 [US3] Create roles/hpc_storage_security/tasks/evidence.yml to collect changelog evidence
- [x] T064 [US3] Create roles/hpc_storage_security/vars/main.yml with internal variables

**Checkpoint**: At this point, User Story 3 should be fully functional - storage is secured with ACLs, monitoring, and sanitization

---

## Phase 6: User Story 4 - Node Lifecycle Management (Priority: P2)

**Goal**: Enable automated node provisioning, compliance scanning, health checks, and secure decommissioning

**Independent Test**: PXE boot new node, verify compliance scan passes, run health checks between jobs, execute decommissioning

### Implementation for User Story 4

- [x] T065 [P] [US4] Create roles/hpc_node_lifecycle/templates/first_boot.sh.j2 for post-PXE compliance scan (FR-032, FR-033)
- [x] T066 [P] [US4] Create roles/hpc_node_lifecycle/templates/health_check.sh.j2 for inter-job checks (FR-035)
- [x] T067 [P] [US4] Create roles/hpc_node_lifecycle/templates/sanitize_node.sh.j2 for NIST 800-88 sanitization (FR-036)
- [x] T068 [US4] Add node quarantine logic to first_boot.sh.j2 (FR-034)
- [x] T069 [US4] Add sanitization verification to sanitize_node.sh.j2 (FR-037)
- [x] T070 [US4] Create roles/hpc_node_lifecycle/tasks/main.yml to deploy lifecycle scripts
- [x] T071 [US4] Create roles/hpc_node_lifecycle/tasks/verify.yml to validate node compliance
- [x] T072 [US4] Create roles/hpc_node_lifecycle/tasks/evidence.yml to collect node state evidence
- [x] T073 [US4] Create roles/hpc_node_lifecycle/vars/main.yml with internal variables

**Checkpoint**: At this point, User Story 4 should be fully functional - nodes have automated lifecycle management

---

## Phase 7: User Story 5 - Researcher Onboarding/Offboarding (Priority: P2)

**Goal**: Enable automated CUI project onboarding and offboarding with proper access provisioning and revocation

**Independent Test**: Run onboarding for test project, verify all resources created, run offboarding, verify complete cleanup

### Implementation for User Story 5

- [x] T074 [P] [US5] Create templates/pi_welcome_packet.md.j2 with plain language PI instructions (FR-042)
- [x] T075 [P] [US5] Update playbooks/vars/onboarding_defaults.yml with production defaults
- [x] T076 [US5] Create playbooks/onboard_project.yml with FreeIPA group creation (FR-038)
- [x] T077 [US5] Add Slurm account creation to onboard_project.yml (FR-039)
- [x] T078 [US5] Add storage directory provisioning to onboard_project.yml (FR-040)
- [x] T079 [US5] Add Duo MFA assignment to onboard_project.yml (FR-041)
- [x] T080 [US5] Add welcome packet generation to onboard_project.yml
- [x] T081 [US5] Create playbooks/offboard_project.yml with access revocation (FR-043)
- [x] T082 [US5] Add 24-hour grace period handling to offboard_project.yml (FR-043a)
- [x] T083 [US5] Add immediate job submission blocking to offboard_project.yml (FR-043b)
- [x] T084 [US5] Add data archive/sanitize option to offboard_project.yml (FR-044)
- [x] T085 [US5] Add completion evidence generation to offboard_project.yml (FR-045)
- [x] T086 [US5] Create onboarding evidence file generation in data/onboarding/
- [x] T087 [US5] Create offboarding evidence file generation in data/offboarding/

**Checkpoint**: At this point, User Story 5 should be fully functional - projects can be onboarded and offboarded automatically

---

## Phase 8: User Story 6 - Interconnect Security Documentation (Priority: P3)

**Goal**: Generate formal InfiniBand RDMA exception documentation with compensating controls verification

**Independent Test**: Generate exception documentation, verify compensating controls documented, validate template produces audit-ready artifacts

### Implementation for User Story 6

- [x] T088 [P] [US6] Create roles/hpc_interconnect/templates/rdma_exception.md.j2 with POA&M format (FR-029)
- [x] T089 [P] [US6] Create roles/hpc_interconnect/templates/compensating_controls.md.j2 for control matrix (FR-030)
- [x] T090 [US6] Add future encryption template placeholder (FR-031)
- [x] T091 [US6] Create roles/hpc_interconnect/tasks/main.yml to generate documentation
- [x] T092 [US6] Create roles/hpc_interconnect/tasks/verify.yml to validate compensating controls
- [x] T093 [US6] Create roles/hpc_interconnect/tasks/evidence.yml to collect boundary evidence
- [x] T094 [US6] Create roles/hpc_interconnect/vars/main.yml with internal variables

**Checkpoint**: At this point, User Story 6 should be fully functional - interconnect exception documented for auditors

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation updates, integration, and testing infrastructure

- [x] T095 [P] Update docs/hpc_tailoring.yml with implementation details for all HPC-specific tailoring decisions (FR-046)
- [x] T096 [P] Update docs/researcher_quickstart.md with HPC-specific instructions (FR-047)
- [x] T097 [P] Create tests/integration/test_slurm_prolog.py with authorization test cases
- [x] T098 [P] Create tests/integration/test_container_security.py with restriction test cases
- [x] T099 [P] Create tests/integration/test_storage_acls.py with ACL sync test cases
- [x] T100 Create tests/molecule/hpc_slurm_cui/molecule.yml with test configuration
- [x] T101 [P] Create tests/molecule/hpc_container_security/molecule.yml with test configuration
- [x] T102 [P] Create tests/molecule/hpc_storage_security/molecule.yml with test configuration
- [x] T103 [P] Create tests/molecule/hpc_interconnect/molecule.yml with test configuration
- [x] T104 [P] Create tests/molecule/hpc_node_lifecycle/molecule.yml with test configuration
- [x] T105 Add HPC roles to playbooks/site.yml with appropriate tags
- [x] T106 Add HPC verification tasks to playbooks/verify.yml
- [x] T107 Add HPC evidence tasks to playbooks/ssp_evidence.yml
- [x] T108 Run make ee-lint and fix any ansible-lint warnings
- [x] T109 Run make ee-yamllint and fix any YAML issues
- [x] T110 Run make ee-syntax-check to verify playbook syntax
- [x] T111 Validate quickstart.md scenarios work as documented
- [x] T112 Update specs/004-hpc-cui-roles/checklists/requirements.md to mark all items complete

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phases 3-8)**: All depend on Foundational phase completion
  - US1, US2, US3 are all P1 priority - implement in order for single developer
  - US4, US5 are P2 priority - can start after P1 stories
  - US6 is P3 priority - can run in parallel with earlier stories
- **Polish (Phase 9)**: Depends on all desired user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Slurm CUI Partition - No dependencies on other stories, foundational for job execution
- **User Story 2 (P1)**: Container Security - Independent, but containers run within Slurm jobs
- **User Story 3 (P1)**: Storage Security - Independent, provides storage for all projects
- **User Story 4 (P2)**: Node Lifecycle - Uses health check from US1 epilog, otherwise independent
- **User Story 5 (P2)**: Onboarding - Uses storage from US3, Slurm accounts, independent playbooks
- **User Story 6 (P3)**: Interconnect Docs - Fully independent, documentation only

### Within Each User Story

- Templates before tasks
- main.yml before verify.yml before evidence.yml
- Core implementation before documentation
- Story complete before moving to next priority

### Parallel Opportunities

- All role directory creation (T001-T005) can run in parallel
- All meta/main.yml creation (T011-T015) can run in parallel
- All defaults/main.yml creation (T016-T020) can run in parallel
- Templates within a role can often run in parallel (different files)
- Molecule configs (T100-T104) can run in parallel
- Integration tests (T097-T099) can run in parallel

---

## Parallel Example: Phase 1 Setup

```bash
# Launch all role directory creation together:
Task: "Create role directory structure for roles/hpc_slurm_cui/"
Task: "Create role directory structure for roles/hpc_container_security/"
Task: "Create role directory structure for roles/hpc_storage_security/"
Task: "Create role directory structure for roles/hpc_interconnect/"
Task: "Create role directory structure for roles/hpc_node_lifecycle/"
```

## Parallel Example: User Story 3 Templates

```bash
# Launch filesystem-specific templates together:
Task: "Create roles/hpc_storage_security/templates/lustre_changelog.conf.j2"
Task: "Create roles/hpc_storage_security/templates/beegfs_changelog.conf.j2"
```

---

## Implementation Strategy

### MVP First (User Stories 1-3 Only)

1. Complete Phase 1: Setup (role scaffolding)
2. Complete Phase 2: Foundational (meta, defaults, control mappings)
3. Complete Phase 3: User Story 1 - Slurm CUI Partition
4. **STOP and VALIDATE**: Test job submission with prolog/epilog
5. Complete Phase 4: User Story 2 - Container Security
6. **STOP and VALIDATE**: Test container restrictions
7. Complete Phase 5: User Story 3 - Storage Security
8. **STOP and VALIDATE**: Test ACLs and sanitization
9. At this point, core HPC compliance is operational

### Incremental Delivery

1. Setup + Foundational → Foundation ready
2. Add US1 (Slurm) → Test → CUI jobs work
3. Add US2 (Containers) → Test → Containers work
4. Add US3 (Storage) → Test → Storage secured (MVP complete!)
5. Add US4 (Node Lifecycle) → Test → Nodes automated
6. Add US5 (Onboarding) → Test → Projects automated
7. Add US6 (Interconnect) → Test → Audit-ready
8. Polish → Full validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Slurm)
   - Developer B: User Story 2 (Containers)
   - Developer C: User Story 3 (Storage)
3. After P1 stories complete:
   - Developer A: User Story 4 (Node Lifecycle)
   - Developer B: User Story 5 (Onboarding)
   - Developer C: User Story 6 (Interconnect) + Polish

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story is independently completable and testable
- All roles follow main.yml/verify.yml/evidence.yml pattern (Constitution Principle VII)
- Plain language documentation required for all roles (Constitution Principle I)
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
