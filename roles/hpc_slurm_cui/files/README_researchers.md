# Using the CUI Slurm Partition

This guide explains what is different when you run jobs in the CUI partition.

## Before you submit

- Your CUI training must be current.
- You must be in your project's approved FreeIPA group.
- Use the project Slurm account assigned during onboarding.

## Submit jobs

```bash
sbatch --partition=cui --account=cui_your_project job.sh
```

## What happens automatically

1. A prolog checks your authorization and training before the job starts.
2. At job completion, an epilog clears shared memory and temporary files.
3. On GPU nodes, GPU memory reset is attempted before node reuse.
4. Audit records are written for job start and completion events.

## If your job is rejected

- Expired training: renew training and resubmit.
- Authorization timeout: wait a moment and resubmit.
- Group membership issue: contact HPC operations.
