# 006 Vagrant Demo Lab Validation Report

Date: 2026-02-15
Host: macOS 26.2 (arm64)
Repository: rcd-cui (local clone)

## T071 - Full Demo Flow on macOS with VirtualBox

Status: Executed (blocked)

Commands:
- `DEMO_PROVIDER=virtualbox ./demo/scripts/demo-setup.sh`

Result:
- Fails immediately because VirtualBox is not installed (`VBoxManage` not found).
- Installing VirtualBox/Vagrant casks requires interactive `sudo` password entry, unavailable in this execution environment.

## T072 - Full Demo Flow on Linux with libvirt

Status: Executed (blocked)

Method:
- Ran Ubuntu 24.04 privileged Docker environment with libvirt/qemu/vagrant setup attempt.

Commands:
- `docker run --rm --privileged ... ubuntu:24.04 ... DEMO_PROVIDER=libvirt ./demo/scripts/demo-setup.sh`

Result:
- `demo-setup.sh` prerequisite check reports only `7GB` RAM inside Docker environment and exits as designed.
- Full multi-VM libvirt flow cannot proceed under current Docker Desktop memory cap.

## T073 - Air-Gapped Operation After Initial Provisioning

Status: Executed (partial pass)

Precondition:
- Rocky box cached locally from prior Vagrant download.

Commands:
- Set invalid proxies to simulate no internet: `HTTP_PROXY/HTTPS_PROXY/ALL_PROXY=http://127.0.0.1:9`
- `vagrant up mgmt01 --provider qemu --no-provision`

Result:
- Startup used local box import and did not attempt Vagrant Cloud metadata fetch.
- Confirms cached-box startup path works without internet reachability.

## T074 - quickstart.md End-to-End Validation

Status: Executed (partial pass with environment blockers)

Validated:
- Script executability: `demo-setup.sh`, `demo-break.sh`, `demo-fix.sh`, `demo-reset.sh`.
- Playbook syntax: `provision.yml`, `scenario-a-onboard.yml`, `scenario-b-drift.yml`, `scenario-c-audit.yml`, `scenario-d-lifecycle.yml`.
- Vagrantfile Ruby syntax check passes.

Blocked portions:
- Full end-to-end Quickstart runtime remains blocked by provider availability (VirtualBox absent) and environment constraints for complete multi-VM provisioning in this session.

## Notes

- QEMU provider path was hardened during validation to fix:
  - invalid autostart usage (`config.vm.define ..., autostart:`)
  - x86 network device mismatch (`virtio-net-pci`)
  - per-node SSH port collisions (`qemu.ssh_port` + `ssh_auto_correct`)
