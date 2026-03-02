# Tasks: Cloud Snapshot Demo Lifecycle

**Input**: Design documents from `/specs/008-cloud-snapshot-lifecycle/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: No test tasks generated (manual end-to-end testing against live Hetzner Cloud; follows existing project pattern for infrastructure scripts).

**Organization**: Tasks are grouped by user story. Note that the implementation order differs from spec priority order because US3 (Health Check) is a foundational dependency for US1 (Warm Start) and US2 (Snapshot Create).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, Makefile targets, gitignore updates, and script skeletons

- [X] T001 Add snapshot-manifest.json to .gitignore in .gitignore
- [X] T002 [P] Add Makefile targets (demo-warm, demo-cool, demo-snapshot, demo-health) using $(DEMO_DOCKER) wrapper pattern in Makefile
- [X] T003 [P] Create empty executable script shells with standard headers (set -euo pipefail, SCRIPT_DIR/REPO_ROOT/TF_DIR path resolution, .env sourcing, info/warn/error functions) for all four new scripts: infra/scripts/demo-cloud-snapshot.sh, infra/scripts/demo-cloud-warm.sh, infra/scripts/demo-cloud-cool.sh, infra/scripts/demo-cloud-health.sh

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Post-restore playbook and shared helper patterns that MUST be complete before user story scripts

**CRITICAL**: US1 (Warm Start) depends on the post-restore playbook and inventory generation. Build these first.

- [X] T004 Create post-restore Ansible playbook that fixes FQDN hostnames ({{ inventory_hostname }}.demo.lab), verifies /etc/hosts private IP entries, and restarts hostname-dependent services (ipa/sssd, slurmctld/slurmd) in demo/playbooks/post-restore.yml
- [X] T005 [P] Add require_command validation function for hcloud, jq, and ssh prerequisites; add cluster_exists detection function that checks both hcloud server labels (--selector "cluster=rcd-demo") and Terraform state; add detect_ssh_key function (reuse hierarchy from demo-cloud-up.sh); add these to each script's function section in infra/scripts/demo-cloud-snapshot.sh, infra/scripts/demo-cloud-warm.sh, infra/scripts/demo-cloud-cool.sh, infra/scripts/demo-cloud-health.sh
- [X] T006 [P] Add generate_inventory function that writes Ansible inventory YAML (matching infra/terraform/inventory.tpl format) from hcloud server data (public IPs from API, private IPs from labels, SSH key path adapting for Docker vs native context) to infra/terraform/inventory.yml; implement in infra/scripts/demo-cloud-warm.sh

**Checkpoint**: Foundation ready — user story implementation can begin

---

## Phase 3: User Story 3 — Health Check a Running Cluster (Priority: P1)

**Goal**: Standalone health check script that SSHs into each node, verifies critical services, attempts auto-remediation on failure, and outputs a structured pass/fail summary table.

**Independent Test**: Run `make demo-health` against any running cluster (cold-built or snapshot-restored) and verify the summary table shows pass/fail for every service on every node. Exit code 0 when all pass, non-zero when any fail.

### Implementation for User Story 3

- [X] T007 [US3] Implement inventory parsing function that reads infra/terraform/inventory.yml, extracts node names, ansible_host IPs, node_role, and SSH key path using awk/grep (no Python dependency) in infra/scripts/demo-cloud-health.sh
- [X] T008 [US3] Implement per-node service check function that SSHs into a node and runs systemctl is-active for each required service (mgmt01: ipa.service, slurmctld.service, wazuh-manager.service, nfs-server.service, munge.service, chronyd.service; login01: sssd.service, munge.service, wazuh-agent.service, chronyd.service; compute nodes: sssd.service, slurmd.service, munge.service, wazuh-agent.service, chronyd.service) in infra/scripts/demo-cloud-health.sh
- [X] T009 [US3] Implement mount and enrollment checks: verify /shared is mounted (mountpoint -q /shared) on login/compute nodes, verify /shared is exported (exportfs -v) on mgmt01, verify FreeIPA client enrollment (ipa-client-install --is-installed or realm list) on login/compute nodes, verify FreeIPA server status (ipactl status) on mgmt01 in infra/scripts/demo-cloud-health.sh
- [X] T010 [US3] Implement auto-remediation logic: on service check failure, attempt one systemctl restart of the failed service, wait 5 seconds, re-check; track whether remediation was attempted and whether it succeeded in infra/scripts/demo-cloud-health.sh
- [X] T011 [US3] Implement summary table output: display Node/Service/Status columns with pass (✓) and FAIL (✗) markers, show "(restarted)" for remediated services, display total pass/fail count at bottom; implement --json flag for JSON output; set exit code 0 for all pass, 1 for any fail, 3 for SSH unreachable in infra/scripts/demo-cloud-health.sh
- [X] T012 [US3] Implement --inventory flag for custom inventory path (default: infra/terraform/inventory.yml) and argument parsing (--inventory, --json, --help) in infra/scripts/demo-cloud-health.sh

**Checkpoint**: `make demo-health` works against any running cluster, reports per-service status, auto-remediates transient failures

---

## Phase 4: User Story 2 — Create Snapshot Set from Running Cluster (Priority: P1)

**Goal**: Snapshot all 4 VMs as a labeled set with service stop/restart for consistency, write metadata to local manifest file.

**Independent Test**: After `make demo-cloud-up`, run `make demo-snapshot`. Verify 4 snapshots appear in Hetzner console with correct labels. Verify snapshot-manifest.json contains the new set entry.

### Implementation for User Story 2

- [X] T013 [US2] Implement set label generation function: format rcd-demo-YYYYMMDD-NN where NN auto-increments by querying existing snapshot labels via hcloud image list --type snapshot --selector "cluster=rcd-demo" -o json and local manifest in infra/scripts/demo-cloud-snapshot.sh
- [X] T014 [US2] Implement service stop function: SSH into each node and stop services in reverse dependency order (slurmd/slurmctld → wazuh-agent/wazuh-manager → NFS unmount clients/stop server → munge → sssd/ipa); implement corresponding service restart function in forward dependency order (ipa/sssd → munge → NFS server/mount clients → wazuh-manager/wazuh-agent → slurmctld/slurmd) in infra/scripts/demo-cloud-snapshot.sh
- [X] T015 [US2] Implement snapshot creation loop: for each VM (discovered via hcloud server list --selector "cluster=rcd-demo" -o json), run hcloud server create-image --type snapshot with labels (cluster, snapshot-set, node-name, node-role, server-type, private-ip); capture snapshot IDs from JSON output; display progress per VM in infra/scripts/demo-cloud-snapshot.sh
- [X] T016 [US2] Implement manifest file management: read/create/update infra/terraform/snapshot-manifest.json using jq; add new snapshot set entry with created_at timestamp, source_cluster, source_commit (from git rev-parse --short HEAD), and per-snapshot metadata (snapshot_id, node_name, node_role, server_type, private_ip); validate schema per data-model.md in infra/scripts/demo-cloud-snapshot.sh
- [X] T017 [US2] Implement default create mode main flow: validate prerequisites → run health check (call demo-cloud-health.sh) → stop services → create snapshots → restart services → update manifest → display summary with storage cost estimate; handle partial failure (label incomplete sets for cleanup); handle API errors with retry (1 retry after 10-second wait) and quota exceeded errors with actionable message suggesting --delete of old sets in infra/scripts/demo-cloud-snapshot.sh
- [X] T018 [US2] Implement argument parsing for demo-cloud-snapshot.sh: no args = create mode, --list = list mode (placeholder), --delete = delete mode (placeholder), --help = usage; wire up create mode as default in infra/scripts/demo-cloud-snapshot.sh

**Checkpoint**: `make demo-snapshot` creates a labeled snapshot set from a running cluster, services stop/restart cleanly, manifest file is written

---

## Phase 5: User Story 1 — Warm Start a Demo Cluster from Snapshots (Priority: P1) MVP

**Goal**: Restore a complete 4-node cluster from snapshots in under 5 minutes with network configuration, hostname fixup, and health verification.

**Independent Test**: With a snapshot set available, run `make demo-warm`. Verify 4 VMs created, private network configured with correct IPs, health check passes, and existing demo scenarios run unchanged.

### Implementation for User Story 1

- [X] T019 [US1] Implement snapshot set loading function: read most recent set from infra/terraform/snapshot-manifest.json using jq; support --set flag for specific set selection; validate set exists and contains 4 snapshots; exit with guidance if no sets exist in infra/scripts/demo-cloud-warm.sh
- [X] T020 [US1] Implement cluster existence check: query hcloud server list --selector "cluster=rcd-demo" and Terraform state (terraform state list); block warm-start with error if any cluster resources exist; suggest teardown command in infra/scripts/demo-cloud-warm.sh
- [X] T021 [US1] Implement SSH key upload: detect SSH key (reuse hierarchy from demo-cloud-up.sh), upload to Hetzner via hcloud ssh-key create with cluster=rcd-demo label in infra/scripts/demo-cloud-warm.sh
- [X] T022 [US1] Implement network creation: create private network via hcloud network create (10.0.0.0/8, cluster=rcd-demo label), create subnet via hcloud network subnet add (10.0.0.0/24, us-west zone) in infra/scripts/demo-cloud-warm.sh
- [X] T023 [US1] Implement server creation from snapshots: for each snapshot in set, run hcloud server create --name <node-name> --type <server-type> --image <snapshot-id> --ssh-key <key> --network <network> --location hil with labels (cluster=rcd-demo, node-role, snapshot-set); handle server network attachment and verify private IP assignment via hcloud server attach-to-network with --ip flag in infra/scripts/demo-cloud-warm.sh
- [X] T024 [US1] Implement SSH wait loop: poll each node's public IP (from hcloud server describe -o json) with ssh -o ConnectTimeout=5 until all 4 nodes respond, with 300-second overall timeout in infra/scripts/demo-cloud-warm.sh
- [X] T025 [US1] Implement post-restore integration: generate inventory file (call generate_inventory function from T006), run ansible-playbook -i inventory.yml demo/playbooks/post-restore.yml with ANSIBLE_HOST_KEY_CHECKING=False, run health check (call demo-cloud-health.sh) in infra/scripts/demo-cloud-warm.sh
- [X] T026 [US1] Implement main flow and output: validate prerequisites → check no existing cluster → load snapshot set → detect SSH key → create SSH key + network → create servers → wait for SSH → run post-restore → generate inventory → run health check → display connection info (SSH commands for mgmt01/login01) and cost estimate; handle partial restore failure (tag partial resources with cluster=rcd-demo for cleanup, display teardown guidance); handle network IP conflict by checking for existing 10.0.0.0/24 networks before creation in infra/scripts/demo-cloud-warm.sh
- [X] T027 [US1] Implement --set argument parsing and --help usage output in infra/scripts/demo-cloud-warm.sh

**Checkpoint**: `make demo-warm` restores a full cluster from snapshots in under 5 minutes. Health check passes. Demo scenarios A-D run unchanged on the restored cluster.

---

## Phase 6: User Story 4 — Graceful Session Wind-Down (Priority: P2)

**Goal**: Clean shutdown with optional pre-teardown snapshot, label-based resource destruction, session cost reporting.

**Independent Test**: With a running cluster, run `make demo-cool`. Verify snapshot prompt appears, teardown destroys all resources (zero orphans in Hetzner console), session summary displays duration and cost.

### Implementation for User Story 4

- [X] T028 [US4] Implement label-based resource discovery and teardown: query hcloud server/network/ssh-key list --selector "cluster=rcd-demo" -o json; display resource count summary; delete servers first, then networks, then SSH keys (dependency order); handle missing resources gracefully in infra/scripts/demo-cloud-cool.sh
- [X] T029 [US4] Implement session tracking: read cluster creation timestamp from hcloud server labels (created_at) or server creation time; calculate elapsed duration; compute estimated cost using total cluster rate ~EUR 0.03/hour (cpx21 + 3×cpx11, billed per minute); format as "Xh Ym" and "EUR X.XX" in infra/scripts/demo-cloud-cool.sh
- [X] T030 [US4] Implement main flow: verify cluster exists → display session info (duration, cost) → prompt for snapshot (unless --no-snapshot flag) → if yes call demo-cloud-snapshot.sh → confirm teardown → delete resources → display final session summary in infra/scripts/demo-cloud-cool.sh
- [X] T031 [US4] Implement --no-snapshot flag parsing and --help usage output in infra/scripts/demo-cloud-cool.sh

**Checkpoint**: `make demo-cool` cleanly winds down a session with optional snapshot and cost summary

---

## Phase 7: User Story 5 — Manage Snapshot Sets (Priority: P2)

**Goal**: List available snapshot sets with metadata and delete old sets to control costs.

**Independent Test**: Create multiple snapshot sets, run `demo-cloud-snapshot.sh --list` to verify tabular output, run `demo-cloud-snapshot.sh --delete <label>` to verify removal from both Hetzner and manifest.

### Implementation for User Story 5

- [X] T032 [US5] Implement --list mode: query hcloud image list --type snapshot --selector "cluster=rcd-demo" -o json; group by snapshot-set label; display table with columns: Set Label, Created, Snapshots (count/4), Est. Storage; sort newest first; also cross-reference with local manifest in infra/scripts/demo-cloud-snapshot.sh
- [X] T033 [US5] Implement --delete mode: validate set label exists (check both hcloud API and manifest); prompt for confirmation; delete all 4 snapshots via hcloud image delete; remove set entry from manifest file; display confirmation in infra/scripts/demo-cloud-snapshot.sh

**Checkpoint**: Snapshot lifecycle is fully manageable — create, list, delete all work

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Integration with existing cold-build workflow, end-to-end validation

- [X] T034 Add snapshot prompt to demo-cloud-up.sh: after successful Ansible provisioning (exit code 0), prompt "Snapshot this cluster for future fast starts? [Y/n]" and call demo-cloud-snapshot.sh if accepted in infra/scripts/demo-cloud-up.sh
- [X] T035 [P] Verify TTL compatibility: confirm check-ttl.sh --status and --warn work correctly against a snapshot-restored cluster (label-based detection via hcloud server list --selector) without Terraform state in infra/scripts/check-ttl.sh
- [ ] T036 [P] Validate end-to-end workflow: run make demo-cloud-up → make demo-snapshot → make demo-cloud-down → make demo-warm → make demo-health → run all 4 demo scenarios (scenario-a-onboarding.yml, scenario-b-drift.yml, scenario-c-audit.yml, scenario-d-offboarding.yml) → make demo-cool; verify all steps complete successfully, all scenarios pass unchanged, and all resources are cleaned up (validates SC-004)
- [ ] T037 Verify all scripts work inside Docker container (make demo-warm, make demo-cool, make demo-snapshot, make demo-health) and also natively when hcloud/terraform/ansible are installed locally

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion — BLOCKS all user stories
- **US3 - Health Check (Phase 3)**: Depends on Foundational — no user story dependencies
- **US2 - Snapshot Create (Phase 4)**: Depends on US3 (runs health check before snapshotting)
- **US1 - Warm Start (Phase 5)**: Depends on US2 (needs snapshot sets) and US3 (runs health check after restore)
- **US4 - Wind-Down (Phase 6)**: Depends on US2 (optional snapshot before teardown)
- **US5 - Manage Snapshots (Phase 7)**: Depends on US2 (extends same script with list/delete modes)
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

```
US3 (Health Check) ──┬──→ US2 (Snapshot Create) ──┬──→ US1 (Warm Start) ──→ US4 (Wind-Down)
                     │                             │
                     └─────────────────────────────┘
                                                   └──→ US5 (Manage Snapshots)
```

- **US3**: No story dependencies — implement first
- **US2**: Depends on US3 (health check runs before snapshot)
- **US1**: Depends on US2 (needs snapshots to restore from) and US3 (health check at end)
- **US4**: Depends on US2 (optional snapshot) — can start after US2
- **US5**: Depends on US2 (extends same script) — can start after US2, parallel with US4

### Within Each User Story

- Helper functions before main flow
- Argument parsing alongside main flow (parallel within script)
- Main flow integrates all components last

### Parallel Opportunities

Within Setup (Phase 1):
```
T002 (Makefile) + T003 (script shells) — different files, no dependencies
```

Within Foundational (Phase 2):
```
T005 (shared helpers) + T006 (inventory generator) — different functions, different scripts
```

Within US3 (Phase 3):
```
T007 (inventory parsing) + T008 (service checks) + T009 (mount/enrollment checks) — same file but independent functions
```

After US2 completes:
```
US1 (Warm Start) can proceed
US4 (Wind-Down) + US5 (Manage Snapshots) can proceed in parallel
```

---

## Implementation Strategy

### MVP First (Health Check + Snapshot Create + Warm Start)

1. Complete Phase 1: Setup (T001-T003)
2. Complete Phase 2: Foundational (T004-T006)
3. Complete Phase 3: US3 Health Check (T007-T012)
4. Complete Phase 4: US2 Snapshot Create (T013-T018)
5. Complete Phase 5: US1 Warm Start (T019-T027)
6. **STOP and VALIDATE**: Run end-to-end: `make demo-cloud-up` → `make demo-snapshot` → `make demo-cloud-down` → `make demo-warm` → `make demo-health`
7. This is the MVP — you can now demo from snapshots

### Incremental Delivery

1. Complete MVP (Phases 1-5) → Fast demos work
2. Add US4 Wind-Down (Phase 6) → Clean session lifecycle
3. Add US5 Manage Snapshots (Phase 7) → Cost housekeeping
4. Polish (Phase 8) → Integrated cold-build prompt, validation

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- All scripts MUST follow existing patterns: set -euo pipefail, info/warn/error functions, exit codes (0=success, 1=failure, 2=secondary failure, 3=prerequisites)
- All scripts MUST use printf (not echo) for output, consistent with existing scripts
- SSH commands MUST use -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null for ephemeral infrastructure
- jq MUST be used for all JSON parsing (available in Docker container)
- Commit after each phase completion
