# Data Model: HPC-Specific CUI Compliance Roles

**Branch**: `004-hpc-cui-roles` | **Date**: 2026-02-15

## Overview

This document defines the data entities, relationships, and state transitions for HPC-specific CUI compliance operations. These models extend the Spec 001 data model with HPC-specific concepts.

## Entities

### 1. CUIProject

Represents a funded research effort handling CUI data within the HPC enclave.

```yaml
CUIProject:
  description: A CUI research project with associated team, storage, and compute resources

  fields:
    project_id:
      type: string
      format: "^cui-[a-z0-9]{4,12}$"
      description: Unique identifier (e.g., "cui-nasa2026")
      required: true
      immutable: true

    project_name:
      type: string
      maxLength: 100
      description: Human-readable project name
      required: true

    pi_username:
      type: string
      description: FreeIPA username of Principal Investigator
      required: true

    pi_email:
      type: string
      format: email
      description: PI contact email
      required: true

    freeipa_group:
      type: string
      format: "^cuiproj-[a-z0-9-]+$"
      description: FreeIPA group name for team members
      required: true
      derived_from: project_id

    slurm_account:
      type: string
      format: "^cui_[a-z0-9_]+$"
      description: Slurm account for job submission
      required: true
      derived_from: project_id

    storage_path:
      type: string
      format: "^/cui/projects/[a-z0-9-]+$"
      description: Project directory on parallel filesystem
      required: true

    storage_quota_gb:
      type: integer
      minimum: 100
      maximum: 100000
      description: Storage quota in gigabytes
      required: true

    status:
      type: enum
      values: [pending, active, offboarding, archived]
      description: Project lifecycle status
      required: true
      default: pending

    created_date:
      type: string
      format: date
      required: true

    expiration_date:
      type: string
      format: date
      description: Expected project end date
      required: false

    offboarding_initiated:
      type: string
      format: date-time
      description: When offboarding was started
      required: false

    archived_date:
      type: string
      format: date
      description: When project was fully archived/sanitized
      required: false

  relationships:
    team_members:
      type: one-to-many
      target: CUIProjectMember
      description: Users authorized for this project

    jobs:
      type: one-to-many
      target: CUIJob
      description: Jobs submitted by this project

  validation_rules:
    - "freeipa_group must exist in FreeIPA before project activation"
    - "slurm_account must exist in Slurm before project activation"
    - "storage_path must exist with correct ACLs before project activation"
    - "offboarding cannot start until all team members acknowledged"
```

### 2. CUIProjectMember

Represents a user's membership in a CUI project.

```yaml
CUIProjectMember:
  description: A user's authorization to access a CUI project

  fields:
    project_id:
      type: string
      description: Reference to CUIProject
      required: true

    username:
      type: string
      description: FreeIPA username
      required: true

    role:
      type: enum
      values: [pi, researcher, readonly]
      description: User's role in project
      required: true
      default: researcher

    training_expiry:
      type: string
      format: date
      description: CUI training certification expiration
      required: true

    mfa_configured:
      type: boolean
      description: Whether Duo MFA is configured for user
      required: true
      default: false

    status:
      type: enum
      values: [pending, active, suspended, removed]
      description: Membership status
      required: true
      default: pending

    added_date:
      type: string
      format: date
      required: true

    removed_date:
      type: string
      format: date
      required: false

  validation_rules:
    - "training_expiry must be in the future for status=active"
    - "mfa_configured must be true for status=active"
    - "pi role requires at least one per project"
```

### 3. CUIJob

Represents a batch job executing on CUI partition nodes.

```yaml
CUIJob:
  description: A Slurm job executing in the CUI partition

  fields:
    job_id:
      type: integer
      description: Slurm job ID
      required: true
      immutable: true

    project_id:
      type: string
      description: Reference to CUIProject (via Slurm account)
      required: true

    username:
      type: string
      description: Submitting user
      required: true

    partition:
      type: string
      description: Slurm partition (always CUI partition)
      required: true

    nodes:
      type: array
      items:
        type: string
      description: Node hostnames allocated
      required: true

    submit_time:
      type: string
      format: date-time
      required: true

    start_time:
      type: string
      format: date-time
      required: false

    end_time:
      type: string
      format: date-time
      required: false

    prolog_status:
      type: enum
      values: [pending, passed, failed, timeout]
      description: Authorization check result
      required: true
      default: pending

    prolog_message:
      type: string
      description: Error message if prolog failed
      required: false

    epilog_status:
      type: enum
      values: [pending, passed, failed]
      description: Sanitization result
      required: false

    gpu_count:
      type: integer
      description: Number of GPUs allocated
      required: false

    audit_tags:
      type: object
      description: CUI-specific audit metadata
      properties:
        authorization_verified: { type: boolean }
        training_verified: { type: boolean }
        memory_sanitized: { type: boolean }
        gpu_reset: { type: boolean }
      required: true

  validation_rules:
    - "prolog_status must be passed for job to start"
    - "epilog_status set only after job ends"
    - "gpu_reset in audit_tags required if gpu_count > 0"
```

### 4. SignedContainer

Represents a container image verified for CUI enclave use.

```yaml
SignedContainer:
  description: A container image with verified signature

  fields:
    image_hash:
      type: string
      format: "^sha256:[a-f0-9]{64}$"
      description: SHA256 hash of container image
      required: true
      immutable: true

    image_path:
      type: string
      description: Original path/URI of image
      required: true

    signature_key_id:
      type: string
      description: ID of signing key used
      required: true

    signed_by:
      type: string
      description: Username who signed the image
      required: true

    signed_date:
      type: string
      format: date-time
      required: true

    description:
      type: string
      maxLength: 500
      description: Purpose/contents of container
      required: false

    base_image:
      type: string
      description: Parent image if applicable
      required: false

    software_manifest:
      type: array
      items:
        type: string
      description: Key software packages included
      required: false

    status:
      type: enum
      values: [active, revoked, expired]
      description: Whether container is still trusted
      required: true
      default: active

    revoked_date:
      type: string
      format: date
      required: false

    revoke_reason:
      type: string
      required: false

  validation_rules:
    - "signature must be valid against signing key"
    - "revoked containers must not execute"
```

### 5. ContainerExecution

Represents a single container execution event.

```yaml
ContainerExecution:
  description: Audit record of container execution

  fields:
    execution_id:
      type: string
      format: uuid
      description: Unique execution identifier
      required: true
      immutable: true

    job_id:
      type: integer
      description: Associated Slurm job ID
      required: true

    username:
      type: string
      description: User who executed container
      required: true

    image_hash:
      type: string
      description: Reference to SignedContainer
      required: true

    image_path:
      type: string
      description: Path as invoked by user
      required: true

    hostname:
      type: string
      description: Node where executed
      required: true

    start_time:
      type: string
      format: date-time
      required: true

    end_time:
      type: string
      format: date-time
      required: false

    exit_code:
      type: integer
      required: false

    bind_mounts:
      type: array
      items:
        type: string
      description: Paths mounted into container
      required: true

    network_mode:
      type: string
      description: Network isolation mode applied
      required: true
      default: "none"

    infiniband_enabled:
      type: boolean
      description: Whether IB passthrough was allowed
      required: true
      default: false

  validation_rules:
    - "image_hash must reference active SignedContainer"
    - "bind_mounts must be subset of approved paths"
```

### 6. NodeState

Represents the compliance status of a compute node.

```yaml
NodeState:
  description: Compute node compliance and operational status

  fields:
    hostname:
      type: string
      description: Node hostname
      required: true

    state:
      type: enum
      values: [provisioning, scanning, compliant, quarantined, draining, decommissioning, decommissioned]
      description: Current lifecycle state
      required: true

    partition:
      type: string
      description: Slurm partition assigned
      required: false

    last_compliance_scan:
      type: string
      format: date-time
      description: When last compliance scan ran
      required: false

    compliance_score:
      type: integer
      minimum: 0
      maximum: 100
      description: Percentage of controls passing
      required: false

    compliance_failures:
      type: array
      items:
        type: string
      description: Control IDs that failed
      required: false

    quarantine_reason:
      type: string
      description: Why node was quarantined
      required: false

    quarantine_date:
      type: string
      format: date-time
      required: false

    last_health_check:
      type: string
      format: date-time
      required: false

    health_status:
      type: enum
      values: [healthy, unhealthy, unknown]
      required: true
      default: unknown

    sanitization_status:
      type: enum
      values: [not_required, pending, in_progress, completed, failed, verified]
      required: true
      default: not_required

    sanitization_method:
      type: enum
      values: [clear, purge]
      description: NIST 800-88 method used
      required: false

    sanitization_date:
      type: string
      format: date-time
      required: false

    sanitization_verified_by:
      type: string
      description: Username who verified sanitization
      required: false

  validation_rules:
    - "compliant state requires compliance_score >= 100"
    - "quarantined state requires quarantine_reason"
    - "decommissioned state requires sanitization_status = verified"
```

### 7. ProjectDirectory

Represents a CUI project's storage allocation on parallel filesystem.

```yaml
ProjectDirectory:
  description: Parallel filesystem directory for a CUI project

  fields:
    path:
      type: string
      format: "^/cui/projects/[a-z0-9-]+$"
      description: Absolute path to directory
      required: true
      immutable: true

    project_id:
      type: string
      description: Reference to CUIProject
      required: true

    filesystem_type:
      type: enum
      values: [lustre, beegfs]
      description: Underlying parallel filesystem
      required: true

    quota_gb:
      type: integer
      description: Storage quota in GB
      required: true

    used_gb:
      type: integer
      description: Current usage in GB
      required: true
      default: 0

    quota_exceeded:
      type: boolean
      description: Whether quota is currently exceeded
      required: true
      default: false

    quota_exceeded_since:
      type: string
      format: date-time
      required: false

    acl_group:
      type: string
      description: FreeIPA group controlling access
      required: true

    acl_last_sync:
      type: string
      format: date-time
      description: When ACLs were last synchronized
      required: false

    changelog_enabled:
      type: boolean
      description: Whether changelog monitoring is active
      required: true
      default: true

    encryption_verified:
      type: boolean
      description: Whether encryption at rest is verified
      required: true

    backup_encrypted:
      type: boolean
      description: Whether backups are encrypted
      required: true

    sanitization_status:
      type: enum
      values: [active, sanitizing, sanitized, archived]
      required: true
      default: active

  validation_rules:
    - "quota_exceeded triggers write blocking"
    - "acl_group must match project's freeipa_group"
    - "sanitization_status=sanitized requires verification"
```

### 8. CompensatingControl

Represents a security measure mitigating an unmet baseline requirement.

```yaml
CompensatingControl:
  description: Control that mitigates risk when baseline control unavailable

  fields:
    control_id:
      type: string
      format: "^CC-[0-9]{3}$"
      description: Compensating control identifier
      required: true

    baseline_control_id:
      type: string
      description: NIST control being compensated
      required: true

    title:
      type: string
      maxLength: 100
      description: Brief title of compensating control
      required: true

    description:
      type: string
      description: Full description of what this control does
      required: true

    implementation:
      type: string
      description: How the control is implemented
      required: true

    evidence_sources:
      type: array
      items:
        type: string
      description: Where to collect evidence for this control
      required: true

    verification_method:
      type: string
      description: How to verify control is effective
      required: true

    status:
      type: enum
      values: [proposed, approved, implemented, verified]
      required: true
      default: proposed

    approved_by:
      type: string
      description: Security officer who approved
      required: false

    approved_date:
      type: string
      format: date
      required: false

    review_date:
      type: string
      format: date
      description: Next scheduled review
      required: true

  validation_rules:
    - "approved status requires approved_by and approved_date"
    - "verified status requires evidence collection successful"
```

## State Transitions

### CUIProject Lifecycle

```
pending → active → offboarding → archived
           ↓
       [suspended]
           ↓
       [reactivated]
```

| From | To | Trigger | Validation |
|------|-----|---------|------------|
| pending | active | Onboarding complete | FreeIPA group, Slurm account, storage all exist |
| active | offboarding | Offboarding initiated | Grace period starts for active jobs |
| offboarding | archived | Sanitization verified | All access revoked, data sanitized |
| active | suspended | Manual action | Admin-initiated hold |
| suspended | active | Manual action | Issues resolved |

### NodeState Lifecycle

```
provisioning → scanning → compliant → draining → decommissioning → decommissioned
                  ↓            ↓
              quarantined ← unhealthy
                  ↓
               [remediated]
                  ↓
               scanning
```

| From | To | Trigger | Validation |
|------|-----|---------|------------|
| provisioning | scanning | PXE boot complete | Node reachable |
| scanning | compliant | Scan passes | 100% compliance score |
| scanning | quarantined | Scan fails | Has compliance failures |
| compliant | quarantined | Health check fails | Has quarantine reason |
| quarantined | scanning | Remediation | Issues addressed |
| compliant | draining | Decommission initiated | Slurm drain command |
| draining | decommissioning | Jobs complete | No running jobs |
| decommissioning | decommissioned | Sanitization verified | Has verification |

### ProjectDirectory Lifecycle

```
active → sanitizing → sanitized → archived
   ↓
[quota_exceeded] → [restored] → active
```

| From | To | Trigger | Validation |
|------|-----|---------|------------|
| active | sanitizing | Offboarding | Project in offboarding state |
| sanitizing | sanitized | Sanitization complete | Verification passed |
| sanitized | archived | Retention period | Backup confirmed |

## Relationships Diagram

```
┌─────────────────┐     ┌──────────────────┐
│   CUIProject    │────<│ CUIProjectMember │
└────────┬────────┘     └──────────────────┘
         │
         │1
         │
         ▼*
┌─────────────────┐     ┌──────────────────┐
│     CUIJob      │────>│    NodeState     │
└────────┬────────┘     └──────────────────┘
         │
         │1
         │
         ▼*
┌─────────────────────┐
│ ContainerExecution  │
└─────────┬───────────┘
          │
          │*
          │
          ▼1
┌─────────────────────┐
│   SignedContainer   │
└─────────────────────┘

┌─────────────────┐     ┌──────────────────────┐
│   CUIProject    │1───1│   ProjectDirectory   │
└─────────────────┘     └──────────────────────┘

┌─────────────────────┐
│ CompensatingControl │ (standalone, linked to baseline controls)
└─────────────────────┘
```

## Integration with Spec 001 Data Model

These entities extend the Spec 001 data model:

| Spec 001 Entity | Spec 004 Extension |
|-----------------|-------------------|
| Control | CompensatingControl references baseline_control_id |
| SystemComponent | NodeState adds HPC-specific lifecycle |
| User | CUIProjectMember extends with project membership |
| (new) | CUIProject, CUIJob, SignedContainer, ContainerExecution, ProjectDirectory |

Data model files updated:

- `docs/hpc_tailoring.yml`: Add entries for each HPC-specific control tailoring
- `docs/glossary/terms.yml`: Add HPC terms (prolog, epilog, RDMA, etc.)
