# Feature Specification: Cloud Snapshot Demo Lifecycle

**Feature Branch**: `008-cloud-snapshot-lifecycle`
**Created**: 2026-02-27
**Status**: Draft
**Input**: Add snapshot-based cloud demo lifecycle management to the existing Hetzner Cloud infrastructure, enabling near-instant demo readiness by restoring from pre-built snapshots instead of provisioning from scratch

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Warm Start a Demo Cluster from Snapshots (Priority: P1)

As a presenter preparing for a stakeholder meeting, I need to bring up a fully-provisioned CUI demo cluster in under 5 minutes so that I can demonstrate compliance capabilities without a 25-minute cold-start delay.

**Why this priority**: This is the core value proposition. The entire feature exists to eliminate the provisioning bottleneck that prevents practical demos. Without fast cluster restore, no other functionality in this feature matters.

**Independent Test**: Can be fully tested by having a snapshot set available (from a previous cold build) and running the warm-start command. Verify all 4 VMs are accessible, all services are running, and demo scenarios execute successfully.

**Acceptance Scenarios**:

1. **Given** a snapshot set exists from a previous cluster build, **When** I run the warm-start command, **Then** 4 VMs are created from snapshots with the same server types as the original cluster (mgmt01: cpx21, others: cpx11)
2. **Given** VMs are created from snapshots, **When** the warm-start completes, **Then** all nodes are attached to a private network with the same IP assignments (mgmt01: 10.0.0.10, login01: 10.0.0.20, compute01: 10.0.0.31, compute02: 10.0.0.32)
3. **Given** the cluster is restored, **When** I check service health, **Then** FreeIPA, Slurm, Wazuh, NFS, Munge, and chronyd are all running on their respective nodes
4. **Given** the cluster is restored, **When** I run any existing demo scenario (A, B, C, or D), **Then** the scenario executes identically to a cold-provisioned cluster
5. **Given** no snapshot set exists, **When** I run the warm-start command, **Then** I see a clear message directing me to build a cluster first and create snapshots

---

### User Story 2 - Create Snapshot Set from Running Cluster (Priority: P1)

As a presenter who has just completed a successful cold-build provisioning, I need to snapshot the entire cluster so that future demos can start in minutes instead of waiting for full provisioning.

**Why this priority**: Equal to warm-start. Without the ability to create snapshots, there is nothing to restore from. This is the "plant the seed" step that enables all future fast starts.

**Independent Test**: Can be fully tested by running demo-cloud-up.sh to completion, then creating snapshots, and verifying the snapshot set is listed and contains metadata for all 4 VMs.

**Acceptance Scenarios**:

1. **Given** a running, fully-provisioned cluster, **When** I run the snapshot command, **Then** all 4 VMs are snapshotted via the cloud API
2. **Given** snapshots are being created, **When** the process runs, **Then** I see progress output showing each VM being snapshotted with its name and status
3. **Given** snapshots are complete, **When** I list available snapshot sets, **Then** I see the new set with creation date, VM names, and snapshot identifiers
4. **Given** a successful cold-build via demo-cloud-up.sh, **When** provisioning completes, **Then** I am prompted with the option to snapshot the cluster for future fast starts
5. **Given** I have multiple snapshot sets, **When** I list them, **Then** they are displayed chronologically with identifying labels

---

### User Story 3 - Health Check a Running Cluster (Priority: P1)

As a presenter about to start a demo, I need to verify that all critical services are operational so that I can confidently begin my presentation without surprises.

**Why this priority**: A restored cluster is only useful if services actually came back correctly. The health check is the trust layer that confirms readiness. It runs automatically during warm-start but must also be available independently.

**Independent Test**: Can be tested by running the health check against any running cluster (cold-built or restored) and verifying it produces a clear pass/fail summary.

**Acceptance Scenarios**:

1. **Given** a running cluster, **When** I run the health check, **Then** I see a summary table showing pass/fail status for each service on each node
2. **Given** all services are healthy, **When** the health check completes, **Then** it exits with code 0 and displays an all-clear message
3. **Given** one or more services are down, **When** the health check completes, **Then** it exits with a non-zero code and clearly identifies which services on which nodes have failed
4. **Given** a warm-start has just completed, **When** the warm-start process finishes, **Then** the health check runs automatically as a final verification step

---

### User Story 4 - Graceful Session Wind-Down (Priority: P2)

As a presenter who has finished a demo session, I need to cleanly shut down the cluster with the option to preserve current state before teardown so that demo artifacts are not lost and billing stops promptly.

**Why this priority**: Important for cost management and data preservation, but secondary to the core warm-start/snapshot workflow. Users can always use the existing demo-cloud-down.sh as a fallback.

**Independent Test**: Can be tested by running the wind-down command on a running cluster, optionally choosing to snapshot first, and verifying all resources are destroyed and cost summary is displayed.

**Acceptance Scenarios**:

1. **Given** a running cluster, **When** I run the wind-down command, **Then** I am asked whether to snapshot current state before teardown
2. **Given** I choose to snapshot before teardown, **When** teardown proceeds, **Then** a snapshot set is created before resources are destroyed
3. **Given** I choose not to snapshot, **When** teardown proceeds, **Then** resources are destroyed immediately (with confirmation)
4. **Given** teardown completes, **When** the process finishes, **Then** I see session duration and estimated cost for the session

---

### User Story 5 - Manage Snapshot Sets (Priority: P2)

As a user managing cloud costs, I need to list and delete old snapshot sets so that I do not accumulate storage charges for outdated snapshots.

**Why this priority**: Housekeeping capability that prevents cost creep. Not needed for initial demo workflows but becomes important over time.

**Independent Test**: Can be tested by creating multiple snapshot sets, listing them, deleting one, and verifying it no longer appears in the list.

**Acceptance Scenarios**:

1. **Given** multiple snapshot sets exist, **When** I list them, **Then** I see each set with creation date, label, and number of snapshots
2. **Given** I identify an old snapshot set, **When** I delete it, **Then** all snapshots in the set are removed from the cloud provider
3. **Given** I delete a snapshot set, **When** I list remaining sets, **Then** the deleted set no longer appears

---

### Edge Cases

- What happens when a snapshot restore fails partway through (e.g., 2 of 4 VMs created)? System provides cleanup guidance and exits with error, leaving partial resources tagged for identification.
- What happens when the cloud provider's snapshot API is temporarily unavailable? System retries with backoff and reports the specific API error.
- What happens when a restored cluster's services fail to start (e.g., FreeIPA fails after IP reassignment)? Health check catches and reports the failures; system suggests re-creating snapshots from a fresh build.
- What happens when snapshot storage quota is exceeded? System displays quota error and suggests deleting old snapshot sets.
- What happens when the warm-start command is run while a cluster already exists? System blocks the operation and warns the user to tear down the existing cluster first.
- What happens when the private network IP range is already in use by another Hetzner resource? System reports the conflict and suggests teardown of the conflicting resource.

## Requirements *(mandatory)*

### Functional Requirements

**Snapshot Creation**

- **FR-001**: System MUST snapshot all 4 VMs (mgmt01, login01, compute01, compute02) as an atomic set via the cloud provider's snapshot API. Before creating snapshots, the system MUST stop critical services (FreeIPA, Slurm, Wazuh, Munge) on each node to ensure database and state file consistency, then restart them after snapshot completion
- **FR-002**: System MUST label each snapshot with a set identifier (format: rcd-demo-YYYYMMDD-NN, where NN is a two-digit sequence number starting at 01, incrementing for multiple sets created on the same day), VM name, node role, and cluster metadata
- **FR-003**: System MUST store snapshot set metadata (snapshot IDs, creation date, source cluster state, VM-to-snapshot mapping) in a local manifest file for later restore
- **FR-004**: System MUST verify that the source cluster is fully provisioned and services are running before creating snapshots
- **FR-005**: System MUST prompt users to create snapshots upon successful completion of a cold-build provisioning

**Snapshot Restore (Warm Start)**

- **FR-006**: System MUST create new VMs from the most recent snapshot set, using the same server types as the original cluster
- **FR-007**: System MUST create a new private network and attach all restored VMs with the same IP assignments as the original cluster (10.0.0.10, 10.0.0.20, 10.0.0.31, 10.0.0.32)
- **FR-008**: System MUST generate a fresh Ansible inventory file compatible with the existing demo playbook inventory format
- **FR-009**: System MUST run the health check automatically after restore to verify all services are operational
- **FR-010**: System MUST block warm-start if an existing cluster is detected
- **FR-011**: System MUST block warm-start and display guidance if no snapshot sets exist

**Health Check**

- **FR-012**: System MUST verify the following services on mgmt01: FreeIPA server, slurmctld, wazuh-manager, NFS exports, munge, chronyd
- **FR-013**: System MUST verify the following services on login01: FreeIPA client enrollment (sssd.service), munge, wazuh-agent, NFS mount, chronyd
- **FR-014**: System MUST verify the following services on compute nodes: FreeIPA client enrollment (sssd.service), slurmd, munge, wazuh-agent, NFS mount, chronyd
- **FR-015**: System MUST output a structured pass/fail summary table showing each node and service status
- **FR-016**: System MUST exit with non-zero status if any service check fails
- **FR-016a**: When a service check fails, system MUST attempt one automatic restart of the failed service and re-check before reporting failure. If the service remains down after the restart attempt, report it as failed

**Session Wind-Down**

- **FR-017**: System MUST offer to snapshot the current cluster state before teardown
- **FR-018**: System MUST destroy all cloud resources (VMs, networks, SSH keys) using the same mechanism as the existing teardown
- **FR-019**: System MUST report session duration and estimated cost upon completion

**Snapshot Management**

- **FR-020**: System MUST support listing all available snapshot sets with creation date and label
- **FR-021**: System MUST support deleting a specific snapshot set by label, removing all associated snapshots from the cloud provider
- **FR-022**: System MUST confirm before deleting snapshot sets

**Integration**

- **FR-023**: System MUST provide Makefile targets: demo-warm, demo-cool, demo-snapshot, demo-health
- **FR-024**: System MUST work inside the existing Docker container (rcd-demo-infra image) and also natively when required CLI tools are installed locally
- **FR-025**: System MUST respect existing TTL safety checks when operating on restored clusters
- **FR-026**: System MUST NOT modify existing demo scenarios or playbooks; restored clusters MUST be compatible with existing demo workflows without changes

### Key Entities

- **SnapshotSet**: A labeled group of VM snapshots representing a complete cluster state; contains set label, creation timestamp, source cluster metadata, and individual snapshot references
- **SnapshotManifest**: Local file storing snapshot set metadata; maps set labels to cloud snapshot IDs, VM names, server types, and private IP assignments
- **ServiceHealthReport**: Result of a health check run; contains per-node, per-service pass/fail status and an overall cluster readiness assessment
- **DemoSession**: Runtime state (not persisted) representing a warm-started cluster instance; tracked via Hetzner server labels and computed on-demand during wind-down (session duration, estimated cost)

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A cluster restored from snapshots is fully operational (all services healthy, all demo scenarios runnable) in under 5 minutes from command invocation
- **SC-002**: Snapshot creation for a 4-node cluster completes in under 10 minutes
- **SC-003**: Health check completes in under 60 seconds and correctly identifies all service failures
- **SC-004**: All 4 existing demo scenarios (A, B, C, D) execute successfully on a snapshot-restored cluster without any playbook modifications
- **SC-005**: Session wind-down destroys all resources with zero orphaned cloud resources
- **SC-006**: Snapshot set listing and deletion operations complete in under 30 seconds
- **SC-007**: The end-to-end workflow (warm-start, run demo scenario B, wind-down) completes in under 15 minutes total

## Scope

### In Scope

- Hetzner Cloud snapshot create/restore/delete operations via hcloud CLI
- Local snapshot manifest file management
- Health check script for all critical cluster services
- Warm-start and wind-down scripts
- Integration with existing Makefile, Docker wrapper, and TTL checks
- Prompt to snapshot after successful cold-build

### Out of Scope

- Changes to the Vagrant demo lab (separate feature)
- Changes to existing demo scenarios or playbooks
- CI/CD pipeline for automated reproducibility testing (separate feature)
- Multi-region or multi-provider snapshot support
- Incremental or differential snapshots
- Automatic snapshot rotation or expiry policies
- Snapshot transfer between Hetzner Cloud projects

## Assumptions

- Users have an active Hetzner Cloud account with snapshot creation permissions
- The hcloud CLI is available (installed locally or in the Docker container)
- Hetzner Cloud snapshot API preserves full disk state including running service configurations
- FreeIPA, Slurm, Wazuh, NFS, and Munge services resume correctly after a VM is restored from snapshot and assigned to the same private IP
- Snapshot storage costs are acceptable to users (Hetzner charges per GB/month for snapshots)
- The Docker container image (rcd-demo-infra) already includes the hcloud CLI
- A cold-build provisioning (demo-cloud-up.sh) has been completed at least once before snapshot workflows can be used

## Dependencies

- **Spec 007 (Cloud Demo Infrastructure)**: Provides demo-cloud-up.sh, demo-cloud-down.sh, check-ttl.sh, Terraform configuration, Docker wrapper, and Ansible provisioning playbook that this feature extends
- **Spec 006 (Vagrant Demo Lab)**: Provides demo scenarios (A, B, C, D) and playbooks that must work unchanged on snapshot-restored clusters
- **Hetzner Cloud Snapshot API**: Required for creating and restoring VM snapshots (external dependency)
- **hcloud CLI**: Required for snapshot operations (bundled in Docker container)

## Clarifications

### Session 2026-02-27

- Q: Should VMs be shut down, have services stopped, or be snapshotted live? → A: Stop critical services (FreeIPA, Slurm, Wazuh, Munge) before snapshot to protect database consistency; VMs stay running; services restart after snapshot completion
- Q: How should snapshot set label uniqueness be handled for multiple sets on the same day? → A: Append a two-digit sequence suffix (rcd-demo-YYYYMMDD-01, rcd-demo-YYYYMMDD-02)
- Q: Should the health check attempt automatic remediation of failed services or only report? → A: One automatic restart attempt per failed service, then report if still failing
