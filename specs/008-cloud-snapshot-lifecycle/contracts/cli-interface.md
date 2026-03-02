# CLI Interface Contracts

**Feature**: 008-cloud-snapshot-lifecycle
**Date**: 2026-02-27

This feature exposes CLI scripts (not HTTP APIs). These contracts define the command interface, arguments, exit codes, and output formats.

---

## demo-cloud-snapshot.sh

**Purpose**: Create a snapshot set from a running cluster, or manage existing snapshot sets.

### Create (default mode)

```bash
./infra/scripts/demo-cloud-snapshot.sh
```

**Preconditions**: Running cluster with all services healthy (validated via health check).

**Behavior**:
1. Run health check on current cluster
2. Stop critical services on all nodes (reverse dependency order)
3. Create snapshot of each VM via hcloud API
4. Label snapshots with set identifier and node metadata
5. Restart services on all nodes (forward dependency order)
6. Write snapshot set entry to manifest file
7. Display snapshot set summary with storage cost estimate

**Exit codes**:
- `0`: All 4 snapshots created successfully
- `1`: Snapshot creation failed (partial set may exist — labeled for cleanup)
- `3`: Prerequisites missing (hcloud CLI, HCLOUD_TOKEN, no running cluster)

**Stdout**: Progress messages and completion summary.

### List mode

```bash
./infra/scripts/demo-cloud-snapshot.sh --list
```

**Stdout**: Tabular list of snapshot sets sorted by date (newest first).
```
Set Label                  Created              Snapshots  Est. Storage
──────────────────────────────────────────────────────────────────────
rcd-demo-20260227-02       2026-02-27 16:00     4/4        ~EUR 0.35/mo
rcd-demo-20260227-01       2026-02-27 14:30     4/4        ~EUR 0.35/mo
```

### Delete mode

```bash
./infra/scripts/demo-cloud-snapshot.sh --delete <set-label>
```

**Behavior**: Prompts for confirmation, then deletes all snapshots in the set from Hetzner and removes the entry from the manifest file.

**Exit codes**:
- `0`: Set deleted successfully
- `1`: Deletion failed
- `2`: Set label not found

---

## demo-cloud-warm.sh

**Purpose**: Restore a demo cluster from the most recent snapshot set.

```bash
./infra/scripts/demo-cloud-warm.sh [--set <set-label>]
```

**Arguments**:
- `--set <label>` (optional): Restore a specific snapshot set instead of the most recent.

**Preconditions**: No existing cluster running (blocks if cluster detected). At least one snapshot set exists.

**Behavior**:
1. Validate no existing cluster (check hcloud server labels + Terraform state)
2. Detect SSH key (same hierarchy as demo-cloud-up.sh)
3. Load snapshot set from manifest (most recent or specified)
4. Upload SSH key to Hetzner
5. Create private network (10.0.0.0/24)
6. Create 4 servers from snapshots with correct server types, names, labels
7. Attach servers to private network with correct IPs
8. Wait for SSH availability on all nodes
9. Run post-restore playbook (fix hostnames, verify /etc/hosts)
10. Generate Ansible inventory
11. Run health check with auto-remediation
12. Display connection info and session cost estimate

**Exit codes**:
- `0`: Cluster restored and healthy
- `1`: Restore failed (partial resources may exist — tagged for cleanup)
- `2`: Health check failed after remediation attempt
- `3`: Prerequisites missing (no snapshots, existing cluster, missing tools)

**Stdout**: Progress messages, connection info, cost estimate.

---

## demo-cloud-cool.sh

**Purpose**: Gracefully wind down a demo session with optional pre-teardown snapshot.

```bash
./infra/scripts/demo-cloud-cool.sh [--no-snapshot]
```

**Arguments**:
- `--no-snapshot`: Skip the snapshot prompt, proceed directly to teardown.

**Behavior**:
1. Verify running cluster exists
2. Display session duration and cost
3. Unless `--no-snapshot`, prompt: "Snapshot current state before teardown? [y/N]"
4. If yes: run demo-cloud-snapshot.sh
5. Prompt for teardown confirmation
6. Delete servers (by label selector), then networks, then SSH keys
7. Display final session summary (duration, estimated cost)

**Exit codes**:
- `0`: All resources destroyed
- `1`: Teardown failed
- `3`: No running cluster found

---

## demo-cloud-health.sh

**Purpose**: Verify all critical services are running on the demo cluster.

```bash
./infra/scripts/demo-cloud-health.sh [--inventory <path>] [--json]
```

**Arguments**:
- `--inventory <path>` (optional): Path to inventory file. Default: `infra/terraform/inventory.yml`
- `--json` (optional): Output results as JSON instead of table.

**Behavior**:
1. Parse inventory for node IPs and SSH key path
2. SSH to each node in parallel
3. Check systemd services (systemctl is-active)
4. Check NFS mounts (mountpoint -q)
5. Check FreeIPA enrollment (ipa-client --installed check on clients, ipactl status on server)
6. On failure: attempt one restart, wait 5 seconds, re-check
7. Output summary table (or JSON)

**Exit codes**:
- `0`: All checks passed
- `1`: One or more checks failed after remediation attempt
- `3`: Cannot reach one or more nodes via SSH

---

## Makefile Targets

```makefile
demo-snapshot:   # Create snapshot set from running cluster
demo-warm:       # Restore cluster from snapshots
demo-cool:       # Wind down session (optional snapshot + teardown)
demo-health:     # Run health check on running cluster
```

All targets use `$(DEMO_DOCKER)` wrapper for Docker container execution, consistent with existing `demo-cloud-up`, `demo-cloud-down`, `demo-cloud-status` targets.

---

## Post-Restore Playbook Contract

**File**: `demo/playbooks/post-restore.yml`

**Purpose**: Fix hostname and service state after snapshot restore (cloud-init overwrites).

**Hosts**: all (from generated inventory)

**Tasks**:
1. Set FQDN hostname (`{{ inventory_hostname }}.demo.lab`)
2. Verify /etc/hosts has correct private IP entries
3. Restart services that bind to hostname (ipa, sssd, slurmctld/slurmd)

**Expected runtime**: Under 30 seconds.
**Idempotent**: Yes — safe to run multiple times.
