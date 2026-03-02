# Quickstart: Cloud Snapshot Demo Lifecycle

**Feature**: 008-cloud-snapshot-lifecycle

## Prerequisites

- Hetzner Cloud account with API token (`HCLOUD_TOKEN` in `infra/.env`)
- Docker installed (or Terraform + Ansible + hcloud CLI installed locally)
- A successfully provisioned cluster (via `make demo-cloud-up`) — needed once

## One-Time Setup: Create Your First Snapshot Set

```bash
# 1. Build the cluster from scratch (one-time, ~25 min)
make demo-cloud-up

# 2. At the end of provisioning, you'll be prompted:
#    "Snapshot this cluster for future fast starts? [Y/n]"
#    Say yes. Or run manually:
make demo-snapshot

# 3. Tear down the running cluster (stops billing)
make demo-cloud-down
```

You now have a snapshot set stored in Hetzner Cloud. This is your seed.

## Daily Demo Workflow

```bash
# Warm start from snapshots (~3-5 min)
make demo-warm

# Verify everything is healthy
make demo-health

# Run your demo scenarios
make demo-scenario-a    # Project onboarding (3-5 min)
make demo-scenario-b    # Drift detect & fix (5-8 min)
make demo-scenario-c    # Audit package (3-5 min)

# When done, wind down (stops billing)
make demo-cool
```

## Managing Snapshots

```bash
# List available snapshot sets
make demo-snapshot ARGS="--list"
# Or directly:
./infra/scripts/demo-cloud-snapshot.sh --list

# Delete an old snapshot set
./infra/scripts/demo-cloud-snapshot.sh --delete rcd-demo-20260227-01
```

## Typical Timeline

| Step | Time | What Happens |
|------|------|--------------|
| `make demo-warm` | 3-5 min | VMs created from snapshots, network configured, services verified |
| Demo scenarios | 3-15 min | Run one or more scenarios for stakeholders |
| `make demo-cool` | 1-2 min | Optional snapshot, then destroy all resources |
| **Total** | **7-22 min** | Down from 45+ minutes with cold-start |

## Cost

- **Compute**: ~EUR 0.03/hour for the full 4-node cluster (cpx21 + 3×cpx11), billed per minute
- **Per demo session**: ~EUR 0.01 for a 15-min session, ~EUR 0.03 for a 1-hour session
- **Snapshots**: ~EUR 0.35/month per snapshot set (stored even when cluster is down)
- **Monthly budget for weekly demos**: ~EUR 0.50 (4 × 1-hour sessions + 1 snapshot set)
