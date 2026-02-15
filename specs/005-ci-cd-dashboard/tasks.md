# Tasks: CI/CD Pipeline and Living Dashboard

**Input**: Design documents from `/specs/005-ci-cd-dashboard/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Workflows**: `.github/workflows/`
- **Scripts**: `scripts/`
- **Reports**: `reports/`
- **Documentation**: `docs/generated/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and workflow directory structure

- [x] T001 Create .github/workflows/ directory structure
- [x] T002 [P] Verify existing Makefile targets work locally (ee-build, ee-lint, ee-syntax-check, ee-yamllint)
- [x] T003 [P] Verify existing documentation generation works (make docs, make dashboard, make crosswalk)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core scripts and shared components that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T004 Create scripts/generate_badge_data.py with BadgeData JSON schema from data-model.md
- [x] T005 Add Makefile target `make badge-data` to invoke badge data generation
- [x] T006 Create _site/ assembly script or Makefile target to prepare deployment artifacts
- [x] T007 [P] Create .github/actions/setup-ee/action.yml reusable composite action for EE build with caching

**Checkpoint**: Foundation ready - user story implementation can now begin

---

## Phase 3: User Story 1 - PR Validation Feedback (Priority: P1) 🎯 MVP

**Goal**: Automated lint, syntax-check, and YAML validation on every PR with clear status checks

**Independent Test**: Open a PR with intentional lint errors, verify status check fails, fix errors, verify status check passes

### Implementation for User Story 1

- [x] T008 [US1] Create .github/workflows/ci.yml with workflow name and PR trigger configuration
- [x] T009 [US1] Add lint job to ci.yml using make ee-lint with proper caching
- [x] T010 [P] [US1] Add syntax-check job to ci.yml using make ee-syntax-check
- [x] T011 [P] [US1] Add yaml-validation job to ci.yml using make ee-yamllint
- [x] T012 [US1] Configure all three jobs to run in parallel with fail-fast disabled
- [x] T013 [US1] Add step annotations for clear error messages with file paths and line numbers
- [x] T014 [US1] Test ci.yml by creating test PR with intentional errors

**Checkpoint**: PR validation workflow functional - developers see lint/syntax/yaml status on PRs

---

## Phase 4: User Story 2 - Live Compliance Dashboard (Priority: P1) 🎯 MVP

**Goal**: Dashboard auto-deploys to GitHub Pages after merge to main, showing SPRS score and compliance status

**Independent Test**: Merge to main, wait for workflow, navigate to GitHub Pages URL, verify dashboard displays

### Implementation for User Story 2

- [x] T015 [US2] Create .github/workflows/deploy.yml with push-to-main trigger
- [x] T016 [US2] Add concurrency group configuration to prevent overlapping deployments
- [x] T017 [US2] Add build job: checkout, setup-python, build EE with caching
- [x] T018 [US2] Add build job steps: make docs, make dashboard, make crosswalk, make badge-data
- [x] T019 [US2] Add build job step to assemble _site/ directory with all artifacts
- [x] T020 [US2] Add deploy job using peaceiris/actions-gh-pages@v4 to publish _site/ to gh-pages branch
- [x] T021 [US2] Configure deploy job to fail workflow if deployment fails (per clarification)
- [x] T022 [US2] Create root index.html redirect to /dashboard/ in _site/
- [x] T023 [US2] Test deploy.yml by triggering manual workflow_dispatch run

**Checkpoint**: Dashboard auto-deploys on merge to main - stakeholders can view compliance posture

---

## Phase 5: User Story 3 - Generated Documentation Access (Priority: P2)

**Goal**: Audience-specific documentation (PI guide, researcher quickstart, etc.) accessible on GitHub Pages

**Independent Test**: Navigate to docs section on GitHub Pages, verify all 5 audience guides are accessible with glossary links

### Implementation for User Story 3

- [x] T024 [US3] Update deploy.yml build job to copy docs/generated/ to _site/docs/
- [x] T025 [US3] Ensure crosswalk.csv is included in _site/docs/crosswalk.csv
- [x] T026 [US3] Add docs navigation or index page listing all available documentation
- [x] T027 [US3] Verify glossary hyperlinks work in generated documentation

**Checkpoint**: All 5 audience-specific documents accessible on GitHub Pages

---

## Phase 6: User Story 4 - README Status Badges (Priority: P2)

**Goal**: README displays CI status, SPRS score, and last assessment badges that update automatically

**Independent Test**: View README on GitHub, verify badges show current values, trigger CI, verify badges update

### Implementation for User Story 4

- [x] T028 [US4] Add CI status badge to README.md using GitHub workflow badge URL
- [x] T029 [US4] Add SPRS score badge to README.md using shields.io dynamic JSON endpoint
- [x] T030 [US4] Add last assessment date badge to README.md using shields.io dynamic JSON endpoint
- [x] T031 [US4] Verify badge-data.json is published to correct path for shields.io access
- [x] T032 [US4] Test badges by triggering deployment and verifying shields.io renders correctly

**Checkpoint**: README badges reflect current CI status and compliance score

---

## Phase 7: User Story 5 - Branch Protection Enforcement (Priority: P2)

**Goal**: Main branch requires CI pass and approval before merge, no direct pushes allowed

**Independent Test**: Attempt to merge PR with failing CI or without approval, verify GitHub blocks merge

### Implementation for User Story 5

- [x] T033 [US5] Document branch protection configuration in specs/005-ci-cd-dashboard/quickstart.md
- [x] T034 [US5] Create scripts/configure_branch_protection.sh using GitHub CLI (gh) for reproducible setup
- [x] T035 [US5] Configure required status checks: lint, syntax-check, yaml-validation
- [x] T036 [US5] Configure required approvals: 1 reviewer minimum
- [x] T037 [US5] Test branch protection by attempting merge with failing CI

**Checkpoint**: Branch protection enforces code quality gates on main branch

---

## Phase 8: User Story 6 - Nightly Assessment Run (Priority: P3)

**Goal**: Scheduled workflow runs compliance assessment nightly and updates dashboard

**Independent Test**: Wait for scheduled run (or trigger manually), verify dashboard updates with new assessment data

### Implementation for User Story 6

- [x] T038 [US6] Create .github/workflows/nightly.yml with cron schedule (0 2 * * *)
- [x] T039 [US6] Add workflow_dispatch trigger for manual runs
- [x] T040 [US6] Add concurrency group shared with deploy.yml to prevent conflicts
- [x] T041 [US6] Add assessment job: build EE, run make assess (or equivalent)
- [x] T042 [US6] Add deployment job to update dashboard after assessment
- [x] T043 [US6] Test nightly.yml by triggering manual workflow_dispatch

**Checkpoint**: Nightly assessment runs automatically and updates dashboard

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, cleanup, and validation

- [x] T044 [P] Update specs/005-ci-cd-dashboard/quickstart.md with actual URLs and configuration steps
- [x] T045 [P] Add workflow status badges to spec documentation
- [x] T046 [P] Add troubleshooting section to quickstart.md based on actual issues encountered
- [x] T047 Run quickstart.md validation to verify setup instructions work end-to-end
- [x] T048 Clean up any temporary test artifacts (test branches, test PRs)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1 and US2 are both P1 and can proceed in parallel
  - US3-US6 depend on US2 (deploy workflow) being functional
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (PR Validation)**: Can start after Foundational (Phase 2) - No dependencies on other stories
- **US2 (Dashboard)**: Can start after Foundational (Phase 2) - No dependencies on US1
- **US3 (Documentation)**: Depends on US2 (deploy workflow) being functional
- **US4 (Badges)**: Depends on US2 (badge-data.json published via deploy workflow)
- **US5 (Branch Protection)**: Depends on US1 (requires CI job names for status checks)
- **US6 (Nightly)**: Depends on US2 (shares deployment infrastructure)

### Within Each User Story

- Create workflow file structure first
- Add triggers and configuration
- Add jobs and steps
- Test workflow execution
- Validate acceptance criteria

### Parallel Opportunities

- **Phase 1**: T002 and T003 can run in parallel (different verification tasks)
- **Phase 2**: T007 can run in parallel with other foundational tasks
- **Phase 3**: T010 and T011 can run in parallel (separate jobs in same workflow)
- **Phase 5**: All docs tasks independent of each other
- **Phase 6**: Badge additions to README can be parallelized
- **Phase 9**: All polish tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1 (PR Validation)

```bash
# After T008 (workflow file created), these can run in parallel:
Task: "T010 [P] [US1] Add syntax-check job to ci.yml"
Task: "T011 [P] [US1] Add yaml-validation job to ci.yml"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (PR Validation)
4. Complete Phase 4: User Story 2 (Dashboard Deployment)
5. **STOP and VALIDATE**: Test both stories independently
6. Deploy/demo if ready - this is the core MVP

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add US1 + US2 → Test independently → Deploy/Demo (MVP!)
3. Add US3 (Documentation) → Test independently → Deploy
4. Add US4 (Badges) → Test independently → Deploy
5. Add US5 (Branch Protection) → Configure and verify
6. Add US6 (Nightly) → Test independently → Deploy
7. Each story adds value without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: User Story 1 (PR Validation)
   - Developer B: User Story 2 (Dashboard)
3. After US1 + US2 complete:
   - Developer A: User Story 5 (Branch Protection - needs US1)
   - Developer B: User Story 3 + 4 (Docs + Badges - needs US2)
4. After US2 complete:
   - Either developer: User Story 6 (Nightly)

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- GitHub Actions workflows can be tested via workflow_dispatch before full PR/merge testing
