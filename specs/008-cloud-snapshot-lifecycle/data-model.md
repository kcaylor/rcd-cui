# Data Model: Cloud Snapshot Demo Lifecycle

**Feature**: 008-cloud-snapshot-lifecycle
**Date**: 2026-02-27

## Entities

### SnapshotManifest

Local JSON file at `infra/terraform/snapshot-manifest.json`. Tracks all snapshot sets for offline reference and restore operations.

**File structure**:
```json
{
  "version": 1,
  "sets": {
    "rcd-demo-20260227-01": {
      "created_at": "2026-02-27T14:30:00Z",
      "source_cluster": "rcd-demo",
      "source_commit": "d88c4e4",
      "snapshots": [
        {
          "snapshot_id": 12345678,
          "node_name": "mgmt01",
          "node_role": "mgmt",
          "server_type": "cpx21",
          "private_ip": "10.0.0.10"
        },
        {
          "snapshot_id": 12345679,
          "node_name": "login01",
          "node_role": "login",
          "server_type": "cpx11",
          "private_ip": "10.0.0.20"
        },
        {
          "snapshot_id": 12345680,
          "node_name": "compute01",
          "node_role": "compute",
          "server_type": "cpx11",
          "private_ip": "10.0.0.31"
        },
        {
          "snapshot_id": 12345681,
          "node_name": "compute02",
          "node_role": "compute",
          "server_type": "cpx11",
          "private_ip": "10.0.0.32"
        }
      ]
    }
  }
}
```

**Fields**:
- `version` (integer): Schema version for forward compatibility. Currently `1`.
- `sets` (object): Keyed by set label (rcd-demo-YYYYMMDD-NN). Each entry is a SnapshotSet.

**Validation rules**:
- Set label MUST match pattern `rcd-demo-\d{8}-\d{2}`
- Each set MUST contain exactly 4 snapshots (one per node)
- `snapshot_id` MUST be a positive integer (Hetzner image ID)
- `node_name` MUST be one of: mgmt01, login01, compute01, compute02
- `server_type` MUST be a valid Hetzner server type string
- `private_ip` MUST be a valid IPv4 address in the 10.0.0.0/24 subnet

**Lifecycle**: Created/updated by snapshot script, read by warm-start and list scripts, entries removed by delete script. File is gitignored (contains cloud-specific IDs).

---

### SnapshotSet

A logical grouping of 4 VM snapshots representing a complete cluster state at a point in time. Exists both as cloud resource labels and as an entry in the local manifest.

**Cloud resource representation** (Hetzner image labels):
```
cluster=rcd-demo
snapshot-set=rcd-demo-20260227-01
node-name=mgmt01
node-role=mgmt
server-type=cpx21
private-ip=10.0.0.10
```

**Identity**: Uniquely identified by set label (`rcd-demo-YYYYMMDD-NN`).

**State transitions**:
```
[creating] → [complete] → [deleted]
```
- Creating: Snapshots being taken for each VM (may be partial if interrupted)
- Complete: All 4 snapshots exist and are tagged with matching set label
- Deleted: All snapshots in the set have been removed from Hetzner

**Invariants**:
- A complete set always has exactly 4 snapshots
- All snapshots in a set share the same `snapshot-set` label value
- Node names within a set are unique

---

### ServiceHealthReport

Runtime structure representing the result of a health check. Not persisted to disk — output to stdout only.

**Structure** (conceptual):
```
{
  "timestamp": "2026-02-27T14:35:00Z",
  "cluster_ready": true|false,
  "nodes": [
    {
      "name": "mgmt01",
      "reachable": true,
      "services": [
        { "name": "ipa.service", "status": "pass", "remediated": false },
        { "name": "slurmctld.service", "status": "pass", "remediated": false },
        { "name": "wazuh-manager.service", "status": "fail", "remediated": true },
        ...
      ],
      "mounts": [
        { "path": "/shared", "status": "pass" }
      ]
    },
    ...
  ]
}
```

**Display format** (stdout table):
```
Node         Service                 Status
─────────────────────────────────────────────
mgmt01       ipa.service             ✓ pass
mgmt01       slurmctld.service       ✓ pass
mgmt01       wazuh-manager.service   ✓ pass (restarted)
mgmt01       nfs-server.service      ✓ pass
mgmt01       munge.service           ✓ pass
mgmt01       chronyd.service         ✓ pass
mgmt01       /shared export          ✓ pass
login01      sssd.service            ✓ pass
login01      munge.service           ✓ pass
...
compute02    slurmd.service          ✗ FAIL
─────────────────────────────────────────────
Result: 23/24 checks passed, 1 FAILED
```

---

### AnsibleInventory

Generated YAML file at `infra/terraform/inventory.yml`. Same format as Terraform-generated inventory to maintain compatibility with existing playbooks.

**Structure** (matches existing inventory.tpl):
```yaml
all:
  vars:
    ansible_ssh_private_key_file: <ssh_key_path>
  children:
    mgmt:
      hosts:
        mgmt01:
          ansible_host: <new_public_ip>
          ansible_user: root
          private_ip: 10.0.0.10
          node_role: mgmt
          zone: management
    login:
      hosts:
        login01:
          ansible_host: <new_public_ip>
          ansible_user: root
          private_ip: 10.0.0.20
          node_role: login
          zone: internal
    compute:
      hosts:
        compute01:
          ansible_host: <new_public_ip>
          ansible_user: root
          private_ip: 10.0.0.31
          node_role: compute
          zone: restricted
        compute02:
          ansible_host: <new_public_ip>
          ansible_user: root
          private_ip: 10.0.0.32
          node_role: compute
          zone: restricted
```

**Key difference from cold-build**: Public IPs change on every restore (assigned by Hetzner), but private IPs are always the same (from snapshot labels). SSH key path adapts to Docker vs native context.

## Relationships

```
SnapshotManifest 1──* SnapshotSet
SnapshotSet      1──4 HetznerSnapshot (cloud resource)
SnapshotSet      1──1 AnsibleInventory (generated on restore)
AnsibleInventory 1──* DemoScenario (consumed by existing playbooks)
ServiceHealthReport ←── AnsibleInventory (uses same node/IP data)
```
