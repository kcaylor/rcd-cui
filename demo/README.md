# Demo Lab

Local and cloud demo environments for the RCD-CUI framework.

## Pre-Baked Vagrant Boxes

Pre-baked boxes allow you to boot a fully provisioned demo cluster in under 5 minutes instead of the usual 20-30 minute provisioning cycle.

See `specs/009-vagrant-prebaked-boxes/quickstart.md` for detailed workflows.

### Quick Start

```bash
# First time: provision and bake
./demo/scripts/demo-setup.sh        # Provisions from scratch, offers to bake at end
./demo/scripts/demo-bake.sh --list  # Verify baked boxes

# Subsequent runs: boot from baked boxes
./demo/scripts/demo-setup.sh        # Detects boxes, offers fast boot

# Refresh boxes after code changes
./demo/scripts/demo-refresh.sh      # Destroy → provision → bake
```

### QEMU Provider Limitations

QEMU (vagrant-qemu) is supported on a **best-effort** basis for box baking. Key differences from VirtualBox and libvirt:

- **Packaging method**: QEMU uses raw disk image export (`qemu-img convert`) rather than native `vagrant package`, since vagrant-qemu does not support the package command.
- **Box file size**: QEMU boxes may be larger than VirtualBox or libvirt equivalents due to the disk conversion process, even with qcow2 compression.
- **Additional prerequisites**: QEMU baking requires `qemu-img` and `jq` to be installed on the host.
- **VM halt/restart**: During baking, QEMU VMs are halted for disk export and restarted afterward. This adds time compared to other providers.
- **Disk location**: The script locates QEMU disk images at `.vagrant/machines/<vm>/qemu/vq_*/linked-box.img`. If your vagrant-qemu version stores disks elsewhere, baking may fail.

### Environment Variables

| Variable | Values | Default | Description |
|----------|--------|---------|-------------|
| `DEMO_USE_BAKED` | `0`, `1`, unset | unset | Force fresh (`0`), force baked (`1`), or prompt (unset) |
| `DEMO_PROVIDER` | `virtualbox`, `libvirt`, `qemu` | auto-detect | Override provider detection |
| `DEMO_STALE_DAYS` | integer | `7` | Staleness threshold in days |
