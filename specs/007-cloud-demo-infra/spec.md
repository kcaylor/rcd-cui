# Feature Specification: Cloud Demo Infrastructure

**Feature Branch**: `007-cloud-demo-infra`
**Created**: 2026-02-15
**Status**: Draft
**Input**: On-demand cloud demo environment using Hetzner Cloud VMs, replacing local Vagrant for reliable demo experience

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Spin Up Demo Cluster (Priority: P1)

As a presenter preparing for a conference talk or customer demo, I need to provision a complete 4-node demo cluster in the cloud so that I have a reliable, consistent environment without consuming local resources.

**Why this priority**: This is the core value proposition - without cluster spin-up, no other functionality matters. Presenters need a working environment before they can demonstrate anything.

**Independent Test**: Can be fully tested by running the spin-up command and verifying all 4 VMs are accessible via SSH, delivering a ready-to-use demo environment.

**Acceptance Scenarios**:

1. **Given** valid cloud credentials configured, **When** I run the spin-up command, **Then** 4 VMs are created with correct sizes (mgmt01: 4GB, login01: 2GB, compute01: 2GB, compute02: 2GB)
2. **Given** VMs are provisioned, **When** provisioning completes, **Then** I can SSH to mgmt01 and login01 using the injected SSH key
3. **Given** spin-up is initiated, **When** the process runs, **Then** I see progress output including cost estimation for the session
4. **Given** VMs are created, **When** provisioning completes, **Then** all nodes can communicate on the private network (10.0.0.0/24)

---

### User Story 2 - Tear Down Demo Cluster (Priority: P1)

As a presenter who has finished a demo, I need to destroy all cloud resources immediately so that billing stops and no orphaned resources remain.

**Why this priority**: Equal to spin-up - without reliable teardown, users risk unexpected charges. This is a critical cost-safety feature.

**Independent Test**: Can be fully tested by running teardown after spin-up and verifying zero resources remain in the cloud account.

**Acceptance Scenarios**:

1. **Given** a running demo cluster, **When** I run the teardown command, **Then** all VMs, networks, and associated resources are destroyed
2. **Given** teardown is initiated, **When** I confirm the action, **Then** I see a count of resources being destroyed
3. **Given** teardown completes, **When** I check the cloud console, **Then** no demo-related resources exist and billing has stopped

---

### User Story 3 - Run Demo Scenarios (Priority: P1)

As a presenter with a running cluster, I need to execute the same demo scenarios from spec 006 so that I can demonstrate compliance workflows without modification.

**Why this priority**: The cluster is only useful if existing demo playbooks work unchanged. This validates the integration with spec 006.

**Independent Test**: Can be tested by running scenario-a-onboard.yml on a cloud cluster and verifying the same outputs as the Vagrant environment.

**Acceptance Scenarios**:

1. **Given** a provisioned cloud cluster, **When** I run provision.yml, **Then** FreeIPA, Slurm, Wazuh, and NFS are configured as in the Vagrant environment
2. **Given** core services are running, **When** I run any scenario playbook (a, b, c, or d), **Then** the scenario executes successfully with expected outputs
3. **Given** the cluster is provisioned, **When** I use existing demo/narratives/*.md guides, **Then** all commands and expected outputs match

---

### User Story 4 - Share Access with Workshop Attendees (Priority: P2)

As a workshop instructor, I need to provide SSH access to attendees so they can interact directly with the demo cluster during hands-on exercises.

**Why this priority**: Extends the value beyond single-presenter demos to interactive workshops. Depends on basic cluster functionality.

**Independent Test**: Can be tested by adding an attendee SSH key and verifying they can connect to login01.

**Acceptance Scenarios**:

1. **Given** a running cluster, **When** I add attendee SSH keys, **Then** attendees can SSH to login01 using their keys
2. **Given** attendees are connected, **When** they run permitted commands, **Then** they can interact with Slurm and shared storage
3. **Given** workshop is complete, **When** I teardown, **Then** all access is revoked with the cluster

---

### User Story 5 - Cost Awareness and Safety (Priority: P2)

As a user of cloud resources, I need visibility into costs and protection against forgotten clusters so that I don't incur unexpected charges.

**Why this priority**: Critical for user trust and adoption, but secondary to core spin-up/teardown functionality.

**Independent Test**: Can be tested by verifying TTL warnings appear after the configured threshold and cost estimates display on spin-up.

**Acceptance Scenarios**:

1. **Given** spin-up is initiated, **When** VMs are being created, **Then** I see an estimated hourly cost for the cluster
2. **Given** a cluster has been running longer than the TTL threshold, **When** the threshold is exceeded, **Then** a warning is displayed
3. **Given** teardown is requested, **When** I confirm, **Then** I see the total resources to be destroyed before proceeding

---

### Edge Cases

- What happens when cloud credentials are missing or invalid? System displays clear error with setup instructions.
- What happens when provisioning partially fails (e.g., 2 of 4 VMs created)? System provides rollback option or clear manual cleanup instructions.
- What happens when network quota is exceeded? System displays quota error with guidance.
- What happens when teardown is run with no cluster? System confirms no resources exist, exits cleanly.
- What happens when user loses connectivity during spin-up? Resources are tagged for identification; user can re-run teardown.

## Requirements *(mandatory)*

### Functional Requirements

**Cluster Provisioning**

- **FR-001**: System MUST provision 4 VMs with specified sizes: mgmt01 (4GB RAM), login01 (2GB RAM), compute01 (2GB RAM), compute02 (2GB RAM) in Hetzner US West (Hillsboro) region
- **FR-002**: System MUST create a private network (10.0.0.0/24) connecting all nodes
- **FR-003**: System MUST assign public IP addresses to mgmt01 and login01
- **FR-004**: System MUST inject user's SSH public key for passwordless access, auto-detecting from ~/.ssh/id_rsa.pub or ~/.ssh/id_ed25519.pub
- **FR-005**: System MUST generate an Ansible inventory file from provisioned VM details
- **FR-006**: System MUST run existing demo/playbooks/provision.yml after VM creation
- **FR-006a**: System MUST block spin-up if an existing cluster is detected; user must teardown first

**Teardown**

- **FR-007**: System MUST destroy all VMs, networks, and associated resources on teardown
- **FR-008**: System MUST display resource count and request confirmation before destroying
- **FR-009**: System MUST report completion status after teardown

**Cost and Safety**

- **FR-010**: System MUST display estimated hourly cost when spinning up cluster
- **FR-011**: System MUST tag all resources with a TTL label (default: 4 hours)
- **FR-012**: System MUST warn when cluster has exceeded TTL threshold by displaying a warning on the next command run
- **FR-013**: System MUST tag resources with identifiable metadata for manual cleanup if needed

**Integration**

- **FR-014**: System MUST use existing demo/playbooks/*.yml without modification
- **FR-015**: System MUST provide simple command interface (e.g., make demo-cloud-up, make demo-cloud-down)
- **FR-016**: System MUST work with the same Ansible roles used by spec 006 Vagrant demo

**Documentation**

- **FR-017**: System MUST include setup instructions for obtaining cloud credentials
- **FR-018**: System MUST document cost expectations and billing model
- **FR-019**: System MUST provide troubleshooting guidance for common failures

### Key Entities

- **CloudCluster**: Represents the complete demo environment; contains 4 VMs, 1 private network, resource tags, creation timestamp, TTL threshold
- **VM**: Individual virtual machine; has name, size (RAM/CPU), public IP (optional), private IP, SSH key, provisioning status
- **PrivateNetwork**: Internal network connecting all VMs; has CIDR range (10.0.0.0/24), associated VMs
- **ResourceTag**: Metadata applied to all cloud resources; includes cluster identifier, TTL, creation time

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Complete cluster spin-up (4 VMs provisioned and configured) completes in under 25 minutes
- **SC-002**: Cluster teardown completes in under 5 minutes with zero orphaned resources
- **SC-003**: All 4 demo scenarios (a, b, c, d) execute successfully on cloud cluster without playbook modifications
- **SC-004**: Users can SSH to mgmt01 and login01 within 30 seconds of spin-up completion
- **SC-005**: Cost estimation displayed on spin-up is accurate within 20% of actual charges
- **SC-006**: TTL warning appears within 5 minutes of threshold being exceeded
- **SC-007**: Workshop attendees can connect via SSH within 2 minutes of key injection

## Scope

### In Scope

- Single cloud provider support (Hetzner Cloud)
- 4-node cluster topology matching spec 006 Vagrant demo
- Make targets for spin-up and teardown
- Dynamic Ansible inventory generation
- SSH key injection for access
- Cost estimation and TTL warnings
- Integration with existing demo playbooks and roles

### Out of Scope

- Multi-cloud support (DigitalOcean, AWS, etc.) - Hetzner only for MVP
- Persistent storage between demos - clusters are ephemeral by design
- Automated scheduling of demos - manual spin-up/teardown only
- Web-based dashboard for cluster management
- Automatic teardown based on TTL (warning only)

## Assumptions

- Users have a Hetzner Cloud account with API access
- Users have Ansible 2.15+ installed locally
- SSH keypair exists locally for injection
- Existing demo/playbooks/* from spec 006 are available
- Network quotas in Hetzner account are sufficient (1 network, 4 VMs)
- Users run commands from repository root directory

## Dependencies

- **Spec 006 (Vagrant Demo Lab)**: Provides demo/playbooks/*.yml, demo/narratives/*.md, and roles/* that this feature reuses
- **Hetzner Cloud Account**: Required for VM provisioning (external dependency)
- **Local Ansible Installation**: Required for running provisioning playbooks

## Clarifications

### Session 2026-02-15

- Q: How should TTL warnings be delivered to the user? → A: Warning displayed on next command run (check TTL on any make target)
- Q: Where should the SSH public key be sourced from? → A: Auto-detect from ~/.ssh/id_rsa.pub or ~/.ssh/id_ed25519.pub
- Q: Which Hetzner Cloud region should be used? → A: US West (Hillsboro) for west coast proximity
- Q: Can multiple demo clusters exist simultaneously? → A: No, block spin-up if existing cluster detected; require teardown first
