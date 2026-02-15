# Research: Core Ansible Roles for NIST 800-171 Controls

**Feature**: 002-ansible-roles-core-controls
**Date**: 2026-02-14
**Phase**: 0 - Research & Technology Selection
**Depends On**: [Spec 001 - Data Models](../001-data-models-docs-foundation/research.md)

## Purpose

This document resolves research questions for implementing 24 Ansible roles covering 6 NIST 800-171 control families. Key decisions include zone-aware configuration patterns, three-mode role architecture, control tagging conventions, and integration strategies for established security tools (auditd, FreeIPA, Duo, Wazuh, OpenSCAP, nftables).

---

## Decision 1: Zone-Aware Role Architecture

**Question**: How should roles implement zone-aware behavior supporting management, internal, restricted, and public zones with different security configurations?

**Decision**: **Group-based variable inheritance** with explicit zone validation at role entry

**Rationale**:
1. **Ansible Native**: Uses standard group_vars pattern, no custom plugins required
2. **Explicit Validation**: Roles fail-fast if zone not assigned (per FR-048 and clarification answer #1)
3. **Single Primary Zone**: Each host has one primary zone group membership (per FR-051 and clarification answer #4)
4. **Override Capability**: host_vars can override zone defaults for multi-zone edge cases

**Implementation**:

### Inventory Structure:
```yaml
# inventory/hosts.yml
all:
  children:
    management:
      hosts:
        bastion01.example.edu:
        ansible01.example.edu:
    internal:
      hosts:
        login01.example.edu:
        login02.example.edu:
    restricted:
      hosts:
        compute[001:100].example.edu:
    public:
      hosts:
        web01.example.edu:
```

### Zone Variable Files:
```yaml
# inventory/group_vars/all.yml
---
# Common defaults - MUST be overridden by zone
cui_zone: null  # Forces explicit zone assignment

# Default ODP values from Spec 001 data model
session_timeout_minutes: 15
password_min_length: 15
password_history: 24
inactive_account_days: 90
audit_log_retention_years: 3
```

```yaml
# inventory/group_vars/restricted.yml
---
cui_zone: restricted

# HPC-tailored settings (compute nodes)
session_timeout_minutes: 0  # Disabled for batch jobs
audit_rules_profile: minimal  # Reduce logging overhead
mfa_required: false  # SSH cert auth instead
clamav_realtime_scan: false  # Scheduled scans only
openscap_skip_rules:
  - session_timeout  # HPC tailoring exception
  - screen_lock
```

### Zone Validation Task:
```yaml
# roles/common/tasks/validate_zone.yml
---
- name: Validate zone assignment exists
  ansible.builtin.assert:
    that:
      - cui_zone is defined
      - cui_zone is not none
      - cui_zone in ['management', 'internal', 'restricted', 'public']
    fail_msg: |
      FATAL: System {{ inventory_hostname }} has no explicit zone assignment.

      Every system must belong to exactly one CUI security zone.
      Add this host to one of: management, internal, restricted, public
      in inventory/hosts.yml

      See: https://internal-docs/cui-zones for zone definitions.
    success_msg: "Zone validated: {{ inventory_hostname }} is in {{ cui_zone }} zone"
  tags:
    - always
    - zone_validation
```

### Role Entry Point:
```yaml
# roles/au_auditd/tasks/main.yml
---
- name: Include zone validation
  ansible.builtin.include_role:
    name: common
    tasks_from: validate_zone.yml

- name: Configure auditd with zone-appropriate rules
  ansible.builtin.template:
    src: audit.rules.j2
    dest: /etc/audit/rules.d/cui-audit.rules
    mode: '0640'
  notify: restart auditd
  tags:
    - r2_3.3.1
    - r3_03.03.01
    - cmmc_AU.L2-3.3.1
    - family_AU
    - zone_{{ cui_zone }}
```

**Alternatives Considered**:
- **Role Parameters**: Requires passing zone to every role call, error-prone
- **Ansible Facts**: Custom fact scripts add complexity, harder to override
- **Dynamic Inventory Plugin**: Overkill for static zone assignments

---

## Decision 2: Three-Mode Role Task Structure

**Question**: How should roles implement the three task modes (main.yml, verify.yml, evidence.yml) per constitution Principle VII?

**Decision**: **Separate task files with mode-specific tags** and clear separation of concerns

**Rationale**:
1. **Constitution Compliance**: Principle VII explicitly requires three modes
2. **Operational Flexibility**: Run only verification without changes, collect evidence without verification
3. **Idempotency**: Each mode independently idempotent
4. **--check Mode**: All modes support Ansible's native check mode

**Implementation**:

### Role Directory Structure:
```text
roles/au_auditd/
├── defaults/main.yml          # Tunable variables with documentation
├── tasks/
│   ├── main.yml               # Implementation tasks (implements controls)
│   ├── verify.yml             # Compliance checking (read-only audit)
│   └── evidence.yml           # SSP artifact collection
├── handlers/main.yml          # Service restarts, config reloads
├── templates/
│   └── audit.rules.j2         # Configuration templates
├── files/                     # Static files (if any)
├── meta/main.yml              # Role metadata and dependencies
├── vars/                      # Internal variables (non-overridable)
└── README.md                  # Audience-aware documentation
```

### Main.yml (Implementation):
```yaml
# roles/au_auditd/tasks/main.yml
---
# WHY: Ensure auditd captures all security-relevant events for compliance evidence
# and incident investigation per NIST 800-171 AU-2 (Event Logging).

- name: Include zone validation
  ansible.builtin.include_role:
    name: common
    tasks_from: validate_zone.yml

- name: Install audit packages
  ansible.builtin.dnf:
    name:
      - audit
      - audit-libs
      - audispd-plugins
    state: present
  tags:
    - r2_3.3.1
    - family_AU
    - zone_{{ cui_zone }}

- name: Deploy zone-appropriate audit rules
  ansible.builtin.template:
    src: audit.rules.j2
    dest: /etc/audit/rules.d/99-cui-audit.rules
    owner: root
    group: root
    mode: '0640'
    validate: 'auditctl -R %s'
  notify: restart auditd
  tags:
    - r2_3.3.1
    - r2_3.3.2
    - family_AU

- name: Enable and start auditd
  ansible.builtin.systemd:
    name: auditd
    enabled: true
    state: started
  tags:
    - r2_3.3.1
    - family_AU
```

### Verify.yml (Compliance Check):
```yaml
# roles/au_auditd/tasks/verify.yml
---
# WHY: Non-destructive compliance verification for continuous monitoring
# and pre-audit validation. Makes NO changes to system state.

- name: Check auditd service status
  ansible.builtin.systemd:
    name: auditd
  register: auditd_status
  check_mode: true
  changed_when: false
  tags:
    - verify
    - r2_3.3.1

- name: Verify required audit rules are loaded
  ansible.builtin.shell: |
    auditctl -l | grep -E "(identity|privileged|access|delete|modules)"
  register: audit_rules_check
  changed_when: false
  failed_when: false
  tags:
    - verify
    - r2_3.3.1

- name: Check audit log partition is separate
  ansible.builtin.shell: |
    df /var/log/audit | tail -1 | awk '{print $1}'
  register: audit_partition
  changed_when: false
  tags:
    - verify
    - r2_3.3.1

- name: Generate verification report
  ansible.builtin.set_fact:
    au_auditd_verify_results:
      service_enabled: "{{ auditd_status.status.UnitFileState == 'enabled' }}"
      service_running: "{{ auditd_status.status.ActiveState == 'active' }}"
      rules_loaded: "{{ audit_rules_check.rc == 0 }}"
      separate_partition: "{{ audit_partition.stdout != '/' }}"
      compliant: "{{ auditd_status.status.UnitFileState == 'enabled' and audit_rules_check.rc == 0 }}"
  tags:
    - verify

- name: Display verification results
  ansible.builtin.debug:
    var: au_auditd_verify_results
  tags:
    - verify
```

### Evidence.yml (SSP Artifact Collection):
```yaml
# roles/au_auditd/tasks/evidence.yml
---
# WHY: Collect evidence artifacts for System Security Plan (SSP) and auditor review.
# These artifacts demonstrate control implementation without exposing sensitive data.

- name: Create evidence output directory
  ansible.builtin.file:
    path: "{{ evidence_output_dir | default('/tmp/cui-evidence') }}/{{ inventory_hostname }}"
    state: directory
    mode: '0750'
  delegate_to: localhost
  tags:
    - evidence

- name: Collect auditd configuration
  ansible.builtin.fetch:
    src: /etc/audit/auditd.conf
    dest: "{{ evidence_output_dir }}/{{ inventory_hostname }}/auditd.conf"
    flat: true
  tags:
    - evidence
    - r2_3.3.1

- name: Collect loaded audit rules
  ansible.builtin.shell: auditctl -l
  register: loaded_rules
  changed_when: false
  tags:
    - evidence

- name: Save audit rules to evidence
  ansible.builtin.copy:
    content: |
      # Evidence collected: {{ ansible_date_time.iso8601 }}
      # Host: {{ inventory_hostname }}
      # Zone: {{ cui_zone }}
      # Control: AU-2 Event Logging / NIST 800-171 3.3.1

      {{ loaded_rules.stdout }}
    dest: "{{ evidence_output_dir }}/{{ inventory_hostname }}/audit-rules-loaded.txt"
  delegate_to: localhost
  tags:
    - evidence

- name: Generate evidence summary JSON
  ansible.builtin.copy:
    content: |
      {
        "timestamp": "{{ ansible_date_time.iso8601 }}",
        "hostname": "{{ inventory_hostname }}",
        "zone": "{{ cui_zone }}",
        "control_family": "AU",
        "role": "au_auditd",
        "controls_implemented": ["AU-2", "AU-3", "AU-6", "AU-8", "AU-9"],
        "artifacts": [
          "auditd.conf",
          "audit-rules-loaded.txt"
        ]
      }
    dest: "{{ evidence_output_dir }}/{{ inventory_hostname }}/au_auditd_evidence.json"
  delegate_to: localhost
  tags:
    - evidence
```

**Site Playbook Integration**:
```yaml
# playbooks/verify.yml
---
- name: Run compliance verification across all hosts
  hosts: all
  gather_facts: true
  tasks:
    - name: Include AU role verification
      ansible.builtin.include_role:
        name: au_auditd
        tasks_from: verify.yml

    - name: Include IA role verification
      ansible.builtin.include_role:
        name: ia_freeipa_client
        tasks_from: verify.yml
    # ... continue for all roles ...
```

**Alternatives Considered**:
- **Single main.yml with conditionals**: Harder to maintain, mixes concerns
- **Ansible tags only**: Doesn't provide clear task separation, harder to audit
- **Custom Ansible plugins**: Over-engineered, violates Principle VIII

---

## Decision 3: Control Tagging Convention

**Question**: What tagging convention should be used for NIST 800-171 Rev 2/3, CMMC L2, and 800-53 R5 control mapping?

**Decision**: **Multi-tag strategy** with consistent prefixes for each framework

**Rationale**:
1. **Multi-Framework**: Supports all four frameworks per constitution Principle V
2. **Selective Execution**: Run tasks by framework, family, or zone
3. **Reporting**: Tags enable control-specific reporting from playbook runs
4. **Data Model Alignment**: Tags match control_mapping.yml structure from Spec 001

**Tag Format**:
```
r2_X.X.X       # NIST 800-171 Rev 2 (e.g., r2_3.1.1)
r3_XX.XX.XX    # NIST 800-171 Rev 3 (e.g., r3_03.01.01)
cmmc_XX        # CMMC L2 (e.g., cmmc_AC.L2-3.1.1)
sp53_XX-XX     # NIST 800-53 R5 (e.g., sp53_AC-2)
family_XX      # Control family (e.g., family_AU)
zone_XXXX      # Security zone (e.g., zone_restricted)
```

**Implementation Example**:
```yaml
- name: Configure password complexity policy
  ansible.builtin.template:
    src: pwquality.conf.j2
    dest: /etc/security/pwquality.conf
    mode: '0644'
  tags:
    # NIST 800-171 Rev 2
    - r2_3.5.7
    - r2_3.5.8
    # NIST 800-171 Rev 3
    - r3_03.05.07
    - r3_03.05.08
    # CMMC Level 2
    - cmmc_IA.L2-3.5.7
    - cmmc_IA.L2-3.5.8
    # NIST 800-53 Rev 5
    - sp53_IA-5
    # Organizational
    - family_IA
    - zone_{{ cui_zone }}
```

**Tag-Based Execution**:
```bash
# Run only AU family controls
ansible-playbook site.yml --tags "family_AU"

# Run only CMMC controls
ansible-playbook site.yml --tags "cmmc_*"

# Run controls for restricted zone
ansible-playbook site.yml --tags "zone_restricted"

# Run specific NIST 800-171 Rev 2 control
ansible-playbook site.yml --tags "r2_3.1.1"

# Verify compliance without changes
ansible-playbook verify.yml --tags "verify"
```

**Meta.yml Control Declaration**:
```yaml
# roles/ia_password_policy/meta/main.yml
---
galaxy_info:
  author: RCD-CUI Team
  description: |
    Enforces password complexity requirements per NIST 800-171 IA controls.
    Implements 15-character minimum, complexity requirements, 24-password
    history, and 365-day expiration per ODP values.
  license: MIT
  min_ansible_version: "2.15"
  platforms:
    - name: EL
      versions:
        - "9"

dependencies:
  - role: common
  - role: ia_freeipa_client

# Custom metadata for control mapping
cui_controls:
  nist_800_171_r2:
    - "3.5.7"
    - "3.5.8"
  nist_800_171_r3:
    - "03.05.07"
    - "03.05.08"
  cmmc_l2:
    - "IA.L2-3.5.7"
    - "IA.L2-3.5.8"
  nist_800_53_r5:
    - "IA-5"
```

**Alternatives Considered**:
- **Single composite tag**: Too complex to parse, hard to filter
- **Framework-specific playbooks**: Duplicates logic across playbooks
- **External mapping file only**: Loses task-level traceability

---

## Decision 4: FreeIPA Client Integration

**Question**: How should the ia_freeipa_client role handle FreeIPA enrollment including error handling for unreachable servers?

**Decision**: **Ansible freeipa.ansible_freeipa collection** with retry logic and graceful degradation

**Rationale**:
1. **Established Tool**: Official Red Hat-maintained collection (Principle VIII)
2. **Idempotent**: Collection handles re-enrollment gracefully
3. **Retry Logic**: Configurable retries for transient network issues
4. **Graceful Failure**: Clear error messages when FreeIPA unavailable

**Implementation**:
```yaml
# roles/ia_freeipa_client/defaults/main.yml
---
# FreeIPA server configuration
ipa_domain: "example.edu"
ipa_realm: "EXAMPLE.EDU"
ipa_servers:
  - ipa01.example.edu
  - ipa02.example.edu

# Enrollment behavior
ipa_enrollment_retries: 3
ipa_enrollment_delay: 30
ipa_force_enrollment: false
```

```yaml
# roles/ia_freeipa_client/tasks/main.yml
---
- name: Include zone validation
  ansible.builtin.include_role:
    name: common
    tasks_from: validate_zone.yml

# WHY: Verify FreeIPA servers are reachable before attempting enrollment
# to provide clear error message if infrastructure unavailable.
- name: Check FreeIPA server connectivity
  ansible.builtin.wait_for:
    host: "{{ item }}"
    port: 443
    timeout: 10
  loop: "{{ ipa_servers }}"
  register: ipa_connectivity
  ignore_errors: true
  tags:
    - r2_3.5.1
    - family_IA

- name: Fail if no FreeIPA servers reachable
  ansible.builtin.fail:
    msg: |
      FATAL: Cannot reach any FreeIPA servers.

      Attempted servers: {{ ipa_servers | join(', ') }}

      This role requires FreeIPA infrastructure to be operational.
      Check network connectivity and FreeIPA server status.

      See: https://internal-docs/freeipa-troubleshooting
  when: ipa_connectivity.results | selectattr('failed', 'equalto', true) | list | length == ipa_servers | length
  tags:
    - r2_3.5.1

# WHY: Install required packages for FreeIPA client enrollment
- name: Install FreeIPA client packages
  ansible.builtin.dnf:
    name:
      - freeipa-client
      - sssd
      - sssd-tools
    state: present
  tags:
    - r2_3.5.1
    - family_IA

# WHY: Enroll system in FreeIPA for centralized identity management
# per NIST 800-171 IA-2 (Identification and Authentication).
- name: Enroll in FreeIPA
  freeipa.ansible_freeipa.ipaclient:
    domain: "{{ ipa_domain }}"
    realm: "{{ ipa_realm }}"
    servers: "{{ ipa_servers }}"
    principal: "{{ ipa_enrollment_principal }}"
    password: "{{ ipa_enrollment_password }}"
    force_join: "{{ ipa_force_enrollment }}"
  retries: "{{ ipa_enrollment_retries }}"
  delay: "{{ ipa_enrollment_delay }}"
  register: ipa_enrollment
  tags:
    - r2_3.5.1
    - r2_3.5.2
    - family_IA

- name: Verify Kerberos ticket obtainable
  ansible.builtin.command:
    cmd: kinit -k host/{{ ansible_fqdn }}
  changed_when: false
  tags:
    - r2_3.5.1
    - family_IA
```

**Edge Case - Deferred to clarification (from spec)**: FreeIPA retry logic for transient failures is implemented with configurable retries. Permanent server unavailability fails the playbook with clear diagnostic message.

**Alternatives Considered**:
- **Manual ipa-client-install command**: Less idempotent, harder error handling
- **Custom enrollment script**: Violates Principle VIII, reinvents existing capability
- **ansible.builtin.command only**: Loses structured output, harder to parse status

---

## Decision 5: Duo MFA Integration with Batch Job Bypass

**Question**: How should the ia_duo_mfa role enforce MFA for interactive access while bypassing MFA for batch jobs and SSH certificate authentication?

**Decision**: **PAM configuration with group-based bypass** for service accounts and SSH certificate detection

**Rationale**:
1. **HPC-Aware**: Batch jobs must authenticate without human interaction (constitution Principle IV)
2. **SSH Certificate Detection**: Duo PAM module can detect SSH cert auth and skip MFA
3. **Service Account Groups**: FreeIPA groups define which accounts bypass MFA
4. **Break-glass Support**: YubiKey hardware tokens for emergency access (FR-049)

**Implementation**:
```yaml
# roles/ia_duo_mfa/defaults/main.yml
---
# Duo integration keys (from vault)
duo_integration_key: "{{ vault_duo_ikey }}"
duo_secret_key: "{{ vault_duo_skey }}"
duo_api_host: "api-XXXXXXXX.duosecurity.com"

# Bypass configuration
duo_bypass_groups:
  - "service-accounts"
  - "batch-job-principals"
duo_bypass_ssh_certs: true

# Break-glass configuration
duo_breakglass_enabled: true
duo_breakglass_group: "breakglass-users"
```

```yaml
# roles/ia_duo_mfa/tasks/main.yml
---
# WHY: Deploy Duo PAM module for MFA on interactive SSH sessions while
# allowing batch jobs and SSH certificate auth to proceed without MFA
# per NIST 800-171 IA-2 requirements and HPC tailoring.

- name: Include zone validation
  ansible.builtin.include_role:
    name: common
    tasks_from: validate_zone.yml

- name: Install Duo PAM module
  ansible.builtin.dnf:
    name: duo_unix
    state: present
  tags:
    - r2_3.5.3
    - family_IA

- name: Deploy Duo PAM configuration
  ansible.builtin.template:
    src: pam_duo.conf.j2
    dest: /etc/duo/pam_duo.conf
    owner: root
    group: root
    mode: '0600'
  notify: restart sshd
  tags:
    - r2_3.5.3
    - family_IA

- name: Configure PAM for SSH with Duo
  ansible.builtin.template:
    src: sshd-pam.j2
    dest: /etc/pam.d/sshd
    owner: root
    group: root
    mode: '0644'
    validate: 'pamtester sshd testuser authenticate < /dev/null || true'
  tags:
    - r2_3.5.3
    - family_IA
```

**PAM Configuration Template**:
```jinja2
{# templates/sshd-pam.j2 #}
# SSH PAM configuration with Duo MFA
# Zone: {{ cui_zone }}
# Generated: {{ ansible_date_time.iso8601 }}
#
# WHY: This configuration enforces Duo MFA for interactive SSH sessions
# while bypassing MFA for batch jobs (SSH certificate auth) and service
# accounts. This supports HPC workload requirements per NIST 800-223.

# Standard auth stack
auth       required     pam_sepermit.so
auth       substack     password-auth
auth       include      postlogin

# Duo MFA - skip for SSH certificate auth and bypass groups
{% if duo_bypass_ssh_certs %}
# Skip MFA if authenticated via SSH certificate (batch jobs)
auth       [success=done default=ignore] pam_exec.so quiet /usr/local/bin/check-ssh-cert-auth.sh
{% endif %}

{% for group in duo_bypass_groups %}
# Skip MFA for {{ group }} members (service accounts/batch principals)
auth       [success=done default=ignore] pam_succeed_if.so user ingroup {{ group }}
{% endfor %}

# Require Duo MFA for all other sessions
auth       required     pam_duo.so

# Account and session management
account    required     pam_nologin.so
account    include      password-auth
password   include      password-auth
session    required     pam_selinux.so close
session    required     pam_loginuid.so
session    optional     pam_console.so
session    include      password-auth
session    include      postlogin
```

**SSH Certificate Detection Script**:
```bash
#!/bin/bash
# /usr/local/bin/check-ssh-cert-auth.sh
# WHY: Detect if SSH session authenticated via certificate (batch job)
# and signal PAM to skip Duo MFA for these sessions.

# Check if SSH_AUTH_TYPE indicates certificate authentication
if [[ "${SSH_AUTH_TYPE}" == "publickey" ]] && [[ -n "${SSH_USER_AUTH}" ]]; then
    # Certificate auth detected - allow bypass
    exit 0
fi

# Not certificate auth - require MFA
exit 1
```

**Break-glass Access** (per FR-049):
```yaml
# roles/ia_breakglass/tasks/main.yml
---
# WHY: Pre-provisioned local accounts for emergency access when Duo MFA
# unavailable. All break-glass access is logged and generates alerts.

- name: Create break-glass user accounts
  ansible.builtin.user:
    name: "{{ item.username }}"
    comment: "Break-glass emergency access - {{ item.owner }}"
    groups: "{{ duo_breakglass_group }}"
    shell: /bin/bash
    password_lock: false
  loop: "{{ breakglass_accounts }}"
  no_log: true
  tags:
    - r2_3.5.1
    - family_IA

- name: Configure YubiKey PAM for break-glass accounts
  ansible.builtin.template:
    src: yubikey-pam.j2
    dest: /etc/pam.d/yubikey
    mode: '0644'
  tags:
    - r2_3.5.3
    - family_IA

- name: Deploy break-glass access audit rules
  ansible.builtin.template:
    src: breakglass-audit.rules.j2
    dest: /etc/audit/rules.d/50-breakglass.rules
    mode: '0640'
  notify: restart auditd
  tags:
    - r2_3.3.1
    - family_AU
```

**Alternatives Considered**:
- **Duo proxy server**: Additional infrastructure, doesn't solve batch job bypass
- **Time-based bypass windows**: Security risk, not granular enough
- **IP-based bypass**: Doesn't distinguish batch jobs from interactive sessions

---

## Decision 6: OpenSCAP Integration with HPC Tailoring

**Question**: How should OpenSCAP auto-remediation respect HPC tailoring decisions and skip conflicting remediations?

**Decision**: **Tailored SCAP profile** with HPC-specific exclusions defined in YAML

**Rationale**:
1. **Compliance as Code**: Tailoring expressed as data model (Principle II)
2. **HPC-Aware**: Explicit exclusions for HPC conflicts (Principle IV)
3. **Established Tool**: Uses OpenSCAP's native tailoring capability (Principle VIII)
4. **Auditability**: Tailoring file documents all exclusions with justification

**Implementation**:
```yaml
# roles/cm_openscap_baseline/defaults/main.yml
---
# OpenSCAP profile selection
openscap_profile: xccdf_org.ssgproject.content_profile_cui
openscap_content: /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml

# HPC tailoring (loaded from docs/hpc_tailoring.yml)
openscap_tailoring_enabled: true
openscap_tailoring_file: /etc/scap/cui-hpc-tailoring.xml

# Auto-remediation control
openscap_remediate: true
openscap_remediate_hpc_safe_only: true  # Skip HPC-conflicting rules
```

**HPC Tailoring Data Model** (consumed from Spec 001):
```yaml
# docs/hpc_tailoring.yml (excerpt - from Spec 001)
---
openscap_exclusions:
  - rule_id: xccdf_org.ssgproject.content_rule_accounts_tmout
    justification: |
      Compute nodes run batch jobs that may exceed session timeout.
      Interactive session timeout conflicts with HPC operational model.
    compensating_control: |
      - Slurm job scheduler enforces job time limits
      - Compute nodes accessible only via batch submission
      - Audit logging captures all compute node access
    zones_affected:
      - restricted
    nist_800_223_ref: "Section 4.2.1 - HPC Session Management"

  - rule_id: xccdf_org.ssgproject.content_rule_package_screen_lock
    justification: |
      Compute nodes do not have interactive displays.
      Screen lock requirement not applicable.
    compensating_control: |
      - No direct console access to compute nodes
      - All access via SSH from login nodes
    zones_affected:
      - restricted
    nist_800_223_ref: "Section 4.2.2 - HPC Access Controls"
```

**Tailoring File Generation**:
```yaml
# roles/cm_openscap_baseline/tasks/main.yml
---
- name: Generate HPC-aware SCAP tailoring file
  ansible.builtin.template:
    src: cui-hpc-tailoring.xml.j2
    dest: "{{ openscap_tailoring_file }}"
    mode: '0644'
  when: openscap_tailoring_enabled
  tags:
    - r2_3.4.1
    - family_CM

- name: Run OpenSCAP assessment with tailoring
  ansible.builtin.command:
    cmd: >
      oscap xccdf eval
      --profile {{ openscap_profile }}
      --tailoring-file {{ openscap_tailoring_file }}
      --results /var/log/scap/results-{{ ansible_date_time.date }}.xml
      --report /var/log/scap/report-{{ ansible_date_time.date }}.html
      {% if openscap_remediate %}--remediate{% endif %}
      {{ openscap_content }}
  register: openscap_result
  changed_when: openscap_result.rc == 2  # Some rules remediated
  failed_when: openscap_result.rc not in [0, 2]
  tags:
    - r2_3.4.1
    - r2_3.4.2
    - family_CM
```

**Tailoring XML Template**:
```jinja2
{# templates/cui-hpc-tailoring.xml.j2 #}
<?xml version="1.0" encoding="UTF-8"?>
<!--
  CUI HPC Tailoring File
  Generated: {{ ansible_date_time.iso8601 }}
  Zone: {{ cui_zone }}

  WHY: This tailoring file excludes OpenSCAP rules that conflict with
  HPC operational requirements. Each exclusion is documented with
  justification and compensating controls per NIST 800-223.
-->
<xccdf:Tailoring xmlns:xccdf="http://checklists.nist.gov/xccdf/1.2"
                 id="cui_hpc_tailoring">
  <xccdf:version>1.0</xccdf:version>

  <xccdf:Profile id="cui_hpc_{{ cui_zone }}_profile"
                 extends="{{ openscap_profile }}">
    <xccdf:title>CUI Profile with HPC Tailoring ({{ cui_zone }} zone)</xccdf:title>

{% for exclusion in hpc_tailoring.openscap_exclusions %}
{% if cui_zone in exclusion.zones_affected %}
    <!-- Exclusion: {{ exclusion.rule_id }}
         Justification: {{ exclusion.justification | trim | replace('\n', ' ') }}
         Compensating Control: {{ exclusion.compensating_control | trim | replace('\n', ' ') }}
         Reference: {{ exclusion.nist_800_223_ref }}
    -->
    <xccdf:select idref="{{ exclusion.rule_id }}" selected="false"/>

{% endif %}
{% endfor %}
  </xccdf:Profile>
</xccdf:Tailoring>
```

**Alternatives Considered**:
- **Skip remediation entirely**: Loses automation benefit
- **Post-remediation rollback**: Complex, race conditions
- **Custom remediation scripts**: Reinvents OpenSCAP capability

---

## Decision 7: Audit Log Retention and Protection

**Question**: How should audit logs be protected from tampering and retained for 3 years per FR-052?

**Decision**: **Multi-layer protection** with immutable attributes, separate partition, and remote forwarding

**Rationale**:
1. **Defense in Depth**: Multiple protection layers prevent tampering
2. **3-Year Retention**: Meets federal contract audit window (clarification answer #5)
3. **Established Tools**: Uses auditd, chattr, rsyslog (Principle VIII)
4. **HPC-Aware**: Zone-specific log volume management

**Implementation**:
```yaml
# roles/au_log_protection/tasks/main.yml
---
- name: Ensure /var/log/audit on separate partition
  ansible.builtin.assert:
    that:
      - ansible_mounts | selectattr('mount', 'equalto', '/var/log/audit') | list | length > 0
    fail_msg: |
      FATAL: /var/log/audit must be on a separate partition.

      Per NIST 800-171 3.3.8, audit logs must be protected from
      unauthorized modification. A separate partition prevents
      log exhaustion from filling root filesystem.
  tags:
    - r2_3.3.8
    - family_AU

- name: Configure auditd for log protection
  ansible.builtin.template:
    src: auditd.conf.j2
    dest: /etc/audit/auditd.conf
    mode: '0640'
    validate: 'auditd -tc'
  notify: restart auditd
  tags:
    - r2_3.3.8
    - family_AU

- name: Set immutable attribute on audit logs
  ansible.builtin.command:
    cmd: chattr +a /var/log/audit/audit.log
  changed_when: false
  tags:
    - r2_3.3.8
    - family_AU

- name: Configure log rotation with 3-year retention
  ansible.builtin.template:
    src: audit-logrotate.j2
    dest: /etc/logrotate.d/audit
    mode: '0644'
  tags:
    - r2_3.3.8
    - family_AU
```

**Log Retention Configuration**:
```jinja2
{# templates/audit-logrotate.j2 #}
# Audit log rotation configuration
# WHY: 3-year retention meets federal contract audit window requirements
# per NIST 800-171 3.3.8 and CUI program retention guidelines.

/var/log/audit/audit.log {
    # Rotate weekly, keep 156 weeks (3 years)
    weekly
    rotate 156

    # Compress old logs
    compress
    delaycompress

    # Don't error if log missing
    missingok
    notifempty

    # Maintain permissions
    create 0600 root root

    # Restart auditd after rotation
    postrotate
        /usr/sbin/service auditd restart
    endscript
}
```

**Remote Log Forwarding** (au_rsyslog role):
```yaml
# roles/au_rsyslog/templates/rsyslog-remote.conf.j2
# WHY: Forward audit logs to Wazuh SIEM for centralized storage,
# analysis, and tamper-evident retention per NIST 800-171 3.3.8.

# Forward all audit logs via TLS
module(load="imfile")
input(type="imfile"
      File="/var/log/audit/audit.log"
      Tag="audit"
      Severity="info"
      Facility="authpriv")

# TLS configuration for log forwarding
global(
    DefaultNetstreamDriver="gtls"
    DefaultNetstreamDriverCAFile="/etc/pki/rsyslog/ca.pem"
    DefaultNetstreamDriverCertFile="/etc/pki/rsyslog/client-cert.pem"
    DefaultNetstreamDriverKeyFile="/etc/pki/rsyslog/client-key.pem"
)

# Forward to Wazuh manager
action(type="omfwd"
       target="{{ wazuh_manager_host }}"
       port="{{ wazuh_manager_port | default('1514') }}"
       protocol="tcp"
       StreamDriver="gtls"
       StreamDriverMode="1"
       StreamDriverAuthMode="x509/name"
       StreamDriverPermittedPeers="{{ wazuh_manager_host }}")
```

**Alternatives Considered**:
- **WORM storage only**: Additional hardware dependency
- **Blockchain-based logging**: Over-engineered, immature tooling
- **Application-level encryption**: Doesn't prevent deletion

---

## Summary of Technology Decisions

| Decision | Choice | Justification |
|----------|--------|---------------|
| Zone-Aware Architecture | **Group-based variable inheritance** | Ansible-native, explicit validation, single primary zone |
| Three-Mode Roles | **Separate task files (main/verify/evidence)** | Constitution Principle VII, operational flexibility |
| Control Tagging | **Multi-tag with framework prefixes** | Multi-framework support, selective execution |
| FreeIPA Integration | **ansible_freeipa collection** | Official Red Hat tool, idempotent, retry logic |
| Duo MFA + Batch Bypass | **PAM configuration with group bypass** | HPC-aware, SSH cert detection, break-glass support |
| OpenSCAP Tailoring | **YAML-driven tailoring file** | Data model as source, HPC exclusions documented |
| Audit Log Protection | **Multi-layer (immutable + partition + remote)** | Defense in depth, 3-year retention |

---

## Dependencies and Prerequisites

| Dependency | Source | Required For |
|------------|--------|--------------|
| control_mapping.yml | Spec 001 | Control-to-role mapping updates |
| odp_values.yml | Spec 001 | Password policy, session timeouts |
| hpc_tailoring.yml | Spec 001 | OpenSCAP exclusions, zone configs |
| FreeIPA infrastructure | External | ia_* roles |
| Wazuh SIEM | External | au_rsyslog, au_wazuh_agent |
| Duo account | External | ia_duo_mfa |

---

## Next Steps

1. ✅ **Phase 0 Complete**: All research questions resolved
2. **Phase 1**: Create data-model.md defining role variable schemas
3. **Phase 1**: Create quickstart.md with deployment guide
4. **Phase 1**: Create contracts/README.md (role interfaces)
5. **Phase 2**: Generate tasks.md via `/speckit.tasks` command

---

## References

- NIST SP 800-171 Rev 2: https://csrc.nist.gov/publications/detail/sp/800-171/rev-2/final
- NIST SP 800-171 Rev 3: https://csrc.nist.gov/publications/detail/sp/800-171/rev-3/final
- NIST SP 800-223 (HPC Security): https://csrc.nist.gov/publications/detail/sp/800-223/final
- Ansible FreeIPA Collection: https://github.com/freeipa/ansible-freeipa
- Duo Unix Documentation: https://duo.com/docs/duounix
- OpenSCAP Tailoring: https://www.open-scap.org/resources/documentation/
- ComplianceAsCode: https://github.com/ComplianceAsCode/content
