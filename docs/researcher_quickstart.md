# HPC CUI Researcher Quickstart

## 1. Before you start

- Confirm your CUI training is current.
- Confirm Duo MFA is configured.
- Confirm your project account and storage path were provisioned.

## 2. Submit jobs to the CUI partition

```bash
sbatch --partition=cui --account=cui_<project_id> job.sh
```

Job prolog checks authorization and training before execution.

## 3. Use signed containers only

```bash
apptainer-cui run /cui/containers/<signed-image>.sif
```

The wrapper blocks unsigned images, enforces approved bind paths, and applies network isolation.

## 4. Store data only in project space

Use `/cui/projects/<project_id>` for CUI data. ACLs and quotas are applied automatically.

## 5. Understand post-job sanitization

After each job, the system sanitizes `/dev/shm`, cleans `/tmp`, and resets GPU memory when present.

## 6. Offboarding behavior

When offboarding starts, new submissions are blocked immediately. Active jobs may continue during the grace period (up to 24 hours), then access is revoked.

## 7. Support

- HPC Ops: hpc-ops@example.edu
- Security: security@example.edu
