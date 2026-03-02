# Staged Feature Prompts for Demo Acceleration

**Created**: 2026-02-27
**Context**: Transitioning from cold-start provisioning to snapshot-based demo workflows.
The goal is to separate "prove it's reproducible" from "show it working" — build once,
snapshot, demo from snapshots, prove reproducibility in CI.

---

## Feature 1: Snapshot-Based Cloud Demo Lifecycle (008)

**Status**: Specify now
**Priority**: Critical — this is the seed

```
/speckit.specify

Add snapshot-based cloud demo lifecycle management to the existing Hetzner Cloud
infrastructure (spec 007). The current demo-cloud-up.sh takes 20-25 minutes to
provision from scratch every time. This feature adds the ability to snapshot a
fully-provisioned cluster and restore from snapshots for near-instant demo readiness.

New scripts in infra/scripts/:

1. demo-cloud-snapshot.sh — After a successful demo-cloud-up.sh run, snapshot all 4
   VMs (mgmt01, login01, compute01, compute02) via the hcloud CLI. Tag snapshots with
   a label group (e.g., "rcd-demo-YYYYMMDD") so they can be restored as a set. Store
   snapshot metadata (IDs, creation date, source cluster state) in
   infra/terraform/snapshot-manifest.json for later restore. Support --list to show
   available snapshot sets and --delete to clean up old ones.

2. demo-cloud-warm.sh — Restore a demo cluster from an existing snapshot set. Creates
   new VMs from the snapshots (same server types: cpx21 for mgmt01, cpx11 for others),
   attaches them to a new private network (10.0.0.0/24), generates a fresh Ansible
   inventory, and runs a health-check to verify all critical services are running
   (FreeIPA, Wazuh, Slurm, NFS, Munge). Target: cluster ready in under 5 minutes.
   If no snapshots exist, print a message directing the user to run demo-cloud-up.sh
   first and then demo-cloud-snapshot.sh.

3. demo-cloud-cool.sh — Gracefully wind down a demo session. Optionally snapshot the
   current state before teardown (for preserving demo artifacts). Then destroy all
   cloud resources (same as demo-cloud-down.sh). Report session duration and cost.

4. demo-cloud-health.sh — Standalone health-check script that SSHs into each node and
   verifies critical services: FreeIPA server (mgmt01), FreeIPA client enrollment
   (all others), slurmctld (mgmt01), slurmd (compute nodes), wazuh-manager (mgmt01),
   wazuh-agent (all others), NFS exports (mgmt01), NFS mounts (all others), munge
   (all nodes), chronyd (all nodes). Output a pass/fail summary table. Exit non-zero
   if any service is down. This script is called by demo-cloud-warm.sh but can also
   be run independently.

Integration points:
- demo-cloud-up.sh should prompt "Snapshot this cluster for future fast starts?" on
  successful completion, and call demo-cloud-snapshot.sh if confirmed.
- Add Makefile targets: demo-warm, demo-cool, demo-snapshot, demo-health.
- All scripts must work inside the existing Docker container (rcd-demo-infra image)
  and also natively if hcloud + terraform are installed locally.
- Respect the existing TTL safety checks (check-ttl.sh).
- The snapshot set must capture enough state that FreeIPA, Slurm, and Wazuh all come
  back functional after restore — this means private IPs must be reassigned to the
  same 10.0.0.x addresses as the original cluster.

Non-goals:
- No changes to the Vagrant demo lab (that's a separate feature).
- No changes to the demo scenarios or playbooks — they should work unchanged against
  a snapshot-restored cluster.
- No CI pipeline changes (that's a separate feature).
```

---

## Feature 2: Vagrant Pre-Baked Box Workflow (009)

**Status**: Specify after Feature 1 is implemented
**Priority**: High — local dev fast-start

```
/speckit.specify

Add pre-baked Vagrant box support to the local demo lab (spec 006). The current
demo-setup.sh provisions everything from scratch, taking 20-30+ minutes (worse on
Apple Silicon with QEMU emulation). This feature adds the ability to package a
fully-provisioned cluster as reusable Vagrant boxes and boot from them.

New scripts in demo/scripts/:

1. demo-bake.sh — After a successful demo-setup.sh run, package each VM as a named
   Vagrant box: rcd-cui-mgmt01, rcd-cui-login01, rcd-cui-compute01, rcd-cui-compute02.
   Store boxes in demo/vagrant/boxes/ (gitignored). Record box metadata (creation date,
   source commit hash, provider) in demo/vagrant/boxes/manifest.json.

2. Modify demo-setup.sh — Check for pre-baked boxes before provisioning from scratch.
   If boxes exist and are recent (configurable staleness threshold, default 7 days),
   offer to use them. Boot from baked boxes skips all Ansible provisioning. Target:
   cluster ready in under 5 minutes from baked boxes.

3. demo-refresh.sh — Rebuild baked boxes from the current codebase. Destroys existing
   VMs, provisions from scratch, re-bakes. This is the "prove reproducibility" step
   done periodically, not on every demo.

Integration: Update Vagrantfile to support a DEMO_USE_BAKED=1 environment variable.
Add Makefile targets: demo-bake, demo-refresh. Support all three providers (VirtualBox,
libvirt, QEMU). Baked boxes should be provider-specific.

Non-goals: No changes to cloud infrastructure. No changes to demo scenarios.
```

---

## Feature 3: CI Reproducibility Pipeline (010)

**Status**: Specify after Features 1-2 are stable
**Priority**: Medium — proves the system to auditors without blocking demos

```
/speckit.specify

Add a nightly CI pipeline that proves from-scratch reproducibility of the CUI
compliance stack without requiring manual demo runs. This moves the "prove it's
reproducible" concern from demo time to CI time.

GitHub Actions workflow (.github/workflows/demo-reproducibility.yml):

1. Nightly schedule (configurable cron) plus manual dispatch.
2. Provisions a Hetzner Cloud cluster from scratch using demo-cloud-up.sh.
3. Runs all 4 demo scenarios (A through D) in sequence.
4. Runs the compliance assessment (make assess).
5. Collects timing data, pass/fail results, and compliance scores.
6. Publishes results to the CI dashboard (spec 005) — a reproducibility badge and
   a "last verified" timestamp.
7. Tears down all cloud resources.
8. On failure: posts to a notification channel and retains logs.

Cost control: Only runs on schedule or manual trigger. Estimated cost per run:
~EUR 0.50 (25 min provision + 30 min scenarios at EUR 0.03/hour). Budget alert
if monthly spend exceeds configurable threshold.

Integration: Uses existing demo-cloud-up.sh and demo-cloud-down.sh. Publishes
badge data compatible with spec 005 dashboard. Stores run history as JSON artifacts.

Non-goals: No changes to demo scripts. No changes to roles or playbooks.
```

---

## Execution Order

1. **008 (Snapshot Lifecycle)** — Do this first. Gives you a 5-minute demo today.
2. **009 (Vagrant Bake)** — Do this second. Gives your local dev loop the same speed.
3. **010 (CI Reproducibility)** — Do this third. Proves the system to auditors on autopilot.

Each feature is independent and can be specified, planned, tasked, and implemented
through the full speckit workflow without blocking the others.
