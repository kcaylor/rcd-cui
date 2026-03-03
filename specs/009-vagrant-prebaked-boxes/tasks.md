# Tasks: Pre-Baked Vagrant Box Workflow

**Input**: Design documents from `/specs/009-vagrant-prebaked-boxes/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, quickstart.md

**Tests**: Not explicitly requested. Manual validation via demo scenario playbooks serves as functional test.

**Organization**: Tasks grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create directory structure, update gitignore and Makefile

- [X] T001 [P] Update `.gitignore` to add `demo/vagrant/boxes/` pattern and update `demo/vagrant/.gitignore` to add `boxes/` and `*.box` patterns
- [X] T002 [P] Create `demo/vagrant/boxes/` directory with a `.gitkeep` file to preserve the directory in version control
- [X] T003 [P] Add `demo-bake` and `demo-refresh` targets to `Makefile` (add to `.PHONY` line 14 and add target definitions after line 118, following existing cloud demo target pattern)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 Modify `demo/vagrant/Vagrantfile` to support conditional box selection: read `ENV['RCD_PREBAKED']`, set per-node `vm.vm.box` to `"rcd-cui-#{name}"` when prebaked or `'generic/rocky9'` otherwise, and wrap the Ansible provisioner block (lines 50-62) in `unless ENV['RCD_PREBAKED'] == '1'` conditional
- [X] T005 Create shared helper library `demo/scripts/lib-demo-common.sh` with functions: `log_info()`, `log_warn()`, `log_error()`, `detect_provider()` (extracted from demo-setup.sh lines 39-76), `generate_set_label()` (format: `rcd-demo-YYYYMMDD-NN`), `read_manifest()`, `write_manifest()`, `init_manifest()`, `get_current_set()`, `check_staleness()` — all using `jq` for JSON operations on `demo/vagrant/boxes/manifest.json` per the schema in data-model.md

**Checkpoint**: Foundation ready — user story implementation can now begin

---

## Phase 3: User Story 1 — Package a Provisioned Cluster as Reusable Boxes (Priority: P1) MVP

**Goal**: Create `demo-bake.sh` that packages all 4 running VMs into `.box` files with manifest tracking and 2-set rotation.

**Independent Test**: Run `demo-setup.sh` (from scratch), then `demo-bake.sh`, verify 4 `.box` files exist in `demo/vagrant/boxes/` and `manifest.json` is valid. Run `demo-bake.sh --list` and confirm output. Run `demo-bake.sh --delete <label>` and confirm cleanup.

### Implementation for User Story 1

- [X] T006 [US1] Create `demo/scripts/demo-bake.sh` with script header (set -euo pipefail, SCRIPT_DIR, REPO_ROOT, VAGRANT_CWD), source `lib-demo-common.sh`, and argument parsing: no args = bake, `--list` = list sets, `--delete <label>` = delete set, `--delete-all` = delete all, `--help` = usage
- [X] T007 [US1] Implement `verify_cluster_running()` function in `demo/scripts/demo-bake.sh` that checks all 4 VMs (mgmt01, login01, compute01, compute02) are running via `vagrant status` and exits with clear error if not
- [X] T008 [US1] Implement `package_vm()` function in `demo/scripts/demo-bake.sh` with provider-specific branching: VirtualBox uses `vagrant package <vm> --output <path>`; libvirt uses `vagrant package <vm> --output <path>` with `VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir,-ssh-hostkeys,-lvm-uuids"` to preserve FreeIPA/Munge state; QEMU uses manual flow: halt VM, locate disk at `.vagrant/machines/<vm>/qemu/vq_*/linked-box.img`, `qemu-img convert -O qcow2 -c` to compress, create `metadata.json` and `Vagrantfile`, `tar czf` into `.box`
- [X] T009 [US1] Implement `bake_all()` function in `demo/scripts/demo-bake.sh` that: checks disk space (warn if < 20 GB free), generates a set label via `generate_set_label()`, calls `package_vm()` for each of the 4 VMs, performs 2-set rotation (delete `previous`, relabel `current` to `previous`, set new as `current`), writes manifest, and prints summary with total size
- [X] T010 [US1] Implement `list_sets()` function in `demo/scripts/demo-bake.sh` that reads manifest and prints a formatted table: Label, Created, Provider, Age, Commit, Status (current/previous), Total Size
- [X] T011 [US1] Implement `delete_set()` and `delete_all()` functions in `demo/scripts/demo-bake.sh` that remove box files from `demo/vagrant/boxes/`, deregister from Vagrant via `vagrant box remove`, update manifest, and report reclaimed disk space
- [X] T012 [US1] Add `trap` handler in `demo/scripts/demo-bake.sh` for SIGINT/SIGTERM that cleans up any partially created `.box` files in progress (track current packaging file in a variable, remove on interrupt)

**Checkpoint**: `demo-bake.sh` is fully functional. Can package, list, and delete box sets. `make demo-bake` works.

---

## Phase 4: User Story 2 — Boot a Demo Cluster from Pre-Baked Boxes (Priority: P1)

**Goal**: Modify `demo-setup.sh` to detect baked boxes, offer to use them (skipping provisioning), run post-restore playbook, create baseline snapshot, and prompt to bake after fresh provisions.

**Independent Test**: With baked boxes present, run `demo-setup.sh`, accept baked boot, verify all services operational and demo scenario A passes. With no boxes, verify normal provisioning flow is unchanged.

**Depends on**: User Story 1 (T006-T012) — baked boxes must exist to test boot

### Implementation for User Story 2

- [X] T013 [US2] Add `check_baked_boxes()` function to `demo/scripts/demo-setup.sh` that sources `lib-demo-common.sh`, reads the manifest, checks if a `current` box set exists, verifies provider matches detected provider (exit with clear error on mismatch), compares stored `vagrant_version` with current `vagrant --version` (warn on mismatch), checks staleness (warn if > `DEMO_STALE_DAYS` / default 7), and returns 0 if usable boxes found
- [X] T014 [US2] Add baked-box prompt logic to `demo/scripts/demo-setup.sh` (after prerequisite checks, ~line 195): if `check_baked_boxes` returns 0, display set info (label, age, commit) and prompt "Use baked boxes? [Y/n]"; if user accepts, set `USE_BAKED=true`
- [X] T015 [US2] Implement baked-boot flow in `demo/scripts/demo-setup.sh`: when `USE_BAKED=true`, run `vagrant box add --force --name rcd-cui-<vm> <box-path>` for each VM, set `RCD_PREBAKED=1` env var, run `vagrant up --no-provision --provider <provider>`, skip all Ansible provisioning
- [X] T016 [US2] Add post-restore service reconciliation and health check to `demo/scripts/demo-setup.sh`: when `USE_BAKED=true`, after VMs are running, execute `ansible-playbook` with `demo/playbooks/post-restore.yml` using the appropriate inventory (QEMU uses runtime inventory, others use static), then verify critical services are operational (FreeIPA, slurmctld, wazuh-manager, nfs-server on mgmt01; slurmd on compute nodes; munge and chronyd on all nodes) via SSH service checks, then create baseline snapshot via `vagrant snapshot push baseline`
- [X] T017 [US2] Add auto-bake prompt to `demo/scripts/demo-setup.sh` after successful fresh provision (after baseline snapshot, ~line 225): if `DEMO_USE_BAKED` is not `0`, prompt "Bake this cluster for future fast starts? [Y/n]" and invoke `demo-bake.sh` if confirmed
- [X] T018 [US2] Ensure backward compatibility in `demo/scripts/demo-setup.sh`: when no baked boxes exist and `DEMO_USE_BAKED` is unset, the entire flow runs identically to the pre-feature behavior with no visible changes to the user

**Checkpoint**: Full bake-then-boot cycle works. Boot from baked boxes in < 5 min. Demo scenario A passes against baked-boot cluster. Fresh provision flow unchanged.

---

## Phase 5: User Story 3 — Rebuild Baked Boxes from Current Codebase (Priority: P2)

**Goal**: Create `demo-refresh.sh` for single-command destroy-provision-bake cycle.

**Independent Test**: Run `demo-refresh.sh`, verify VMs are destroyed, reprovisioned, baked, and new manifest reflects current commit.

**Depends on**: User Story 1 (bake functionality), User Story 2 (boot from baked)

### Implementation for User Story 3

- [X] T019 [US3] Create `demo/scripts/demo-refresh.sh` that: sources `lib-demo-common.sh`, destroys existing VMs (`vagrant destroy -f`), preserves the current baked box set as safety net (do not delete until new bake succeeds), runs `demo-setup.sh` with `DEMO_USE_BAKED=0` (force fresh), on success calls `demo-bake.sh` to create new boxes, on failure exits non-zero while preserving previous box set and printing clear error message

**Checkpoint**: `demo-refresh.sh` completes full destroy-provision-bake cycle. `make demo-refresh` works. Previous boxes preserved on failure.

---

## Phase 6: User Story 4 — Override Baked Box Behavior via Environment Variable (Priority: P3)

**Goal**: Ensure `DEMO_USE_BAKED` env var provides deterministic non-interactive control.

**Independent Test**: Run with `DEMO_USE_BAKED=1` (boxes present → boots silently; no boxes → error). Run with `DEMO_USE_BAKED=0` (boxes present → provisions from scratch silently, no auto-bake prompt).

**Depends on**: User Story 2 (prompt logic already in place)

### Implementation for User Story 4

- [X] T020 [US4] Implement `DEMO_USE_BAKED=1` logic in `demo/scripts/demo-setup.sh`: skip all prompts, force baked-box boot; if no boxes exist, exit with error message: "No baked boxes found. Run './demo/scripts/demo-bake.sh' after a successful provision to create them."
- [X] T021 [US4] Implement `DEMO_USE_BAKED=0` logic in `demo/scripts/demo-setup.sh`: skip all prompts, force fresh provisioning, suppress auto-bake prompt after provision (FR-017 suppression), ignore available boxes entirely

**Checkpoint**: `DEMO_USE_BAKED=1 ./demo/scripts/demo-setup.sh` and `DEMO_USE_BAKED=0 ./demo/scripts/demo-setup.sh` both behave deterministically without prompts.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, compatibility validation, edge case handling

- [X] T022 Verify `demo/scripts/demo-reset.sh` works correctly with clusters booted from baked boxes: confirm `vagrant snapshot pop baseline` and `vagrant snapshot push baseline` function identically to fresh-provisioned clusters
- [X] T023 [P] Run quickstart.md validation: execute Workflow A (first-time bake), Workflow B (fast demo start), and Workflow D (non-interactive) from `specs/009-vagrant-prebaked-boxes/quickstart.md` and document results
- [X] T024 [P] Add QEMU best-effort limitations documentation to `demo/README.md`: document that QEMU baking uses raw disk export (not native `vagrant package`), may have larger box files, and requires `qemu-img` and `jq` as additional prerequisites

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational — can start after T004-T005
- **User Story 2 (Phase 4)**: Depends on Foundational AND User Story 1 — needs baked boxes to test boot
- **User Story 3 (Phase 5)**: Depends on User Story 1 + User Story 2 — uses both bake and boot
- **User Story 4 (Phase 6)**: Depends on User Story 2 — refines prompt/override logic
- **Polish (Phase 7)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational (Phase 2) — No dependencies on other stories
- **User Story 2 (P1)**: Depends on User Story 1 (needs baked boxes to exist for testing boot flow)
- **User Story 3 (P2)**: Depends on User Story 1 + 2 (uses bake and boot in sequence)
- **User Story 4 (P3)**: Depends on User Story 2 (adds override logic to existing prompt flow)

### Parallel Opportunities

- All Phase 1 tasks (T001, T002, T003) can run in parallel
- Phase 2 tasks T004 and T005 touch different files — could run in parallel but T005 (helper lib) should complete first since T004 (Vagrantfile) is simpler
- Within US1: T010 and T011 (list and delete) can run in parallel after T009 (manifest/rotation)
- T022, T023, T024 (Polish) can all run in parallel

---

## Parallel Example: User Story 1

```bash
# After Foundational phase complete:

# Sequential (core packaging must be built first):
Task T006: "Create demo-bake.sh argument parsing"
Task T007: "Implement verify_cluster_running()"
Task T008: "Implement package_vm() with provider branching"
Task T009: "Implement bake_all() with rotation"

# Then in parallel (independent operations on same file, different functions):
Task T010: "Implement list_sets()"      # reads manifest only
Task T011: "Implement delete operations" # deletes from manifest

# Then:
Task T012: "Add interrupt/cleanup handler"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T005)
3. Complete Phase 3: User Story 1 (T006-T012)
4. **STOP and VALIDATE**: Bake a cluster, verify 4 `.box` files and valid manifest
5. This alone delivers value: boxes are ready for manual use even before US2

### Incremental Delivery

1. Setup + Foundational → Infrastructure ready
2. User Story 1 → Can bake boxes → **Validate independently**
3. User Story 2 → Can boot from baked boxes in < 5 min → **Validate independently**
4. User Story 3 → Single-command refresh cycle → **Validate independently**
5. User Story 4 → CI/automation support → **Validate independently**
6. Polish → Documentation and compatibility validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- US1 and US2 are both P1 but must be sequential (need boxes before you can boot from them)
- US3 and US4 can theoretically run in parallel since they modify different files
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All scripts should follow existing patterns in `demo/scripts/demo-setup.sh` (error codes, logging, provider detection)
