# Tasks: Cloud Demo Infrastructure

**Input**: Design documents from `/specs/007-cloud-demo-infra/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Terraform configs**: `infra/terraform/`
- **Wrapper scripts**: `infra/scripts/`
- **Documentation**: `infra/README.md`
- **Makefile**: Repository root `Makefile`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Directory structure and Terraform initialization

- [x] T001 Create infra/ directory structure per implementation plan
- [x] T002 Create infra/terraform/variables.tf with region, VM sizes, TTL, SSH key path variables
- [x] T003 [P] Create infra/terraform/main.tf with Hetzner provider configuration
- [x] T004 [P] Add .gitignore entries for Terraform state and generated inventory

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core Terraform resources that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Create infra/terraform/main.tf SSH key resource (hcloud_ssh_key) with auto-detection logic
- [x] T006 Create infra/terraform/main.tf private network resource (hcloud_network, 10.0.0.0/8)
- [x] T007 Create infra/terraform/main.tf subnet resource (hcloud_network_subnet, 10.0.0.0/24, us-west)
- [x] T008 Create infra/terraform/nodes.tf with mgmt01 server definition (cpx21, 4GB)
- [x] T009 [P] Create infra/terraform/nodes.tf with login01 server definition (cpx11, 2GB, public IP)
- [x] T010 [P] Create infra/terraform/nodes.tf with compute01 server definition (cpx11, 2GB, no public IP)
- [x] T011 [P] Create infra/terraform/nodes.tf with compute02 server definition (cpx11, 2GB, no public IP)
- [x] T012 Add network attachments for all servers in infra/terraform/nodes.tf (hcloud_server_network)
- [x] T013 Add resource labels (cluster, ttl, created_at, managed_by) to all resources in nodes.tf
- [x] T014 Create infra/terraform/outputs.tf with mgmt01_ip, login01_ip, private_ips, inventory_path
- [x] T015 Create infra/terraform/inventory.tpl Ansible inventory template
- [x] T016 Add local_file resource to main.tf generating inventory.yml from template

**Checkpoint**: Foundation ready - `terraform apply` creates 4 VMs with network

---

## Phase 3: User Story 1 - Spin Up Demo Cluster (Priority: P1) 🎯 MVP

**Goal**: Complete demo-cloud-up.sh that provisions VMs and runs Ansible configuration

**Independent Test**: Run `make demo-cloud-up` and verify all 4 VMs are SSH accessible

### Implementation for User Story 1

- [x] T017 [US1] Create infra/scripts/demo-cloud-up.sh with SSH key detection function
- [x] T018 [US1] Add HCLOUD_TOKEN validation to demo-cloud-up.sh with setup instructions
- [x] T019 [US1] Add existing cluster detection to demo-cloud-up.sh (terraform state list check)
- [x] T020 [US1] Add terraform init and apply calls to demo-cloud-up.sh with progress output
- [x] T021 [US1] Add Ansible provisioning call to demo-cloud-up.sh (demo/playbooks/provision.yml)
- [x] T022 [US1] Add SSH connection info display to demo-cloud-up.sh on completion
- [x] T023 [US1] Add demo-cloud-up target to root Makefile
- [x] T024 [US1] Make demo-cloud-up.sh executable (chmod +x)

**Checkpoint**: User Story 1 complete - `make demo-cloud-up` provisions working cluster

---

## Phase 4: User Story 2 - Tear Down Demo Cluster (Priority: P1)

**Goal**: Complete demo-cloud-down.sh that destroys all resources

**Independent Test**: Run `make demo-cloud-down` after spin-up and verify zero resources remain

### Implementation for User Story 2

- [x] T025 [US2] Create infra/scripts/demo-cloud-down.sh with resource count display
- [x] T026 [US2] Add confirmation prompt to demo-cloud-down.sh before destroy
- [x] T027 [US2] Add terraform destroy call to demo-cloud-down.sh with progress output
- [x] T028 [US2] Add completion message with elapsed time and cost estimate to demo-cloud-down.sh
- [x] T029 [US2] Add demo-cloud-down target to root Makefile
- [x] T030 [US2] Make demo-cloud-down.sh executable (chmod +x)

**Checkpoint**: User Story 2 complete - `make demo-cloud-down` destroys cluster cleanly

---

## Phase 5: User Story 3 - Run Demo Scenarios (Priority: P1)

**Goal**: Verify existing demo playbooks work unchanged on cloud cluster

**Independent Test**: Run scenario-a-onboard.yml and verify same outputs as Vagrant environment

### Implementation for User Story 3

- [ ] T031 [US3] Update demo/vagrant/ansible.cfg to support alternate inventory path via ANSIBLE_INVENTORY
- [x] T032 [US3] Add ProxyJump configuration to inventory.tpl for compute node access
- [x] T033 [US3] Add ansible_user=root to inventory.tpl (differs from Vagrant's ansible_user=vagrant)
- [ ] T034 [US3] Test provision.yml runs successfully on cloud inventory
- [ ] T035 [US3] Test scenario-a-onboard.yml runs successfully on cloud cluster
- [ ] T036 [US3] Test scenario-b-drift.yml runs successfully on cloud cluster
- [ ] T037 [P] [US3] Test scenario-c-audit.yml runs successfully on cloud cluster
- [ ] T038 [P] [US3] Test scenario-d-lifecycle.yml runs successfully on cloud cluster

**Checkpoint**: User Story 3 complete - All demo scenarios work on cloud cluster

---

## Phase 6: User Story 4 - Share Access with Workshop Attendees (Priority: P2)

**Goal**: Document and enable workshop attendee SSH access

**Independent Test**: Add test SSH key and verify connection to login01

### Implementation for User Story 4

- [x] T039 [US4] Add workshop attendee key injection section to infra/README.md
- [x] T040 [US4] Add example SSH authorized_keys append commands to infra/README.md
- [x] T041 [US4] Document SSH access instructions for attendees in infra/README.md

**Checkpoint**: User Story 4 complete - Workshop access documented

---

## Phase 7: User Story 5 - Cost Awareness and Safety (Priority: P2)

**Goal**: Cost estimation on spin-up and TTL warnings

**Independent Test**: Verify cost estimate displays and TTL warning appears after threshold

### Implementation for User Story 5

- [x] T042 [US5] Add cost estimation display function to demo-cloud-up.sh
- [x] T043 [US5] Add TTL check function to demo-cloud-up.sh (query hcloud API for created_at label)
- [x] T044 [US5] Add TTL warning display to demo-cloud-up.sh and demo-cloud-down.sh
- [x] T045 [US5] Add demo-cloud-status target to Makefile showing cluster age and cost
- [x] T046 [US5] Create infra/scripts/check-ttl.sh helper script for TTL warnings

**Checkpoint**: User Story 5 complete - Cost and TTL warnings functional

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and validation

- [x] T047 [P] Create infra/README.md with Hetzner account setup instructions
- [x] T048 [P] Add cost expectations and billing model to infra/README.md
- [x] T049 [P] Add troubleshooting section to infra/README.md
- [x] T050 Update specs/007-cloud-demo-infra/quickstart.md with actual paths and commands
- [ ] T051 Run full spin-up/scenario/teardown validation cycle
- [x] T052 Document validation results in reports/007-cloud-demo-infra-validation.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-7)**: All depend on Foundational phase completion
  - US1 (Spin Up) must complete before US2 (Tear Down) can be tested
  - US1 must complete before US3 (Run Scenarios) can be tested
  - US1 must complete before US4 (Workshop Access) can be tested
  - US1 must complete before US5 (Cost/TTL) can be tested
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (Spin Up)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **US2 (Tear Down)**: Can start after Foundational (Phase 2) - Test requires US1 cluster
- **US3 (Run Scenarios)**: Can start after Foundational (Phase 2) - Test requires US1 cluster
- **US4 (Workshop Access)**: Can start after Foundational (Phase 2) - Documentation only
- **US5 (Cost/TTL)**: Can start after Foundational (Phase 2) - Test requires US1 cluster

### Within Each User Story

- Create script structure first
- Add core functionality
- Add error handling and validation
- Add Makefile targets
- Test independently

### Parallel Opportunities

- **Phase 1**: T003 and T004 can run in parallel
- **Phase 2**: T009, T010, T011 can run in parallel (different VM definitions)
- **Phase 3-7**: US4 documentation tasks can run in parallel with other stories
- **Phase 5**: T037 and T038 can run in parallel (independent scenario tests)
- **Phase 8**: T047, T048, T049 can run in parallel (different README sections)

---

## Parallel Example: User Story 3 (Run Scenarios)

```bash
# Launch scenario tests in parallel after provision.yml completes:
Task: "T037 [P] [US3] Test scenario-c-audit.yml"
Task: "T038 [P] [US3] Test scenario-d-lifecycle.yml"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (Spin Up)
4. Complete Phase 4: User Story 2 (Tear Down)
5. **STOP and VALIDATE**: Can now spin up and tear down clusters
6. Deploy/demo if ready - this is the core MVP

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add US1 (Spin Up) → Test independently → First demo possible
3. Add US2 (Tear Down) → Test independently → Full lifecycle working (MVP!)
4. Add US3 (Run Scenarios) → Test independently → Demo scenarios working
5. Add US4 (Workshop Access) → Documentation ready
6. Add US5 (Cost/TTL) → Safety features active
7. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (Spin Up) - MUST complete first
   - Developer B: User Story 4 (Documentation) - Can run in parallel
3. After US1 complete:
   - Developer A: User Story 2 (Tear Down)
   - Developer B: User Story 5 (Cost/TTL)
4. After US1+US2 complete:
   - Developer A: User Story 3 (Run Scenarios)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- US1 is the critical path - all other stories depend on having a running cluster to test
