# Quickstart: CUI Compliance Ansible Roles Deployment

**Feature**: 002-ansible-roles-core-controls
**Date**: 2026-02-14
**Depends On**: [Spec 001 - Data Models](../001-data-models-docs-foundation/quickstart.md)

## Purpose

This guide shows you how to deploy and use the CUI compliance Ansible roles implementing NIST 800-171 controls across your research computing enclave.

---

## Prerequisites

### Infrastructure Requirements

- **FreeIPA Server**: Operational FreeIPA infrastructure (not deployed by these roles)
- **Wazuh SIEM**: Operational Wazuh manager for centralized logging
- **Network**: VLAN segmentation for management, internal, restricted, public zones
- **Duo Account**: Duo integration keys for MFA deployment

### System Requirements

- **Target OS**: RHEL 9 / Rocky Linux 9
- **Ansible Controller**: Ansible 2.15+, Python 3.9+
- **Target Systems**: SSH access with root or sudo privileges
- **LUKS**: CUI partitions pre-encrypted during OS installation

### Software Dependencies

```bash
# On Ansible controller
pip install ansible-core>=2.15 ansible-lint yamllint

# Install FreeIPA Ansible collection
ansible-galaxy collection install freeipa.ansible_freeipa

# Install required roles
ansible-galaxy install -r requirements.yml
```

---

## Installation

### 1. Clone Repository

```bash
git clone https://github.com/your-org/rcd-cui.git
cd rcd-cui
```

### 2. Configure Inventory

Edit `inventory/hosts.yml` to define your hosts by zone:

```yaml
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

### 3. Configure Variables

Edit `inventory/group_vars/all.yml` with your environment:

```yaml
# Organization
cui_organization: "Your University Research Computing"
cui_environment: "production"

# Infrastructure endpoints
freeipa_servers:
  - ipa01.example.edu
  - ipa02.example.edu
freeipa_domain: "example.edu"
freeipa_realm: "EXAMPLE.EDU"

wazuh_manager_host: "wazuh.example.edu"

ntp_servers:
  - time1.example.edu
  - time2.example.edu

syslog_server: "logs.example.edu"
```

### 4. Configure Vault Secrets

Create encrypted vault file for sensitive credentials:

```bash
ansible-vault create inventory/group_vars/vault.yml
```

Add secrets:

```yaml
# FreeIPA enrollment
vault_ipa_enroll_principal: "admin"
vault_ipa_enroll_password: "your-secure-password"

# Duo MFA
vault_duo_ikey: "DIXXXXXXXXXXXXXXXXXX"
vault_duo_skey: "YourSecretKey..."

# Wazuh agent
vault_wazuh_registration_key: "your-registration-key"

# Break-glass accounts
vault_breakglass_accounts:
  - username: breakglass01
    owner: "Security Team"
    yubikey_public_id: "vvccccccccc"
    ssh_pubkey: "ssh-rsa AAAA..."
```

---

## Quick Start: Deploy All Roles

### Full Deployment

Deploy all CUI compliance roles to all hosts:

```bash
ansible-playbook playbooks/site.yml --ask-vault-pass
```

**Expected Output**:
```
PLAY [Deploy CUI Compliance Controls] ******************************************

TASK [Validate zone assignment] ************************************************
ok: [login01.example.edu]
ok: [compute001.example.edu]
...

TASK [au_auditd : Install audit packages] **************************************
changed: [login01.example.edu]
...

PLAY RECAP *********************************************************************
login01.example.edu        : ok=127   changed=45   failed=0
compute001.example.edu     : ok=98    changed=32   failed=0

Deployment completed in 18m 42s.
```

### Zone-Specific Deployment

Deploy to specific zone:

```bash
# Deploy only to management zone
ansible-playbook playbooks/zone_specific/management.yml

# Deploy only to compute nodes
ansible-playbook playbooks/zone_specific/restricted.yml
```

### Control Family Deployment

Deploy specific control families using tags:

```bash
# Deploy only Audit & Accountability controls
ansible-playbook playbooks/site.yml --tags "family_AU"

# Deploy only Identity & Authentication controls
ansible-playbook playbooks/site.yml --tags "family_IA"

# Deploy multiple families
ansible-playbook playbooks/site.yml --tags "family_AU,family_IA,family_AC"
```

### Dry Run (Check Mode)

Preview changes without applying:

```bash
ansible-playbook playbooks/site.yml --check --diff
```

---

## Compliance Verification

### Run Verification Playbook

Check compliance status without making changes:

```bash
ansible-playbook playbooks/verify.yml
```

**Expected Output**:
```
PLAY [Verify CUI Compliance Status] ********************************************

TASK [au_auditd : Check auditd service status] *********************************
ok: [login01.example.edu]

TASK [au_auditd : Verify required audit rules are loaded] **********************
ok: [login01.example.edu]

TASK [au_auditd : Generate verification report] ********************************
ok: [login01.example.edu] => {
    "au_auditd_verify_results": {
        "compliant": true,
        "rules_loaded": true,
        "separate_partition": true,
        "service_enabled": true,
        "service_running": true
    }
}

PLAY RECAP *********************************************************************
Verification complete: 24/24 roles compliant
```

### OpenSCAP Assessment

Run OpenSCAP CUI profile assessment:

```bash
ansible-playbook playbooks/site.yml --tags "cm_openscap_baseline" --extra-vars "openscap_remediate=false"
```

View results:

```bash
# On target system
cat /var/log/scap/report-*.html
```

---

## Evidence Collection

### Collect SSP Artifacts

Generate compliance evidence for auditors:

```bash
ansible-playbook playbooks/evidence.yml
```

Evidence is collected to `/tmp/cui-evidence/{hostname}/`:

```
/tmp/cui-evidence/
├── login01.example.edu/
│   ├── auditd.conf
│   ├── audit-rules-loaded.txt
│   ├── au_auditd_evidence.json
│   ├── ia_freeipa_evidence.json
│   └── ...
├── compute001.example.edu/
│   └── ...
```

### Package Evidence for Auditors

```bash
# Create timestamped archive
cd /tmp
tar czvf cui-evidence-$(date +%Y%m%d).tar.gz cui-evidence/
```

---

## Role-Specific Operations

### Deploy Individual Role

```bash
# Deploy only auditd configuration
ansible-playbook playbooks/site.yml --tags "au_auditd"

# Deploy only FreeIPA enrollment
ansible-playbook playbooks/site.yml --tags "ia_freeipa_client"

# Deploy only Duo MFA
ansible-playbook playbooks/site.yml --tags "ia_duo_mfa"
```

### FIPS Mode Enablement

FIPS mode requires reboot. Deploy separately with scheduling:

```bash
# Enable FIPS mode (will reboot systems)
ansible-playbook playbooks/site.yml --tags "cm_fips_mode" --extra-vars "fips_reboot_if_required=true"
```

### OpenSCAP with HPC Tailoring

For compute nodes with HPC tailoring:

```bash
# Apply OpenSCAP with HPC exclusions
ansible-playbook playbooks/zone_specific/restricted.yml --tags "cm_openscap_baseline"
```

The role automatically skips rules conflicting with HPC operations based on zone configuration.

---

## Validation and Testing

### Lint Validation

```bash
# Validate all roles
ansible-lint roles/

# Validate specific role
ansible-lint roles/au_auditd/
```

### YAML Validation

```bash
# Validate all YAML files
yamllint .

# Validate specific directory
yamllint roles/au_auditd/
```

### Integration Testing with Molecule

```bash
# Test all roles
molecule test

# Test specific role
cd roles/au_auditd && molecule test
```

### OpenSCAP Compliance Check

```bash
# Run OpenSCAP assessment only (no remediation)
ansible-playbook playbooks/site.yml --tags "cm_openscap_baseline" --extra-vars "openscap_remediate=false"

# Check compliance score
ssh login01.example.edu "oscap xccdf eval --profile cui --results /tmp/results.xml /usr/share/xml/scap/ssg/content/ssg-rhel9-ds.xml && grep -o 'pass\">[0-9]*' /tmp/results.xml | head -1"
```

---

## Common Operations

### Task 1: Add New Host

1. Add host to appropriate zone in `inventory/hosts.yml`:
   ```yaml
   internal:
     hosts:
       login03.example.edu:  # New host
   ```

2. Run full deployment:
   ```bash
   ansible-playbook playbooks/site.yml --limit login03.example.edu
   ```

3. Verify compliance:
   ```bash
   ansible-playbook playbooks/verify.yml --limit login03.example.edu
   ```

### Task 2: Update Password Policy

1. Edit `inventory/group_vars/all.yml`:
   ```yaml
   password_min_length: 16  # Updated from 15
   ```

2. Deploy password policy role:
   ```bash
   ansible-playbook playbooks/site.yml --tags "ia_password_policy"
   ```

### Task 3: Respond to Security Incident

1. Collect evidence immediately:
   ```bash
   ansible-playbook playbooks/evidence.yml --limit affected-host.example.edu
   ```

2. Review audit logs:
   ```bash
   ansible affected-host.example.edu -m shell -a "ausearch -ts today"
   ```

### Task 4: Prepare for Audit

1. Run full verification:
   ```bash
   ansible-playbook playbooks/verify.yml
   ```

2. Collect all evidence:
   ```bash
   ansible-playbook playbooks/evidence.yml
   ```

3. Run OpenSCAP assessment:
   ```bash
   ansible-playbook playbooks/site.yml --tags "cm_openscap_baseline" --extra-vars "openscap_remediate=false"
   ```

4. Package evidence:
   ```bash
   tar czvf audit-evidence-$(date +%Y%m%d).tar.gz /tmp/cui-evidence/
   ```

### Task 5: Emergency Break-Glass Access

If Duo MFA is unavailable:

1. Use break-glass account:
   ```bash
   ssh breakglass01@login01.example.edu
   # Authenticate with YubiKey
   ```

2. All break-glass access is logged and alerts security team

3. After incident, review logs:
   ```bash
   ausearch -k breakglass -ts today
   ```

---

## Troubleshooting

### Error: Zone Validation Failed

**Problem**: Role fails with "no explicit zone assignment"

**Solution**: Ensure host is in a zone group in `inventory/hosts.yml`:
```yaml
internal:
  hosts:
    your-host.example.edu:  # Add to appropriate zone
```

### Error: FreeIPA Enrollment Failed

**Problem**: `ia_freeipa_client` fails to enroll

**Solution**:
1. Verify FreeIPA servers are reachable:
   ```bash
   ansible your-host -m shell -a "ping -c 3 ipa01.example.edu"
   ```

2. Check enrollment credentials in vault:
   ```bash
   ansible-vault edit inventory/group_vars/vault.yml
   ```

3. If already enrolled, force re-enrollment:
   ```bash
   ansible-playbook playbooks/site.yml --tags "ia_freeipa_client" --extra-vars "ipa_force_enrollment=true"
   ```

### Error: Duo MFA Not Working

**Problem**: Users not prompted for MFA

**Solution**:
1. Verify Duo configuration:
   ```bash
   ansible your-host -m shell -a "cat /etc/duo/pam_duo.conf"
   ```

2. Check PAM configuration:
   ```bash
   ansible your-host -m shell -a "cat /etc/pam.d/sshd | grep duo"
   ```

3. Test Duo connectivity:
   ```bash
   ansible your-host -m shell -a "curl -I https://api-XXXXXXXX.duosecurity.com"
   ```

### Error: OpenSCAP Score Below 85%

**Problem**: System fails to meet >85% compliance target

**Solution**:
1. Review failed rules:
   ```bash
   ansible your-host -m shell -a "cat /var/log/scap/report-*.html" | grep -A5 "fail"
   ```

2. Check if HPC tailoring is applied (for compute nodes):
   ```bash
   ansible your-host -m debug -a "var=openscap_skip_rules"
   ```

3. Run remediation:
   ```bash
   ansible-playbook playbooks/site.yml --tags "cm_openscap_baseline" --extra-vars "openscap_remediate=true"
   ```

### Error: Audit Log Partition Full

**Problem**: Auditd stops due to disk space

**Solution**:
1. Check partition usage:
   ```bash
   ansible your-host -m shell -a "df -h /var/log/audit"
   ```

2. Verify log rotation is configured:
   ```bash
   ansible your-host -m shell -a "cat /etc/logrotate.d/audit"
   ```

3. Manually rotate if needed:
   ```bash
   ansible your-host -m shell -a "logrotate -f /etc/logrotate.d/audit"
   ```

---

## Reference

- **Role Variable Schemas**: [data-model.md](data-model.md)
- **Research & Decisions**: [research.md](research.md)
- **Implementation Plan**: [plan.md](plan.md)
- **Specification**: [spec.md](spec.md)
- **Data Models (Spec 001)**: [../001-data-models-docs-foundation/](../001-data-models-docs-foundation/)

## Support

For questions or issues:
- Review role README.md files in `roles/*/README.md`
- Check [research.md](research.md) for technology decisions
- File issues at [project repository]
