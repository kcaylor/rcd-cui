# Feature Specification: HPC-Specific CUI Compliance Roles

**Feature Branch**: `004-hpc-cui-roles`
**Created**: 2026-02-15
**Status**: Draft
**Dependencies**: Specs 001 (Data Models), 002 (Core Ansible Roles), 003 (Compliance Assessment)

## Clarifications

### Session 2026-02-15

- Q: What happens when a job prolog script exceeds timeout waiting for authorization check? → A: Fail job with specific error message indicating retry is safe
- Q: How does container security handle multi-node MPI jobs that need inter-node communication? → A: Allow high-speed interconnect (InfiniBand) only between CUI partition nodes
- Q: How does offboarding handle active jobs from users being removed? → A: Allow active jobs to complete (up to 24-hour grace period), then revoke access
- Q: What happens when GPU memory reset fails (nvidia-smi command fails or hangs)? → A: Mark node unhealthy and drain from scheduler until manual remediation
- Q: How does the system handle quota exceeded conditions during active CUI processing? → A: Block new writes, alert user, preserve existing data and let job continue read-only

## Overview

This specification defines HPC-specific Ansible roles that integrate CUI compliance requirements with research computing operations. Unlike general-purpose server hardening, HPC environments have unique security challenges: batch job scheduling, container execution, high-performance interconnects, parallel filesystems, and researcher workflows that must continue functioning while maintaining compliance.

The roles bridge the gap between security requirements and research computing realities, providing automation that protects CUI data while enabling legitimate scientific work.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Slurm CUI Partition Operations (Priority: P1)

A researcher submits a job to process CUI data on the cluster. The system must verify authorization before execution begins, ensure memory is cleared after job completion, and generate audit evidence that the security controls worked correctly.

**Why this priority**: Job execution is the core function of an HPC cluster. Without secure job handling, no CUI work can occur. This is the foundational capability all other stories depend on.

**Independent Test**: Can be fully tested by submitting jobs to the CUI partition with authorized and unauthorized users, verifying prolog blocks unauthorized access, epilog clears memory, and audit logs capture all events.

**Acceptance Scenarios**:

1. **Given** a researcher with valid CUI training and group membership, **When** they submit a job to the CUI partition, **Then** the prolog validates their authorization, logs job start with CUI audit tags, and the job executes normally.
2. **Given** a researcher whose CUI training has expired, **When** they submit a job to the CUI partition, **Then** the prolog rejects the job with a clear message explaining the training requirement.
3. **Given** a completed CUI job on a GPU node, **When** the job ends, **Then** the epilog clears /dev/shm, /tmp, resets GPU memory, flushes audit logs, and verifies node health before accepting new jobs.
4. **Given** a running CUI job, **When** an auditor requests evidence, **Then** CUI-specific sacct fields provide job attribution details that integrate with evidence collection.

---

### User Story 2 - Container Security in CUI Enclave (Priority: P1)

A researcher needs to run containerized scientific software (Python/R environments, simulation codes) on CUI data. The container runtime must enforce signed images, restrict filesystem access to approved paths, block network egress, and log all container activity.

**Why this priority**: Containers are ubiquitous in research computing. Without container support, researchers cannot use standard scientific workflows, making the enclave impractical.

**Independent Test**: Can be fully tested by attempting to run signed/unsigned containers, accessing restricted paths, and attempting network connections, verifying each restriction works independently.

**Acceptance Scenarios**:

1. **Given** a researcher with a signed container image, **When** they execute it in the CUI enclave, **Then** the container runs with only CUI-approved bind mounts and no outbound network access.
2. **Given** a researcher with an unsigned container image, **When** they attempt to run it, **Then** execution is blocked with a clear error message explaining signature requirements.
3. **Given** a running container, **When** it attempts to access paths outside approved directories, **Then** the access is denied and logged.
4. **Given** any container execution, **When** it completes, **Then** an audit log entry captures the container image, user, execution time, and data paths accessed.

---

### User Story 3 - Parallel Filesystem Security (Priority: P1)

A system administrator needs to manage CUI project directories on the parallel filesystem with proper access controls, monitor file operations for audit purposes, enforce quotas, and sanitize data when projects complete.

**Why this priority**: CUI data resides on the parallel filesystem. Without proper filesystem controls, data protection cannot be enforced regardless of other security measures.

**Independent Test**: Can be fully tested by creating project directories, verifying ACLs match FreeIPA groups, triggering changelog events, testing quota enforcement, and running sanitization.

**Acceptance Scenarios**:

1. **Given** a new CUI project, **When** storage is provisioned, **Then** a project directory is created with ACLs matching the FreeIPA group, quota enforcement enabled, and changelog monitoring active.
2. **Given** a user not in the project's FreeIPA group, **When** they attempt to access the project directory, **Then** access is denied by ACLs.
3. **Given** file operations in a CUI directory, **When** an auditor needs evidence, **Then** changelog monitoring provides a record of file creation, modification, and deletion events.
4. **Given** a completed CUI project, **When** offboarding is triggered, **Then** data is sanitized according to policy, sanitization is verified, and completion evidence is generated.

---

### User Story 4 - Node Lifecycle Management (Priority: P2)

An HPC administrator provisions new compute nodes, ensures they meet compliance requirements on first boot, validates node health between jobs, and properly decommissions nodes when retired.

**Why this priority**: Node lifecycle affects compliance posture but individual nodes can be managed manually initially. Automation improves efficiency but is not blocking for initial operations.

**Independent Test**: Can be fully tested by PXE booting a new node, verifying compliance scan passes, running health checks between jobs, and executing decommissioning procedures.

**Acceptance Scenarios**:

1. **Given** a new compute node, **When** it PXE boots, **Then** it receives the CUI-hardened image and runs an automated compliance scan before joining the cluster.
2. **Given** a node that fails compliance scan, **When** scan completes, **Then** the node is quarantined from production use until issues are remediated.
3. **Given** a node between jobs, **When** the scheduler checks availability, **Then** a health check validates the node is ready and compliant.
4. **Given** a node being decommissioned, **When** the process runs, **Then** media is sanitized per NIST 800-88 guidelines and sanitization is verified and documented.

---

### User Story 5 - Researcher Onboarding/Offboarding (Priority: P2)

A principal investigator (PI) receives a CUI research award and needs their team onboarded to the secure enclave. Later, when the project ends, the team must be offboarded with proper data handling and access revocation.

**Why this priority**: While critical for operations, initial projects can be onboarded manually. Automation reduces administrative burden and ensures consistency.

**Independent Test**: Can be fully tested by running onboarding for a test project, verifying all resources are created correctly, then running offboarding and verifying complete cleanup.

**Acceptance Scenarios**:

1. **Given** a new CUI project approval, **When** onboarding runs, **Then** FreeIPA group is created, Slurm account configured, storage directory provisioned with ACLs, Duo is assigned, and PI receives a welcome packet with plain language instructions.
2. **Given** a PI receiving the welcome packet, **When** they read it, **Then** they understand what their team needs to do (training requirements, access procedures, data handling rules) without technical jargon.
3. **Given** a completed CUI project, **When** offboarding runs, **Then** all access is revoked, data is archived or sanitized per project requirements, and completion evidence is generated for audit purposes.
4. **Given** an offboarding completion, **When** a team member attempts to access resources, **Then** all access paths (Slurm, storage, systems) are denied.

---

### User Story 6 - Interconnect Security Documentation (Priority: P3)

A compliance officer needs formal documentation for the InfiniBand RDMA exception within the enclave, demonstrating compensating controls that justify the exception until in-network encryption is available.

**Why this priority**: Documentation is essential for audits but does not block technical operations. The enclave can operate while documentation is developed in parallel.

**Independent Test**: Can be fully tested by generating exception documentation, verifying compensating controls are correctly documented, and validating the template produces audit-ready artifacts.

**Acceptance Scenarios**:

1. **Given** the InfiniBand RDMA configuration, **When** documentation is generated, **Then** a formal exception document is produced that explains the encryption gap and justifies compensating controls.
2. **Given** compensating controls (physical security, boundary encryption, port monitoring), **When** verification runs, **Then** each control is validated and evidence is collected.
3. **Given** the documentation template, **When** hardware supports in-network encryption in the future, **Then** the template can be updated to reflect the new capability.

---

### Edge Cases

- Prolog authorization timeout: Job fails with specific error message indicating the timeout was transient and retry is safe (e.g., "Authorization service temporarily unavailable - please resubmit job")
- How does the system handle a node that fails health check mid-job (graceful handling vs. immediate termination)?
- What happens when Lustre changelog buffer fills before events are processed?
- Container MPI communication: Allow high-speed interconnect (InfiniBand) only between CUI partition nodes; external network access remains blocked
- GPU memory reset failure: Mark node unhealthy, drain from scheduler, require manual remediation before returning to service (prevents potential CUI data exposure)
- Offboarding with active jobs: Allow active jobs to complete with up to 24-hour grace period; block new submissions immediately; revoke all access after grace period expires or jobs complete (whichever comes first)
- What happens when a PXE boot fails partway through compliance scan?
- Quota exceeded during processing: Block new writes, alert user immediately, preserve existing data, allow job to continue with read-only access until user frees space

## Requirements *(mandatory)*

### Functional Requirements

#### Slurm CUI Partition (roles/hpc_slurm_cui/)

- **FR-001**: Role MUST configure a Slurm partition with EXCLUSIVE node allocation for CUI workloads
- **FR-002**: Role MUST restrict partition access to accounts in the CUI AllowAccounts list
- **FR-003**: Role MUST configure a CUI-specific QOS for job prioritization and accounting
- **FR-004**: Prolog script MUST verify user CUI authorization before job execution
- **FR-005**: Prolog script MUST verify user CUI training status is current
- **FR-005a**: Prolog script MUST fail job with retry-friendly error message when authorization check times out
- **FR-006**: Prolog script MUST log job start with CUI-specific audit tags (job ID, user, account, partition, node list)
- **FR-007**: Epilog script MUST clear /dev/shm by overwriting with zeros
- **FR-008**: Epilog script MUST clear /tmp of job-created files
- **FR-009**: Epilog script MUST reset GPU memory using nvidia-smi when GPUs are present
- **FR-009a**: Epilog script MUST drain node from scheduler if GPU memory reset fails, requiring manual remediation
- **FR-010**: Epilog script MUST flush audit logs before node is marked available
- **FR-011**: Epilog script MUST run node health check before returning node to available pool
- **FR-012**: Role MUST configure CUI-specific sacct fields for job accounting
- **FR-013**: Role MUST integrate job accounting data with Spec 003 evidence collection
- **FR-014**: Role MUST include plain language README explaining researcher experience differences in CUI partition

#### Container Security (roles/hpc_container_security/)

- **FR-015**: Role MUST configure Apptainer/Singularity for CUI enclave requirements
- **FR-016**: Role MUST enforce signed container image verification (unsigned containers blocked)
- **FR-017**: Role MUST restrict bind mounts to only CUI-approved paths
- **FR-018**: Role MUST enforce network isolation (no outbound connections by default)
- **FR-018a**: Role MUST allow InfiniBand communication between CUI partition nodes for MPI workloads
- **FR-019**: Role MUST log container execution events (image, user, timestamp, data paths)
- **FR-020**: Role MUST include researcher-facing documentation "How to use containers in the CUI enclave"
- **FR-021**: Container restrictions MUST NOT break common scientific workflows (Python, R, MATLAB, GROMACS, VASP patterns)

#### Parallel Filesystem Security (roles/hpc_storage_security/)

- **FR-022**: Role MUST configure changelog monitoring for CUI directories
- **FR-023**: Role MUST manage project directory ACLs tied to FreeIPA groups
- **FR-024**: Role MUST verify encryption at rest is enabled
- **FR-025**: Role MUST enforce storage quotas per CUI project
- **FR-025a**: Role MUST block new writes and alert user when quota exceeded, preserving existing data and allowing read-only access
- **FR-026**: Role MUST provide data sanitization scripts for project completion
- **FR-027**: Role MUST verify backup encryption is enabled
- **FR-028**: Role MUST support both Lustre and BeeGFS parallel filesystems

#### Interconnect Security (roles/hpc_interconnect/)

- **FR-029**: Role MUST generate formal exception documentation for InfiniBand RDMA within enclave
- **FR-030**: Role MUST verify compensating controls (physical security, boundary encryption, port monitoring)
- **FR-031**: Role MUST provide template for future in-network encryption documentation

#### Node Lifecycle (roles/hpc_node_lifecycle/)

- **FR-032**: Role MUST configure PXE boot with CUI-hardened image
- **FR-033**: Role MUST run automated compliance scan on first boot
- **FR-034**: Role MUST quarantine nodes that fail compliance scan
- **FR-035**: Role MUST run node health checks between jobs
- **FR-036**: Role MUST implement media sanitization per NIST 800-88 for decommissioning
- **FR-037**: Role MUST verify and document sanitization completion

#### Researcher Onboarding/Offboarding

- **FR-038**: Onboarding playbook MUST create FreeIPA group for new CUI project
- **FR-039**: Onboarding playbook MUST create Slurm account linked to FreeIPA group
- **FR-040**: Onboarding playbook MUST provision storage directory with proper ACLs
- **FR-041**: Onboarding playbook MUST configure Duo MFA assignment
- **FR-042**: Onboarding playbook MUST generate PI welcome packet with plain language instructions
- **FR-043**: Offboarding playbook MUST revoke all access (Slurm, storage, system)
- **FR-043a**: Offboarding playbook MUST allow active jobs up to 24-hour grace period before final access revocation
- **FR-043b**: Offboarding playbook MUST block new job submissions immediately upon initiation
- **FR-044**: Offboarding playbook MUST archive or sanitize data per project requirements
- **FR-045**: Offboarding playbook MUST generate completion evidence for audit

#### Documentation Updates

- **FR-046**: Update hpc_tailoring.yml with implementation details for each HPC-specific tailoring decision
- **FR-047**: Update researcher quickstart documentation with HPC-specific instructions

### Key Entities

- **CUI Project**: A funded research effort handling CUI data, with defined team membership, storage allocation, and access requirements. Links to FreeIPA group and Slurm account.
- **CUI Job**: A batch job executing on CUI partition nodes, subject to prolog/epilog controls and enhanced accounting.
- **Signed Container**: A container image with cryptographic signature from approved key, required for execution in CUI enclave.
- **Project Directory**: Parallel filesystem directory for a CUI project, with ACLs, quotas, and changelog monitoring.
- **Node State**: Compute node compliance status (compliant, quarantined, decommissioning), tracked through lifecycle.
- **Compensating Control**: Security measure that mitigates risk when primary control (e.g., RDMA encryption) is not available.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Authorized researchers can submit and complete jobs on the CUI partition with no more than 30 seconds prolog overhead
- **SC-002**: Unauthorized job submissions (training expired, wrong group) are blocked 100% of the time with clear error messages
- **SC-003**: Memory sanitization (RAM, GPU) completes within 60 seconds per node and is verifiable by pattern test
- **SC-004**: Container execution logging captures 100% of runs with complete attribution data
- **SC-005**: Project directory ACLs match FreeIPA group membership within 5 minutes of group changes
- **SC-006**: Data sanitization for completed projects is verifiable and produces audit evidence
- **SC-007**: New node provisioning completes compliance scan within 15 minutes of first boot
- **SC-008**: PI can understand onboarding welcome packet without requiring technical assistance (validated by readability test)
- **SC-009**: Common scientific workflows (Python, R, MATLAB, GROMACS, VASP) execute successfully under container restrictions
- **SC-010**: Offboarding revokes all access paths within 1 hour of execution
- **SC-011**: HPC tailoring decisions are fully documented with implementation details in hpc_tailoring.yml

## Assumptions

- Slurm is the job scheduler (not PBS, SGE, or other schedulers)
- Apptainer/Singularity is the container runtime (not Docker)
- FreeIPA is the identity management system (as established in Specs 001-002)
- Parallel filesystem is either Lustre or BeeGFS (not GPFS or other)
- NVIDIA GPUs are used when GPUs are present (not AMD ROCm)
- NIST 800-88 Clear or Purge methods are acceptable for media sanitization (Destroy not required)
- Duo is the MFA provider (as established in Specs 001-002)
- InfiniBand is the high-performance interconnect (not OmniPath or Ethernet)
- Spec 001 data models (control_mapping.yml, hpc_tailoring.yml, glossary) exist and are authoritative
- Spec 002 core roles for general system hardening are complete and functional
- Spec 003 compliance assessment infrastructure (assess.yml, evidence collection) is available for integration
