# Contracts: HPC-Specific CUI Compliance Roles

**Branch**: `004-hpc-cui-roles` | **Date**: 2026-02-15

## Overview

This specification does not expose external REST/GraphQL APIs. Instead, it defines internal contracts between HPC components:

1. **Prolog/Epilog Script Contracts** - Exit codes and output format
2. **Container Wrapper Contract** - Execution logging format
3. **ACL Sync Daemon Contract** - FreeIPA event handling
4. **Onboarding Playbook Variables** - Input/output specification
5. **Health Check Script Contract** - Status reporting format

## 1. Prolog Script Contract

**Location**: `/etc/slurm/prolog.d/cui_prolog.sh`
**Executor**: Slurm slurmctld (as root on compute node)

### Input (Environment Variables)

```bash
# Provided by Slurm
SLURM_JOB_ID          # Job ID (integer)
SLURM_JOB_USER        # Submitting username
SLURM_JOB_ACCOUNT     # Slurm account (maps to CUI project)
SLURM_JOB_PARTITION   # Partition name
SLURM_JOB_NODELIST    # Allocated nodes
SLURM_JOB_UID         # User's numeric UID
SLURM_JOB_GID         # User's numeric GID
```

### Output

**Exit Codes:**

| Code | Meaning | Slurm Behavior |
|------|---------|----------------|
| 0 | Authorization passed | Job proceeds |
| 1 | Authorization failed | Job killed, user notified |
| 2 | Transient error | Job requeued (Slurm handles retry) |

**Stdout (logged to syslog):**

```
CUI_PROLOG: job=12345 user=jdoe account=cui_nasa2026 auth=PASS training=VALID
```

**Stderr (on failure):**

```
CUI_PROLOG_ERROR: Authorization failed - CUI training expired on 2026-01-15
```

### Syslog Format

```
facility: local0
priority: info (success), err (failure)
tag: cui_prolog
message: JSON object
```

```json
{
  "event": "job_start",
  "job_id": 12345,
  "user": "jdoe",
  "account": "cui_nasa2026",
  "partition": "cui",
  "nodes": ["node001", "node002"],
  "authorization": "pass",
  "training_verified": true,
  "timestamp": "2026-02-15T10:30:00Z"
}
```

## 2. Epilog Script Contract

**Location**: `/etc/slurm/epilog.d/cui_epilog.sh`
**Executor**: Slurm slurmctld (as root on compute node)

### Input (Environment Variables)

Same as prolog, plus:

```bash
SLURM_JOB_EXIT_CODE   # Job exit code
```

### Output

**Exit Codes:**

| Code | Meaning | Slurm Behavior |
|------|---------|----------------|
| 0 | Sanitization complete | Node returns to pool |
| 1 | Sanitization failed | Node drained with reason |

**Stdout (logged to syslog):**

```
CUI_EPILOG: job=12345 shm=CLEARED tmp=CLEARED gpu=RESET health=PASS
```

### Syslog Format

```json
{
  "event": "job_end",
  "job_id": 12345,
  "user": "jdoe",
  "exit_code": 0,
  "sanitization": {
    "shm_cleared": true,
    "tmp_cleared": true,
    "gpu_reset": true,
    "gpu_count": 4
  },
  "health_check": "pass",
  "duration_seconds": 45,
  "timestamp": "2026-02-15T12:45:00Z"
}
```

## 3. Container Wrapper Contract

**Location**: `/usr/local/bin/apptainer-cui`
**Executor**: User (via Slurm job)

### Input (Command Line)

```bash
apptainer-cui run [options] <image.sif> [command]
apptainer-cui exec [options] <image.sif> <command>
apptainer-cui shell [options] <image.sif>
```

### Enforced Options

The wrapper automatically adds:

```bash
--net --network=none    # Network isolation (always)
--bind /dev/infiniband  # InfiniBand passthrough (if MPI job)
--no-home               # Don't mount user home
--bind /cui/projects/$PROJECT:/data  # CUI data path only
```

### Output

**Exit Codes:**

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Container execution failed |
| 126 | Signature verification failed |
| 127 | Image not found |

**Stderr (on signature failure):**

```
ERROR: Container signature verification failed.
Image: /path/to/container.sif
Hash: sha256:abc123...

To use containers in the CUI enclave, images must be signed.
See: https://docs.example.edu/cui/container-signing
```

### Audit Log Format

**Location**: `/var/log/apptainer-cui/executions.json` (JSON lines)

```json
{
  "execution_id": "550e8400-e29b-41d4-a716-446655440000",
  "timestamp": "2026-02-15T10:30:00Z",
  "username": "jdoe",
  "slurm_job_id": 12345,
  "hostname": "node001",
  "image_path": "/cui/containers/gromacs-2024.sif",
  "image_hash": "sha256:abc123...",
  "command": "run",
  "args": ["mdrun", "-s", "topol.tpr"],
  "bind_mounts": ["/cui/projects/cui-nasa2026:/data"],
  "network_mode": "none",
  "infiniband_enabled": true,
  "exit_code": 0,
  "duration_seconds": 3600
}
```

## 4. ACL Sync Daemon Contract

**Location**: `/usr/local/lib/cui-acl-sync/acl_sync.py`
**Executor**: systemd service (as root)

### Configuration

**Location**: `/etc/cui-acl-sync/config.yml`

```yaml
freeipa:
  server: ipa.example.edu
  base_dn: dc=example,dc=edu
  group_prefix: cuiproj-

filesystem:
  type: lustre  # or beegfs
  project_root: /cui/projects

sync:
  batch_window_seconds: 30
  max_retries: 3

logging:
  level: INFO
  file: /var/log/cui-acl-sync/sync.log
```

### IPC (systemd socket)

**Socket**: `/run/cui-acl-sync/control.sock`

**Commands:**

| Command | Response |
|---------|----------|
| `STATUS` | JSON status object |
| `SYNC <project_id>` | Force immediate sync |
| `RELOAD` | Reload configuration |

### Status Response

```json
{
  "daemon": "running",
  "uptime_seconds": 86400,
  "last_sync": "2026-02-15T10:30:00Z",
  "syncs_performed": 1234,
  "errors_last_hour": 0,
  "watching_groups": 15,
  "pending_changes": 0
}
```

### Event Log Format

```json
{
  "event": "acl_sync",
  "timestamp": "2026-02-15T10:30:00Z",
  "project_id": "cui-nasa2026",
  "group": "cuiproj-cui-nasa2026",
  "action": "update",
  "members_added": ["newuser"],
  "members_removed": [],
  "directories_updated": 1,
  "duration_ms": 250
}
```

## 5. Onboarding Playbook Contract

**Playbook**: `playbooks/onboard_project.yml`
**Input**: Extra variables

### Required Variables

```yaml
project_id: "cui-nasa2026"           # Unique project identifier
project_name: "NASA Mars Data 2026"  # Human-readable name
pi_username: "jdoe"                  # PI's FreeIPA username
pi_email: "jdoe@example.edu"         # PI contact email
storage_quota_gb: 5000               # Storage allocation
team_members:                         # Initial team (optional)
  - username: "rsmith"
    role: "researcher"
  - username: "mjones"
    role: "researcher"
```

### Output Facts

After successful run, these Ansible facts are set:

```yaml
cui_project_created:
  project_id: "cui-nasa2026"
  freeipa_group: "cuiproj-cui-nasa2026"
  slurm_account: "cui_nasa2026"
  storage_path: "/cui/projects/cui-nasa2026"
  welcome_packet: "/tmp/cui-nasa2026-welcome.md"
```

### Generated Artifacts

| Artifact | Location |
|----------|----------|
| FreeIPA group | `cuiproj-{project_id}` |
| Slurm account | `cui_{project_id}` (underscores) |
| Storage directory | `/cui/projects/{project_id}` |
| Welcome packet | `/tmp/{project_id}-welcome.md` |
| Evidence record | `data/onboarding/{project_id}.json` |

## 6. Offboarding Playbook Contract

**Playbook**: `playbooks/offboard_project.yml`
**Input**: Extra variables

### Required Variables

```yaml
project_id: "cui-nasa2026"           # Project to offboard
data_disposition: "sanitize"          # sanitize | archive
archive_destination: ""               # Required if archive
force: false                          # Skip grace period
```

### State Machine

```
initiated → blocking_submissions → grace_period → revoking_access → sanitizing → completed
```

### Output Facts

```yaml
cui_project_offboarded:
  project_id: "cui-nasa2026"
  status: "completed"
  jobs_at_initiation: 3
  jobs_completed_in_grace: 3
  grace_period_ended: "2026-02-16T10:00:00Z"
  sanitization_method: "clear"
  sanitization_verified: true
  evidence_file: "data/offboarding/cui-nasa2026.json"
```

## 7. Health Check Script Contract

**Location**: `/etc/slurm/healthcheck.d/cui_health.sh`
**Executor**: Slurm slurmctld (as slurm user)

### Input

None (reads local system state)

### Output

**Exit Codes:**

| Code | Meaning | Slurm Action |
|------|---------|--------------|
| 0 | Node healthy | Available for jobs |
| 1 | Node unhealthy | Drain with reason |

**Stdout (on failure):**

```
UNHEALTHY: SSSD not responding
```

### Health Checks Performed

| Check | Pass Condition |
|-------|----------------|
| SSSD | `systemctl is-active sssd` |
| Auditd | `systemctl is-active auditd` |
| Mounts | All required mounts present |
| GPU | `nvidia-smi` returns 0 (if GPUs present) |
| Memory | `/dev/shm` cleared flag present |
| Quarantine | No `/var/run/cui-quarantine` file |

## 8. Sanitization Evidence Contract

**Producer**: Epilog script, offboarding playbook
**Consumer**: Spec 003 evidence collection

### File Format

**Location**: `data/sanitization/{hostname|project_id}_{timestamp}.json`

```json
{
  "type": "node_sanitization",
  "hostname": "node001",
  "timestamp": "2026-02-15T12:45:00Z",
  "method": "clear",
  "scope": "job_memory",
  "job_id": 12345,
  "actions": [
    {
      "target": "/dev/shm",
      "method": "overwrite_zeros",
      "size_bytes": 134217728,
      "duration_ms": 500,
      "verified": true
    },
    {
      "target": "/tmp",
      "method": "secure_delete",
      "files_removed": 42,
      "duration_ms": 1200,
      "verified": true
    },
    {
      "target": "gpu_memory",
      "method": "nvidia_reset",
      "gpu_count": 4,
      "duration_ms": 8000,
      "verified": true
    }
  ],
  "overall_status": "success",
  "performed_by": "cui_epilog",
  "verification": {
    "method": "pattern_test",
    "result": "pass"
  }
}
```

## Contract Versioning

All contracts follow semantic versioning.

| Contract | Current Version | Last Updated |
|----------|-----------------|--------------|
| Prolog Script | 1.0.0 | 2026-02-15 |
| Epilog Script | 1.0.0 | 2026-02-15 |
| Container Wrapper | 1.0.0 | 2026-02-15 |
| ACL Sync Daemon | 1.0.0 | 2026-02-15 |
| Onboarding Playbook | 1.0.0 | 2026-02-15 |
| Offboarding Playbook | 1.0.0 | 2026-02-15 |
| Health Check | 1.0.0 | 2026-02-15 |
| Sanitization Evidence | 1.0.0 | 2026-02-15 |
