# Research: HPC-Specific CUI Compliance Roles

**Branch**: `004-hpc-cui-roles` | **Date**: 2026-02-15

## Overview

This document captures technology decisions, best practices research, and implementation patterns for HPC-specific CUI compliance roles.

## Technology Decisions

### 1. Slurm Prolog/Epilog Script Language

**Decision**: POSIX-compliant Bash with minimal external dependencies

**Rationale**:
- Slurm prolog/epilog scripts run in a restricted environment on compute nodes
- Must execute quickly (<30 seconds for prolog per SC-001)
- Cannot rely on Python or other interpreters being available in all node images
- POSIX compliance ensures portability across RHEL variants

**Alternatives Considered**:
- Python scripts: Rejected due to interpreter overhead and potential dependency issues on minimal node images
- Perl: Rejected as not universally available and declining community support
- Compiled binaries: Rejected as harder to audit and modify; Bash is transparent

**Implementation Notes**:
- Use `set -euo pipefail` for strict error handling
- Timeout all external calls (FreeIPA lookups, nvidia-smi) with explicit limits
- Log all actions to syslog with structured format for evidence collection
- Exit codes: 0=success, 1=failure (reject job), 2=transient error (retry)

### 2. CUI Authorization Verification Method

**Decision**: Query FreeIPA group membership and training attribute via LDAP

**Rationale**:
- FreeIPA is the established identity management system (Constitution Principle VIII)
- Group membership already controls Slurm account access
- Training status stored as custom FreeIPA user attribute (per Spec 002 pattern)
- LDAP query is fast (<1 second) and doesn't require API credentials in script

**Alternatives Considered**:
- HTTP API to FreeIPA: Rejected due to authentication complexity in prolog environment
- Local cache file: Rejected due to stale data risk; authorization must be real-time
- Kerberos ticket validation only: Insufficient; doesn't verify training status

**Implementation Notes**:
- Use `ldapsearch` with Kerberos authentication (host keytab)
- Query `memberOf` for CUI group and `cuiTrainingExpiry` attribute
- Cache DNS lookup for FreeIPA server to reduce latency
- Timeout LDAP query at 10 seconds; fail job with retry message on timeout

### 3. Memory Sanitization Approach

**Decision**: Overwrite with zeros using system utilities, verify with pattern test

**Rationale**:
- NIST 800-88 "Clear" method is sufficient for RAM (volatile memory)
- /dev/shm is tmpfs; overwriting is straightforward
- /tmp on local disk requires careful handling of job-owned files only
- GPU memory reset via nvidia-smi --gpu-reset is NVIDIA-supported method

**Alternatives Considered**:
- Random data overwrite: Rejected as slower with no security benefit for RAM
- Secure delete utilities (srm, shred): Rejected as overkill for RAM; designed for disk
- Skip sanitization, rely on next job overwrite: Rejected as non-compliant with NIST 800-88

**Implementation Notes**:
- /dev/shm: `dd if=/dev/zero of=/dev/shm/sanitize bs=1M; rm /dev/shm/sanitize`
- /tmp: Find files owned by job user, overwrite, then delete
- GPU: `nvidia-smi --gpu-reset` for each GPU; verify with memory query
- Pattern test: Write known pattern, read back to verify clearing works
- Time limit: 60 seconds total; drain node if exceeded

### 4. Container Signature Verification

**Decision**: Apptainer native SIF signature verification with organization signing key

**Rationale**:
- Apptainer 1.2+ has built-in signature verification for SIF images
- Single organization signing key simplifies key management
- Researchers can request container signing via standard process
- Verification is fast (~1 second) and doesn't require network access

**Alternatives Considered**:
- Docker Content Trust: Not applicable; we use Apptainer, not Docker
- External signature database: Rejected due to network dependency and complexity
- Hash allowlist: Rejected as operationally burdensome to maintain

**Implementation Notes**:
- Generate organization signing key pair; store private key in HSM
- Public key deployed to all compute nodes via role
- `apptainer verify --key /etc/apptainer/keys/org-public.pem image.sif`
- Wrapper script performs verification before execution
- Unsigned images: Clear error "Container not signed. See [docs URL] for signing process"

### 5. Container Network Isolation

**Decision**: Apptainer `--net --network=none` with InfiniBand passthrough for MPI

**Rationale**:
- `--network=none` blocks all network access by default
- InfiniBand (RDMA) is separate from IP networking; passthrough doesn't violate isolation
- MPI over InfiniBand requires /dev/infiniband device access
- Clarification confirmed: Allow InfiniBand between CUI partition nodes only

**Alternatives Considered**:
- Network namespace with firewall rules: Rejected as complex and error-prone
- No network isolation (trust enclave boundary): Rejected as non-compliant with least privilege
- Block all inter-node communication: Rejected as breaks MPI workloads (per clarification)

**Implementation Notes**:
- Apptainer config: `allow net none = yes`, `allow net user = no`
- InfiniBand: `--bind /dev/infiniband` for MPI containers
- Execution wrapper enforces `--net --network=none` on all invocations
- Log network mode in execution audit record

### 6. Parallel Filesystem ACL Synchronization

**Decision**: Python daemon with inotify watching FreeIPA changelog, applying POSIX ACLs

**Rationale**:
- Both Lustre and BeeGFS support POSIX ACLs (via `setfacl`)
- FreeIPA group changes are infrequent; daemon can batch updates
- Python provides clean LDAP and ACL library support
- Daemon approach allows <5 minute sync (SC-005) without polling

**Alternatives Considered**:
- Cron job polling: Rejected as too slow or too resource-intensive
- SSSD with autofs: Rejected as doesn't support complex ACL requirements
- Filesystem-native integration (Lustre nodemap): Rejected as Lustre-specific; need BeeGFS support

**Implementation Notes**:
- Daemon watches FreeIPA changelog via persistent LDAP search
- On group change: Query current membership, update ACLs on project directories
- Use `setfacl -R -m g:group_name:rwx` for recursive updates
- Batch multiple changes within 30-second window to reduce filesystem load
- Systemd service with watchdog; alert on daemon failure

### 7. Data Sanitization Method for Project Offboarding

**Decision**: NIST 800-88 Clear (overwrite) for parallel filesystem, Purge for local SSD caches

**Rationale**:
- Parallel filesystem (Lustre/BeeGFS) uses spinning disks; Clear is sufficient
- Local SSD caches on compute nodes require Purge (cryptographic erase or overwrite)
- Destroy not required per assumptions; Clear/Purge are acceptable
- Must be verifiable and produce evidence for audit

**Alternatives Considered**:
- Delete only (unlink): Rejected as non-compliant; data may be recoverable
- Full disk wipe: Rejected as disproportionate; only project data needs sanitization
- Physical destruction: Rejected per assumptions; Destroy not required

**Implementation Notes**:
- Parallel FS: `shred -vzn 1 file` for all files in project directory
- Verification: Attempt to read random sample of sectors; expect zeros/random
- SSD: Use manufacturer secure erase command if available; else 3-pass overwrite
- Evidence: Hash manifest before sanitization, completion timestamp, verification result
- Script produces JSON evidence file for Spec 003 integration

### 8. Node Health Check Implementation

**Decision**: Bash script checking core services, hardware status, compliance state

**Rationale**:
- Health check runs between jobs; must be fast (<5 seconds)
- Slurm HealthCheckProgram feature provides native integration
- Bash script can aggregate checks without external dependencies

**Alternatives Considered**:
- Prometheus node exporter queries: Rejected as adds latency and dependency
- Ansible ad-hoc: Rejected as too slow for inter-job checks
- Slurm GRES plugin: Only handles GPU detection, not compliance

**Implementation Notes**:
- Check: SSSD running, audit daemon running, required mounts present
- Check: GPU available and healthy (`nvidia-smi` exit code)
- Check: Memory sanitization completed (flag file from epilog)
- Check: No quarantine flag file present
- Return: 0=healthy, 1=drain node with reason in Slurm comment

### 9. PI Welcome Packet Format

**Decision**: Markdown document generated from Jinja2 template, convertible to PDF

**Rationale**:
- Markdown is readable in any text editor or web browser
- Jinja2 allows project-specific customization (project name, PI name, team size)
- PDF conversion via pandoc for formal distribution
- Aligns with Constitution Principle I (plain language) and VI (audience-aware)

**Alternatives Considered**:
- HTML email: Rejected as may be filtered or rendered inconsistently
- Word document: Rejected as requires specific software; not version-controllable
- Plain text: Rejected as lacks formatting for readability

**Implementation Notes**:
- Template includes: Welcome message, team responsibilities, training links
- Sections: Getting started, data handling rules, support contacts, FAQ
- Reading level: Target Flesch-Kincaid grade 8 or lower
- Onboarding playbook generates Markdown; optional task converts to PDF

### 10. InfiniBand Exception Documentation

**Decision**: NIST 800-53 POA&M format with compensating control matrix

**Rationale**:
- POA&M (Plan of Action and Milestones) is standard format for security exceptions
- Auditors expect this format for any deviation from baseline controls
- Compensating control matrix maps unmet requirements to mitigations
- Template allows future update when in-network encryption becomes available

**Alternatives Considered**:
- Free-form narrative: Rejected as not auditor-friendly
- Risk acceptance memo: Insufficient; must show compensating controls
- Defer documentation: Rejected; exception must be documented before operation

**Implementation Notes**:
- Template sections: Exception description, affected controls, risk assessment
- Compensating controls: Physical security (data center access), boundary encryption (IPsec to enclave edge), port monitoring (switch SPAN to SIEM)
- Milestones: Track vendor in-network encryption roadmap
- Evidence collection: Physical access logs, firewall configs, SIEM alerts
- Role generates document from template and collects evidence artifacts

## Best Practices Applied

### Slurm Security Best Practices

1. **EXCLUSIVE partition**: Prevents co-tenancy of CUI and non-CUI jobs on same node
2. **AllowAccounts restriction**: Defense in depth; limits who can submit to partition
3. **Prolog/Epilog in restricted paths**: Scripts owned by root, mode 700
4. **Job accounting AdminComment**: Stores CUI audit tags without user visibility
5. **QOS association**: Enforces CUI-specific resource limits and priorities

### Apptainer/Singularity Security Best Practices

1. **Fakeroot disabled**: Prevents privilege escalation attempts
2. **Bind mount allowlist**: Only /home/CUI, /scratch/CUI, /tmp visible
3. **No SETUID installation**: Reduces attack surface
4. **Environment filtering**: Strip dangerous variables (LD_PRELOAD, etc.)
5. **Execution logging**: Centralized audit trail for container usage

### Parallel Filesystem Security Best Practices

1. **Project directory hierarchy**: /cui/projects/{project_id}/ standard layout
2. **Changelog on separate MDT**: Prevents performance impact on metadata operations
3. **Quota by project, not user**: Prevents single user consuming team allocation
4. **Immutable evidence directory**: /cui/projects/{project_id}/.evidence/ read-only after creation
5. **Backup encryption verification**: Regular check that backup targets have encryption enabled

### Node Lifecycle Best Practices

1. **Stateless compute nodes**: All state from PXE image; local data is ephemeral
2. **Compliance scan before join**: Node cannot accept jobs until scan passes
3. **Quarantine state in Slurm**: Use DOWN+REASON to explain why node is unavailable
4. **Sanitization verification**: Cannot mark sanitization complete without verification step
5. **Decommission audit trail**: Full chain of custody from production to disposal

## Integration Points

### With Spec 001 (Data Models)

- `control_mapping.yml`: HPC roles add tags for controls they implement
- `hpc_tailoring.yml`: Updated with implementation details for each decision
- `glossary/terms.yml`: Add HPC-specific terms (prolog, epilog, RDMA, etc.)

### With Spec 002 (Core Roles)

- `freeipa_client`: HPC roles assume FreeIPA client is configured
- `sssd`: HPC roles verify SSSD is running for user lookups
- `auditd`: HPC roles send audit events to existing audit infrastructure
- `selinux`: HPC scripts must be SELinux-compatible

### With Spec 003 (Compliance Assessment)

- `assess.yml`: Include HPC role verify.yml tasks in assessment
- `ssp_evidence.yml`: Include HPC role evidence.yml tasks
- `sprs_weights.yml`: HPC controls map to existing SPRS weights
- `data/assessment_history/`: Job accounting data integrated into history

## Open Questions Resolved

All technical questions from spec clarification session are addressed:

1. ✅ Prolog timeout → Fail with retry message (LDAP timeout handling)
2. ✅ MPI container communication → InfiniBand passthrough (Decision #5)
3. ✅ Offboarding active jobs → 24-hour grace period (playbook implementation)
4. ✅ GPU reset failure → Drain node (epilog implementation)
5. ✅ Quota exceeded → Read-only access (filesystem abstraction layer)
