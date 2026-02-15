# Feature Specification: Core Ansible Roles for NIST 800-171 Controls

**Feature Branch**: `002-ansible-roles-core-controls`
**Created**: 2026-02-14
**Status**: Draft
**Input**: User description: "Build the core Ansible roles that implement NIST 800-171 controls for a CUI-compliant research computing enclave. This spec depends on the data models from Spec 001."

## Clarifications

### Session 2026-02-14

- Q: When a role is applied to a system that isn't assigned to any defined zone, how should the role behave? → A: Fail immediately with error requiring explicit zone assignment
- Q: How should systems handle emergency access when Duo MFA is unavailable (service outage, user loses phone)? → A: Pre-provisioned break-glass local accounts with hardware tokens (YubiKey)
- Q: What should happen when OpenSCAP auto-remediation conflicts with HPC tailoring decisions? → A: Skip conflicting remediations; use HPC tailoring + compensating controls instead
- Q: How should roles handle systems that belong to multiple zones (e.g., bastion host)? → A: Require single primary zone; secondary attributes via explicit variable overrides
- Q: How long must audit logs be retained for compliance evidence? → A: 3 years (typical federal contract audit window)

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Deploy Comprehensive Audit Logging for Compliance Evidence (Priority: P1)

A system administrator needs to deploy comprehensive audit logging across all zones of the research computing enclave to capture evidence of who accessed what data, when, and what they did with it. The audit system must capture enough detail to satisfy CMMC auditors while being zone-aware enough not to overwhelm compute nodes with logging overhead that would degrade scientific workload performance.

**Why this priority**: Audit & Accountability (AU family) controls have the highest visibility during compliance assessments. Without comprehensive, tamper-proof audit logs, the organization cannot prove compliance with any other control family. Auditors will immediately ask "show me the logs" for any control claim. This is the foundational evidence-collection infrastructure that enables all other compliance claims.

**Independent Test**: Can be fully tested by deploying the AU roles to a test RHEL 9 VM, generating test events (user login, sudo usage, file access, privilege escalation), and verifying that all expected events appear in the centralized Wazuh SIEM with correct timestamps, immutability protection, and zone-appropriate detail levels.

**Acceptance Scenarios**:

1. **Given** a fresh RHEL 9 login node, **When** the au_auditd role is applied, **Then** auditd is configured with comprehensive rules covering identity changes, privilege escalation, file permission changes, unauthorized access attempts, and CUI directory access
2. **Given** a compute node in the restricted zone, **When** the au_auditd role is applied with zone-specific variables, **Then** audit rules are focused on critical events only (not every file access) to minimize performance impact on scientific workloads
3. **Given** any system with audit logging configured, **When** an administrator attempts to delete or modify audit logs, **Then** the attempt is blocked by immutable file attributes and itself logged as a suspicious event
4. **Given** multiple systems across different zones, **When** the au_rsyslog role is applied, **Then** all audit logs are forwarded via TLS to a central logging server and locally retained on a separate partition for redundancy
5. **Given** the AU roles are deployed, **When** an auditor requests evidence of "who accessed CUI data in the last 90 days", **Then** the evidence.yml tasks can generate a compliance report from centralized Wazuh indices

---

### User Story 2 - Enforce Strong Identity and MFA Without Breaking Batch Jobs (Priority: P1)

A CISO needs to enforce multi-factor authentication (MFA) for all interactive access to CUI systems while ensuring that batch job submissions and compute node authentication don't require human interaction. The system must integrate with the university's existing FreeIPA identity management and support SSH certificates for passwordless compute node auth.

**Why this priority**: Identification & Authentication (IA family) controls are critical for preventing unauthorized access. MFA is explicitly required by NIST 800-171 Rev 3 for privileged and non-local access. However, naive MFA deployment breaks HPC batch job workflows where jobs need to authenticate to compute nodes without human interaction. This story addresses the highest-impact access control risk while maintaining HPC operational requirements.

**Independent Test**: Can be fully tested by enrolling a test RHEL 9 VM in FreeIPA, configuring Duo MFA for SSH access, submitting a batch job via Slurm that spawns on a compute node, and verifying that: (1) interactive SSH requires Duo push notification, (2) batch jobs authenticate via SSH certificates without MFA prompts, (3) password policy enforces 15-character minimum with complexity, and (4) inactive accounts are automatically disabled after 90 days.

**Acceptance Scenarios**:

1. **Given** a fresh RHEL 9 system, **When** the ia_freeipa_client role is applied, **Then** the system is enrolled in FreeIPA with proper Kerberos configuration and host keytab
2. **Given** a login node in the access zone, **When** the ia_duo_mfa role is applied, **Then** interactive SSH sessions require Duo MFA while service accounts and SSH certificate-based auth bypass Duo
3. **Given** compute nodes in the restricted zone, **When** the ia_ssh_ca role is applied, **Then** compute nodes trust SSH certificates issued by FreeIPA CA for batch job authentication
4. **Given** FreeIPA enrollment, **When** the ia_password_policy role is applied, **Then** password complexity requires 15 characters minimum, prohibits dictionary words, enforces 24-password history, and sets 365-day expiration per ODP values from Spec 001
5. **Given** any enrolled system, **When** the ia_account_lifecycle role runs verify.yml tasks, **Then** it reports all user accounts inactive for >90 days and provides evidence of auto-disable actions

---

### User Story 3 - Harden Access Controls with Zone-Aware Restrictions (Priority: P1)

A system administrator needs to implement role-based access control (RBAC), SSH hardening, session timeouts, and physical media blocking across different security zones with zone-appropriate configurations. Login nodes need strict session timeouts and USB blocking, while compute nodes need relaxed timeouts for long-running jobs but strict network-based access controls.

**Why this priority**: Access Control (AC family) is the largest control family (22 controls in NIST 800-171) and directly impacts user experience. Poor AC configuration either creates security gaps or makes systems unusable. Zone-aware implementation is critical—applying login node restrictions to compute nodes would kill batch jobs, while applying compute node permissiveness to login nodes would create audit findings.

**Independent Test**: Can be fully tested by deploying AC roles to login and compute nodes in separate zones, attempting interactive SSH to both, attempting sudo privilege escalation, attempting to mount a USB drive on a login node, and verifying that: (1) login nodes enforce 15-minute session timeout, (2) compute nodes allow long sessions for batch jobs, (3) USBGuard blocks portable media, (4) sudo is restricted to whitelisted commands per FreeIPA group membership, and (5) SELinux is in enforcing mode.

**Acceptance Scenarios**:

1. **Given** a login node, **When** the ac_pam_access role is applied, **Then** PAM is configured to restrict access based on FreeIPA group membership with explicit deny-by-default
2. **Given** systems in different zones, **When** the ac_ssh_hardening role is applied, **Then** SSH configurations use zone-specific templates (login nodes: strict ciphers, no root login, forced MFA; compute nodes: SSH cert auth, relaxed timeouts for batch)
3. **Given** a login node, **When** the ac_session_timeout role is applied, **Then** interactive sessions timeout after 15 minutes idle while batch job sessions on compute nodes are exempt per HPC tailoring
4. **Given** a login node in the access zone, **When** the ac_usbguard role is applied, **Then** all USB storage devices are blocked while USB keyboards/mice are allowed
5. **Given** any system, **When** the ac_selinux role runs verify.yml tasks, **Then** it confirms SELinux is in enforcing mode and reports any denials from /var/log/audit/audit.log

---

### User Story 4 - Establish Security Baseline with FIPS and Minimal Configuration (Priority: P2)

A compliance officer needs to establish a hardened security baseline for all RHEL 9 systems using OpenSCAP CUI profile, enable FIPS mode for cryptographic compliance, install only required packages per zone, disable unnecessary services, apply kernel hardening, and deploy AIDE file integrity monitoring. This baseline ensures all systems start from a known-secure state before specialized configurations.

**Why this priority**: Configuration Management (CM family) controls establish the security foundation that all other controls build upon. FIPS mode is mandatory for CUI cryptographic operations. Minimal package sets reduce attack surface. However, this is P2 (not P1) because these are foundational hardening steps that don't directly impact audit evidence collection or access control—they're preventive rather than detective.

**Independent Test**: Can be fully tested by deploying CM roles to a fresh RHEL 9 VM, rebooting to apply FIPS mode, running OpenSCAP assessment, and verifying that: (1) system boots in FIPS mode with crypto-policies set to FIPS:OSPP, (2) OpenSCAP CUI profile assessment shows >85% compliance, (3) only zone-required packages are installed, (4) unnecessary services (cups, bluetooth, avahi) are disabled, (5) kernel sysctl hardening is applied, and (6) AIDE baseline is initialized.

**Acceptance Scenarios**:

1. **Given** a fresh RHEL 9 system, **When** the cm_openscap_baseline role is applied, **Then** the system is assessed against the CUI profile and auto-remediation is applied for all automatable controls
2. **Given** any system handling CUI, **When** the cm_fips_mode role is applied, **Then** FIPS mode is enabled, the system reboots if necessary, and crypto-policies are set to FIPS:OSPP
3. **Given** a system in a specific zone, **When** the cm_minimal_packages role is applied, **Then** only zone-required package groups are installed and all unnecessary packages are removed
4. **Given** any system, **When** the cm_service_hardening role is applied, **Then** unnecessary services (cups, bluetooth, avahi, postfix for non-mail servers) are disabled and masked
5. **Given** kernel sysctl hardening applied, **When** the cm_kernel_hardening role runs verify.yml, **Then** it confirms all required sysctl values (e.g., kernel.randomize_va_space=2, net.ipv4.conf.all.accept_source_route=0) are set
6. **Given** AIDE deployed, **When** the cm_aide role runs evidence.yml, **Then** it produces a file integrity baseline report showing all monitored paths and any detected changes since last baseline

---

### User Story 5 - Deploy Zone-Aware Firewalls and Cryptographic Protections (Priority: P2)

A network security engineer needs to deploy nftables firewalls with zone-specific rulesets (default-deny), enforce TLS 1.2+ for all encrypted communications, apply FIPS cryptographic policies, verify LUKS encryption on CUI data partitions, and implement network segmentation templates. Each security zone (management, internal, restricted) has different firewall rules reflecting different threat models.

**Why this priority**: System & Communications Protection (SC family) controls protect data in transit and establish network boundaries. However, firewall rules depend on network architecture planning external to this spec, and encryption verification is a check rather than an implementation (LUKS is assumed to be configured during OS installation). This is foundational but doesn't directly impact compliance evidence or user access, making it P2.

**Independent Test**: Can be fully tested by deploying SC roles to systems in different zones, verifying nftables rules allow only zone-required ports, attempting TLS connections with weak ciphers (should fail), checking crypto-policies configuration, verifying LUKS encryption on /data partition, and confirming network interface assignments match zone templates.

**Acceptance Scenarios**:

1. **Given** a system in any zone, **When** the sc_nftables role is applied, **Then** firewall rules are configured with default-deny and zone-specific allow rules (e.g., management zone allows SSH from bastion only, internal allows HPC management ports)
2. **Given** any service requiring encrypted communications, **When** the sc_tls_enforcement role is applied, **Then** TLS 1.2+ is enforced and weak ciphers (TLS 1.0, 1.1, SSLv3) are disabled
3. **Given** FIPS mode enabled, **When** the sc_fips_crypto_policies role runs verify.yml, **Then** it confirms system-wide crypto policies are set to FIPS:OSPP
4. **Given** a system with /data partition, **When** the sc_luks_verification role runs verify.yml, **Then** it confirms the partition is LUKS-encrypted and reports encryption status in evidence.yml output
5. **Given** systems in different zones, **When** the sc_network_segmentation role is applied, **Then** network interface configurations match zone templates (management zone on VLAN 10, internal on VLAN 20, restricted on VLAN 30)

---

### User Story 6 - Automate Patching and Malware Protection with HPC Awareness (Priority: P3)

A system administrator needs to deploy automated security patching via dnf-automatic, install ClamAV antivirus with HPC-aware exclusions (don't scan /scratch or /tmp during peak hours), maintain AIDE file integrity monitoring, and run OpenSCAP OVAL vulnerability scanning. The system must balance security with HPC performance requirements.

**Why this priority**: System & Information Integrity (SI family) controls are important for maintaining security posture over time, but they're reactive rather than proactive. Patching, antivirus, and vulnerability scanning happen after deployment and don't directly impact initial system authorization. This is P3 because these are ongoing maintenance activities rather than initial compliance gates, though they're still required for continuous monitoring.

**Independent Test**: Can be fully tested by deploying SI roles to a test system, waiting for dnf-automatic to run (or triggering manually), verifying ClamAV is installed with /scratch and /tmp excluded from real-time scanning, running AIDE check to detect any file changes, and executing OpenSCAP OVAL scan to identify vulnerabilities requiring patches.

**Acceptance Scenarios**:

1. **Given** any system, **When** the si_dnf_automatic role is applied, **Then** dnf-automatic is configured to check for security updates daily and auto-apply critical updates during maintenance windows
2. **Given** a compute node, **When** the si_clamav role is applied, **Then** ClamAV is deployed with performance exclusions for /scratch, /tmp, and parallel filesystem mounts, and scheduled scans run during off-peak hours only
3. **Given** AIDE baseline initialized, **When** the si_aide role runs verify.yml tasks, **Then** it performs file integrity check and reports any unauthorized modifications to system binaries or configuration files
4. **Given** any system, **When** the si_openscap_oval role runs verify.yml, **Then** it executes OVAL vulnerability scan and produces a report of CVEs requiring remediation with NIST severity ratings

---

### Edge Cases

- When a role is applied to a system without an explicit zone assignment, the role MUST fail immediately with a clear error message requiring zone assignment before proceeding
- Systems belonging to multiple zones (e.g., bastion hosts) MUST declare a single primary zone; secondary zone attributes are applied via explicit variable overrides in host_vars or group_vars
- What if FIPS mode enablement fails or hardware doesn't support required cryptographic instructions?
- How do audit rules handle high-throughput parallel filesystems where every file access event would generate terabytes of logs?
- What if FreeIPA server is unavailable during ia_freeipa_client enrollment?
- Emergency access when Duo MFA is unavailable MUST be handled via pre-provisioned break-glass local accounts authenticated with hardware tokens (YubiKey), with all break-glass access logged and alerted
- When OpenSCAP auto-remediation conflicts with HPC tailoring decisions (e.g., session timeouts on compute nodes), the role MUST skip the conflicting remediation and apply the HPC tailoring with documented compensating controls instead
- How do firewall rules handle dynamic port allocation for MPI jobs or Slurm communications?
- What if a system needs to transition between zones (e.g., compute node repurposed as login node)?
- How do roles handle partial compliance scenarios where some controls are implemented via external systems (e.g., network-based MFA vs host-based MFA)?

## Requirements *(mandatory)*

### Functional Requirements

**Audit & Accountability (AU) Roles**:
- **FR-001**: System MUST deploy auditd with comprehensive rules covering identity changes, privilege escalation, file permission changes, unauthorized access attempts, CUI data directory access, data transfer tool usage, kernel module loads, time changes, and cron modifications
- **FR-002**: Audit rules MUST be zone-aware with comprehensive logging for access/management zones and focused logging for compute zones to minimize performance impact
- **FR-003**: System MUST configure rsyslog to forward audit logs via TLS to centralized Wazuh server
- **FR-004**: System MUST deploy chrony for NTP time synchronization with authenticated time sources
- **FR-005**: System MUST protect audit logs with immutable file attributes and separate partition storage
- **FR-006**: System MUST deploy Wazuh agent configured to send security events to central SIEM
- **FR-052**: Audit logs MUST be retained for minimum 3 years to support federal contract audit windows and research grant closeout requirements

**Identification & Authentication (IA) Roles**:
- **FR-007**: System MUST enroll in FreeIPA identity management with proper Kerberos and host keytab configuration
- **FR-008**: System MUST deploy Duo PAM for MFA on interactive access while bypassing MFA for batch jobs and SSH certificate authentication
- **FR-009**: System MUST configure SSH certificate authority trust for compute node authentication via FreeIPA CA
- **FR-010**: System MUST enforce password policy with 15-character minimum, complexity requirements, 24-password history, and 365-day expiration per ODP values
- **FR-011**: System MUST automatically disable user accounts inactive for more than 90 days
- **FR-049**: System MUST provision break-glass local accounts authenticated via hardware tokens (YubiKey) for emergency access when Duo MFA is unavailable, with all break-glass access logged and generating immediate security alerts

**Access Control (AC) Roles**:
- **FR-012**: System MUST implement PAM-based access restrictions with explicit deny-by-default based on FreeIPA group membership
- **FR-013**: System MUST implement RBAC via FreeIPA group assignments mapping to sudo command whitelists
- **FR-014**: System MUST deploy zone-specific SSH hardening configurations (strict for login nodes, certificate-based for compute nodes)
- **FR-015**: System MUST enforce 15-minute session timeout on interactive login nodes while exempting batch job sessions on compute nodes per HPC tailoring
- **FR-016**: System MUST display login banner with use authorization warning
- **FR-017**: System MUST deploy USBGuard to block portable storage devices while allowing USB keyboards/mice
- **FR-018**: System MUST configure SELinux in enforcing mode with targeted policy

**Configuration Management (CM) Roles**:
- **FR-019**: System MUST apply OpenSCAP CUI profile baseline with auto-remediation for automatable controls
- **FR-020**: System MUST enable FIPS mode with crypto-policies set to FIPS:OSPP
- **FR-021**: System MUST install only zone-required minimal package sets
- **FR-022**: System MUST disable and mask unnecessary services (cups, bluetooth, avahi, postfix on non-mail servers)
- **FR-023**: System MUST apply kernel sysctl hardening for network stack and memory protections
- **FR-024**: System MUST deploy AIDE file integrity monitoring with initialized baseline
- **FR-050**: OpenSCAP auto-remediation MUST skip controls that conflict with HPC tailoring decisions defined in Spec 001, applying documented compensating controls instead to maintain both compliance and HPC operational requirements

**System & Communications Protection (SC) Roles**:
- **FR-025**: System MUST deploy nftables firewall with zone-specific rulesets implementing default-deny
- **FR-026**: System MUST enforce TLS 1.2+ for all encrypted communications and disable weak ciphers
- **FR-027**: System MUST verify FIPS crypto-policies are applied system-wide
- **FR-028**: System MUST verify LUKS encryption on partitions containing CUI data
- **FR-029**: System MUST implement network segmentation templates with zone-appropriate VLAN assignments

**System & Information Integrity (SI) Roles**:
- **FR-030**: System MUST deploy dnf-automatic for automated security patching with configurable maintenance windows
- **FR-031**: System MUST deploy ClamAV antivirus with HPC-aware exclusions for high-performance filesystems
- **FR-032**: System MUST maintain AIDE file integrity monitoring with regular verification scans
- **FR-033**: System MUST execute OpenSCAP OVAL vulnerability scanning and report CVEs requiring remediation

**Role Structure Requirements**:
- **FR-034**: Every role MUST include defaults/main.yml with documented, tunable variables
- **FR-035**: Every role MUST include tasks/main.yml with implementation tasks tagged with all framework control IDs (r2_X.X.X, r3_XX.XX.XX, cmmc_XX, family_XX, zone_XX)
- **FR-036**: Every role MUST include tasks/verify.yml with audit-only tasks that check compliance without making changes
- **FR-037**: Every role MUST include tasks/evidence.yml that collect SSP artifacts for auditors
- **FR-038**: Every role MUST include handlers/main.yml for service restarts and configuration reloads
- **FR-039**: Every role MUST include templates/ with configuration files containing plain-language header blocks explaining purpose
- **FR-040**: Every role MUST include README.md following audience-aware template with "What This Does" section
- **FR-041**: Every role MUST include meta/main.yml declaring dependencies and control metadata
- **FR-042**: Every Ansible task MUST include plain-language comment explaining WHY (not what)
- **FR-043**: All tasks MUST work correctly in --check mode without making changes
- **FR-048**: Zone-aware roles MUST fail immediately with clear error if target system has no explicit zone assignment, preventing accidental misconfiguration
- **FR-051**: Systems requiring multi-zone behavior MUST declare a single primary zone with secondary zone attributes applied via explicit variable overrides in host_vars or group_vars, ensuring deterministic configuration

**Integration Requirements**:
- **FR-044**: Roles MUST update control_mapping.yml ansible_roles field to reference implemented roles
- **FR-045**: All roles MUST pass ansible-lint validation
- **FR-046**: All YAML files MUST pass yamllint validation
- **FR-047**: Running full playbook on fresh RHEL 9 VM MUST produce system passing OpenSCAP CUI profile at >85% compliance

### Key Entities

- **Ansible Role**: Implementation package for one or more related NIST controls, containing tasks (implement/verify/evidence), templates, handlers, defaults, and metadata
- **Security Zone**: Logical grouping of systems by security requirements and threat model (management, internal, restricted, public) determining which controls apply and how strictly
- **Control Tag**: Ansible task tag mapping to specific NIST 800-171 Rev 2/3, CMMC L2, and 800-53 R5 control identifiers enabling control-specific playbook runs
- **Audit Event**: Structured log entry from auditd capturing who did what, when, on which system, with immutability guarantees for compliance evidence
- **HPC Tailoring Decision**: Documented deviation from baseline security control with justification, compensating controls, and risk acceptance per constitution principles
- **Evidence Artifact**: SSP documentation generated by evidence.yml tasks showing control implementation status, configuration snapshots, and compliance posture

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: System administrator can deploy all AU roles to a RHEL 9 login node and successfully capture test audit events in centralized Wazuh within 5 minutes
- **SC-002**: Running OpenSCAP CUI profile assessment on a system with all roles applied achieves >85% compliance score
- **SC-003**: Compliance officer can run evidence.yml playbook and generate complete SSP artifacts for all implemented controls in under 10 minutes
- **SC-004**: System with IA roles applied successfully enforces Duo MFA for interactive SSH while allowing batch job authentication without human interaction
- **SC-005**: AC roles configured on compute node do not reduce parallel filesystem I/O throughput by more than 5% compared to baseline (per HPC tailoring)
- **SC-006**: All roles pass ansible-lint and yamllint validation without errors or warnings
- **SC-007**: Security engineer can apply CM baseline roles to 100 fresh RHEL 9 systems in parallel and achieve identical FIPS-enabled hardened state within 20 minutes
- **SC-008**: Audit logs from systems with AU roles deployed are immutable (cannot be deleted or modified by root) and survive targeted deletion attempts
- **SC-009**: verify.yml tasks for all roles produce clear pass/fail output identifying specific non-compliant configurations within 2 minutes per system
- **SC-010**: Running all core control roles on fresh RHEL 9 VM produces no Ansible failures and system passes >85% of OpenSCAP CUI profile checks on first run

## Assumptions

- RHEL 9 or Rocky Linux 9 is the target platform per constitution tech stack
- FreeIPA server infrastructure already exists and is accessible from target systems
- Wazuh SIEM infrastructure already exists for centralized log collection
- Network segmentation (VLANs for management/internal/restricted zones) is already implemented at network layer
- LUKS encryption is configured during OS installation on partitions that will contain CUI data
- Duo account and integration keys are available for MFA configuration
- Target systems have internet access (direct or via proxy) for package installation and OpenSCAP content updates
- SSH certificate authority is already configured in FreeIPA
- Time synchronization sources (NTP servers) are accessible and authenticated
- control_mapping.yml from Spec 001 is available and contains all 110 NIST 800-171 Rev 2 controls
- HPC tailoring decisions from Spec 001 document known conflicts (session timeouts, audit volume, FIPS on InfiniBand)
- ODP values from Spec 001 define password policy requirements, session timeouts, and other configurable parameters
- Ansible 2.15+ is available per constitution tech stack
- Target systems have at least 2GB RAM and 20GB disk for minimal installation
- System administrator has root access via SSH to target systems

## Constraints

- All roles must be zone-aware and support per-zone variable overrides
- Roles must not conflict with HPC workload schedulers (Slurm, PBS) or parallel filesystems
- FIPS mode enablement requires system reboot which must be handled gracefully in playbooks
- Audit rules on compute nodes must be limited to prevent log volume from impacting scientific workload I/O performance
- MFA configuration must not break SSH certificate-based authentication used by batch jobs
- OpenSCAP auto-remediation must respect HPC tailoring decisions and not blindly apply enterprise security policies
- All configuration templates must include plain-language explanatory headers per constitution
- Role dependencies must be explicitly declared in meta/main.yml to ensure correct application order
- verify.yml tasks must be read-only (no system changes) to support safe compliance audits
- evidence.yml tasks must not expose sensitive data (passwords, keys) in generated reports
- All roles must support --check mode for validation without changes
- Tag naming must follow consistent format: r2_X.X.X (Rev 2), r3_XX.XX.XX (Rev 3), cmmc_XX, family_XX, zone_XX

## Out of Scope

- Implementation of FreeIPA server infrastructure (assumed to exist)
- Implementation of Wazuh SIEM server infrastructure (assumed to exist)
- Network hardware firewall configuration (roles configure host-based nftables only)
- Physical security controls (PE family) - badge readers, locks, CCTV
- Incident response procedures and playbooks (IR family process documentation)
- Personnel security controls (PS family) - background checks, security training curriculum
- Risk assessment methodology (RA family) - covered in separate spec
- Supply chain security (SA family) - vendor assessment, secure acquisition
- Media protection hardware (MP family) - degaussers, crypto-shredders
- Initial LUKS encryption setup (assumed done during OS install)
- Duo MFA account provisioning workflow (assumed Duo admin provides integration keys)
- Slurm/PBS scheduler integration (batch job submission workflow assumes existing scheduler)
- HPC application-specific security controls (OpenMPI, CUDA, MPI libraries)
- Data classification and labeling (covered in separate data handling spec)
- Penetration testing and vulnerability assessment procedures
- Security awareness training content for end users
- Compliance reporting dashboard or web UI (evidence collection is CLI-based)
- Integration with external compliance management platforms (ServiceNow, Archer)
