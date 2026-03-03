# Feature Specification: Pre-Baked Vagrant Box Workflow

**Feature Branch**: `009-vagrant-prebaked-boxes`
**Created**: 2026-03-02
**Status**: Draft
**Input**: User description: "Add pre-baked Vagrant box support to the local demo lab (spec 006) for fast cluster boot from reusable packaged boxes."

## Clarifications

### Session 2026-03-02

- Q: What level of QEMU provider support is required for baking/booting boxes? → A: VirtualBox and libvirt are first-class (native `vagrant package`); QEMU uses raw disk image export as a best-effort workaround with documented limitations.
- Q: Should the system retain multiple box sets or just the latest? → A: Keep up to 2 sets (current + previous) with automatic rotation. The previous set is preserved as a rollback safety net until replaced by the next bake.
- Q: Should demo-setup.sh prompt to bake after a successful fresh provision? → A: Yes, prompt "Bake this cluster for future fast starts?" after fresh provision (skippable, suppressed when DEMO_USE_BAKED=0). Consistent with cloud snapshot workflow (008).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Package a Provisioned Cluster as Reusable Boxes (Priority: P1)

A demo operator has just completed a full `demo-setup.sh` run, which took 20-30 minutes. They want to capture the fully provisioned state of all four VMs (mgmt01, login01, compute01, compute02) as reusable Vagrant boxes so that future demo sessions can skip the lengthy provisioning step entirely.

The operator runs `demo-bake.sh`, which packages each VM into a named Vagrant box, stores them locally, and records metadata (creation date, source commit, provider) in a manifest file. The operator can later list available baked box sets or delete stale ones.

**Why this priority**: This is the foundational capability — without the ability to create baked boxes, nothing else in this feature works. It delivers immediate value by capturing a known-good cluster state for reuse.

**Independent Test**: Can be fully tested by running `demo-setup.sh` followed by `demo-bake.sh` and verifying that four box files are created with a valid manifest.

**Acceptance Scenarios**:

1. **Given** a fully provisioned and running demo cluster (all 4 VMs up with baseline services), **When** the operator runs `demo-bake.sh`, **Then** four named box files are created in the local box storage directory and a manifest file records creation date, source commit hash, and provider for each box.
2. **Given** one or more baked box sets exist, **When** the operator runs `demo-bake.sh --list`, **Then** a table of available box sets is displayed showing set name, creation date, provider, age, and source commit.
3. **Given** an older baked box set exists, **When** the operator runs `demo-bake.sh --delete <set-name>`, **Then** the specified box files and manifest entry are removed and disk space is reclaimed.
4. **Given** VMs are not all running or provisioning is incomplete, **When** the operator runs `demo-bake.sh`, **Then** the script exits with a clear error message explaining that a fully provisioned cluster is required.

---

### User Story 2 - Boot a Demo Cluster from Pre-Baked Boxes (Priority: P1)

A demo presenter needs a working CUI demo cluster ready in under 5 minutes. They have previously baked a box set. Instead of running the full 20-30 minute provisioning cycle, the existing `demo-setup.sh` detects the available baked boxes and offers to use them, skipping all Ansible provisioning.

**Why this priority**: This is the primary value proposition — reducing demo startup from 20-30 minutes to under 5 minutes. Co-equal with User Story 1 since baking without booting delivers no time savings.

**Independent Test**: Can be tested by booting from pre-baked boxes and verifying that all critical services (FreeIPA, Slurm, Wazuh, NFS, Munge) are operational and demo scenarios run successfully.

**Acceptance Scenarios**:

1. **Given** a recent baked box set exists (within the staleness threshold), **When** the operator runs `demo-setup.sh`, **Then** the script detects available boxes, prompts the user to choose between baked boxes or fresh provisioning, and when baked is selected, boots from the boxes without running Ansible provisioning.
2. **Given** baked boxes are used for boot, **When** all 4 VMs are running, **Then** FreeIPA (server on mgmt01, clients on others), Slurm (slurmctld on mgmt01, slurmd on compute nodes), Wazuh (manager on mgmt01, agents on others), NFS (exports on mgmt01, mounts on others), Munge (all nodes), and Chronyd (all nodes) are all operational.
3. **Given** baked boxes are used for boot, **When** the operator runs any demo scenario (A through D), **Then** the scenario completes successfully with the same results as a fresh-provisioned cluster.
4. **Given** baked boxes exist but are older than the staleness threshold (default: 7 days), **When** the operator runs `demo-setup.sh`, **Then** the script warns that boxes are stale and recommends refreshing, but still allows the user to proceed with stale boxes if desired.
5. **Given** no baked boxes exist, **When** the operator runs `demo-setup.sh`, **Then** the script proceeds with normal from-scratch provisioning (current behavior unchanged).
6. **Given** a fresh provision completes successfully, **When** no `DEMO_USE_BAKED=0` is set, **Then** the script prompts "Bake this cluster for future fast starts?" and bakes if confirmed.

---

### User Story 3 - Rebuild Baked Boxes from Current Codebase (Priority: P2)

A developer has made changes to Ansible roles or provisioning playbooks and needs to create a fresh set of baked boxes that reflect the updated codebase. They run `demo-refresh.sh`, which destroys existing VMs, provisions from scratch, and automatically bakes the result into new boxes. This is the "prove reproducibility" workflow done periodically, not on every demo.

**Why this priority**: Important for keeping baked boxes current with code changes, but not needed for initial demo acceleration. Can be run on a schedule or after significant changes rather than every session.

**Independent Test**: Can be tested by modifying a provisioning playbook, running `demo-refresh.sh`, and verifying the resulting boxes reflect the code changes.

**Acceptance Scenarios**:

1. **Given** any cluster state (running, stopped, or no VMs), **When** the operator runs `demo-refresh.sh`, **Then** existing VMs are destroyed, a fresh cluster is provisioned from scratch using current playbooks, and the result is baked into a new box set.
2. **Given** a previous baked box set exists, **When** `demo-refresh.sh` completes, **Then** the old box set is replaced by the new one and the manifest is updated with the current commit hash and date.
3. **Given** provisioning fails during `demo-refresh.sh`, **When** the error occurs, **Then** the script reports the failure, preserves any previous baked box set (does not delete old boxes until new ones are confirmed), and exits with a non-zero status.

---

### User Story 4 - Override Baked Box Behavior via Environment Variable (Priority: P3)

An advanced user or CI system needs deterministic control over whether baked boxes are used, without interactive prompts. They set `DEMO_USE_BAKED=1` to force baked-box boot (failing if no boxes exist) or `DEMO_USE_BAKED=0` to force fresh provisioning regardless of box availability.

**Why this priority**: Supports automation and CI integration but is not required for interactive demo workflows.

**Independent Test**: Can be tested by running `demo-setup.sh` with `DEMO_USE_BAKED=1` and `DEMO_USE_BAKED=0` and verifying the expected behavior in each case.

**Acceptance Scenarios**:

1. **Given** baked boxes exist, **When** `DEMO_USE_BAKED=1` is set and `demo-setup.sh` is run, **Then** baked boxes are used without prompting.
2. **Given** no baked boxes exist, **When** `DEMO_USE_BAKED=1` is set and `demo-setup.sh` is run, **Then** the script exits with an error directing the user to run `demo-bake.sh` first.
3. **Given** baked boxes exist, **When** `DEMO_USE_BAKED=0` is set and `demo-setup.sh` is run, **Then** fresh provisioning runs without prompting, ignoring available boxes.

---

### Edge Cases

- What happens when baked boxes were created with a different Vagrant provider (e.g., VirtualBox) than the current host supports (e.g., QEMU on Apple Silicon)? The system must detect this mismatch and report a clear error rather than attempting to boot incompatible boxes.
- What happens when disk space is insufficient to store the baked boxes (4 VMs at potentially 2-5 GB each)? The script should check available disk space before baking and warn if below a reasonable threshold.
- What happens when the user interrupts `demo-bake.sh` mid-packaging? Partial box files should be cleaned up to avoid corrupted state.
- What happens when the Vagrant version or provider plugin version changes between bake and boot? The manifest should record version info, and the boot process should warn on mismatches.
- What happens when `demo-reset.sh` is run against a cluster booted from baked boxes? Snapshot-based reset should work identically since a baseline snapshot is created during `demo-setup.sh` regardless of boot method.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide a `demo-bake.sh` script that packages all four demo VMs (mgmt01, login01, compute01, compute02) into individual reusable box files.
- **FR-002**: The system MUST store baked boxes in a dedicated local directory (`demo/vagrant/boxes/`) that is excluded from version control.
- **FR-003**: The system MUST record box set metadata in a manifest file (`demo/vagrant/boxes/manifest.json`) including: creation date, source Git commit hash, Vagrant provider name, and box file names.
- **FR-004**: The system MUST retain at most 2 box sets (current and previous), automatically rotating out the oldest when a new set is baked. The system MUST support listing available sets via `demo-bake.sh --list` with age, provider, and commit information.
- **FR-005**: The system MUST support deleting box sets via `demo-bake.sh --delete <set-name>` (or `--delete-all` to remove both).
- **FR-006**: The system MUST modify `demo-setup.sh` to detect available baked boxes and offer to use them before provisioning from scratch.
- **FR-007**: When booting from baked boxes, the system MUST skip all Ansible provisioning and create a baseline snapshot for `demo-reset.sh` compatibility.
- **FR-017**: After a successful fresh provision, `demo-setup.sh` MUST prompt the user "Bake this cluster for future fast starts?" and invoke `demo-bake.sh` if confirmed. The prompt MUST be suppressed when `DEMO_USE_BAKED=0` is set.
- **FR-008**: The system MUST validate that all critical services are operational after booting from baked boxes (FreeIPA, Slurm, Wazuh, NFS, Munge, Chronyd).
- **FR-009**: The system MUST implement a configurable staleness threshold (default: 7 days) and warn users when baked boxes exceed it.
- **FR-010**: The system MUST provide a `demo-refresh.sh` script that destroys, reprovisions, and re-bakes in a single operation.
- **FR-011**: The system MUST support the `DEMO_USE_BAKED` environment variable for non-interactive control (`1` = force baked, `0` = force fresh).
- **FR-012**: The system MUST create baked boxes that are provider-specific and detect provider mismatches at boot time.
- **FR-013**: The system MUST provide first-class baking support for VirtualBox and libvirt (using native `vagrant package` or provider-equivalent). QEMU (vagrant-qemu) MUST be supported on a best-effort basis using raw disk image export, with documented limitations.
- **FR-014**: The system MUST clean up partial artifacts if baking is interrupted.
- **FR-015**: The system MUST add Makefile targets `demo-bake` and `demo-refresh` for workflow consistency with the existing cloud demo targets.
- **FR-016**: The system MUST update `.gitignore` to exclude baked box files and the boxes directory from version control.

### Key Entities

- **Baked Box Set**: A collection of four Vagrant box files representing a fully provisioned demo cluster at a specific point in time. Identified by a label (e.g., `rcd-demo-YYYYMMDD-NN`), associated with a Git commit and a Vagrant provider. At most 2 sets are retained (current + previous) with automatic rotation.
- **Box Manifest**: A structured record of all available baked box sets, their metadata, and file locations. Used by `demo-setup.sh` to discover and validate available boxes.
- **Staleness Threshold**: A configurable duration (default: 7 days) after which baked boxes are considered outdated and the user is warned to refresh them.

## Assumptions

- The existing `vagrant package` command (or provider-equivalent) is sufficient for capturing VM state including all installed services and configurations.
- Network configuration (IP addresses, hostnames) within baked boxes will remain valid when booted on the same host, since the Vagrantfile assigns the same static IPs on the same private network.
- Baked box files are stored locally only — there is no requirement for uploading to Vagrant Cloud or sharing between machines in this feature.
- The baseline snapshot created by `demo-setup.sh` after boot-from-baked-boxes will function identically to one created after fresh provisioning for `demo-reset.sh` purposes.
- Box file sizes will be manageable for local storage (estimated 2-5 GB per VM, 8-20 GB total per set, up to 40 GB with 2 retained sets).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A demo cluster booted from baked boxes is fully operational with all critical services running in under 5 minutes (compared to 20-30 minutes from scratch).
- **SC-002**: All four demo scenarios (A through D) pass identically whether the cluster was provisioned from scratch or booted from baked boxes.
- **SC-003**: The `demo-bake.sh` script completes packaging of all four VMs in under 15 minutes.
- **SC-004**: The `demo-refresh.sh` cycle (destroy + provision + bake) completes in under 45 minutes.
- **SC-005**: Baked box boot works without manual intervention on VirtualBox and libvirt (first-class), and on QEMU via best-effort disk image export with documented limitations.
- **SC-006**: A first-time user can go from "no cluster" to "running demo" in under 10 minutes when baked boxes are provided to them.
