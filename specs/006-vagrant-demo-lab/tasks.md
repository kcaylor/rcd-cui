# Tasks: Vagrant Demo Lab Environment

**Input**: Design documents from `/specs/006-vagrant-demo-lab/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Demo environment**: `demo/vagrant/`, `demo/scripts/`, `demo/playbooks/`, `demo/narratives/`
- **Existing roles**: `roles/` at repository root
- **Inventory**: `demo/vagrant/inventory/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and directory structure

- [x] T001 Create demo/ directory structure per implementation plan
- [x] T002 Create demo/vagrant/ansible.cfg with paths to roles and inventory
- [x] T003 [P] Create demo/vagrant/inventory/hosts.yml with static inventory structure

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Vagrantfile and provisioning that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create demo/vagrant/Vagrantfile with 4 VM definitions (mgmt01, login01, compute01, compute02)
- [x] T005 Add VirtualBox provider block to Vagrantfile with memory/CPU settings
- [x] T006 [P] Add libvirt provider block to Vagrantfile with memory/CPU settings
- [x] T007 [P] Add QEMU provider block to Vagrantfile for Apple Silicon (x86 emulation)
- [x] T008 Configure private network in Vagrantfile (192.168.56.0/24)
- [x] T009 Add Ansible provisioner block to Vagrantfile calling demo/playbooks/provision.yml
- [x] T010 Create demo/playbooks/provision.yml with base provisioning tasks
- [x] T011 Add FreeIPA server installation tasks to provision.yml for mgmt01
- [x] T012 Add FreeIPA client enrollment tasks to provision.yml for all nodes
- [x] T013 [P] Add Wazuh manager installation tasks to provision.yml for mgmt01
- [x] T014 [P] Add Wazuh agent installation tasks to provision.yml for all nodes
- [x] T015 Add Slurm controller (slurmctld) tasks to provision.yml for mgmt01
- [x] T016 Add Slurm compute (slurmd) tasks to provision.yml for compute nodes
- [x] T017 Add Slurm submit host configuration to provision.yml for login01
- [x] T018 [P] Add NFS server tasks to provision.yml for mgmt01 (/shared export)
- [x] T019 [P] Add NFS client mount tasks to provision.yml for all nodes

**Checkpoint**: Foundation ready - basic `vagrant up` creates 4 VMs with core services

---

## Phase 3: User Story 1 - Lab Environment Setup (Priority: P1) 🎯 MVP

**Goal**: Complete demo-setup.sh that brings up lab and runs provisioning with baseline snapshot

**Independent Test**: Run `demo-setup.sh` and verify all 4 VMs are running with FreeIPA, Slurm, and NFS operational

### Implementation for User Story 1

- [x] T020 [US1] Create demo/scripts/demo-setup.sh with vagrant up and provision logic
- [x] T021 [US1] Add progress output and colored status messages to demo-setup.sh
- [x] T022 [US1] Add baseline snapshot creation to demo-setup.sh (vagrant snapshot push)
- [x] T023 [US1] Add error handling and exit codes to demo-setup.sh
- [x] T024 [US1] Add host prerequisites check to demo-setup.sh (Vagrant, provider, RAM)
- [x] T025 [US1] Create verification tasks in provision.yml to confirm all services are running

**Checkpoint**: User Story 1 complete - `demo-setup.sh` provisions working lab

---

## Phase 4: User Story 2 - Project Onboarding Demonstration (Priority: P1)

**Goal**: Scenario A playbook creates Project Helios with users, QOS, and storage ACLs

**Independent Test**: Run `scenario-a-onboard.yml` and verify helios group exists with alice_helios and bob_helios users

### Implementation for User Story 2

- [x] T026 [P] [US2] Create roles/project_onboarding/tasks/main.yml for project creation workflow
- [x] T027 [P] [US2] Create roles/project_onboarding/defaults/main.yml with default values
- [x] T028 [US2] Create demo/playbooks/scenario-a-onboard.yml calling project_onboarding role
- [x] T029 [US2] Add FreeIPA group creation tasks (group: helios) to project_onboarding role
- [x] T030 [US2] Add FreeIPA user creation tasks (alice_helios, bob_helios) to project_onboarding role
- [x] T031 [US2] Add Slurm QOS creation tasks (project-helios) to project_onboarding role
- [x] T032 [US2] Add NFS project directory creation with ACLs (/shared/projects/helios) to project_onboarding role
- [x] T033 [US2] Create demo/narratives/scenario-a.md with talking points and expected outputs
- [x] T034 [US2] Add timing estimates and presenter notes to scenario-a.md

**Checkpoint**: User Story 2 complete - Project onboarding demonstration works independently

---

## Phase 5: User Story 3 - Compliance Drift Detection and Remediation (Priority: P1)

**Goal**: demo-break.sh introduces violations, assessment detects them, demo-fix.sh remediates

**Independent Test**: Run demo-break.sh, verify assessment fails, run demo-fix.sh, verify assessment passes

### Implementation for User Story 3

- [x] T035 [P] [US3] Create roles/compliance_break/tasks/main.yml with violation introduction tasks
- [x] T036 [P] [US3] Create roles/compliance_break/defaults/main.yml with violation definitions
- [x] T037 [US3] Add SSH PermitRootLogin violation task to compliance_break role
- [x] T038 [US3] Add auditd stop violation task to compliance_break role
- [x] T039 [US3] Add /etc/shadow chmod 644 violation task to compliance_break role
- [x] T040 [US3] Add firewalld stop violation task to compliance_break role
- [x] T041 [US3] Create demo/scripts/demo-break.sh calling compliance_break role
- [x] T042 [US3] Create demo/scripts/demo-fix.sh calling existing remediation roles
- [x] T043 [US3] Create demo/playbooks/scenario-b-drift.yml orchestrating break/detect/fix cycle
- [x] T044 [US3] Add assessment invocation to scenario-b-drift.yml showing failing controls
- [x] T045 [US3] Create demo/narratives/scenario-b.md with talking points and expected outputs
- [x] T046 [US3] Add timing estimates and presenter notes to scenario-b.md

**Checkpoint**: User Story 3 complete - Drift detection and remediation demonstration works independently

---

## Phase 6: User Story 4 - Auditor Package Generation (Priority: P2)

**Goal**: Scenario C generates complete auditor package with SPRS score and evidence

**Independent Test**: Run scenario-c-audit.yml and verify auditor package is generated in /shared/auditor

### Implementation for User Story 4

- [x] T047 [US4] Create demo/playbooks/scenario-c-audit.yml calling evidence and reporting roles
- [x] T048 [US4] Add assessment run to scenario-c-audit.yml to generate fresh data
- [x] T049 [US4] Add auditor package generation tasks to scenario-c-audit.yml
- [x] T050 [US4] Create demo/narratives/scenario-c.md with talking points and expected outputs
- [x] T051 [US4] Add timing estimates and presenter notes to scenario-c.md

**Checkpoint**: User Story 4 complete - Auditor package generation demonstration works independently

---

## Phase 7: User Story 5 - Node Lifecycle Management (Priority: P2)

**Goal**: Scenario D demonstrates adding compute03, compliance gate, and decommissioning

**Independent Test**: Run scenario-d-lifecycle.yml with add tag, verify compliance gate blocks/allows, then remove

### Implementation for User Story 5

- [x] T052 [P] [US5] Create roles/node_provision/tasks/main.yml for dynamic node addition
- [x] T053 [P] [US5] Create roles/compliance_gate/tasks/main.yml for compliance check before joining
- [x] T054 [P] [US5] Create roles/node_decommission/tasks/main.yml for clean node removal
- [x] T055 [US5] Create demo/playbooks/scenario-d-lifecycle.yml with add/verify/remove tags
- [x] T056 [US5] Add compute03 VM definition to Vagrantfile (dormant by default)
- [x] T057 [US5] Add FreeIPA enrollment for new node in node_provision role
- [x] T058 [US5] Add Slurm node registration in node_provision role
- [x] T059 [US5] Add credential revocation in node_decommission role
- [x] T060 [US5] Create demo/narratives/scenario-d.md with talking points and expected outputs
- [x] T061 [US5] Add timing estimates and presenter notes to scenario-d.md

**Checkpoint**: User Story 5 complete - Node lifecycle demonstration works independently

---

## Phase 8: User Story 6 - Lab Reset Between Demonstrations (Priority: P2)

**Goal**: demo-reset.sh restores baseline state in under 5 minutes using snapshots

**Independent Test**: Run any scenario, then demo-reset.sh, verify clean state in < 5 minutes

### Implementation for User Story 6

- [x] T062 [US6] Create demo/scripts/demo-reset.sh with snapshot restore logic
- [x] T063 [US6] Add vagrant snapshot pop command to demo-reset.sh
- [x] T064 [US6] Add vagrant snapshot push command to demo-reset.sh (new baseline)
- [x] T065 [US6] Add progress output and timing display to demo-reset.sh
- [x] T066 [US6] Add verification that reset completed successfully

**Checkpoint**: User Story 6 complete - Lab reset demonstration works independently

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and validation

- [x] T067 [P] Update specs/006-vagrant-demo-lab/quickstart.md with actual paths and commands
- [x] T068 [P] Add troubleshooting section to quickstart.md based on common issues
- [x] T069 [P] Create demo/README.md with overview and quick reference
- [x] T070 Add provider detection and auto-selection to all demo scripts
- [x] T071 Test full demo flow on macOS with VirtualBox
- [x] T072 [P] Test full demo flow on Linux with libvirt
- [x] T073 Validate air-gapped operation after initial provisioning
- [x] T074 Run quickstart.md validation to verify setup instructions work end-to-end

Validation evidence: `reports/006-vagrant-demo-lab-validation.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1 (Lab Setup) is prerequisite for all other stories (provides running VMs)
  - US2, US3 can proceed in parallel after US1
  - US4 depends on US3 (needs assessment data from drift scenario)
  - US5, US6 can proceed in parallel after US1
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (Lab Setup)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **US2 (Onboarding)**: Depends on US1 (needs running lab)
- **US3 (Drift)**: Depends on US1 (needs running lab)
- **US4 (Audit)**: Depends on US3 (needs assessment history)
- **US5 (Lifecycle)**: Depends on US1 (needs running lab)
- **US6 (Reset)**: Depends on US1 (needs baseline snapshot)

### Within Each User Story

- Create role structure first (if applicable)
- Add tasks to roles
- Create playbook calling roles
- Create narrative documentation
- Test independently

### Parallel Opportunities

- **Phase 1**: T002 and T003 can run in parallel
- **Phase 2**: T006, T007 can run in parallel (different provider blocks); T013, T014 can run in parallel; T018, T019 can run in parallel
- **Phase 4**: T026, T027 can run in parallel (role structure)
- **Phase 5**: T035, T036 can run in parallel (role structure)
- **Phase 7**: T052, T053, T054 can run in parallel (different roles)
- **Phase 9**: Most documentation tasks can run in parallel

---

## Parallel Example: User Story 3 (Compliance Drift)

```bash
# Launch role structure tasks in parallel:
Task: "T035 [P] [US3] Create roles/compliance_break/tasks/main.yml"
Task: "T036 [P] [US3] Create roles/compliance_break/defaults/main.yml"

# Then sequentially add violation tasks (same file):
Task: "T037 [US3] Add SSH PermitRootLogin violation task"
Task: "T038 [US3] Add auditd stop violation task"
# etc.
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 + 3)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Lab Setup)
4. **STOP and VALIDATE**: Test that `demo-setup.sh` creates working lab
5. Complete Phase 4: User Story 2 (Onboarding)
6. Complete Phase 5: User Story 3 (Drift)
7. **STOP and VALIDATE**: Test all P1 scenarios independently
8. Deploy/demo if ready - this is the core MVP

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add US1 (Lab Setup) → Test independently → First demo possible
3. Add US2 (Onboarding) → Test independently → Two scenarios available
4. Add US3 (Drift) → Test independently → Three scenarios available (MVP!)
5. Add US4 (Audit) → Test independently → Four scenarios
6. Add US5 (Lifecycle) → Test independently → Five scenarios
7. Add US6 (Reset) → Test independently → Full feature complete
8. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Lab Setup) - MUST complete first
3. After US1 complete:
   - Developer A: User Story 2 (Onboarding)
   - Developer B: User Story 3 (Drift)
   - Developer C: User Story 5 (Lifecycle) + User Story 6 (Reset)
4. After US3 complete:
   - Developer B: User Story 4 (Audit) - depends on US3

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- Roles leverage existing rcd-cui roles where possible
- Narratives are critical for presenter experience - don't skip them
