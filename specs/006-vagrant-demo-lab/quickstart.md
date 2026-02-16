# Quickstart: Vagrant Demo Lab

**Feature**: 006-vagrant-demo-lab
**Date**: 2026-02-15

## Prerequisites

### Hardware

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 16 GB | 32 GB |
| Disk | 100 GB free | 200 GB SSD |
| CPU | 4 cores | 8 cores |

### Software

- Vagrant 2.3+
- Ansible 2.15+
- One provider: VirtualBox, libvirt, or QEMU (`vagrant-qemu`)

Examples:

```bash
# macOS Intel
brew install vagrant virtualbox ansible

# macOS Apple Silicon
brew install vagrant qemu ansible
vagrant plugin install vagrant-qemu

# Linux (libvirt)
sudo dnf install vagrant libvirt ansible
vagrant plugin install vagrant-libvirt
```

## Directory Layout

```text
rcd-cui/
  demo/
    vagrant/
      Vagrantfile
      ansible.cfg
      inventory/hosts.yml
    scripts/
      demo-setup.sh
      demo-break.sh
      demo-fix.sh
      demo-reset.sh
    playbooks/
      provision.yml
      scenario-a-onboard.yml
      scenario-b-drift.yml
      scenario-c-audit.yml
      scenario-d-lifecycle.yml
    narratives/
      scenario-a.md
      scenario-b.md
      scenario-c.md
      scenario-d.md
```

## First Run

```bash
cd /path/to/rcd-cui
./demo/scripts/demo-setup.sh
```

Optional provider override:

```bash
DEMO_PROVIDER=virtualbox ./demo/scripts/demo-setup.sh
DEMO_PROVIDER=libvirt ./demo/scripts/demo-setup.sh
DEMO_PROVIDER=qemu ./demo/scripts/demo-setup.sh
```

## Scenario Commands

### Scenario A: Project Onboarding

```bash
cd /path/to/rcd-cui/demo/vagrant
ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-a-onboard.yml -i inventory/hosts.yml
```

### Scenario B: Compliance Drift

```bash
cd /path/to/rcd-cui
./demo/scripts/demo-break.sh

cd /path/to/rcd-cui/demo/vagrant
ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-b-drift.yml -i inventory/hosts.yml --tags detect

cd /path/to/rcd-cui
./demo/scripts/demo-fix.sh
```

### Scenario C: Auditor Package

```bash
cd /path/to/rcd-cui/demo/vagrant
ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-c-audit.yml -i inventory/hosts.yml
```

### Scenario D: Node Lifecycle

```bash
cd /path/to/rcd-cui/demo/vagrant
ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-d-lifecycle.yml -i inventory/hosts.yml --tags add
ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-d-lifecycle.yml -i inventory/hosts.yml --tags verify
ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-d-lifecycle.yml -i inventory/hosts.yml --tags remove
```

## Reset and Shutdown

```bash
cd /path/to/rcd-cui
./demo/scripts/demo-reset.sh

cd demo/vagrant
vagrant halt
# or: vagrant suspend
# or: vagrant destroy -f
```

## Troubleshooting

### `vagrant: command not found`

Install Vagrant and reopen the shell so `PATH` updates apply.

### Provider not available

- VirtualBox: confirm `VBoxManage --version`
- libvirt: confirm `virsh version` and plugin `vagrant-libvirt`
- QEMU: confirm plugin `vagrant-qemu`

### VM startup fails from resource limits

Close other memory-heavy apps. The lab needs ~10GB guest RAM plus host overhead.

### Provisioning fails

Re-run:

```bash
cd /path/to/rcd-cui/demo/vagrant
vagrant provision
```

For verbose logs:

```bash
ANSIBLE_VERBOSITY=2 vagrant provision
```

### Baseline snapshot missing

```bash
cd /path/to/rcd-cui/demo/vagrant
vagrant snapshot list
vagrant snapshot push baseline --no-provision
```

### Network conflict with `192.168.56.0/24`

Update `demo/vagrant/Vagrantfile` private network IPs to a free subnet and update `demo/vagrant/inventory/hosts.yml` accordingly.

## Air-Gapped Operation Notes

After first successful provisioning with internet access:

1. Base box is cached in `~/.vagrant.d/boxes/`
2. Guest packages remain available in VM package caches
3. Scenario playbooks and narratives run without internet access
