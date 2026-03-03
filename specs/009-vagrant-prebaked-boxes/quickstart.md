# Quickstart: Pre-Baked Vagrant Box Workflow

**Feature**: 009-vagrant-prebaked-boxes
**Date**: 2026-03-02

## Prerequisites

- Vagrant 2.3+ installed
- One of: VirtualBox 7.0+, libvirt (with `libguestfs-tools`), or vagrant-qemu
- 16 GB RAM minimum
- ~40 GB free disk space (for 2 retained box sets)
- `jq` installed (for manifest parsing)
- `qemu-img` installed (required only for QEMU provider baking)

## Workflow A: First-Time Bake

```bash
# 1. Provision from scratch (20-30 min)
./demo/scripts/demo-setup.sh

# 2. At the prompt, accept "Bake this cluster for future fast starts?" [Y/n]
#    Or bake manually:
./demo/scripts/demo-bake.sh

# 3. Verify baked boxes
./demo/scripts/demo-bake.sh --list
```

## Workflow B: Fast Demo Start (from Baked Boxes)

```bash
# 1. Start demo (detects baked boxes, prompts to use them)
./demo/scripts/demo-setup.sh
# → "Baked boxes found (rcd-demo-20260302-01, 2 days old). Use them? [Y/n]"
# → Boots in ~5 min instead of 20-30 min

# 2. Run demo scenarios as normal
ansible-playbook -i demo/vagrant/inventory/hosts.yml demo/playbooks/scenario-a-onboard.yml
```

## Workflow C: Refresh Baked Boxes

```bash
# After code changes to roles/playbooks:
./demo/scripts/demo-refresh.sh
# → Destroys VMs, provisions from scratch, bakes new boxes (~45 min)
```

## Workflow D: Non-Interactive (CI/Automation)

```bash
# Force baked boxes (fail if none exist)
DEMO_USE_BAKED=1 ./demo/scripts/demo-setup.sh

# Force fresh provisioning (ignore available boxes)
DEMO_USE_BAKED=0 ./demo/scripts/demo-setup.sh
```

## Makefile Targets

```bash
make demo-bake          # Package current cluster as boxes
make demo-refresh       # Destroy, reprovision, and re-bake
```

## Managing Box Sets

```bash
# List available sets
./demo/scripts/demo-bake.sh --list

# Delete a specific set
./demo/scripts/demo-bake.sh --delete rcd-demo-20260301-01

# Delete all sets
./demo/scripts/demo-bake.sh --delete-all
```

## Environment Variables

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `DEMO_USE_BAKED` | `0`, `1`, unset | unset | Force fresh (`0`), force baked (`1`), or prompt (unset) |
| `DEMO_PROVIDER` | `virtualbox`, `libvirt`, `qemu` | auto-detect | Override provider detection |
| `DEMO_STALE_DAYS` | integer | `7` | Staleness threshold in days |

## Validation Checklist

After booting from baked boxes, verify:

- [ ] All 4 VMs running (`vagrant status`)
- [ ] FreeIPA server operational on mgmt01
- [ ] FreeIPA client enrolled on login01, compute01, compute02
- [ ] Slurm controller running on mgmt01
- [ ] Slurm compute daemons running on compute01, compute02
- [ ] NFS exports active on mgmt01
- [ ] NFS mounts present on login01, compute01, compute02
- [ ] Munge running on all nodes
- [ ] Wazuh manager running on mgmt01
- [ ] Demo scenario A completes successfully
