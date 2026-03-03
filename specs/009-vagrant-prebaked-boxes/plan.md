# Implementation Plan: Pre-Baked Vagrant Box Workflow

**Branch**: `009-vagrant-prebaked-boxes` | **Date**: 2026-03-02 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/009-vagrant-prebaked-boxes/spec.md`

## Summary

Add pre-baked Vagrant box support to the local demo lab, reducing cluster boot time from 20-30 minutes to under 5 minutes. The approach packages fully provisioned VMs as reusable Vagrant boxes using native `vagrant package` for VirtualBox/libvirt and manual qcow2 export for QEMU (best-effort). A JSON manifest tracks box sets with automatic 2-set rotation. The existing `demo-setup.sh` is modified to detect and offer baked boxes, and a `demo-refresh.sh` script provides a single-command destroy-provision-bake cycle.

## Technical Context

**Language/Version**: Bash (POSIX-compatible with Bash extensions, matching existing scripts), Ruby (Vagrantfile)
**Primary Dependencies**: Vagrant 2.3+, vagrant-libvirt (libvirt provider), vagrant-qemu (QEMU provider), `jq` (JSON parsing), `qemu-img` (QEMU disk operations)
**Storage**: Local filesystem (`demo/vagrant/boxes/`), JSON manifest file
**Testing**: Manual validation per provider; reuse existing demo scenario playbooks as functional tests
**Target Platform**: macOS (Apple Silicon via QEMU), Linux (libvirt, VirtualBox)
**Project Type**: Shell scripts + Vagrantfile modifications within existing Ansible framework
**Performance Goals**: Boot from baked boxes < 5 min; bake < 15 min; refresh cycle < 45 min
**Constraints**: 16 GB RAM minimum; ~40 GB disk for 2 retained box sets; boxes are provider-specific and non-portable across providers
**Scale/Scope**: 4 VMs per set, max 2 sets retained, single-user local development tool

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Plain Language First | PASS | Scripts use clear log messages, `--list` output is human-readable, prompts are self-explanatory |
| II. Data Model as Source of Truth | PASS | Box manifest is the single source of truth for box set state; no duplication |
| III. Compliance as Code | N/A | This feature is demo infrastructure tooling, not compliance controls |
| IV. HPC-Aware | N/A | No HPC/security control conflicts in demo tooling |
| V. Multi-Framework | N/A | Not a compliance framework feature |
| VI. Audience-Aware Documentation | PASS | quickstart.md provides per-workflow documentation |
| VII. Idempotent and Auditable | PASS | Scripts are idempotent (re-running demo-bake.sh rotates sets cleanly); manifest provides audit trail |
| VIII. Prefer Established Tools | PASS | Uses Vagrant's native `vagrant package` (VirtualBox, libvirt); QEMU workaround uses standard `qemu-img` |

**Post-Phase 1 Re-check**: PASS — Design uses existing `post-restore.yml` playbook (Principle VIII), JSON manifest follows pattern from cloud snapshot feature (Principle II), no new abstractions introduced.

## Project Structure

### Documentation (this feature)

```text
specs/009-vagrant-prebaked-boxes/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0: packaging research per provider
├── data-model.md        # Phase 1: manifest schema and entity model
├── quickstart.md        # Phase 1: usage workflows
├── checklists/
│   └── requirements.md  # Spec quality checklist
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
demo/
├── scripts/
│   ├── demo-setup.sh        # MODIFY: add baked-box detection, auto-bake prompt
│   ├── demo-bake.sh          # NEW: package VMs as boxes, manage manifest
│   ├── demo-refresh.sh       # NEW: destroy + provision + bake cycle
│   ├── demo-reset.sh         # UNCHANGED: snapshot restore works with baked boxes
│   ├── demo-break.sh         # UNCHANGED
│   └── demo-fix.sh           # UNCHANGED
├── vagrant/
│   ├── Vagrantfile           # MODIFY: conditional box selection via ENV
│   ├── boxes/                # NEW: baked box storage (gitignored)
│   │   └── manifest.json     # NEW: box set manifest
│   ├── .gitignore            # MODIFY: add boxes/ pattern
│   └── inventory/            # UNCHANGED
├── playbooks/
│   └── post-restore.yml      # REUSE: service reconciliation after baked boot
└── narratives/               # UNCHANGED

Makefile                      # MODIFY: add demo-bake, demo-refresh targets
.gitignore                    # MODIFY: add demo/vagrant/boxes/ pattern
```

**Structure Decision**: No new directories beyond `demo/vagrant/boxes/` (gitignored runtime artifact storage). New scripts follow existing naming convention (`demo-*.sh`) in `demo/scripts/`. Modifications to existing files are minimal and backward-compatible.

## Key Design Decisions

### D-001: Per-VM Boxing with Shared Set Label

Each of the 4 VMs is packaged as a separate `.box` file but grouped under a shared set label (e.g., `rcd-demo-20260302-01`). This enables:
- Vagrant's multi-machine model (each VM needs its own box)
- Potential future partial re-baking
- Clear naming: `rcd-demo-20260302-01-mgmt01.box`

### D-002: Provider-Specific Packaging Strategy

| Provider | Method | Prerequisites |
|----------|--------|---------------|
| VirtualBox | `vagrant package <vm> --output <file>` | None |
| libvirt | `vagrant package <vm> --output <file>` with custom `VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS` to preserve FreeIPA/Munge/SSH state | `libguestfs-tools` |
| QEMU | Manual: halt VM, `qemu-img convert` disk, create metadata.json, `tar` into `.box` | `qemu-img`, `jq` |

### D-003: Vagrantfile Conditional Box Selection

The Vagrantfile uses a simple Ruby conditional driven by `ENV['RCD_PREBAKED']`:

```ruby
baked = ENV['RCD_PREBAKED'] == '1'
nodes.each do |name, settings|
  config.vm.define name do |vm|
    vm.vm.box = baked ? "rcd-cui-#{name}" : 'generic/rocky9'
  end
end
```

The `demo-setup.sh` script sets this env var and runs `vagrant box add` for each VM before `vagrant up`.

### D-004: Post-Boot Service Reconciliation

After booting from baked boxes, run the existing `post-restore.yml` playbook to restart services that may not start cleanly from a disk image restore (FreeIPA, Munge, NFS, Slurm, SSSD). This reuses the cloud warm-restore pattern (008).

### D-005: Ansible Provisioner Conditional

When booting from baked boxes, skip the Vagrantfile's embedded Ansible provisioner entirely (no `--provision` flag, or `--no-provision`). The `demo-setup.sh` script handles post-restore separately.

### D-006: 2-Set Rotation

Manifest tracks at most 2 sets (`current` and `previous`). On each bake:
1. If `previous` exists, delete its box files and remove from manifest
2. If `current` exists, relabel it as `previous`
3. New set becomes `current`

This provides a rollback safety net without unbounded disk growth.

## Complexity Tracking

No constitution violations to justify. All design choices use established tools and patterns.
