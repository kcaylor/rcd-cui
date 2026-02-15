# Tasks: Core Ansible Roles for NIST 800-171 Controls

**Input**: Design documents from `/specs/002-ansible-roles-core-controls/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md
**Depends On**: Spec 001 - Data Models and Documentation Foundation

**Organization**: Tasks are grouped by user story (control family) to enable independent implementation and testing. Each user story can be deployed to validate a specific set of NIST controls.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1-US6)
- Include exact file paths in descriptions

## Path Conventions

This is an Ansible project with roles organized by control family prefix:
- `roles/au_*` - Audit & Accountability (User Story 1)
- `roles/ia_*` - Identification & Authentication (User Story 2)
- `roles/ac_*` - Access Control (User Story 3)
- `roles/cm_*` - Configuration Management (User Story 4)
- `roles/sc_*` - System & Communications Protection (User Story 5)
- `roles/si_*` - System & Information Integrity (User Story 6)

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization, common role, inventory structure, and playbook scaffolding

- [ ] T001 Create Ansible project directory structure per plan.md in repository root
- [ ] T002 [P] Create ansible.cfg with role paths and inventory settings at repository root
- [ ] T003 [P] Create requirements.yml with FreeIPA collection dependency at repository root
- [ ] T004 [P] Create inventory/hosts.yml with zone groups (management, internal, restricted, public)
- [ ] T005 [P] Create inventory/group_vars/all.yml with common variables per data-model.md
- [ ] T006 [P] Create inventory/group_vars/management.yml with management zone overrides
- [ ] T007 [P] Create inventory/group_vars/internal.yml with internal zone overrides
- [ ] T008 [P] Create inventory/group_vars/restricted.yml with HPC-tailored restricted zone overrides
- [ ] T009 [P] Create inventory/group_vars/public.yml with public zone overrides
- [ ] T010 Create tests/lint/ansible-lint.yml configuration file
- [ ] T011 [P] Create tests/lint/yamllint.yml configuration file

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Common role with zone validation, site playbooks, and lint validation infrastructure

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T012 Create roles/common/tasks/validate_zone.yml with zone assertion per research.md Decision 1
- [ ] T013 [P] Create roles/common/tasks/main.yml that includes validate_zone.yml
- [ ] T014 [P] Create roles/common/defaults/main.yml with common variable documentation
- [ ] T015 [P] Create roles/common/meta/main.yml with role metadata
- [ ] T016 [P] Create roles/common/README.md with zone validation documentation
- [ ] T017 Create playbooks/site.yml master playbook that includes all roles in dependency order
- [ ] T018 [P] Create playbooks/verify.yml that runs verify.yml tasks from all roles
- [ ] T019 [P] Create playbooks/evidence.yml that runs evidence.yml tasks from all roles
- [ ] T020 [P] Create playbooks/zone_specific/management.yml for management zone deployment
- [ ] T021 [P] Create playbooks/zone_specific/internal.yml for internal zone deployment
- [ ] T022 [P] Create playbooks/zone_specific/restricted.yml for restricted zone deployment
- [ ] T023 [P] Create playbooks/zone_specific/public.yml for public zone deployment
- [ ] T024 Validate ansible-lint passes on roles/common/ structure
- [ ] T025 Validate yamllint passes on all YAML files in inventory/ and roles/common/

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Comprehensive Audit Logging (Priority: P1) 🎯 MVP

**Goal**: Deploy zone-aware audit logging with centralized Wazuh forwarding and immutable log protection

**Independent Test**: Deploy AU roles to test RHEL 9 VM, generate audit events (login, sudo, file access), verify events appear in Wazuh with correct timestamps and zone-appropriate detail levels

### AU Role: au_auditd

- [ ] T026 [P] [US1] Create roles/au_auditd/defaults/main.yml with audit configuration variables per data-model.md
- [ ] T027 [P] [US1] Create roles/au_auditd/meta/main.yml declaring common role dependency and AU control metadata
- [ ] T028 [P] [US1] Create roles/au_auditd/templates/audit.rules.j2 with zone-aware audit rules (comprehensive/minimal profiles)
- [ ] T029 [P] [US1] Create roles/au_auditd/templates/auditd.conf.j2 with log rotation and space handling
- [ ] T030 [US1] Create roles/au_auditd/tasks/main.yml implementing auditd deployment with control tags (r2_3.3.1, r2_3.3.2, family_AU)
- [ ] T031 [P] [US1] Create roles/au_auditd/tasks/verify.yml checking auditd service status and rules loaded
- [ ] T032 [P] [US1] Create roles/au_auditd/tasks/evidence.yml collecting audit configuration and loaded rules
- [ ] T033 [P] [US1] Create roles/au_auditd/handlers/main.yml with auditd restart handler
- [ ] T034 [P] [US1] Create roles/au_auditd/README.md with plain-language "What This Does" section

### AU Role: au_rsyslog

- [ ] T035 [P] [US1] Create roles/au_rsyslog/defaults/main.yml with TLS forwarding configuration
- [ ] T036 [P] [US1] Create roles/au_rsyslog/meta/main.yml declaring au_auditd dependency
- [ ] T037 [P] [US1] Create roles/au_rsyslog/templates/rsyslog-remote.conf.j2 with TLS forwarding to Wazuh
- [ ] T038 [US1] Create roles/au_rsyslog/tasks/main.yml implementing rsyslog forwarding with control tags
- [ ] T039 [P] [US1] Create roles/au_rsyslog/tasks/verify.yml checking rsyslog service and TLS configuration
- [ ] T040 [P] [US1] Create roles/au_rsyslog/tasks/evidence.yml collecting rsyslog configuration
- [ ] T041 [P] [US1] Create roles/au_rsyslog/handlers/main.yml with rsyslog restart handler
- [ ] T042 [P] [US1] Create roles/au_rsyslog/README.md with plain-language documentation

### AU Role: au_chrony

- [ ] T043 [P] [US1] Create roles/au_chrony/defaults/main.yml with NTP configuration
- [ ] T044 [P] [US1] Create roles/au_chrony/meta/main.yml with role metadata
- [ ] T045 [P] [US1] Create roles/au_chrony/templates/chrony.conf.j2 with authenticated NTP sources
- [ ] T046 [US1] Create roles/au_chrony/tasks/main.yml implementing chrony deployment with AU-8 tags
- [ ] T047 [P] [US1] Create roles/au_chrony/tasks/verify.yml checking time sync status
- [ ] T048 [P] [US1] Create roles/au_chrony/tasks/evidence.yml collecting NTP configuration and drift
- [ ] T049 [P] [US1] Create roles/au_chrony/handlers/main.yml with chronyd restart handler
- [ ] T050 [P] [US1] Create roles/au_chrony/README.md with plain-language documentation

### AU Role: au_wazuh_agent

- [ ] T051 [P] [US1] Create roles/au_wazuh_agent/defaults/main.yml with Wazuh agent configuration
- [ ] T052 [P] [US1] Create roles/au_wazuh_agent/meta/main.yml declaring au_rsyslog dependency
- [ ] T053 [P] [US1] Create roles/au_wazuh_agent/templates/ossec.conf.j2 with agent configuration
- [ ] T054 [US1] Create roles/au_wazuh_agent/tasks/main.yml implementing Wazuh agent deployment
- [ ] T055 [P] [US1] Create roles/au_wazuh_agent/tasks/verify.yml checking agent connectivity to manager
- [ ] T056 [P] [US1] Create roles/au_wazuh_agent/tasks/evidence.yml collecting agent status and configuration
- [ ] T057 [P] [US1] Create roles/au_wazuh_agent/handlers/main.yml with wazuh-agent restart handler
- [ ] T058 [P] [US1] Create roles/au_wazuh_agent/README.md with plain-language documentation

### AU Role: au_log_protection

- [ ] T059 [P] [US1] Create roles/au_log_protection/defaults/main.yml with log protection and retention config
- [ ] T060 [P] [US1] Create roles/au_log_protection/meta/main.yml declaring au_auditd dependency
- [ ] T061 [P] [US1] Create roles/au_log_protection/templates/audit-logrotate.j2 with 3-year retention
- [ ] T062 [US1] Create roles/au_log_protection/tasks/main.yml implementing immutable attributes and partition check
- [ ] T063 [P] [US1] Create roles/au_log_protection/tasks/verify.yml checking log immutability and partition
- [ ] T064 [P] [US1] Create roles/au_log_protection/tasks/evidence.yml collecting log protection status
- [ ] T065 [P] [US1] Create roles/au_log_protection/README.md with plain-language documentation

### US1 Integration

- [ ] T066 [US1] Update playbooks/site.yml to include AU roles in correct dependency order
- [ ] T067 [US1] Run ansible-lint on all roles/au_* directories
- [ ] T068 [US1] Run yamllint on all roles/au_* YAML files

**Checkpoint**: User Story 1 (Audit Logging) is independently deployable and testable

---

## Phase 4: User Story 2 - Identity and MFA Without Breaking Batch Jobs (Priority: P1)

**Goal**: Enforce FreeIPA enrollment, Duo MFA for interactive access, SSH certificate trust for batch jobs, password policy, and break-glass emergency access

**Independent Test**: Enroll test VM in FreeIPA, verify Duo MFA prompts for interactive SSH, submit batch job via Slurm without MFA prompt, verify password policy enforcement and inactive account disabling

### IA Role: ia_freeipa_client

- [ ] T069 [P] [US2] Create roles/ia_freeipa_client/defaults/main.yml with FreeIPA enrollment configuration
- [ ] T070 [P] [US2] Create roles/ia_freeipa_client/meta/main.yml declaring au_chrony dependency (NTP required for Kerberos)
- [ ] T071 [US2] Create roles/ia_freeipa_client/tasks/main.yml implementing FreeIPA enrollment with retry logic per research.md Decision 4
- [ ] T072 [P] [US2] Create roles/ia_freeipa_client/tasks/verify.yml checking enrollment status and Kerberos ticket
- [ ] T073 [P] [US2] Create roles/ia_freeipa_client/tasks/evidence.yml collecting enrollment and sssd configuration
- [ ] T074 [P] [US2] Create roles/ia_freeipa_client/handlers/main.yml with sssd restart handler
- [ ] T075 [P] [US2] Create roles/ia_freeipa_client/README.md with plain-language documentation

### IA Role: ia_duo_mfa

- [ ] T076 [P] [US2] Create roles/ia_duo_mfa/defaults/main.yml with Duo configuration and bypass settings
- [ ] T077 [P] [US2] Create roles/ia_duo_mfa/meta/main.yml declaring ia_freeipa_client dependency
- [ ] T078 [P] [US2] Create roles/ia_duo_mfa/templates/pam_duo.conf.j2 with Duo API configuration
- [ ] T079 [P] [US2] Create roles/ia_duo_mfa/templates/sshd-pam.j2 with group-based MFA bypass per research.md Decision 5
- [ ] T080 [P] [US2] Create roles/ia_duo_mfa/files/check-ssh-cert-auth.sh for SSH certificate detection
- [ ] T081 [US2] Create roles/ia_duo_mfa/tasks/main.yml implementing Duo PAM with batch job bypass
- [ ] T082 [P] [US2] Create roles/ia_duo_mfa/tasks/verify.yml checking Duo configuration and PAM setup
- [ ] T083 [P] [US2] Create roles/ia_duo_mfa/tasks/evidence.yml collecting MFA configuration (secrets redacted)
- [ ] T084 [P] [US2] Create roles/ia_duo_mfa/handlers/main.yml with sshd restart handler
- [ ] T085 [P] [US2] Create roles/ia_duo_mfa/README.md with plain-language documentation

### IA Role: ia_ssh_ca

- [ ] T086 [P] [US2] Create roles/ia_ssh_ca/defaults/main.yml with SSH CA configuration
- [ ] T087 [P] [US2] Create roles/ia_ssh_ca/meta/main.yml declaring ia_freeipa_client dependency
- [ ] T088 [P] [US2] Create roles/ia_ssh_ca/templates/sshd_config_ca.j2 with CA trust configuration
- [ ] T089 [US2] Create roles/ia_ssh_ca/tasks/main.yml implementing SSH CA trust for batch job auth
- [ ] T090 [P] [US2] Create roles/ia_ssh_ca/tasks/verify.yml checking CA trust configuration
- [ ] T091 [P] [US2] Create roles/ia_ssh_ca/tasks/evidence.yml collecting SSH CA configuration
- [ ] T092 [P] [US2] Create roles/ia_ssh_ca/README.md with plain-language documentation

### IA Role: ia_password_policy

- [ ] T093 [P] [US2] Create roles/ia_password_policy/defaults/main.yml with ODP-derived password requirements
- [ ] T094 [P] [US2] Create roles/ia_password_policy/meta/main.yml declaring ia_freeipa_client dependency
- [ ] T095 [P] [US2] Create roles/ia_password_policy/templates/pwquality.conf.j2 with complexity requirements
- [ ] T096 [US2] Create roles/ia_password_policy/tasks/main.yml implementing password policy per IA-5(1)
- [ ] T097 [P] [US2] Create roles/ia_password_policy/tasks/verify.yml checking pwquality configuration
- [ ] T098 [P] [US2] Create roles/ia_password_policy/tasks/evidence.yml collecting password policy settings
- [ ] T099 [P] [US2] Create roles/ia_password_policy/README.md with plain-language documentation

### IA Role: ia_account_lifecycle

- [ ] T100 [P] [US2] Create roles/ia_account_lifecycle/defaults/main.yml with inactive account threshold (90 days)
- [ ] T101 [P] [US2] Create roles/ia_account_lifecycle/meta/main.yml declaring ia_freeipa_client dependency
- [ ] T102 [US2] Create roles/ia_account_lifecycle/tasks/main.yml implementing inactive account disabling
- [ ] T103 [P] [US2] Create roles/ia_account_lifecycle/tasks/verify.yml reporting accounts inactive >90 days
- [ ] T104 [P] [US2] Create roles/ia_account_lifecycle/tasks/evidence.yml collecting account lifecycle actions
- [ ] T105 [P] [US2] Create roles/ia_account_lifecycle/README.md with plain-language documentation

### IA Role: ia_breakglass

- [ ] T106 [P] [US2] Create roles/ia_breakglass/defaults/main.yml with break-glass account configuration
- [ ] T107 [P] [US2] Create roles/ia_breakglass/meta/main.yml declaring ia_duo_mfa dependency
- [ ] T108 [P] [US2] Create roles/ia_breakglass/templates/yubikey-pam.j2 with YubiKey authentication
- [ ] T109 [P] [US2] Create roles/ia_breakglass/templates/breakglass-audit.rules.j2 for break-glass access logging
- [ ] T110 [US2] Create roles/ia_breakglass/tasks/main.yml implementing break-glass accounts per FR-049
- [ ] T111 [P] [US2] Create roles/ia_breakglass/tasks/verify.yml checking break-glass configuration
- [ ] T112 [P] [US2] Create roles/ia_breakglass/tasks/evidence.yml collecting break-glass setup (secrets redacted)
- [ ] T113 [P] [US2] Create roles/ia_breakglass/README.md with plain-language documentation

### US2 Integration

- [ ] T114 [US2] Update playbooks/site.yml to include IA roles after AU roles
- [ ] T115 [US2] Run ansible-lint on all roles/ia_* directories
- [ ] T116 [US2] Run yamllint on all roles/ia_* YAML files

**Checkpoint**: User Story 2 (Identity & MFA) is independently deployable and testable

---

## Phase 5: User Story 3 - Zone-Aware Access Controls (Priority: P1)

**Goal**: Implement RBAC, SSH hardening, session timeouts (zone-aware), USB blocking, login banner, and SELinux enforcement

**Independent Test**: Deploy AC roles to login and compute nodes, verify 15-minute session timeout on login nodes, long sessions allowed on compute nodes, USBGuard blocks storage, sudo restricted to whitelisted commands, SELinux enforcing

### AC Role: ac_pam_access

- [ ] T117 [P] [US3] Create roles/ac_pam_access/defaults/main.yml with deny-by-default PAM configuration
- [ ] T118 [P] [US3] Create roles/ac_pam_access/meta/main.yml declaring ia_freeipa_client dependency
- [ ] T119 [P] [US3] Create roles/ac_pam_access/templates/access.conf.j2 with group-based access rules
- [ ] T120 [US3] Create roles/ac_pam_access/tasks/main.yml implementing PAM access restrictions
- [ ] T121 [P] [US3] Create roles/ac_pam_access/tasks/verify.yml checking PAM access configuration
- [ ] T122 [P] [US3] Create roles/ac_pam_access/tasks/evidence.yml collecting access.conf and PAM settings
- [ ] T123 [P] [US3] Create roles/ac_pam_access/README.md with plain-language documentation

### AC Role: ac_rbac

- [ ] T124 [P] [US3] Create roles/ac_rbac/defaults/main.yml with sudo rule definitions per data-model.md
- [ ] T125 [P] [US3] Create roles/ac_rbac/meta/main.yml declaring ia_freeipa_client dependency
- [ ] T126 [P] [US3] Create roles/ac_rbac/templates/sudoers.j2 with RBAC command whitelists
- [ ] T127 [US3] Create roles/ac_rbac/tasks/main.yml implementing RBAC via sudo per AC-6(7)
- [ ] T128 [P] [US3] Create roles/ac_rbac/tasks/verify.yml checking sudo configuration
- [ ] T129 [P] [US3] Create roles/ac_rbac/tasks/evidence.yml collecting sudo rules and group mappings
- [ ] T130 [P] [US3] Create roles/ac_rbac/README.md with plain-language documentation

### AC Role: ac_ssh_hardening

- [ ] T131 [P] [US3] Create roles/ac_ssh_hardening/defaults/main.yml with zone-aware SSH configuration
- [ ] T132 [P] [US3] Create roles/ac_ssh_hardening/meta/main.yml declaring ia_duo_mfa and ia_ssh_ca dependencies
- [ ] T133 [P] [US3] Create roles/ac_ssh_hardening/templates/sshd_config.j2 with FIPS-compliant ciphers
- [ ] T134 [US3] Create roles/ac_ssh_hardening/tasks/main.yml implementing zone-specific SSH hardening
- [ ] T135 [P] [US3] Create roles/ac_ssh_hardening/tasks/verify.yml checking SSH configuration and ciphers
- [ ] T136 [P] [US3] Create roles/ac_ssh_hardening/tasks/evidence.yml collecting sshd_config and crypto settings
- [ ] T137 [P] [US3] Create roles/ac_ssh_hardening/handlers/main.yml with sshd restart handler
- [ ] T138 [P] [US3] Create roles/ac_ssh_hardening/README.md with plain-language documentation

### AC Role: ac_session_timeout

- [ ] T139 [P] [US3] Create roles/ac_session_timeout/defaults/main.yml with zone-aware timeout settings
- [ ] T140 [P] [US3] Create roles/ac_session_timeout/meta/main.yml with role metadata
- [ ] T141 [P] [US3] Create roles/ac_session_timeout/templates/profile_tmout.sh.j2 for shell timeout
- [ ] T142 [US3] Create roles/ac_session_timeout/tasks/main.yml implementing session timeout (0 for restricted zone)
- [ ] T143 [P] [US3] Create roles/ac_session_timeout/tasks/verify.yml checking TMOUT and logind settings
- [ ] T144 [P] [US3] Create roles/ac_session_timeout/tasks/evidence.yml collecting timeout configuration
- [ ] T145 [P] [US3] Create roles/ac_session_timeout/README.md with HPC tailoring explanation

### AC Role: ac_login_banner

- [ ] T146 [P] [US3] Create roles/ac_login_banner/defaults/main.yml with banner text per data-model.md
- [ ] T147 [P] [US3] Create roles/ac_login_banner/meta/main.yml with role metadata
- [ ] T148 [P] [US3] Create roles/ac_login_banner/templates/issue.j2 with authorization warning
- [ ] T149 [US3] Create roles/ac_login_banner/tasks/main.yml deploying login banner per AC-8
- [ ] T150 [P] [US3] Create roles/ac_login_banner/tasks/verify.yml checking banner presence
- [ ] T151 [P] [US3] Create roles/ac_login_banner/tasks/evidence.yml collecting banner content
- [ ] T152 [P] [US3] Create roles/ac_login_banner/README.md with plain-language documentation

### AC Role: ac_usbguard

- [ ] T153 [P] [US3] Create roles/ac_usbguard/defaults/main.yml with USB policy configuration
- [ ] T154 [P] [US3] Create roles/ac_usbguard/meta/main.yml with role metadata
- [ ] T155 [P] [US3] Create roles/ac_usbguard/templates/rules.conf.j2 with storage blocking rules
- [ ] T156 [US3] Create roles/ac_usbguard/tasks/main.yml implementing USBGuard per MP-7
- [ ] T157 [P] [US3] Create roles/ac_usbguard/tasks/verify.yml checking USBGuard policy
- [ ] T158 [P] [US3] Create roles/ac_usbguard/tasks/evidence.yml collecting USB policy
- [ ] T159 [P] [US3] Create roles/ac_usbguard/handlers/main.yml with usbguard restart handler
- [ ] T160 [P] [US3] Create roles/ac_usbguard/README.md with plain-language documentation

### AC Role: ac_selinux

- [ ] T161 [P] [US3] Create roles/ac_selinux/defaults/main.yml with SELinux enforcing configuration
- [ ] T162 [P] [US3] Create roles/ac_selinux/meta/main.yml with role metadata
- [ ] T163 [US3] Create roles/ac_selinux/tasks/main.yml implementing SELinux enforcing mode
- [ ] T164 [P] [US3] Create roles/ac_selinux/tasks/verify.yml checking SELinux status and denials
- [ ] T165 [P] [US3] Create roles/ac_selinux/tasks/evidence.yml collecting SELinux status and policy
- [ ] T166 [P] [US3] Create roles/ac_selinux/README.md with plain-language documentation

### US3 Integration

- [ ] T167 [US3] Update playbooks/site.yml to include AC roles after IA roles
- [ ] T168 [US3] Run ansible-lint on all roles/ac_* directories
- [ ] T169 [US3] Run yamllint on all roles/ac_* YAML files

**Checkpoint**: User Story 3 (Access Control) is independently deployable and testable

---

## Phase 6: User Story 4 - Security Baseline with FIPS and Minimal Configuration (Priority: P2)

**Goal**: Establish hardened baseline with OpenSCAP CUI profile, FIPS mode, minimal packages, service hardening, kernel hardening, and AIDE file integrity

**Independent Test**: Deploy CM roles to fresh VM, reboot for FIPS, run OpenSCAP assessment showing >85% compliance, verify only zone-required packages installed, unnecessary services disabled, kernel hardening applied, AIDE baseline initialized

### CM Role: cm_fips_mode

- [ ] T170 [P] [US4] Create roles/cm_fips_mode/defaults/main.yml with FIPS enablement configuration
- [ ] T171 [P] [US4] Create roles/cm_fips_mode/meta/main.yml with role metadata
- [ ] T172 [US4] Create roles/cm_fips_mode/tasks/main.yml implementing FIPS mode with reboot handling
- [ ] T173 [P] [US4] Create roles/cm_fips_mode/tasks/verify.yml checking FIPS mode and crypto-policies
- [ ] T174 [P] [US4] Create roles/cm_fips_mode/tasks/evidence.yml collecting FIPS status
- [ ] T175 [P] [US4] Create roles/cm_fips_mode/README.md with plain-language documentation

### CM Role: cm_openscap_baseline

- [ ] T176 [P] [US4] Create roles/cm_openscap_baseline/defaults/main.yml with CUI profile configuration
- [ ] T177 [P] [US4] Create roles/cm_openscap_baseline/meta/main.yml declaring ac_selinux dependency
- [ ] T178 [P] [US4] Create roles/cm_openscap_baseline/templates/cui-hpc-tailoring.xml.j2 with HPC exclusions per research.md Decision 6
- [ ] T179 [US4] Create roles/cm_openscap_baseline/tasks/main.yml implementing OpenSCAP assessment and remediation
- [ ] T180 [P] [US4] Create roles/cm_openscap_baseline/tasks/verify.yml running OpenSCAP check and reporting score
- [ ] T181 [P] [US4] Create roles/cm_openscap_baseline/tasks/evidence.yml collecting OpenSCAP results
- [ ] T182 [P] [US4] Create roles/cm_openscap_baseline/README.md with HPC tailoring explanation

### CM Role: cm_minimal_packages

- [ ] T183 [P] [US4] Create roles/cm_minimal_packages/defaults/main.yml with zone-specific package lists
- [ ] T184 [P] [US4] Create roles/cm_minimal_packages/meta/main.yml with role metadata
- [ ] T185 [US4] Create roles/cm_minimal_packages/tasks/main.yml implementing minimal package enforcement
- [ ] T186 [P] [US4] Create roles/cm_minimal_packages/tasks/verify.yml checking installed packages
- [ ] T187 [P] [US4] Create roles/cm_minimal_packages/tasks/evidence.yml collecting package inventory
- [ ] T188 [P] [US4] Create roles/cm_minimal_packages/README.md with plain-language documentation

### CM Role: cm_service_hardening

- [ ] T189 [P] [US4] Create roles/cm_service_hardening/defaults/main.yml with service disable lists
- [ ] T190 [P] [US4] Create roles/cm_service_hardening/meta/main.yml with role metadata
- [ ] T191 [US4] Create roles/cm_service_hardening/tasks/main.yml disabling cups, bluetooth, avahi
- [ ] T192 [P] [US4] Create roles/cm_service_hardening/tasks/verify.yml checking service states
- [ ] T193 [P] [US4] Create roles/cm_service_hardening/tasks/evidence.yml collecting service status
- [ ] T194 [P] [US4] Create roles/cm_service_hardening/README.md with plain-language documentation

### CM Role: cm_kernel_hardening

- [ ] T195 [P] [US4] Create roles/cm_kernel_hardening/defaults/main.yml with sysctl parameters per data-model.md
- [ ] T196 [P] [US4] Create roles/cm_kernel_hardening/meta/main.yml with role metadata
- [ ] T197 [P] [US4] Create roles/cm_kernel_hardening/templates/99-cui-hardening.conf.j2 with sysctl settings
- [ ] T198 [US4] Create roles/cm_kernel_hardening/tasks/main.yml applying kernel hardening
- [ ] T199 [P] [US4] Create roles/cm_kernel_hardening/tasks/verify.yml checking sysctl values
- [ ] T200 [P] [US4] Create roles/cm_kernel_hardening/tasks/evidence.yml collecting sysctl configuration
- [ ] T201 [P] [US4] Create roles/cm_kernel_hardening/README.md with plain-language documentation

### CM Role: cm_aide

- [ ] T202 [P] [US4] Create roles/cm_aide/defaults/main.yml with AIDE configuration per data-model.md
- [ ] T203 [P] [US4] Create roles/cm_aide/meta/main.yml declaring cm_openscap_baseline dependency
- [ ] T204 [P] [US4] Create roles/cm_aide/templates/aide.conf.j2 with monitoring paths and exclusions
- [ ] T205 [US4] Create roles/cm_aide/tasks/main.yml implementing AIDE baseline initialization
- [ ] T206 [P] [US4] Create roles/cm_aide/tasks/verify.yml running AIDE check for changes
- [ ] T207 [P] [US4] Create roles/cm_aide/tasks/evidence.yml collecting AIDE baseline report
- [ ] T208 [P] [US4] Create roles/cm_aide/README.md with plain-language documentation

### US4 Integration

- [ ] T209 [US4] Update playbooks/site.yml to include CM roles (cm_fips_mode early for reboot)
- [ ] T210 [US4] Run ansible-lint on all roles/cm_* directories
- [ ] T211 [US4] Run yamllint on all roles/cm_* YAML files

**Checkpoint**: User Story 4 (Configuration Management) is independently deployable and testable

---

## Phase 7: User Story 5 - Zone-Aware Firewalls and Cryptographic Protections (Priority: P2)

**Goal**: Deploy nftables firewalls with zone-specific rulesets, enforce TLS 1.2+, verify FIPS crypto-policies, verify LUKS encryption, implement network segmentation templates

**Independent Test**: Deploy SC roles to systems in different zones, verify nftables allows only zone-required ports, TLS weak ciphers rejected, crypto-policies FIPS:OSPP, LUKS verified on /data partition

### SC Role: sc_nftables

- [ ] T212 [P] [US5] Create roles/sc_nftables/defaults/main.yml with zone firewall rule definitions per data-model.md
- [ ] T213 [P] [US5] Create roles/sc_nftables/meta/main.yml with role metadata
- [ ] T214 [P] [US5] Create roles/sc_nftables/templates/nftables.conf.j2 with default-deny and zone rules
- [ ] T215 [US5] Create roles/sc_nftables/tasks/main.yml implementing zone-specific firewall rules
- [ ] T216 [P] [US5] Create roles/sc_nftables/tasks/verify.yml checking nftables ruleset
- [ ] T217 [P] [US5] Create roles/sc_nftables/tasks/evidence.yml collecting firewall rules
- [ ] T218 [P] [US5] Create roles/sc_nftables/handlers/main.yml with nftables restart handler
- [ ] T219 [P] [US5] Create roles/sc_nftables/README.md with zone firewall explanation

### SC Role: sc_tls_enforcement

- [ ] T220 [P] [US5] Create roles/sc_tls_enforcement/defaults/main.yml with TLS policy configuration
- [ ] T221 [P] [US5] Create roles/sc_tls_enforcement/meta/main.yml declaring cm_fips_mode dependency
- [ ] T222 [US5] Create roles/sc_tls_enforcement/tasks/main.yml enforcing TLS 1.2+ and disabling weak ciphers
- [ ] T223 [P] [US5] Create roles/sc_tls_enforcement/tasks/verify.yml checking crypto-policies
- [ ] T224 [P] [US5] Create roles/sc_tls_enforcement/tasks/evidence.yml collecting TLS configuration
- [ ] T225 [P] [US5] Create roles/sc_tls_enforcement/README.md with plain-language documentation

### SC Role: sc_luks_verification

- [ ] T226 [P] [US5] Create roles/sc_luks_verification/defaults/main.yml with required encrypted partitions
- [ ] T227 [P] [US5] Create roles/sc_luks_verification/meta/main.yml with role metadata
- [ ] T228 [US5] Create roles/sc_luks_verification/tasks/main.yml (verify-only - no implementation)
- [ ] T229 [P] [US5] Create roles/sc_luks_verification/tasks/verify.yml checking LUKS encryption status
- [ ] T230 [P] [US5] Create roles/sc_luks_verification/tasks/evidence.yml collecting encryption evidence
- [ ] T231 [P] [US5] Create roles/sc_luks_verification/README.md with plain-language documentation

### SC Role: sc_network_segmentation

- [ ] T232 [P] [US5] Create roles/sc_network_segmentation/defaults/main.yml with VLAN templates
- [ ] T233 [P] [US5] Create roles/sc_network_segmentation/meta/main.yml with role metadata
- [ ] T234 [US5] Create roles/sc_network_segmentation/tasks/main.yml configuring zone network interfaces
- [ ] T235 [P] [US5] Create roles/sc_network_segmentation/tasks/verify.yml checking VLAN assignments
- [ ] T236 [P] [US5] Create roles/sc_network_segmentation/tasks/evidence.yml collecting network configuration
- [ ] T237 [P] [US5] Create roles/sc_network_segmentation/README.md with zone network explanation

### US5 Integration

- [ ] T238 [US5] Update playbooks/site.yml to include SC roles
- [ ] T239 [US5] Run ansible-lint on all roles/sc_* directories
- [ ] T240 [US5] Run yamllint on all roles/sc_* YAML files

**Checkpoint**: User Story 5 (System & Communications Protection) is independently deployable and testable

---

## Phase 8: User Story 6 - Automated Patching and Malware Protection (Priority: P3)

**Goal**: Deploy dnf-automatic for security patching, ClamAV with HPC-aware exclusions, AIDE integrity monitoring, OpenSCAP OVAL vulnerability scanning

**Independent Test**: Deploy SI roles to test system, trigger dnf-automatic, verify ClamAV excludes /scratch and /tmp, run AIDE check, execute OVAL scan reporting CVEs

### SI Role: si_dnf_automatic

- [ ] T241 [P] [US6] Create roles/si_dnf_automatic/defaults/main.yml with patching configuration
- [ ] T242 [P] [US6] Create roles/si_dnf_automatic/meta/main.yml with role metadata
- [ ] T243 [P] [US6] Create roles/si_dnf_automatic/templates/dnf-automatic.conf.j2 with security updates
- [ ] T244 [US6] Create roles/si_dnf_automatic/tasks/main.yml implementing automated patching
- [ ] T245 [P] [US6] Create roles/si_dnf_automatic/tasks/verify.yml checking dnf-automatic configuration
- [ ] T246 [P] [US6] Create roles/si_dnf_automatic/tasks/evidence.yml collecting patching configuration
- [ ] T247 [P] [US6] Create roles/si_dnf_automatic/README.md with plain-language documentation

### SI Role: si_clamav

- [ ] T248 [P] [US6] Create roles/si_clamav/defaults/main.yml with HPC-aware exclusions per data-model.md
- [ ] T249 [P] [US6] Create roles/si_clamav/meta/main.yml with role metadata
- [ ] T250 [P] [US6] Create roles/si_clamav/templates/clamd.conf.j2 with performance exclusions
- [ ] T251 [P] [US6] Create roles/si_clamav/templates/freshclam.conf.j2 for database updates
- [ ] T252 [US6] Create roles/si_clamav/tasks/main.yml implementing ClamAV with /scratch exclusion
- [ ] T253 [P] [US6] Create roles/si_clamav/tasks/verify.yml checking ClamAV status and exclusions
- [ ] T254 [P] [US6] Create roles/si_clamav/tasks/evidence.yml collecting AV configuration
- [ ] T255 [P] [US6] Create roles/si_clamav/handlers/main.yml with clamd restart handler
- [ ] T256 [P] [US6] Create roles/si_clamav/README.md with HPC exclusion explanation

### SI Role: si_openscap_oval

- [ ] T257 [P] [US6] Create roles/si_openscap_oval/defaults/main.yml with OVAL content configuration
- [ ] T258 [P] [US6] Create roles/si_openscap_oval/meta/main.yml declaring cm_openscap_baseline dependency
- [ ] T259 [US6] Create roles/si_openscap_oval/tasks/main.yml downloading OVAL content and scheduling scans
- [ ] T260 [P] [US6] Create roles/si_openscap_oval/tasks/verify.yml executing OVAL scan and reporting CVEs
- [ ] T261 [P] [US6] Create roles/si_openscap_oval/tasks/evidence.yml collecting vulnerability report
- [ ] T262 [P] [US6] Create roles/si_openscap_oval/README.md with plain-language documentation

### US6 Integration

- [ ] T263 [US6] Update playbooks/site.yml to include SI roles
- [ ] T264 [US6] Run ansible-lint on all roles/si_* directories
- [ ] T265 [US6] Run yamllint on all roles/si_* YAML files

**Checkpoint**: User Story 6 (System & Information Integrity) is independently deployable and testable

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Final validation, control mapping updates, and documentation

- [ ] T266 [P] Update roles/common/vars/control_mapping.yml ansible_roles field with all implemented roles per FR-044
- [ ] T267 [P] Verify all roles have complete three-mode task structure (main.yml, verify.yml, evidence.yml)
- [ ] T268 [P] Verify all tasks have plain-language WHY comments per FR-042
- [ ] T269 [P] Verify all templates have plain-language header blocks per FR-039
- [ ] T270 Run full ansible-lint validation across all 24 roles per FR-045
- [ ] T271 Run full yamllint validation across all YAML files per FR-046
- [ ] T272 [P] Verify all roles support --check mode without making changes per FR-043
- [ ] T273 [P] Validate playbooks/site.yml role ordering matches dependency graph
- [ ] T274 Create tests/molecule/default/molecule.yml for role testing infrastructure
- [ ] T275 [P] Create tests/molecule/default/converge.yml for default test scenario
- [ ] T276 [P] Create tests/molecule/default/verify.yml for verification assertions
- [ ] T277 [P] Create tests/molecule/openscap/verify.yml for CUI profile validation
- [ ] T278 Run quickstart.md validation with dry-run deployment

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3-8)**: All depend on Foundational phase completion
  - US1-US3 are P1 priority - implement first
  - US4-US5 are P2 priority - implement after P1 complete
  - US6 is P3 priority - implement last
- **Polish (Phase 9)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (AU - P1)**: Can start after Foundational - No dependencies on other stories
- **User Story 2 (IA - P1)**: Depends on US1 (au_chrony required for Kerberos)
- **User Story 3 (AC - P1)**: Depends on US2 (ia_freeipa_client, ia_duo_mfa required)
- **User Story 4 (CM - P2)**: Depends on US3 (ac_selinux required for OpenSCAP)
- **User Story 5 (SC - P2)**: Depends on US4 (cm_fips_mode required)
- **User Story 6 (SI - P3)**: Depends on US4 (cm_openscap_baseline for OVAL)

### Role Dependencies (within stories)

```text
AU: common → au_auditd → au_rsyslog → au_wazuh_agent
          → au_chrony
          → au_log_protection

IA: au_chrony → ia_freeipa_client → ia_duo_mfa → ia_breakglass
                                  → ia_ssh_ca
                                  → ia_password_policy
                                  → ia_account_lifecycle

AC: ia_freeipa_client → ac_pam_access
                      → ac_rbac
    ia_duo_mfa + ia_ssh_ca → ac_ssh_hardening
    common → ac_session_timeout
           → ac_login_banner
           → ac_usbguard
           → ac_selinux

CM: common → cm_fips_mode (early - requires reboot)
    ac_selinux → cm_openscap_baseline → cm_aide
    common → cm_minimal_packages
           → cm_service_hardening
           → cm_kernel_hardening

SC: common → sc_nftables
    cm_fips_mode → sc_tls_enforcement
    common → sc_luks_verification
           → sc_network_segmentation

SI: common → si_dnf_automatic
           → si_clamav
    cm_openscap_baseline → si_openscap_oval
```

### Parallel Opportunities

- **Setup Phase**: All T002-T011 can run in parallel
- **Foundational Phase**: T012-T023 playbooks can run in parallel after common role
- **Within Each User Story**:
  - All `defaults/main.yml`, `meta/main.yml`, `templates/`, `README.md` files marked [P] can be created in parallel
  - `tasks/main.yml` depends on templates but `tasks/verify.yml` and `tasks/evidence.yml` are independent
- **Across User Stories**: With sufficient team capacity, US1-US6 can progress in parallel respecting dependency chain

---

## Parallel Example: User Story 1 (AU Roles)

```bash
# Launch all defaults/main.yml files in parallel:
Task: T026 "Create roles/au_auditd/defaults/main.yml"
Task: T035 "Create roles/au_rsyslog/defaults/main.yml"
Task: T043 "Create roles/au_chrony/defaults/main.yml"
Task: T051 "Create roles/au_wazuh_agent/defaults/main.yml"
Task: T059 "Create roles/au_log_protection/defaults/main.yml"

# Launch all meta/main.yml files in parallel:
Task: T027 "Create roles/au_auditd/meta/main.yml"
Task: T036 "Create roles/au_rsyslog/meta/main.yml"
Task: T044 "Create roles/au_chrony/meta/main.yml"
Task: T052 "Create roles/au_wazuh_agent/meta/main.yml"
Task: T060 "Create roles/au_log_protection/meta/main.yml"

# Launch all templates in parallel:
Task: T028 "Create roles/au_auditd/templates/audit.rules.j2"
Task: T037 "Create roles/au_rsyslog/templates/rsyslog-remote.conf.j2"
Task: T045 "Create roles/au_chrony/templates/chrony.conf.j2"
Task: T053 "Create roles/au_wazuh_agent/templates/ossec.conf.j2"
Task: T061 "Create roles/au_log_protection/templates/audit-logrotate.j2"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1 (AU - Audit Logging)
4. **STOP and VALIDATE**: Deploy AU roles to test VM, verify events in Wazuh
5. Deploy to production audit logging infrastructure

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 (AU) → Test independently → Audit infrastructure operational (MVP!)
3. Add User Story 2 (IA) → Test independently → Identity/MFA deployed
4. Add User Story 3 (AC) → Test independently → Access controls enforced
5. Add User Story 4 (CM) → Test independently → FIPS baseline established
6. Add User Story 5 (SC) → Test independently → Firewall/crypto deployed
7. Add User Story 6 (SI) → Test independently → Patching/AV operational
8. Each story adds compliance controls without breaking previous stories

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done, assign by control family:
   - Developer A: AU roles (US1)
   - Developer B: IA roles (US2) - wait for au_chrony
   - Developer C: AC roles (US3) - wait for ia_* roles
   - Developer D: CM roles (US4) - can start cm_fips_mode immediately
3. Stories complete and integrate via dependency chain
4. SC and SI roles assigned after CM foundation ready

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label (US1-US6) maps task to specific user story/control family
- Each user story is independently deployable and testable
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
- All roles must pass ansible-lint and yamllint before proceeding to next story
- Avoid: cross-story file conflicts, breaking role dependency order
