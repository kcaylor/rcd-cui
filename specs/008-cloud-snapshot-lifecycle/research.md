# Research: Cloud Snapshot Demo Lifecycle

**Feature**: 008-cloud-snapshot-lifecycle
**Date**: 2026-02-27

## Decision 1: Snapshot Creation Workflow

**Decision**: Use `hcloud server create-image --type snapshot` with label selectors for grouping, stopping critical services via SSH before snapshotting.

**Rationale**: The hcloud CLI provides direct snapshot creation with label support. Labels enable querying snapshot sets via `--selector`. Stopping services (not full VM shutdown) balances data consistency with speed — FreeIPA's LDAP database is the highest-risk component for corruption.

**Service stop order** (reverse dependency):
1. slurmd/slurmctld (Slurm depends on Munge)
2. wazuh-agent/wazuh-manager
3. nfs-server / unmount NFS clients
4. munge
5. FreeIPA (ipa-server / sssd on clients)

**Service restart order** (forward dependency):
1. FreeIPA (ipa-server / sssd)
2. munge
3. NFS server / mount NFS clients
4. wazuh-manager/wazuh-agent
5. slurmctld/slurmd

**Alternatives considered**:
- Full VM shutdown before snapshot: Safest but adds 2-3 minutes and requires power-on + boot wait after
- Live snapshot (no stop): Fastest but risks LDAP corruption and inconsistent Slurm state files

## Decision 2: Bypass Terraform for Snapshot Restore

**Decision**: Use hcloud CLI directly for creating servers from snapshots. Do not use Terraform for the restore workflow.

**Rationale**: Terraform manages infrastructure declaratively from scratch. Snapshot restore is a different workflow — we're creating servers from pre-built images, not from base OS images with provisioning. Using Terraform would require a separate Terraform configuration with `image = snapshot_id` variables, adding complexity without benefit. The hcloud CLI is simpler and faster for this use case.

**Implications**:
- Warm-started clusters are NOT tracked in Terraform state
- Teardown uses `hcloud server delete` with label selectors, not `terraform destroy`
- The existing `check-ttl.sh` already supports label-based server discovery via `hcloud server list --selector`, so TTL checks work without Terraform state
- A separate manifest file tracks snapshot sets locally

**Alternatives considered**:
- Terraform with snapshot image IDs: Would require a second Terraform config, managing two state files, and dynamically setting image variables — overengineered for this use case
- Terraform import after hcloud create: Fragile and error-prone

## Decision 3: Hostname Restoration After Snapshot Restore

**Decision**: Run a minimal post-restore Ansible playbook to fix FQDN hostnames after cloud-init overwrites them.

**Rationale**: Hetzner's cloud-init sets the hostname to the `--name` value on first boot of a new server instance. Since server names cannot contain dots (Hetzner restriction), the FQDN (`mgmt01.demo.lab`) gets overwritten to just `mgmt01`. FreeIPA requires correct FQDN hostnames. A 2-task Ansible playbook restores hostnames in under 30 seconds.

**Post-restore playbook tasks**:
1. Set hostname to `{{ inventory_hostname }}.demo.lab` on each node
2. Verify /etc/hosts has correct private IP entries (should be intact from snapshot)
3. Restart services that bind to hostname (FreeIPA, Slurm)

**Alternatives considered**:
- Disable cloud-init in the snapshot: Would prevent SSH key injection on restore and is fragile across Hetzner image updates
- Use `--name mgmt01.demo.lab`: Hetzner server names don't allow dots

## Decision 4: Snapshot Set Labeling Scheme

**Decision**: Use Hetzner resource labels on snapshots for grouping and discovery, with a local JSON manifest for offline reference.

**Label scheme**:
```
cluster=rcd-demo                    # Cluster identifier (matches existing pattern)
snapshot-set=rcd-demo-20260227-01   # Set identifier with date + sequence
node-name=mgmt01                   # Original VM name
node-role=mgmt                     # Node role (mgmt, login, compute)
server-type=cpx21                  # Original server type for restore
private-ip=10.0.0.10               # Original private IP assignment
```

**Rationale**: Labels are queryable via `hcloud image list --selector` which enables both snapshot set discovery and individual snapshot lookup. The local manifest file (`snapshot-manifest.json`) provides a fast offline reference without API calls.

**Alternatives considered**:
- Description-only metadata: Not queryable, requires parsing text
- Only local manifest (no labels): Breaks if manifest file is lost or machine changes

## Decision 5: Inventory Generation for Restored Clusters

**Decision**: Generate Ansible inventory directly in the warm-start script using the same YAML format as Terraform's `inventory.tpl`, writing to the same output path.

**Rationale**: The restored cluster needs an inventory file in the exact same format expected by existing demo playbooks. Since we bypass Terraform, we generate it from hcloud API data (new public IPs) combined with snapshot labels (private IPs, roles). The output path (`infra/terraform/inventory.yml`) matches what existing playbooks expect.

**Alternatives considered**:
- Dynamic Ansible inventory plugin: Adds complexity, requires hcloud Ansible collection, slower execution
- Separate inventory path: Would require modifying demo scenario playbooks (violates FR-026)

## Decision 6: Health Check Implementation

**Decision**: Implement as a standalone Bash script that SSHs into each node and checks systemd service status, NFS mounts, and FreeIPA enrollment.

**Rationale**: A Bash script with parallel SSH checks is faster than an Ansible playbook (no Ansible overhead, no fact gathering). The health check needs to complete in under 60 seconds (SC-003). Checking systemd service states via `systemctl is-active` is the most reliable method.

**Service checks per node**:

| Node | Service Checks | Mount/State Checks |
|------|---------------|-------------------|
| mgmt01 | ipa.service, slurmctld.service, wazuh-manager.service, nfs-server.service, munge.service, chronyd.service | `/shared` exported |
| login01 | sssd.service, munge.service, wazuh-agent.service, chronyd.service | `/shared` mounted, `ipa-client` enrolled |
| compute01/02 | sssd.service, slurmd.service, munge.service, wazuh-agent.service, chronyd.service | `/shared` mounted, `ipa-client` enrolled |

**Auto-remediation**: On failure, attempt one `systemctl restart <service>`, wait 5 seconds, re-check. Report final status.

**Alternatives considered**:
- Ansible playbook with service_facts: Slower startup (~10-15 seconds for Ansible init), overkill for status checks
- Ansible ad-hoc commands: Faster than playbook but still requires Ansible overhead

## Decision 7: Cluster Teardown for Snapshot-Restored Clusters

**Decision**: Use `hcloud` CLI with label selectors to identify and destroy all resources belonging to a snapshot-restored cluster.

**Teardown sequence**:
1. Query servers: `hcloud server list --selector "cluster=rcd-demo" -o json`
2. Query networks: `hcloud network list --selector "cluster=rcd-demo" -o json`
3. Query SSH keys: `hcloud ssh-key list --selector "cluster=rcd-demo" -o json`
4. Display resource summary, request confirmation
5. Delete servers, then networks, then SSH keys
6. Report session duration and estimated cost

**Rationale**: Label-based discovery is resilient (works even if manifest is lost) and follows the same pattern used by `check-ttl.sh`. Deleting in dependency order (servers before networks) avoids "resource in use" errors.

**Alternatives considered**:
- Terraform import + destroy: Complex, error-prone, unnecessary roundtrip
- Delete by name pattern: Fragile if other resources share naming prefix

## Decision 8: Snapshot Cost Estimation

**Decision**: Display snapshot storage cost estimates based on Hetzner's published per-GB pricing.

**Pricing** (as of February 2026):
- Snapshot storage: EUR 0.011/GB/month (increasing to EUR 0.0143/GB/month on April 1, 2026)
- Typical 4-node cluster snapshot size: ~20-40 GB total (estimated from cpx21 20GB + 3x cpx11 20GB disk sizes, compressed)
- Estimated monthly snapshot cost: EUR 0.22-0.44/month per snapshot set

**Rationale**: Users should understand snapshot storage costs alongside compute costs. Displaying estimates during snapshot creation and listing helps cost-aware decision making.
