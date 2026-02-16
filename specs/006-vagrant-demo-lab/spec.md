# Feature Specification: Vagrant Demo Lab Environment

**Feature Branch**: `006-vagrant-demo-lab`
**Created**: 2026-02-15
**Status**: Draft
**Input**: Reproducible multi-VM environment for interactive demonstrations with Vagrant, Rocky Linux 9 VMs, FreeIPA, Wazuh, Slurm cluster, and demo orchestration scripts

## Clarifications

### Session 2026-02-15

- Q: What virtualization approach for Apple Silicon Macs? → A: x86 emulation via QEMU (slower but uses identical box images as Intel/Linux)
- Q: What specific compliance violations should demo-break.sh introduce? → A: 3-4 violations: SSH permits root login, auditd stopped, world-readable /etc/shadow, firewall disabled
- Q: What demo users should Project Helios onboarding create? → A: Two users (alice_helios, bob_helios) with documented demo password "DemoPass123!"

## User Scenarios & Testing *(mandatory)*

### E2E Validation Environment Note

This feature is intended to be portable across providers (VirtualBox, libvirt, QEMU). However, **full end-to-end (E2E) validation of the demo flows requires a native x86_64 virtualization environment or equivalent cloud infrastructure** (for example: Intel macOS with VirtualBox, or a Linux x86_64 host using libvirt/KVM).

Apple Silicon macOS can run the lab via QEMU x86_64 emulation, but that environment is **not a substitute for provider-native E2E validation** due to emulation performance characteristics and provider/networking differences that can affect timing and service bring-up.

### User Story 1 - Lab Environment Setup (Priority: P1)

As a presenter or developer, I need to quickly spin up a complete multi-VM lab environment that simulates a real HPC cluster with compliance controls, so I can demonstrate the rcd-cui project capabilities without needing access to production infrastructure.

**Why this priority**: Without a working lab environment, no demonstrations are possible. This is the foundational requirement that enables all other scenarios.

**Independent Test**: Run `vagrant up` from the demo/vagrant directory and verify all 4 VMs are running with basic connectivity between them. Can be tested by pinging between VMs and verifying hostname resolution.

**Acceptance Scenarios**:

1. **Given** a host machine with Vagrant and VirtualBox/libvirt installed, **When** I run `demo-setup.sh`, **Then** 4 Rocky Linux 9 VMs are provisioned with networking configured between them
2. **Given** the lab is running, **When** I SSH to any VM, **Then** I can reach all other VMs by hostname
3. **Given** the lab is running, **When** I check FreeIPA on mgmt01, **Then** the FreeIPA server is operational and all nodes are enrolled as clients
4. **Given** the lab is running, **When** I check Slurm status, **Then** slurmctld is running on mgmt01 and slurmd is running on compute nodes

---

### User Story 2 - Project Onboarding Demonstration (Priority: P1)

As a presenter, I need to demonstrate the complete project onboarding workflow (Scenario A), showing how a new research project is configured with proper identity management, resource allocation, and storage access controls.

**Why this priority**: Onboarding is a core use case that showcases the value proposition of automated compliance. Tied for P1 as it demonstrates immediate user value.

**Independent Test**: Run scenario-a-onboard.yml playbook and verify "Project Helios" is created with users, Slurm QOS, and storage ACLs configured.

**Acceptance Scenarios**:

1. **Given** a running lab environment, **When** I execute the onboarding scenario playbook, **Then** a new project group "helios" is created in FreeIPA with specified users
2. **Given** the onboarding playbook has run, **When** I check Slurm, **Then** a QOS entry exists for project-helios with appropriate resource limits
3. **Given** the onboarding playbook has run, **When** I check the NFS shared storage, **Then** a project directory exists with correct ACLs restricting access to helios group members
4. **Given** I am logged in as a helios project user, **When** I submit a Slurm job, **Then** the job runs successfully with the project's QOS applied

---

### User Story 3 - Compliance Drift Detection and Remediation (Priority: P1)

As a presenter, I need to demonstrate the drift detection and remediation workflow (Scenario B), showing how compliance violations are introduced, detected, and automatically remediated.

**Why this priority**: This scenario directly demonstrates the core value of the compliance automation framework - detecting and fixing security drift.

**Independent Test**: Run demo-break.sh to introduce violations, run assessment to detect them, then run demo-fix.sh to remediate and verify compliance is restored.

**Acceptance Scenarios**:

1. **Given** a compliant lab environment, **When** I run `demo-break.sh`, **Then** 4 compliance violations are introduced: SSH PermitRootLogin enabled, auditd stopped, /etc/shadow world-readable, firewall disabled
2. **Given** violations have been introduced, **When** I run the compliance assessment, **Then** the dashboard shows failing controls with specific violations identified
3. **Given** violations are detected, **When** I run `demo-fix.sh`, **Then** remediation playbooks execute and restore compliance
4. **Given** remediation has completed, **When** I re-run the assessment, **Then** all previously failing controls now pass

---

### User Story 4 - Auditor Package Generation (Priority: P2)

As a presenter demonstrating to compliance officers or auditors, I need to generate a complete auditor package (Scenario C) that shows the evidence collection and reporting capabilities.

**Why this priority**: Important for demonstrating compliance reporting value, but depends on the lab being operational with assessment data.

**Independent Test**: Run scenario-c-audit.yml and verify a complete auditor package is generated with SPRS score, control evidence, and documentation.

**Acceptance Scenarios**:

1. **Given** a running lab with assessment history, **When** I execute the audit scenario playbook, **Then** a complete auditor package is generated in the standard format
2. **Given** an auditor package is generated, **When** I examine the contents, **Then** it contains SPRS score calculation, control-by-control evidence, and narrative documentation
3. **Given** an auditor package is generated, **When** I check the dashboard, **Then** the package is accessible via the dashboard's auditor view

---

### User Story 5 - Node Lifecycle Management (Priority: P2)

As a presenter, I need to demonstrate adding a new node to the cluster (Scenario D), showing how compliance gates prevent non-compliant nodes from joining the production environment.

**Why this priority**: Demonstrates lifecycle management and compliance gates - valuable but more advanced use case.

**Independent Test**: Run scenario-d-lifecycle.yml to add a new node, verify compliance check blocks if non-compliant, then show successful addition after remediation.

**Acceptance Scenarios**:

1. **Given** a running lab environment, **When** I initiate the add-node workflow, **Then** a new compute node VM is provisioned
2. **Given** a new node is provisioned, **When** compliance assessment runs, **Then** the node is blocked from joining the cluster if any required controls fail
3. **Given** a compliant new node, **When** the lifecycle playbook completes, **Then** the node is enrolled in FreeIPA, added to Slurm, and accessible to users
4. **Given** a demonstration of decommissioning, **When** I remove a node, **Then** it is properly removed from all services and its credentials are revoked

---

### User Story 6 - Lab Reset Between Demonstrations (Priority: P2)

As a presenter doing multiple demos in a day, I need to quickly reset the lab to a known baseline state without rebuilding all VMs from scratch.

**Why this priority**: Enables efficient multi-demo sessions, but not required for initial functionality.

**Independent Test**: After running any scenario, execute `demo-reset.sh` and verify the lab returns to baseline state.

**Acceptance Scenarios**:

1. **Given** a lab with modifications from previous demos, **When** I run `demo-reset.sh`, **Then** the lab returns to baseline state within 5 minutes
2. **Given** a reset lab, **When** I verify state, **Then** no project-helios artifacts exist and all compliance controls pass
3. **Given** a reset lab, **When** I run any scenario again, **Then** the scenario executes successfully as if running for the first time

---

### Edge Cases

- What happens when the host machine has insufficient resources (less than 16GB RAM)?
- How does the lab handle network conflicts with existing host network ranges?
- What happens if Vagrant provisioning is interrupted mid-setup?
- How does the system handle VirtualBox vs libvirt provider differences?
- What happens when running on Apple Silicon (ARM) vs Intel architecture?

## Requirements *(mandatory)*

### Functional Requirements

#### Lab Infrastructure

- **FR-001**: Lab MUST provision 4 Rocky Linux 9 VMs with specified resource allocations (mgmt01: 4GB RAM, others: 2GB RAM)
- **FR-002**: Lab MUST configure private networking between all VMs with hostname resolution
- **FR-003**: Lab MUST install and configure FreeIPA server on mgmt01 with all other nodes as clients
- **FR-004**: Lab MUST install and configure Wazuh manager on mgmt01
- **FR-005**: Lab MUST configure Slurm cluster with slurmctld on mgmt01 and slurmd on compute nodes
- **FR-006**: Lab MUST configure NFS server on mgmt01 with shared storage mounted on all nodes

#### Demo Orchestration

- **FR-007**: `demo-setup.sh` MUST bring up all VMs and run initial provisioning automatically
- **FR-008**: `demo-reset.sh` MUST restore lab to baseline state without full VM rebuild
- **FR-009**: `demo-break.sh` MUST introduce these compliance violations: (1) SSH PermitRootLogin enabled, (2) auditd service stopped, (3) /etc/shadow world-readable, (4) firewall disabled
- **FR-010**: `demo-fix.sh` MUST run remediation playbooks to restore compliance
- **FR-011**: All demo scripts MUST provide clear progress output and error handling

#### Scenario Playbooks

- **FR-012**: `scenario-a-onboard.yml` MUST create FreeIPA group "helios" with users alice_helios and bob_helios (password: DemoPass123!), Slurm QOS, and storage ACLs
- **FR-013**: `scenario-b-drift.yml` MUST orchestrate the break/detect/fix cycle with clear status output
- **FR-014**: `scenario-c-audit.yml` MUST generate a complete auditor package with all evidence artifacts
- **FR-015**: `scenario-d-lifecycle.yml` MUST demonstrate node addition with compliance gate and decommissioning

#### Documentation

- **FR-016**: Each scenario MUST have a narrative guide with talking points and timing estimates
- **FR-017**: Narrative guides MUST include expected outputs for presenter reference
- **FR-018**: Lab MUST include troubleshooting documentation for common issues

#### Platform Compatibility

- **FR-019**: Lab MUST work on macOS hosts (both Apple Silicon and Intel)
- **FR-020**: Lab MUST work on Linux hosts with libvirt or VirtualBox
- **FR-021**: Lab MUST function without internet access after initial setup (air-gapped demos)

### Key Entities

- **VM Node**: A virtual machine in the lab environment with role (mgmt/login/compute), zone assignment, and resource allocation
- **Project**: A research project entity with associated FreeIPA group, users, Slurm QOS, and storage allocation
- **Scenario**: A demonstration workflow consisting of playbooks, expected state changes, and narrative documentation
- **Compliance Violation**: A specific control failure that can be introduced and detected, with defined remediation

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `vagrant up` completes successfully in under 30 minutes on first run with a host having 16GB RAM and SSD storage
- **SC-002**: `demo-reset.sh` returns the lab to baseline state in under 5 minutes
- **SC-003**: All four demonstration scenarios can be executed without internet connectivity
- **SC-004**: Lab provisions successfully on macOS (Apple Silicon via UTM/QEMU, Intel via VirtualBox) and Linux (libvirt/VirtualBox)
- **SC-005**: Presenter can complete any single scenario demonstration in under 15 minutes using the narrative guide
- **SC-006**: FreeIPA enrollment succeeds for all nodes with working Kerberos authentication
- **SC-007**: Slurm cluster accepts and runs jobs submitted from login01 on compute nodes
- **SC-008**: Compliance assessment correctly identifies all violations introduced by demo-break.sh
- **SC-009**: Remediation playbooks successfully fix all violations introduced by demo-break.sh

## Assumptions

- Host machine has at least 16GB RAM and 100GB free disk space
- Vagrant 2.3+ is installed with either VirtualBox 7.0+ or libvirt provider
- For Apple Silicon Macs, QEMU with x86 emulation is used (vagrant-qemu plugin), ensuring identical box images across all platforms at the cost of slower performance
- Network range 192.168.56.0/24 (or similar) is available for private VM networking
- Internet access is available during initial `vagrant up` for package downloads
- Rocky Linux 9 base boxes are available from Vagrant Cloud or can be cached locally
- Demo presenter has basic familiarity with command-line operations

## Dependencies

- Existing rcd-cui Ansible roles for compliance controls
- Existing assessment and reporting scripts from the main project
- FreeIPA and Wazuh Ansible roles (either existing or to be created)
- Slurm configuration roles (either existing or to be created)
