# Data Model: Ansible Role Variable Schemas

**Feature**: 002-ansible-roles-core-controls
**Date**: 2026-02-14
**Phase**: 1 - Design & Contracts
**Depends On**: [Spec 001 Data Models](../001-data-models-docs-foundation/data-model.md)

## Purpose

This document defines the variable schemas and interfaces for all Ansible roles implementing NIST 800-171 controls. These schemas ensure consistency across roles, enable zone-aware configuration, and document the contract between roles and consuming playbooks.

---

## Core Variable Inheritance Model

All roles inherit from a common base configuration defined in `group_vars/all.yml` and zone-specific overrides in `group_vars/{zone}.yml`.

```yaml
# Inheritance hierarchy (most specific wins)
1. host_vars/{hostname}.yml     # Host-specific overrides
2. group_vars/{zone}.yml        # Zone defaults (management, internal, restricted, public)
3. group_vars/all.yml           # Global defaults
4. roles/{role}/defaults/main.yml  # Role defaults (lowest priority)
```

### Common Variables Schema

```yaml
# group_vars/all.yml - REQUIRED base configuration
---
# Zone assignment - MUST be overridden in zone group_vars
# Roles fail if this is null (per FR-048)
cui_zone: null

# Organization info for evidence artifacts
cui_organization: "University Research Computing"
cui_environment: "production"  # or "staging", "development"

# ODP values consumed from Spec 001 data model
# These are the authoritative values referenced by roles
session_timeout_minutes: 15
password_min_length: 15
password_complexity_enabled: true
password_history: 24
password_max_age_days: 365
inactive_account_days: 90
audit_log_retention_years: 3
failed_login_lockout_threshold: 3
failed_login_lockout_duration_minutes: 15

# Infrastructure endpoints (required by roles)
freeipa_servers:
  - ipa01.example.edu
  - ipa02.example.edu
freeipa_domain: "example.edu"
freeipa_realm: "EXAMPLE.EDU"

wazuh_manager_host: "wazuh.example.edu"
wazuh_manager_port: 1514

ntp_servers:
  - time1.example.edu
  - time2.example.edu

syslog_server: "logs.example.edu"
syslog_port: 514
syslog_protocol: "tcp"
syslog_tls_enabled: true

# Evidence collection configuration
evidence_output_dir: "/tmp/cui-evidence"
evidence_include_timestamps: true

# OpenSCAP configuration
openscap_profile: "xccdf_org.ssgproject.content_profile_cui"
openscap_content: "/usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml"
openscap_tailoring_enabled: true
```

### Zone-Specific Overrides

```yaml
# group_vars/management.yml - Management zone (bastion hosts, Ansible controllers)
---
cui_zone: management

# Stricter session timeouts for management systems
session_timeout_minutes: 10

# Full audit logging
audit_rules_profile: comprehensive

# MFA required for all access
mfa_required: true
mfa_bypass_ssh_certs: false

# All USB devices blocked
usbguard_policy: deny_all
```

```yaml
# group_vars/internal.yml - Internal zone (login nodes, user-facing systems)
---
cui_zone: internal

# Standard session timeout
session_timeout_minutes: 15

# Comprehensive audit logging
audit_rules_profile: comprehensive

# MFA required with SSH cert bypass for automation
mfa_required: true
mfa_bypass_ssh_certs: true

# USB storage blocked, HID allowed
usbguard_policy: deny_storage
```

```yaml
# group_vars/restricted.yml - Restricted zone (compute nodes, batch processing)
---
cui_zone: restricted

# Session timeout disabled for batch jobs (HPC tailoring)
session_timeout_minutes: 0

# Minimal audit logging to reduce I/O overhead
audit_rules_profile: minimal

# MFA not required - SSH certificate auth from Slurm
mfa_required: false
mfa_bypass_ssh_certs: true

# USB devices not applicable (no physical access)
usbguard_policy: deny_all

# ClamAV performance tuning
clamav_realtime_scan: false
clamav_scheduled_scan_hour: 3  # 3 AM off-peak

# OpenSCAP HPC exclusions (per research.md Decision 6)
openscap_skip_rules:
  - "xccdf_org.ssgproject.content_rule_accounts_tmout"
  - "xccdf_org.ssgproject.content_rule_package_screen_lock"
  - "xccdf_org.ssgproject.content_rule_dconf_gnome_screensaver_idle_delay"
```

```yaml
# group_vars/public.yml - Public zone (web servers, API endpoints)
---
cui_zone: public

# Strict session timeout
session_timeout_minutes: 10

# Full audit logging
audit_rules_profile: comprehensive

# MFA required
mfa_required: true

# Strictest firewall rules
firewall_default_zone: drop
```

---

## Role Interface Schemas

### AU Family Roles

#### au_auditd

Deploys and configures auditd with zone-appropriate audit rules.

```yaml
# roles/au_auditd/defaults/main.yml
---
# Audit rules profile: comprehensive, standard, minimal
# Default is "standard" but overridden by zone group_vars
audit_rules_profile: standard

# Audit log configuration
audit_log_path: /var/log/audit/audit.log
audit_log_max_size_mb: 50
audit_log_num_logs: 8
audit_log_format: ENRICHED

# Space handling
audit_space_left_action: email
audit_admin_space_left_action: halt
audit_disk_full_action: halt
audit_disk_error_action: halt

# Email notifications
audit_action_mail_acct: root

# CUI-specific audit rules
audit_cui_data_paths:
  - /data/cui
  - /home/*/cui
  - /projects/*/cui

# Excluded paths for performance (HPC scratch)
audit_exclude_paths:
  - /scratch
  - /tmp
  - /dev/shm
```

**Implements Controls**: AU-2, AU-3, AU-6, AU-8, AU-9, AU-12
**Tags**: `r2_3.3.1`, `r2_3.3.2`, `r3_03.03.01`, `r3_03.03.02`, `family_AU`

---

#### au_rsyslog

Configures rsyslog to forward audit logs via TLS to centralized SIEM.

```yaml
# roles/au_rsyslog/defaults/main.yml
---
# Remote logging configuration (from group_vars/all.yml)
rsyslog_remote_host: "{{ syslog_server }}"
rsyslog_remote_port: "{{ syslog_port }}"
rsyslog_protocol: "{{ syslog_protocol }}"

# TLS configuration
rsyslog_tls_enabled: "{{ syslog_tls_enabled }}"
rsyslog_tls_ca_file: /etc/pki/rsyslog/ca.pem
rsyslog_tls_cert_file: /etc/pki/rsyslog/client-cert.pem
rsyslog_tls_key_file: /etc/pki/rsyslog/client-key.pem

# Queue configuration for reliability
rsyslog_queue_type: LinkedList
rsyslog_queue_filename: rsyslog_fwd
rsyslog_queue_max_disk_space: 1g
rsyslog_queue_save_on_shutdown: true
rsyslog_action_resume_retry_count: -1

# Log forwarding selection
rsyslog_forward_facilities:
  - authpriv.*
  - auth.*
  - local6.*
```

**Implements Controls**: AU-4, AU-6(3)
**Tags**: `r2_3.3.4`, `r3_03.03.04`, `family_AU`

---

#### au_chrony

Configures chrony for authenticated NTP time synchronization.

```yaml
# roles/au_chrony/defaults/main.yml
---
# NTP servers (from group_vars/all.yml)
chrony_ntp_servers: "{{ ntp_servers }}"

# Authentication
chrony_nts_enabled: true  # Network Time Security
chrony_key_file: /etc/chrony.keys

# Stratum and accuracy
chrony_max_stratum: 3
chrony_max_drift_ppm: 100

# RTC synchronization
chrony_sync_rtc: true

# Makestep (large initial adjustment)
chrony_makestep_threshold: 1.0
chrony_makestep_limit: 3
```

**Implements Controls**: AU-8
**Tags**: `r2_3.3.7`, `r3_03.03.07`, `family_AU`

---

#### au_wazuh_agent

Deploys Wazuh agent for centralized SIEM integration.

```yaml
# roles/au_wazuh_agent/defaults/main.yml
---
# Wazuh manager (from group_vars/all.yml)
wazuh_manager: "{{ wazuh_manager_host }}"
wazuh_port: "{{ wazuh_manager_port }}"

# Agent registration
wazuh_agent_name: "{{ inventory_hostname }}"
wazuh_agent_group: "{{ cui_zone }}"
wazuh_registration_key: "{{ vault_wazuh_registration_key }}"

# Agent configuration
wazuh_agent_config:
  syscheck:
    frequency: 43200  # 12 hours
    directories:
      - /etc
      - /usr/bin
      - /usr/sbin
      - /boot
  rootcheck:
    frequency: 43200
  log_format: json
```

**Implements Controls**: AU-6, SI-4
**Tags**: `r2_3.3.5`, `r3_03.03.05`, `family_AU`, `family_SI`

---

#### au_log_protection

Implements audit log protection with immutable attributes and separate partition.

```yaml
# roles/au_log_protection/defaults/main.yml
---
# Log retention (from group_vars/all.yml via ODP values)
audit_retention_weeks: "{{ audit_log_retention_years | int * 52 }}"

# Immutable attributes
audit_log_immutable: true
audit_log_chattr_append: true

# Partition requirements
audit_partition_required: true
audit_partition_mount: /var/log/audit
audit_partition_min_size_gb: 10

# Logrotate configuration
audit_logrotate_frequency: weekly
audit_logrotate_compress: true
audit_logrotate_delay_compress: true
```

**Implements Controls**: AU-9
**Tags**: `r2_3.3.8`, `r2_3.3.9`, `r3_03.03.08`, `family_AU`

---

### IA Family Roles

#### ia_freeipa_client

Enrolls system in FreeIPA identity management.

```yaml
# roles/ia_freeipa_client/defaults/main.yml
---
# FreeIPA configuration (from group_vars/all.yml)
ipa_domain: "{{ freeipa_domain }}"
ipa_realm: "{{ freeipa_realm }}"
ipa_servers: "{{ freeipa_servers }}"

# Enrollment credentials (from vault)
ipa_enrollment_principal: "{{ vault_ipa_enroll_principal }}"
ipa_enrollment_password: "{{ vault_ipa_enroll_password }}"

# Enrollment behavior
ipa_force_enrollment: false
ipa_enrollment_retries: 3
ipa_enrollment_retry_delay: 30

# Client configuration
ipa_enable_dns: true
ipa_enable_ntp: false  # Managed by au_chrony
ipa_mkhomedir: true
ipa_ssh_trust_dns: true

# Kerberos configuration
ipa_krb5_ticket_lifetime: 24h
ipa_krb5_renew_lifetime: 7d
```

**Implements Controls**: IA-2, IA-4, IA-5
**Tags**: `r2_3.5.1`, `r2_3.5.2`, `r3_03.05.01`, `family_IA`

---

#### ia_duo_mfa

Deploys Duo MFA with batch job bypass capability.

```yaml
# roles/ia_duo_mfa/defaults/main.yml
---
# Duo credentials (from vault)
duo_integration_key: "{{ vault_duo_ikey }}"
duo_secret_key: "{{ vault_duo_skey }}"
duo_api_host: "api-XXXXXXXX.duosecurity.com"

# MFA policy (from zone group_vars)
duo_required: "{{ mfa_required | default(true) }}"

# Bypass configuration
duo_bypass_groups:
  - service-accounts
  - batch-job-principals
duo_bypass_ssh_certs: "{{ mfa_bypass_ssh_certs | default(false) }}"

# Failopen behavior
duo_failmode: secure  # 'secure' = deny if Duo unavailable, 'safe' = allow

# Push notification settings
duo_pushinfo: true
duo_autopush: true
duo_prompts: 1

# SSH PAM integration
duo_pam_priority: 50
```

**Implements Controls**: IA-2(1), IA-2(2)
**Tags**: `r2_3.5.3`, `r3_03.05.03`, `family_IA`

---

#### ia_ssh_ca

Configures SSH certificate authority trust for FreeIPA CA.

```yaml
# roles/ia_ssh_ca/defaults/main.yml
---
# SSH CA configuration
ssh_ca_principals_file: /etc/ssh/auth_principals/%u
ssh_ca_trusted_user_ca_keys: /etc/ssh/ca-user-key.pub
ssh_ca_host_certificate: /etc/ssh/ssh_host_rsa_key-cert.pub

# FreeIPA CA integration
ssh_ca_use_freeipa: true
ssh_ca_freeipa_ca_pubkey: "{{ ipa_ssh_ca_pubkey }}"

# Certificate validation
ssh_ca_allow_expired: false
ssh_ca_require_principals: true

# Logging
ssh_ca_log_level: INFO
```

**Implements Controls**: IA-2, IA-5(2)
**Tags**: `r2_3.5.2`, `r3_03.05.02`, `family_IA`

---

#### ia_password_policy

Enforces password complexity requirements per ODP values.

```yaml
# roles/ia_password_policy/defaults/main.yml
---
# Password length (from group_vars/all.yml via ODP)
password_minlen: "{{ password_min_length }}"

# Complexity requirements
password_minclass: 3  # At least 3 character classes
password_dcredit: -1  # At least 1 digit
password_ucredit: -1  # At least 1 uppercase
password_lcredit: -1  # At least 1 lowercase
password_ocredit: -1  # At least 1 special character
password_maxrepeat: 3
password_maxclassrepeat: 4

# Dictionary check
password_dictcheck: true
password_usercheck: true
password_gecoscheck: true

# History (from group_vars/all.yml via ODP)
password_remember: "{{ password_history }}"

# Aging (from group_vars/all.yml via ODP)
password_max_days: "{{ password_max_age_days }}"
password_min_days: 1
password_warn_age: 14
```

**Implements Controls**: IA-5(1)
**Tags**: `r2_3.5.7`, `r2_3.5.8`, `r3_03.05.07`, `family_IA`

---

#### ia_account_lifecycle

Manages account lifecycle including inactive account disabling.

```yaml
# roles/ia_account_lifecycle/defaults/main.yml
---
# Inactive account threshold (from group_vars/all.yml via ODP)
account_inactive_days: "{{ inactive_account_days }}"

# Account disable behavior
account_disable_action: disable  # 'disable' or 'lock'
account_disable_notify: true
account_disable_notify_email: "{{ admin_email }}"

# Exceptions
account_disable_exceptions:
  - root
  - ansible
  - monitoring

# Scheduled check
account_check_schedule: daily
account_check_hour: 2
account_check_minute: 0
```

**Implements Controls**: IA-4, AC-2(3)
**Tags**: `r2_3.5.6`, `r3_03.05.06`, `family_IA`

---

#### ia_breakglass

Provisions break-glass emergency access accounts with YubiKey authentication.

```yaml
# roles/ia_breakglass/defaults/main.yml
---
# Break-glass accounts (from vault)
breakglass_accounts: "{{ vault_breakglass_accounts }}"
# Structure:
# - username: breakglass01
#   owner: "Security Team"
#   yubikey_public_id: "vvccccccccc"
#   ssh_pubkey: "ssh-rsa AAAA..."

# Break-glass group
breakglass_group: breakglass-users

# PAM configuration
breakglass_pam_priority: 40  # Before Duo
breakglass_yubikey_required: true
breakglass_yubikey_id: "{{ vault_yubikey_api_id }}"
breakglass_yubikey_key: "{{ vault_yubikey_api_key }}"

# Audit requirements
breakglass_audit_enabled: true
breakglass_alert_enabled: true
breakglass_alert_command: "/usr/local/bin/breakglass-alert.sh"
```

**Implements Controls**: IA-2(1), AC-2(2)
**Tags**: `r2_3.5.3`, `r3_03.05.03`, `family_IA`, `family_AC`

---

### AC Family Roles

#### ac_pam_access

Implements PAM-based access restrictions with FreeIPA group membership.

```yaml
# roles/ac_pam_access/defaults/main.yml
---
# Default policy: deny all except explicitly allowed
pam_access_default: deny

# Allowed groups (zone-specific overrides in group_vars)
pam_access_groups:
  - cui-users
  - administrators

# Allowed origins
pam_access_origins:
  - LOCAL
  - "192.168.0.0/16"
  - "10.0.0.0/8"

# Service restrictions
pam_access_services:
  - sshd
  - login
  - su
  - sudo

# Exception users (never denied)
pam_access_exceptions:
  - root
  - ansible
```

**Implements Controls**: AC-2, AC-3
**Tags**: `r2_3.1.1`, `r2_3.1.2`, `r3_03.01.01`, `family_AC`

---

#### ac_rbac

Implements RBAC via FreeIPA groups and sudo command whitelists.

```yaml
# roles/ac_rbac/defaults/main.yml
---
# RBAC group mappings (FreeIPA group -> sudo commands)
rbac_sudo_rules:
  - name: sysadmin-full
    groups:
      - sysadmins
    commands:
      - ALL
    nopasswd: false

  - name: researcher-limited
    groups:
      - researchers
    commands:
      - /usr/bin/sbatch
      - /usr/bin/squeue
      - /usr/bin/scancel
      - /usr/bin/sinfo
    nopasswd: true

  - name: security-audit
    groups:
      - security-team
    commands:
      - /usr/sbin/ausearch
      - /usr/sbin/aureport
      - /usr/bin/oscap
    nopasswd: true

# Sudo configuration
rbac_sudo_log_input: true
rbac_sudo_log_output: true
rbac_sudo_requiretty: true
rbac_sudo_lecture: always
```

**Implements Controls**: AC-2, AC-3, AC-6(7)
**Tags**: `r2_3.1.5`, `r2_3.1.7`, `r3_03.01.05`, `family_AC`

---

#### ac_ssh_hardening

Deploys zone-specific SSH hardening configurations.

```yaml
# roles/ac_ssh_hardening/defaults/main.yml
---
# SSH protocol
ssh_protocol: 2

# Authentication
ssh_permit_root_login: "no"
ssh_password_authentication: "{{ 'no' if mfa_required else 'yes' }}"
ssh_pubkey_authentication: "yes"
ssh_permit_empty_passwords: "no"
ssh_challenge_response: "{{ 'yes' if mfa_required else 'no' }}"

# Session
ssh_client_alive_interval: 300
ssh_client_alive_count_max: "{{ (session_timeout_minutes | int * 60 / 300) | int if session_timeout_minutes > 0 else 0 }}"

# Cryptography (FIPS-compliant)
ssh_ciphers:
  - aes256-gcm@openssh.com
  - aes128-gcm@openssh.com
  - aes256-ctr
  - aes128-ctr
ssh_macs:
  - hmac-sha2-512-etm@openssh.com
  - hmac-sha2-256-etm@openssh.com
  - hmac-sha2-512
  - hmac-sha2-256
ssh_kex_algorithms:
  - curve25519-sha256
  - ecdh-sha2-nistp384
  - ecdh-sha2-nistp521
  - diffie-hellman-group16-sha512
  - diffie-hellman-group18-sha512

# X11 and forwarding
ssh_x11_forwarding: "no"
ssh_allow_tcp_forwarding: "no"
ssh_allow_agent_forwarding: "yes"

# Banner
ssh_banner: /etc/issue.net

# Logging
ssh_log_level: VERBOSE
```

**Implements Controls**: AC-17, SC-8
**Tags**: `r2_3.1.12`, `r2_3.13.8`, `r3_03.01.12`, `family_AC`, `family_SC`

---

#### ac_session_timeout

Enforces session timeouts with HPC-aware exemptions.

```yaml
# roles/ac_session_timeout/defaults/main.yml
---
# Session timeout (from group_vars via ODP)
# Set to 0 in restricted zone to disable for batch jobs
session_timeout_seconds: "{{ session_timeout_minutes | int * 60 }}"

# Shell timeout (TMOUT)
shell_timeout_enabled: "{{ session_timeout_minutes > 0 }}"

# PAM session timeout
pam_session_timeout_enabled: "{{ session_timeout_minutes > 0 }}"

# systemd-logind configuration
logind_idle_action: "{{ 'lock' if session_timeout_minutes > 0 else 'ignore' }}"
logind_idle_action_sec: "{{ session_timeout_seconds }}"

# HPC exemption detection
session_timeout_exempt_tty_patterns:
  - "pts/[0-9]+"  # Slurm allocated PTYs
```

**Implements Controls**: AC-11, AC-12
**Tags**: `r2_3.1.10`, `r2_3.1.11`, `r3_03.01.10`, `family_AC`

---

#### ac_login_banner

Displays login banner with use authorization warning.

```yaml
# roles/ac_login_banner/defaults/main.yml
---
# Banner text (plain language per constitution)
login_banner_text: |
  **************************************************************************
  *                       AUTHORIZED USE ONLY                              *
  **************************************************************************

  This system is part of {{ cui_organization }}'s Controlled Unclassified
  Information (CUI) environment. Access is restricted to authorized users
  only.

  By logging in, you acknowledge:
  - All activity is monitored and logged
  - Unauthorized access is prohibited and may result in prosecution
  - Data on this system may be subject to federal export control regulations

  If you are not authorized to access this system, disconnect immediately.

  For help: {{ support_contact | default('security@example.edu') }}
  **************************************************************************

# Banner files
login_banner_issue: /etc/issue
login_banner_issue_net: /etc/issue.net
login_banner_motd: /etc/motd

# GDM banner (if applicable)
login_banner_gdm_enabled: false
```

**Implements Controls**: AC-8
**Tags**: `r2_3.1.9`, `r3_03.01.09`, `family_AC`

---

#### ac_usbguard

Implements USBGuard to block portable storage devices.

```yaml
# roles/ac_usbguard/defaults/main.yml
---
# Policy mode (from zone group_vars)
# deny_all: Block all USB devices
# deny_storage: Block storage, allow HID
# allow_all: Allow all USB devices (not recommended)
usbguard_policy_mode: "{{ usbguard_policy | default('deny_storage') }}"

# Default policy
usbguard_implicit_policy: block

# Device rules
usbguard_rules:
  - name: allow-hid
    condition: "with-interface one-of { 03:*:* }"  # HID class
    action: allow
    enabled: "{{ usbguard_policy_mode != 'deny_all' }}"

  - name: block-storage
    condition: "with-interface one-of { 08:*:* }"  # Mass storage class
    action: block
    enabled: true

# Logging
usbguard_audit_policy: true
usbguard_audit_file: /var/log/usbguard/usbguard-audit.log
```

**Implements Controls**: MP-7, AC-19
**Tags**: `r2_3.8.7`, `r3_03.08.07`, `family_MP`, `family_AC`

---

#### ac_selinux

Ensures SELinux is in enforcing mode with targeted policy.

```yaml
# roles/ac_selinux/defaults/main.yml
---
# SELinux state
selinux_state: enforcing
selinux_policy: targeted

# Booleans to set
selinux_booleans:
  - name: httpd_can_network_connect
    state: false
  - name: ssh_sysadm_login
    state: true

# Custom modules
selinux_custom_modules: []
# - name: my_custom_policy
#   source: files/my_custom_policy.te

# Relabeling
selinux_relabel_autorelabel: false
```

**Implements Controls**: AC-3, AC-6
**Tags**: `r2_3.1.3`, `r2_3.1.4`, `r3_03.01.03`, `family_AC`

---

### CM Family Roles

#### cm_openscap_baseline

Applies OpenSCAP CUI profile with HPC-aware tailoring.

```yaml
# roles/cm_openscap_baseline/defaults/main.yml
---
# OpenSCAP content (from group_vars/all.yml)
openscap_profile: "{{ openscap_profile }}"
openscap_content_file: "{{ openscap_content }}"

# Tailoring (from group_vars)
openscap_tailoring_enabled: "{{ openscap_tailoring_enabled | default(true) }}"
openscap_tailoring_file: /etc/scap/cui-hpc-tailoring.xml

# HPC rule exclusions (from zone group_vars)
openscap_skip_rules: "{{ openscap_skip_rules | default([]) }}"

# Remediation
openscap_remediate: true
openscap_remediate_only_failed: true

# Output
openscap_results_dir: /var/log/scap
openscap_generate_report: true
openscap_report_format: html
```

**Implements Controls**: CM-2, CM-6
**Tags**: `r2_3.4.1`, `r2_3.4.2`, `r3_03.04.01`, `family_CM`

---

#### cm_fips_mode

Enables FIPS mode with FIPS:OSPP crypto-policies.

```yaml
# roles/cm_fips_mode/defaults/main.yml
---
# FIPS enablement
fips_enabled: true
fips_crypto_policy: FIPS:OSPP

# Reboot handling
fips_reboot_if_required: true
fips_reboot_delay: 60  # seconds
fips_reboot_msg: "Rebooting to enable FIPS mode"

# Verification
fips_verify_after_reboot: true
fips_verification_command: "/usr/bin/fips-mode-setup --check"
```

**Implements Controls**: SC-13
**Tags**: `r2_3.13.11`, `r3_03.13.08`, `family_SC`, `family_CM`

---

#### cm_minimal_packages

Ensures only zone-required minimal package sets are installed.

```yaml
# roles/cm_minimal_packages/defaults/main.yml
---
# Base packages (all zones)
packages_required_base:
  - audit
  - aide
  - chrony
  - rsyslog
  - openscap-scanner
  - scap-security-guide

# Zone-specific packages (merged with base)
packages_required_zone:
  management:
    - ansible
    - git
    - python3
  internal:
    - bash-completion
    - vim
  restricted:
    - slurm-slurmd
    - openmpi
  public:
    - httpd
    - mod_ssl

# Packages to remove (unnecessary services)
packages_removed:
  - cups
  - cups-client
  - cups-libs
  - bluez
  - avahi-daemon
  - avahi
  - postfix  # Unless mail server

# Package locking
packages_lock_kernel: true
```

**Implements Controls**: CM-7, CM-11
**Tags**: `r2_3.4.6`, `r2_3.4.8`, `r3_03.04.06`, `family_CM`

---

#### cm_service_hardening

Disables and masks unnecessary services.

```yaml
# roles/cm_service_hardening/defaults/main.yml
---
# Services to disable and mask
services_disabled:
  - cups.service
  - cups.socket
  - cups-browsed.service
  - avahi-daemon.service
  - avahi-daemon.socket
  - bluetooth.service
  - kdump.service

# Services to enable
services_enabled:
  - auditd.service
  - rsyslog.service
  - chronyd.service
  - sshd.service
  - firewalld.service

# Socket activation to disable
sockets_disabled:
  - cups.socket
  - avahi-daemon.socket
```

**Implements Controls**: CM-7
**Tags**: `r2_3.4.7`, `r3_03.04.07`, `family_CM`

---

#### cm_kernel_hardening

Applies kernel sysctl hardening parameters.

```yaml
# roles/cm_kernel_hardening/defaults/main.yml
---
# Kernel sysctl parameters
kernel_sysctl_params:
  # Address space layout randomization
  kernel.randomize_va_space: 2

  # Restrict kernel pointers
  kernel.kptr_restrict: 2

  # Restrict dmesg
  kernel.dmesg_restrict: 1

  # Restrict ptrace
  kernel.yama.ptrace_scope: 1

  # Network hardening
  net.ipv4.conf.all.accept_redirects: 0
  net.ipv4.conf.default.accept_redirects: 0
  net.ipv4.conf.all.secure_redirects: 0
  net.ipv4.conf.default.secure_redirects: 0
  net.ipv4.conf.all.send_redirects: 0
  net.ipv4.conf.default.send_redirects: 0
  net.ipv4.conf.all.accept_source_route: 0
  net.ipv4.conf.default.accept_source_route: 0
  net.ipv4.conf.all.log_martians: 1
  net.ipv4.conf.default.log_martians: 1
  net.ipv4.icmp_echo_ignore_broadcasts: 1
  net.ipv4.icmp_ignore_bogus_error_responses: 1
  net.ipv4.conf.all.rp_filter: 1
  net.ipv4.conf.default.rp_filter: 1
  net.ipv4.tcp_syncookies: 1

  # IPv6 (disable if not used)
  net.ipv6.conf.all.accept_redirects: 0
  net.ipv6.conf.default.accept_redirects: 0
  net.ipv6.conf.all.accept_source_route: 0
  net.ipv6.conf.default.accept_source_route: 0

# Core dump restrictions
kernel_core_pattern: "|/bin/false"
kernel_core_uses_pid: 1
```

**Implements Controls**: CM-6, SC-5
**Tags**: `r2_3.4.2`, `r2_3.13.1`, `r3_03.04.02`, `family_CM`

---

#### cm_aide

Deploys AIDE file integrity monitoring with initialized baseline.

```yaml
# roles/cm_aide/defaults/main.yml
---
# AIDE database location
aide_db_dir: /var/lib/aide
aide_db_file: aide.db.gz
aide_db_new_file: aide.db.new.gz

# Directories to monitor
aide_monitored_dirs:
  - /boot
  - /etc
  - /usr/bin
  - /usr/sbin
  - /lib
  - /lib64

# Directories to exclude
aide_excluded_dirs:
  - /var/log
  - /var/cache
  - /tmp
  - /var/tmp
  - /scratch  # HPC scratch

# Monitoring rules
aide_rules:
  NORMAL: "p+i+n+u+g+s+m+c+acl+selinux+xattrs+sha512"
  DATAONLY: "p+n+u+g+s+sha512"
  LSPP: "p+i+n+u+g+s+m+c+acl+selinux+xattrs+sha512+ftype"

# Scheduled check
aide_cron_enabled: true
aide_cron_schedule: "0 5 * * *"  # Daily at 5 AM
```

**Implements Controls**: SI-7
**Tags**: `r2_3.14.3`, `r3_03.14.03`, `family_SI`, `family_CM`

---

### SC Family Roles

#### sc_nftables

Deploys nftables firewall with zone-specific rulesets.

```yaml
# roles/sc_nftables/defaults/main.yml
---
# Default policy
nftables_default_input_policy: drop
nftables_default_forward_policy: drop
nftables_default_output_policy: accept

# Common rules (all zones)
nftables_common_rules:
  - name: allow-established
    rule: "ct state established,related accept"
  - name: allow-loopback
    rule: "iif lo accept"
  - name: drop-invalid
    rule: "ct state invalid drop"

# Zone-specific rules (merged from zone group_vars)
nftables_zone_rules:
  management:
    - name: allow-ssh-bastion
      rule: "tcp dport 22 ip saddr {{ bastion_ip }} accept"
  internal:
    - name: allow-ssh
      rule: "tcp dport 22 accept"
  restricted:
    - name: allow-ssh-internal
      rule: "tcp dport 22 ip saddr {{ internal_network }} accept"
    - name: allow-slurm
      rule: "tcp dport { 6817, 6818, 6819 } accept"
    - name: allow-mpi
      rule: "tcp dport 10000-65535 ip saddr {{ compute_network }} accept"
  public:
    - name: allow-http
      rule: "tcp dport { 80, 443 } accept"

# Logging
nftables_log_dropped: true
nftables_log_prefix: "nftables-drop: "
```

**Implements Controls**: SC-7
**Tags**: `r2_3.13.1`, `r2_3.13.5`, `r3_03.13.01`, `family_SC`

---

#### sc_tls_enforcement

Enforces TLS 1.2+ and disables weak ciphers.

```yaml
# roles/sc_tls_enforcement/defaults/main.yml
---
# System-wide crypto policy
crypto_policy: FIPS:OSPP

# Minimum TLS version
tls_min_version: "1.2"

# Application-specific configurations
tls_configure_apache: false
tls_configure_nginx: false
tls_configure_postfix: false

# Cipher suite (FIPS-compliant)
tls_cipher_suite: "ECDHE+AESGCM:DHE+AESGCM:ECDHE+AES:DHE+AES"

# SSL/TLS verification
tls_verify_certificates: true
tls_ca_bundle: /etc/pki/tls/certs/ca-bundle.crt
```

**Implements Controls**: SC-8, SC-13
**Tags**: `r2_3.13.8`, `r2_3.13.11`, `r3_03.13.08`, `family_SC`

---

#### sc_luks_verification

Verifies LUKS encryption on CUI data partitions.

```yaml
# roles/sc_luks_verification/defaults/main.yml
---
# Partitions that must be LUKS encrypted
luks_required_partitions:
  - /data
  - /home

# Verification mode (verify only, no implementation)
luks_verify_only: true

# LUKS parameters to verify
luks_required_cipher: aes-xts-plain64
luks_required_key_size: 512
luks_fips_mode_required: true

# Reporting
luks_report_unencrypted: true
luks_fail_on_unencrypted: true
```

**Implements Controls**: SC-28
**Tags**: `r2_3.13.16`, `r3_03.13.16`, `family_SC`

---

### SI Family Roles

#### si_dnf_automatic

Configures automated security patching via dnf-automatic.

```yaml
# roles/si_dnf_automatic/defaults/main.yml
---
# Update types
dnf_automatic_upgrade_type: security  # security or default

# Schedule
dnf_automatic_random_sleep: 360  # Random delay up to 6 hours
dnf_automatic_timer_oncalendar: "*-*-* 06:00"  # 6 AM daily

# Behavior
dnf_automatic_download_updates: true
dnf_automatic_apply_updates: true

# Email notifications
dnf_automatic_emit_via: email
dnf_automatic_email_from: "dnf-automatic@{{ ansible_fqdn }}"
dnf_automatic_email_to: "{{ admin_email }}"

# Reboot handling
dnf_automatic_reboot: "when-needed"
dnf_automatic_reboot_command: "/sbin/shutdown -r +5"
```

**Implements Controls**: SI-2
**Tags**: `r2_3.14.1`, `r3_03.14.01`, `family_SI`

---

#### si_clamav

Deploys ClamAV antivirus with HPC-aware exclusions.

```yaml
# roles/si_clamav/defaults/main.yml
---
# ClamAV installation
clamav_install_clamd: true
clamav_install_freshclam: true

# Real-time scanning (disabled in restricted zone)
clamav_realtime_enabled: "{{ clamav_realtime_scan | default(true) }}"

# Scheduled scanning
clamav_scheduled_enabled: true
clamav_scheduled_hour: "{{ clamav_scheduled_scan_hour | default(2) }}"
clamav_scheduled_paths:
  - /home
  - /data
  - /opt

# HPC exclusions (per constitution Principle IV)
clamav_excluded_paths:
  - /scratch
  - /tmp
  - /var/tmp
  - /dev/shm
  - /lustre
  - /gpfs

# Resource limits
clamav_max_filesize: 100M
clamav_max_scansize: 400M
clamav_max_recursion: 16
clamav_max_files: 10000

# Database updates
clamav_freshclam_checks: 12  # Per day
```

**Implements Controls**: SI-3
**Tags**: `r2_3.14.2`, `r3_03.14.02`, `family_SI`

---

#### si_openscap_oval

Executes OpenSCAP OVAL vulnerability scanning.

```yaml
# roles/si_openscap_oval/defaults/main.yml
---
# OVAL content
oval_content_url: "https://www.redhat.com/security/data/oval/v2/RHEL9/rhel-9.oval.xml.bz2"
oval_content_file: /var/lib/openscap/oval/rhel-9.oval.xml

# Scanning schedule
oval_scan_enabled: true
oval_scan_schedule: "weekly"
oval_scan_day: "Sunday"
oval_scan_hour: 4

# Output
oval_results_dir: /var/log/openscap
oval_report_format: html

# Severity threshold for alerting
oval_alert_severity: "High"
oval_alert_email: "{{ admin_email }}"
```

**Implements Controls**: SI-2, RA-5
**Tags**: `r2_3.14.1`, `r2_3.11.2`, `r3_03.14.01`, `family_SI`, `family_RA`

---

## Role Dependencies

```yaml
# Dependency graph (role -> depends on)
au_auditd: []
au_rsyslog: [au_auditd]
au_chrony: []
au_wazuh_agent: [au_rsyslog]
au_log_protection: [au_auditd]

ia_freeipa_client: [au_chrony]  # NTP required for Kerberos
ia_duo_mfa: [ia_freeipa_client]
ia_ssh_ca: [ia_freeipa_client]
ia_password_policy: [ia_freeipa_client]
ia_account_lifecycle: [ia_freeipa_client]
ia_breakglass: [ia_duo_mfa]

ac_pam_access: [ia_freeipa_client]
ac_rbac: [ia_freeipa_client]
ac_ssh_hardening: [ia_duo_mfa, ia_ssh_ca]
ac_session_timeout: []
ac_login_banner: []
ac_usbguard: []
ac_selinux: []

cm_openscap_baseline: [ac_selinux]
cm_fips_mode: []  # Must run early
cm_minimal_packages: []
cm_service_hardening: []
cm_kernel_hardening: []
cm_aide: [cm_openscap_baseline]

sc_nftables: []
sc_tls_enforcement: [cm_fips_mode]
sc_luks_verification: []

si_dnf_automatic: []
si_clamav: []
si_openscap_oval: [cm_openscap_baseline]
```

---

## Validation Requirements

### Variable Validation

Each role includes validation in `tasks/main.yml`:

```yaml
- name: Validate required variables
  ansible.builtin.assert:
    that:
      - cui_zone is defined
      - cui_zone in ['management', 'internal', 'restricted', 'public']
    fail_msg: "Zone assignment required - see FR-048"
```

### Testing Strategy

1. **ansible-lint**: Validate all roles (FR-045)
2. **yamllint**: Validate all YAML files (FR-046)
3. **Molecule**: Integration testing per role
4. **OpenSCAP**: Validate >85% CUI profile compliance (FR-047)

---

## Next Steps

1. ✅ **Phase 1 Complete**: Role variable schemas defined
2. **Phase 1**: Create quickstart.md with deployment guide
3. **Phase 1**: Create contracts/README.md (role interface summary)
4. **Phase 2**: Generate tasks.md via `/speckit.tasks` command
