# Internal Contracts: Vagrant Demo Lab

**Feature**: 006-vagrant-demo-lab
**Date**: 2026-02-15

This feature is an infrastructure demo environment. Instead of API contracts, this document defines internal contracts between components.

## 1. Vagrantfile ↔ Ansible Provisioner Contract

**Provider**: Vagrantfile
**Consumer**: Ansible provisioner

### Inventory Generation

Vagrantfile generates Ansible inventory with:
- Groups: `mgmt`, `login`, `compute`, `all`
- Host variables: `ansible_host`, `ansible_user`, `ansible_ssh_private_key_file`

```yaml
# Expected inventory structure
all:
  children:
    mgmt:
      hosts:
        mgmt01:
          ansible_host: 192.168.56.10
          node_role: mgmt
          zone: management
    login:
      hosts:
        login01:
          ansible_host: 192.168.56.20
          node_role: login
          zone: internal
    compute:
      hosts:
        compute01:
          ansible_host: 192.168.56.31
          node_role: compute
          zone: restricted
        compute02:
          ansible_host: 192.168.56.32
          node_role: compute
          zone: restricted
```

### Expected Behavior

- Vagrant provisions VMs before calling Ansible
- Ansible can SSH to all VMs using generated inventory
- Host variables are accessible in playbooks

---

## 2. Demo Scripts ↔ Vagrant Contract

**Provider**: Vagrant CLI
**Consumer**: demo-*.sh scripts

### Command Interface

| Script | Vagrant Commands Used |
|--------|----------------------|
| demo-setup.sh | `vagrant up`, `vagrant provision`, `vagrant snapshot push` |
| demo-reset.sh | `vagrant snapshot pop`, `vagrant snapshot push` |
| demo-break.sh | None (Ansible only) |
| demo-fix.sh | None (Ansible only) |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Vagrant command failed |
| 2 | VMs not running |
| 3 | Ansible provisioning failed |

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| VAGRANT_CWD | Path to Vagrantfile | `demo/vagrant` |
| ANSIBLE_CONFIG | Ansible config path | `demo/vagrant/ansible.cfg` |

---

## 3. Demo Scripts ↔ Ansible Playbooks Contract

**Provider**: Ansible playbooks in demo/playbooks/
**Consumer**: demo-*.sh scripts

### Playbook Interface

| Playbook | Required Tags | Extra Vars |
|----------|--------------|------------|
| provision.yml | `base`, `freeipa`, `slurm`, `wazuh`, `nfs` | None |
| scenario-a-onboard.yml | None | `project_name=helios` |
| scenario-b-drift.yml | `break`, `detect`, `fix` | `violations=all` |
| scenario-c-audit.yml | None | `output_dir=/shared/auditor` |
| scenario-d-lifecycle.yml | `add`, `verify`, `remove` | `node_name=compute03` |

### Output Format

All playbooks produce JSON output when `ANSIBLE_STDOUT_CALLBACK=json`:

```json
{
  "stats": {
    "mgmt01": {"changed": 5, "failures": 0, "ok": 12}
  },
  "plays": [...]
}
```

---

## 4. Scenario Playbooks ↔ Existing Roles Contract

**Provider**: rcd-cui Ansible roles in roles/
**Consumer**: demo/playbooks/*.yml

### Role Dependencies

| Scenario | Roles Required |
|----------|---------------|
| provision.yml | `common`, `freeipa_server`, `freeipa_client`, `slurm`, `wazuh_manager`, `wazuh_agent`, `nfs_server`, `nfs_client` |
| scenario-a-onboard.yml | `project_onboarding`, `freeipa_user`, `slurm_qos`, `storage_acl` |
| scenario-b-drift.yml | `compliance_break`, `compliance_assess`, `ssh_hardening`, `auditd`, `file_permissions`, `firewall` |
| scenario-c-audit.yml | `ssp_evidence`, `generate_auditor_package` |
| scenario-d-lifecycle.yml | `node_provision`, `compliance_gate`, `node_decommission` |

### Role Interface

All roles must support:
- `--check` mode (dry run)
- Tags matching NIST control IDs
- Variables documented in `defaults/main.yml`

---

## 5. Compliance Violations ↔ Assessment Contract

**Provider**: demo-break.sh (introduces violations)
**Consumer**: Compliance assessment playbooks

### Violation Detection

| Violation ID | Detection Method | Expected Finding |
|--------------|------------------|------------------|
| V001 | `grep PermitRootLogin /etc/ssh/sshd_config` | `PermitRootLogin yes` |
| V002 | `systemctl is-active auditd` | `inactive` |
| V003 | `stat -c %a /etc/shadow` | `644` (not `000`) |
| V004 | `systemctl is-active firewalld` | `inactive` |

### Assessment Output

Assessment produces JSON with control status:

```json
{
  "controls": [
    {"id": "3.1.1", "status": "fail", "finding": "SSH permits root login"},
    {"id": "3.3.1", "status": "fail", "finding": "auditd not running"}
  ],
  "sprs_score": 98
}
```

---

## 6. FreeIPA ↔ Slurm Integration Contract

**Provider**: FreeIPA server on mgmt01
**Consumer**: Slurm controller and compute nodes

### User Synchronization

- Slurm uses SSSD for user resolution (FreeIPA backend)
- Users created in FreeIPA are immediately visible to Slurm
- UIDs/GIDs are consistent across all nodes

### Expected Behavior

1. Create user `alice_helios` in FreeIPA
2. User can SSH to login01 with Kerberos ticket
3. User can submit job via `sbatch`
4. Job runs on compute nodes as correct UID
