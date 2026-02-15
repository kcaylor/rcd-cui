# Quickstart: HPC-Specific CUI Compliance Roles

**Branch**: `004-hpc-cui-roles` | **Date**: 2026-02-15

## Prerequisites

Before deploying HPC-specific CUI compliance roles, ensure:

1. **Specs 001-003 Complete**: Core data models, Ansible roles, and compliance assessment infrastructure deployed
2. **Slurm Controller Access**: Administrative access to slurmctld configuration
3. **Parallel Filesystem Access**: Root access to Lustre/BeeGFS management nodes
4. **FreeIPA Admin**: Ability to create groups and modify user attributes
5. **Execution Environment Built**: `make ee-build` completed successfully

## Role Deployment

### Deploy All HPC Roles

```bash
# Deploy to all HPC nodes
ansible-playbook playbooks/site.yml -i inventory/hosts.yml \
  --tags hpc_slurm_cui,hpc_container_security,hpc_storage_security,hpc_interconnect,hpc_node_lifecycle
```

### Deploy Individual Roles

```bash
# Slurm CUI partition only
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags hpc_slurm_cui

# Container security only
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags hpc_container_security

# Storage security only (run on storage servers)
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags hpc_storage_security --limit storage

# Interconnect documentation only
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags hpc_interconnect

# Node lifecycle only
ansible-playbook playbooks/site.yml -i inventory/hosts.yml --tags hpc_node_lifecycle
```

## Project Onboarding

### Onboard a New CUI Project

```bash
# Create new CUI project with all resources
ansible-playbook playbooks/onboard_project.yml \
  -e project_id=cui-nasa2026 \
  -e project_name="NASA Mars Data Analysis 2026" \
  -e pi_username=jdoe \
  -e pi_email=jdoe@example.edu \
  -e storage_quota_gb=5000

# View generated welcome packet
cat /tmp/cui-nasa2026-welcome.md

# Convert to PDF (optional)
pandoc /tmp/cui-nasa2026-welcome.md -o /tmp/cui-nasa2026-welcome.pdf
```

### Add Team Members to Project

```bash
# Add researchers to existing project
ansible-playbook playbooks/onboard_project.yml \
  -e project_id=cui-nasa2026 \
  -e "team_members=[{username: rsmith, role: researcher}, {username: mjones, role: researcher}]"
```

### Verify Onboarding

```bash
# Check FreeIPA group
ipa group-show cuiproj-cui-nasa2026

# Check Slurm account
sacctmgr show account cui_nasa2026

# Check storage directory
ls -la /cui/projects/cui-nasa2026
getfacl /cui/projects/cui-nasa2026
```

## Project Offboarding

### Standard Offboarding (with grace period)

```bash
# Initiate offboarding with 24-hour grace period
ansible-playbook playbooks/offboard_project.yml \
  -e project_id=cui-nasa2026 \
  -e data_disposition=sanitize

# Check status after grace period
ansible-playbook playbooks/offboard_project.yml \
  -e project_id=cui-nasa2026 \
  -e check_only=true
```

### Immediate Offboarding (skip grace period)

```bash
# Force immediate offboarding (use with caution)
ansible-playbook playbooks/offboard_project.yml \
  -e project_id=cui-nasa2026 \
  -e data_disposition=sanitize \
  -e force=true
```

### Archive Instead of Sanitize

```bash
# Archive data to encrypted storage
ansible-playbook playbooks/offboard_project.yml \
  -e project_id=cui-nasa2026 \
  -e data_disposition=archive \
  -e archive_destination=/cui/archive/cui-nasa2026.tar.enc
```

## Researcher Workflow

### Submitting Jobs to CUI Partition

```bash
# Standard job submission (CUI partition)
sbatch --partition=cui --account=cui_nasa2026 job.sh

# Interactive session
srun --partition=cui --account=cui_nasa2026 --pty bash

# Check authorization before submitting
srun --partition=cui --account=cui_nasa2026 --test-only hostname
```

### Running Containers

```bash
# Run signed container
apptainer-cui run /cui/containers/gromacs-2024.sif mdrun -s topol.tpr

# Interactive container shell
apptainer-cui shell /cui/containers/python-data-2024.sif

# Check if container is signed
apptainer verify /cui/containers/myimage.sif
```

### Common Job Script

```bash
#!/bin/bash
#SBATCH --partition=cui
#SBATCH --account=cui_nasa2026
#SBATCH --nodes=2
#SBATCH --ntasks-per-node=32
#SBATCH --time=24:00:00
#SBATCH --job-name=cui-analysis

# Load modules
module load openmpi

# Run with signed container
srun apptainer-cui exec /cui/containers/myanalysis.sif ./my_program
```

## Administration

### Check Node Compliance

```bash
# Run compliance verification on specific node
ansible-playbook playbooks/verify.yml -i inventory/hosts.yml --limit node001 --tags hpc

# Check node health status
scontrol show node node001

# View quarantine reason if node is drained
scontrol show node node001 | grep Reason
```

### Manual Node Quarantine

```bash
# Quarantine a node
scontrol update NodeName=node001 State=DRAIN Reason="Manual quarantine for investigation"

# Release from quarantine
scontrol update NodeName=node001 State=RESUME
```

### View Container Execution Logs

```bash
# Recent executions
tail -100 /var/log/apptainer-cui/executions.json | jq .

# Filter by user
cat /var/log/apptainer-cui/executions.json | jq 'select(.username == "jdoe")'

# Filter by project
cat /var/log/apptainer-cui/executions.json | jq 'select(.image_path | contains("cui-nasa2026"))'
```

### Check ACL Sync Status

```bash
# Check daemon status
systemctl status cui-acl-sync

# Query daemon IPC
echo "STATUS" | nc -U /run/cui-acl-sync/control.sock

# Force sync for specific project
echo "SYNC cui-nasa2026" | nc -U /run/cui-acl-sync/control.sock

# View sync logs
tail -f /var/log/cui-acl-sync/sync.log
```

### Node Decommissioning

```bash
# Initiate decommissioning
ansible-playbook playbooks/decommission_node.yml \
  -e hostname=node001 \
  -e sanitization_method=purge

# Verify sanitization
ansible-playbook playbooks/verify_sanitization.yml \
  -e hostname=node001
```

## Compliance Verification

### Run HPC Compliance Assessment

```bash
# Verify HPC-specific controls
ansible-playbook playbooks/verify.yml -i inventory/hosts.yml \
  --tags hpc_slurm_cui,hpc_container_security,hpc_storage_security

# Collect HPC evidence
ansible-playbook playbooks/ssp_evidence.yml -i inventory/hosts.yml \
  --tags hpc
```

### Generate Reports

```bash
# Update HPC tailoring documentation
make docs

# View HPC-specific tailoring decisions
cat docs/hpc_tailoring.yml | grep -A 20 "hpc_specific"
```

## Troubleshooting

### Job Rejected by Prolog

```bash
# Check prolog logs
journalctl -t cui_prolog --since "1 hour ago"

# Verify user training status in FreeIPA
ipa user-show jdoe --all | grep cuiTraining

# Check group membership
ipa group-show cuiproj-cui-nasa2026 --all
```

### Container Signature Failure

```bash
# Verify container signature
apptainer verify /path/to/container.sif

# Check signing key is deployed
ls -la /etc/apptainer/keys/

# Re-sign container (admin only)
apptainer sign /path/to/container.sif
```

### ACL Sync Not Working

```bash
# Check daemon status
systemctl status cui-acl-sync

# Check FreeIPA connection
ldapsearch -x -H ldap://ipa.example.edu -b "cn=cuiproj-cui-nasa2026,cn=groups,cn=accounts,dc=example,dc=edu"

# Check ACLs on directory
getfacl /cui/projects/cui-nasa2026

# Force manual sync
python3 /usr/local/lib/cui-acl-sync/acl_sync.py --sync-now cui-nasa2026
```

### Node Stuck in Quarantine

```bash
# Check quarantine reason
scontrol show node node001 | grep Reason

# Check health check output
/etc/slurm/healthcheck.d/cui_health.sh
echo $?

# View system logs
journalctl -u sssd --since "1 hour ago"
journalctl -u auditd --since "1 hour ago"

# Clear quarantine after fix
rm /var/run/cui-quarantine
scontrol update NodeName=node001 State=RESUME
```

### GPU Memory Reset Failed

```bash
# Check nvidia-smi status
nvidia-smi

# Attempt manual reset
nvidia-smi --gpu-reset

# If GPU hung, may need reboot
# File ticket with HPC admin

# Check epilog logs
journalctl -t cui_epilog --since "1 hour ago"
```

## Integration with Spec 003

### Evidence Collection

HPC roles automatically integrate with Spec 003 evidence collection:

```bash
# Full assessment including HPC controls
make assess

# HPC-specific evidence
ansible-playbook playbooks/ssp_evidence.yml --tags hpc

# View HPC evidence
ls data/evidence/hpc/
```

### SPRS Score Impact

HPC controls contribute to SPRS score:

- **3.1.1** (Access Control): Prolog authorization check
- **3.4.1** (System Monitoring): Container execution logging
- **3.8.3** (Media Sanitization): Epilog memory scrub
- **3.13.1** (System Boundary): Network isolation

## File Locations Summary

| Purpose | Location |
|---------|----------|
| Slurm prolog | `/etc/slurm/prolog.d/cui_prolog.sh` |
| Slurm epilog | `/etc/slurm/epilog.d/cui_epilog.sh` |
| Container wrapper | `/usr/local/bin/apptainer-cui` |
| Container logs | `/var/log/apptainer-cui/executions.json` |
| ACL sync daemon | `/usr/local/lib/cui-acl-sync/` |
| ACL sync config | `/etc/cui-acl-sync/config.yml` |
| Health check | `/etc/slurm/healthcheck.d/cui_health.sh` |
| Sanitization evidence | `data/sanitization/` |
| Onboarding evidence | `data/onboarding/` |
| Offboarding evidence | `data/offboarding/` |
