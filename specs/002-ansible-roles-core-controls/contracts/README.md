# Contracts: Ansible Role Interfaces

**Feature**: 002-ansible-roles-core-controls
**Date**: 2026-02-14
**Phase**: 1 - Design & Contracts

## Purpose

This directory would normally contain API contracts, interface specifications, or external integration schemas. For this feature (Ansible roles), there are no external APIs. Role interfaces are fully documented in [data-model.md](../data-model.md).

---

## Role Interface Summary

All roles follow the same interface pattern:

### Input Interface (Variables)

```yaml
# Required Variables (from group_vars)
cui_zone: string                    # management | internal | restricted | public
cui_organization: string            # Organization name for evidence artifacts
cui_environment: string             # production | staging | development

# Infrastructure Variables (from group_vars/all.yml)
freeipa_servers: list[string]       # FreeIPA server hostnames
freeipa_domain: string              # FreeIPA domain name
wazuh_manager_host: string          # Wazuh SIEM hostname
ntp_servers: list[string]           # NTP server addresses
syslog_server: string               # Central syslog server

# ODP Variables (from group_vars/all.yml)
session_timeout_minutes: int        # Session timeout (0 = disabled)
password_min_length: int            # Minimum password length
audit_log_retention_years: int      # Audit log retention period
```

### Output Interface (Task Files)

Each role provides three task entry points:

| Task File | Purpose | Mode |
|-----------|---------|------|
| `tasks/main.yml` | Implement security controls | Read-write |
| `tasks/verify.yml` | Check compliance status | Read-only |
| `tasks/evidence.yml` | Collect SSP artifacts | Read-only + fetch |

### Output Variables (Registered Facts)

Each role registers verification results:

```yaml
# Example: au_auditd
au_auditd_verify_results:
  service_enabled: bool
  service_running: bool
  rules_loaded: bool
  separate_partition: bool
  compliant: bool

# Example: ia_freeipa_client
ia_freeipa_verify_results:
  enrolled: bool
  kerberos_valid: bool
  sssd_running: bool
  compliant: bool
```

---

## Playbook Integration Contract

### Site Playbook Structure

```yaml
# playbooks/site.yml
---
- name: Deploy CUI Compliance Controls
  hosts: all
  gather_facts: true
  roles:
    # Phase 1: Foundation
    - role: common  # Zone validation
    - role: cm_fips_mode  # Requires reboot

    # Phase 2: Identity
    - role: ia_freeipa_client
    - role: ia_password_policy
    - role: ia_duo_mfa
    - role: ia_ssh_ca
    - role: ia_account_lifecycle
    - role: ia_breakglass

    # Phase 3: Access Control
    - role: ac_pam_access
    - role: ac_rbac
    - role: ac_ssh_hardening
    - role: ac_session_timeout
    - role: ac_login_banner
    - role: ac_usbguard
    - role: ac_selinux

    # Phase 4: Audit & Logging
    - role: au_auditd
    - role: au_rsyslog
    - role: au_chrony
    - role: au_wazuh_agent
    - role: au_log_protection

    # Phase 5: Hardening
    - role: cm_openscap_baseline
    - role: cm_minimal_packages
    - role: cm_service_hardening
    - role: cm_kernel_hardening
    - role: cm_aide

    # Phase 6: Network & Crypto
    - role: sc_nftables
    - role: sc_tls_enforcement
    - role: sc_luks_verification

    # Phase 7: Maintenance
    - role: si_dnf_automatic
    - role: si_clamav
    - role: si_openscap_oval
```

### Verification Playbook Structure

```yaml
# playbooks/verify.yml
---
- name: Verify CUI Compliance Status
  hosts: all
  gather_facts: true
  tasks:
    - name: Include role verification tasks
      ansible.builtin.include_role:
        name: "{{ item }}"
        tasks_from: verify.yml
      loop:
        - au_auditd
        - ia_freeipa_client
        - ac_ssh_hardening
        # ... all roles ...
```

### Evidence Collection Playbook Structure

```yaml
# playbooks/evidence.yml
---
- name: Collect SSP Evidence Artifacts
  hosts: all
  gather_facts: true
  vars:
    evidence_output_dir: /tmp/cui-evidence
  tasks:
    - name: Include role evidence tasks
      ansible.builtin.include_role:
        name: "{{ item }}"
        tasks_from: evidence.yml
      loop:
        - au_auditd
        - ia_freeipa_client
        # ... all roles ...
```

---

## Tag Contract

All tasks are tagged with control identifiers:

| Tag Pattern | Framework | Example |
|-------------|-----------|---------|
| `r2_X.X.X` | NIST 800-171 Rev 2 | `r2_3.3.1` |
| `r3_XX.XX.XX` | NIST 800-171 Rev 3 | `r3_03.03.01` |
| `cmmc_XX` | CMMC Level 2 | `cmmc_AU.L2-3.3.1` |
| `sp53_XX-XX` | NIST 800-53 Rev 5 | `sp53_AU-2` |
| `family_XX` | Control family | `family_AU` |
| `zone_XXXX` | Security zone | `zone_restricted` |

---

## External System Contracts

### FreeIPA Integration

- **Protocol**: LDAP/Kerberos
- **Required**: FreeIPA server operational before role execution
- **Credentials**: Enrollment principal/password via Ansible Vault

### Wazuh Integration

- **Protocol**: TCP 1514 (agent registration)
- **Required**: Wazuh manager operational
- **Credentials**: Registration key via Ansible Vault

### Duo MFA Integration

- **Protocol**: HTTPS to Duo API
- **Required**: Duo account with Unix integration
- **Credentials**: Integration key, secret key, API hostname via Ansible Vault

---

## Reference

For complete variable schemas and role interfaces, see:

- **[data-model.md](../data-model.md)** - Complete role variable schemas
- **[research.md](../research.md)** - Technology decisions
- **[quickstart.md](../quickstart.md)** - Deployment guide
