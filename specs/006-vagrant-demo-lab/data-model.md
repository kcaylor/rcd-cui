# Data Model: Vagrant Demo Lab Environment

**Feature**: 006-vagrant-demo-lab
**Date**: 2026-02-15

## Entities

### 1. VMNode

Represents a virtual machine in the demo lab environment.

| Attribute | Type | Description | Constraints |
|-----------|------|-------------|-------------|
| name | string | VM hostname | Required, unique, pattern: `[a-z]+[0-9]+` |
| role | enum | Node function | `mgmt`, `login`, `compute` |
| zone | enum | Security zone | `management`, `internal`, `restricted` |
| vcpus | integer | Virtual CPU count | Min: 1, Max: 4 |
| memory_mb | integer | RAM in megabytes | Min: 1024, Max: 8192 |
| disk_gb | integer | Primary disk size | Min: 10, Max: 100 |
| ip_address | string | Private network IP | IPv4 in 192.168.56.0/24 |
| freeipa_enrolled | boolean | FreeIPA client status | Default: false |
| slurm_role | enum | Slurm daemon type | `controller`, `compute`, `submit`, `none` |
| wazuh_agent | boolean | Wazuh agent installed | Default: false |

**Relationships**:
- VMNode mgmt01 hosts FreeIPA server, Wazuh manager, Slurm controller, NFS server
- VMNode login01 is Slurm submit host
- VMNode compute01/02 are Slurm compute nodes

**State Transitions**:
- `undefined` → `provisioning` (vagrant up)
- `provisioning` → `running` (provisioning complete)
- `running` → `compliant` (all controls pass)
- `compliant` → `non_compliant` (violations introduced)
- `non_compliant` → `compliant` (remediation applied)
- `running` → `decommissioned` (node removed)

### 2. Project

Represents a research project onboarded to the cluster.

| Attribute | Type | Description | Constraints |
|-----------|------|-------------|-------------|
| name | string | Project short name | Required, lowercase alphanumeric |
| display_name | string | Human-readable name | Required, max 64 chars |
| freeipa_group | string | FreeIPA group name | Derived from name |
| slurm_qos | string | Slurm QOS name | Derived from name |
| storage_path | string | NFS shared directory | Pattern: `/shared/projects/{name}` |
| users | list[User] | Project members | Min: 1 |

**Relationships**:
- Project has many Users (members)
- Project has one FreeIPA group
- Project has one Slurm QOS
- Project has one storage directory

### 3. User

Represents a user account in the demo environment.

| Attribute | Type | Description | Constraints |
|-----------|------|-------------|-------------|
| username | string | FreeIPA username | Required, pattern: `[a-z_]+` |
| password | string | User password | Required, min 8 chars |
| first_name | string | Given name | Required |
| last_name | string | Family name | Required |
| email | string | Email address | Valid email format |
| project | string | Associated project | FK to Project.name |
| ssh_authorized | boolean | SSH key configured | Default: false |

**Demo Users (Project Helios)**:
- `alice_helios` (password: DemoPass123!)
- `bob_helios` (password: DemoPass123!)

### 4. ComplianceViolation

Represents a specific compliance violation for demonstration.

| Attribute | Type | Description | Constraints |
|-----------|------|-------------|-------------|
| id | string | Violation identifier | Required, unique |
| description | string | Human-readable description | Required |
| control_id | string | NIST 800-171 control | FK to control_mapping |
| introduce_command | string | Command to create violation | Required |
| detect_pattern | string | Pattern to detect violation | Required |
| remediate_role | string | Ansible role for fix | Required |
| severity | enum | Impact level | `high`, `medium`, `low` |

**Demo Violations**:

| ID | Description | Control | Introduce | Remediate |
|----|-------------|---------|-----------|-----------|
| V001 | SSH PermitRootLogin | 3.1.1 | `sed -i 's/PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config` | ssh_hardening |
| V002 | auditd stopped | 3.3.1 | `systemctl stop auditd` | auditd |
| V003 | shadow world-readable | 3.1.2 | `chmod 644 /etc/shadow` | file_permissions |
| V004 | firewall disabled | 3.13.1 | `systemctl stop firewalld` | firewall |

### 5. Scenario

Represents a demonstration workflow.

| Attribute | Type | Description | Constraints |
|-----------|------|-------------|-------------|
| id | string | Scenario identifier | Required, pattern: `scenario-[a-d]` |
| name | string | Display name | Required |
| duration_minutes | integer | Expected demo time | Required |
| playbook | string | Main playbook path | Required |
| narrative | string | Markdown guide path | Required |
| prerequisites | list[string] | Required prior scenarios | Optional |
| user_stories | list[string] | Linked user stories | Required |

**Demo Scenarios**:

| ID | Name | Duration | Prerequisites |
|----|------|----------|---------------|
| scenario-a | Project Onboarding | 10 min | None |
| scenario-b | Compliance Drift | 12 min | None |
| scenario-c | Auditor Package | 8 min | scenario-b |
| scenario-d | Node Lifecycle | 15 min | None |

### 6. LabState

Represents the overall state of the demo lab.

| Attribute | Type | Description | Constraints |
|-----------|------|-------------|-------------|
| status | enum | Current lab status | `stopped`, `starting`, `running`, `error` |
| baseline_snapshot | string | Vagrant snapshot name | Default: `baseline` |
| current_scenario | string | Active scenario ID | Nullable |
| last_reset | datetime | Last reset timestamp | Nullable |
| nodes | list[VMNode] | All VMs in lab | Fixed: 4 nodes |

## Relationships Diagram

```text
┌─────────────┐     has many      ┌─────────────┐
│   Project   │──────────────────▶│    User     │
└─────────────┘                   └─────────────┘
       │
       │ has one
       ▼
┌─────────────┐
│ FreeIPA Grp │
└─────────────┘

┌─────────────┐     introduces    ┌─────────────────────┐
│  Scenario B │──────────────────▶│ ComplianceViolation │
└─────────────┘                   └─────────────────────┘
       │                                    │
       │ remediates via                     │ maps to
       ▼                                    ▼
┌─────────────┐                   ┌─────────────────────┐
│ Ansible Role│                   │   NIST Control      │
└─────────────┘                   └─────────────────────┘

┌─────────────┐     contains      ┌─────────────┐
│  LabState   │──────────────────▶│   VMNode    │
└─────────────┘                   └─────────────┘
```

## Validation Rules

1. **VMNode IP uniqueness**: All VMs must have unique IP addresses in the private network
2. **Project name format**: Must be lowercase alphanumeric, used to derive FreeIPA group and Slurm QOS names
3. **User-Project association**: Every user must belong to exactly one project
4. **Violation-Control mapping**: Every violation must reference a valid NIST 800-171 control from control_mapping.yml
5. **Scenario ordering**: Scenarios with prerequisites cannot be run until prerequisites complete
6. **Resource limits**: Total lab resources must not exceed 8 vCPUs + 10GB RAM (fits 16GB host)
