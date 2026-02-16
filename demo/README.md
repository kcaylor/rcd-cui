# Demo Lab Reference

This directory contains the Vagrant demo environment for feature `006-vagrant-demo-lab`.

## Quick Start

```bash
cd /path/to/rcd-cui
./demo/scripts/demo-setup.sh
```

## Main Scripts

- `demo/scripts/demo-setup.sh`: bring up/provision VMs and create baseline snapshot
- `demo/scripts/demo-break.sh`: introduce compliance violations
- `demo/scripts/demo-fix.sh`: remediate violations
- `demo/scripts/demo-reset.sh`: restore baseline snapshot

Provider override for any script:

```bash
DEMO_PROVIDER=virtualbox ./demo/scripts/demo-setup.sh
DEMO_PROVIDER=libvirt ./demo/scripts/demo-setup.sh
DEMO_PROVIDER=qemu ./demo/scripts/demo-setup.sh
```

## Playbooks

- `demo/playbooks/provision.yml`
- `demo/playbooks/scenario-a-onboard.yml`
- `demo/playbooks/scenario-b-drift.yml`
- `demo/playbooks/scenario-c-audit.yml`
- `demo/playbooks/scenario-d-lifecycle.yml`

Run pattern:

```bash
cd /path/to/rcd-cui/demo/vagrant
ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/<playbook>.yml -i inventory/hosts.yml
```

## Narratives

- `demo/narratives/scenario-a.md`
- `demo/narratives/scenario-b.md`
- `demo/narratives/scenario-c.md`
- `demo/narratives/scenario-d.md`

## VM Topology

- `mgmt01` `192.168.56.10`
- `login01` `192.168.56.20`
- `compute01` `192.168.56.31`
- `compute02` `192.168.56.32`
- `compute03` `192.168.56.33` (dormant, lifecycle demo only)

## Testing Status

Validation performed (see `reports/006-vagrant-demo-lab-validation.md`):

- **Passed**: Script executability, playbook syntax, Vagrantfile syntax, air-gapped cached-box startup
- **Blocked**: Full multi-VM e2e runtime due to environment constraints (Apple Silicon QEMU emulation, RAM limits)

Full end-to-end validation is planned for spec 007 (cloud demo infrastructure) which provisions native x86 VMs on Hetzner Cloud.
