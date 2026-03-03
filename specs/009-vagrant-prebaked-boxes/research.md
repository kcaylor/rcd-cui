# Research: Pre-Baked Vagrant Box Workflow

**Feature**: 009-vagrant-prebaked-boxes
**Date**: 2026-03-02

## R-001: Vagrant Packaging Across Providers

### Decision
Use native `vagrant package` for VirtualBox and libvirt (first-class). Use manual qcow2 extraction and tarball construction for QEMU (best-effort).

### Rationale
- **VirtualBox**: `vagrant package` is natively supported. Exports OVF/VMDK, wraps in tarball with `metadata.json`. Straightforward.
- **libvirt**: `vagrant-libvirt` implements its own `PackageDomain` action using `virt-sysprep`. Requires `libguestfs-tools`. Produces qcow2-based `.box` files. Supports customizing sysprep operations via `VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS` env var — important to preserve SSH host keys and FreeIPA state.
- **QEMU**: `vagrant-qemu` (ppggff) does NOT implement `vagrant package`. Disk images are stored at `.vagrant/machines/<name>/qemu/vq_*/linked-box.img` as qcow2. Must be manually extracted, compressed with `qemu-img convert`, and packaged into a tarball with appropriate `metadata.json`.

### Alternatives Considered
- **Vagrant Cloud upload**: Rejected — adds external dependency, bandwidth costs, and latency. Local-only storage is sufficient.
- **Vagrant snapshots instead of boxes**: Rejected — snapshots are provider-internal and cannot be moved between machines. Boxes are portable.
- **OVA export for all providers**: Rejected — OVA is VirtualBox-specific. Not applicable to libvirt/QEMU.

## R-002: Box File Format

### Decision
Follow the standard Vagrant box format: a `.tar.gz` archive containing `metadata.json`, `Vagrantfile`, and the provider-specific disk image.

### Rationale
The format is consistent across providers but the disk image format differs:

| Component | VirtualBox | libvirt | QEMU |
|-----------|-----------|---------|------|
| Disk image | `box-disk1.vmdk` | `box.img` (qcow2) | `box.img` (qcow2) |
| VM descriptor | `box.ovf` | None | None |
| metadata.json | `{"provider":"virtualbox"}` | `{"provider":"libvirt","format":"qcow2","virtual_size":N}` | `{"provider":"qemu","format":"qcow2","virtual_size":N}` |

### Alternatives Considered
- Custom archive format: Rejected — would break `vagrant box add` compatibility.

## R-003: Per-VM vs. Per-Cluster Boxing

### Decision
Package each VM as a separate named box (4 boxes per set). Each VM gets its own box registered with Vagrant under a name like `rcd-cui-mgmt01`, `rcd-cui-login01`, etc.

### Rationale
- The Vagrantfile defines 4 separate VMs with different roles, IPs, and resource configs.
- `vagrant package` operates per-VM (you package one machine at a time).
- Separate boxes allow partial re-baking (e.g., only re-bake mgmt01 after FreeIPA changes).
- The Vagrantfile can reference each box by name using per-node `config.vm.box` overrides.

### Alternatives Considered
- Single monolithic box: Not possible — Vagrant's multi-machine model requires separate box definitions per VM.

## R-004: Vagrantfile Conditional Box Selection

### Decision
Use per-node box name overrides driven by `DEMO_USE_BAKED` environment variable detection in `demo-setup.sh`. The script will `vagrant box add` the baked boxes before `vagrant up`, then set an environment variable that the Vagrantfile reads.

### Rationale
The Vagrantfile supports conditional logic via Ruby and provider overrides:

```ruby
baked = ENV['RCD_PREBAKED'] == '1'
nodes.each do |name, settings|
  config.vm.define name do |vm|
    vm.vm.box = baked ? "rcd-cui-#{name}" : 'generic/rocky9'
    # ... provider configs unchanged
  end
end
```

The `demo-setup.sh` script handles the `vagrant box add` step before invoking `vagrant up`, ensuring boxes are registered with Vagrant's internal box store.

### Alternatives Considered
- Provider override (`override.vm.box`): More verbose, requires duplicate logic per provider. The simpler top-level `vm.vm.box` assignment works for all providers.
- `config.vm.box_url` with `file://` path: Less clean — requires URL encoding and doesn't integrate with `vagrant box list`.

## R-005: Service Preservation During Baking

### Decision
For VirtualBox: use `vagrant package` directly (handles export cleanly). For libvirt: customize `virt-sysprep` operations to preserve FreeIPA, Kerberos, Munge, and Wazuh state. For QEMU: halt VMs cleanly before extracting disk images.

### Rationale
FreeIPA server state (Kerberos KDC, CA certificates, LDAP database) and Slurm state (munge keys, node registrations) must be preserved in baked boxes. The default `virt-sysprep` operations can strip critical identity files.

For libvirt, the critical environment variable is:
```bash
export VAGRANT_LIBVIRT_VIRT_SYSPREP_OPERATIONS="defaults,-ssh-userdir,-ssh-hostkeys,-lvm-uuids"
```

This preserves SSH host keys (needed for known_hosts), while cleaning other transient state.

### Alternatives Considered
- Full sysprep (cloud-init style): Rejected — would require re-enrolling FreeIPA clients, regenerating munge keys, and re-registering Slurm nodes on every boot. Defeats the purpose of pre-baking.

## R-006: Post-Restore Service Reconciliation

### Decision
Reuse the existing `demo/playbooks/post-restore.yml` playbook (88 lines) for service restart after booting from baked boxes.

### Rationale
The `post-restore.yml` playbook already handles:
- Setting FQDN hostnames
- Updating `/etc/hosts` with private IP mappings
- Restarting FreeIPA/SSSD services
- Restarting NFS server and remounting on clients
- Restarting Munge and Slurm services

This was built for the cloud snapshot warm-restore (008) and is pure Ansible with no cloud-specific dependencies. It works identically for Vagrant.

### Alternatives Considered
- New Vagrant-specific post-restore playbook: Rejected — the existing one covers all needed service reconciliation.
- No post-restore at all: Risky — services may not start cleanly after VM image restore without explicit restart.

## R-007: Manifest Structure

### Decision
Use a JSON manifest at `demo/vagrant/boxes/manifest.json` following the pattern established by the cloud snapshot manifest (`infra/terraform/snapshot-manifest.json`).

### Rationale
Consistency with the cloud snapshot workflow (008). The manifest tracks:
- Box set label, creation timestamp, Git commit hash
- Provider name, Vagrant version
- Per-VM box file paths and sizes
- Staleness metadata for threshold checking

### Alternatives Considered
- YAML manifest: Rejected — JSON is consistent with the cloud snapshot manifest and easier to parse from Bash with `jq`.
- No manifest (rely on `vagrant box list`): Rejected — `vagrant box list` doesn't track creation date, commit hash, or set associations.

## R-008: Insertion Points in Existing Scripts

### Decision
Modify `demo-setup.sh` with minimal changes — insert baked-box detection after prerequisite checks (line ~195) and wrap the provisioning block in a conditional.

### Key Modification Points

| File | Location | Change |
|------|----------|--------|
| `demo-setup.sh` | After line 191 (prerequisites) | Insert `check_baked_boxes()` function call |
| `demo-setup.sh` | Lines 199-225 (provisioning) | Wrap in `if ! $USE_BAKED; then ... fi` conditional |
| `demo-setup.sh` | After line 225 (baseline snapshot) | Add auto-bake prompt for fresh provisions |
| `Vagrantfile` | Line 4 (`config.vm.box`) | Move into per-node conditional based on `ENV['RCD_PREBAKED']` |
| `Vagrantfile` | Lines 50-62 (ansible provisioner) | Wrap in `unless ENV['RCD_PREBAKED']` conditional |
| `Makefile` | Line 14 (.PHONY) | Add `demo-bake demo-refresh` |
| `Makefile` | After line 118 | Add target definitions |
| `demo/vagrant/.gitignore` | After line 2 | Add `boxes/` and `*.box` patterns |
