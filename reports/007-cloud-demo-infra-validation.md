# Validation Report: Spec 007 Cloud Demo Infrastructure

Date: 2026-02-16
Workspace: `/Users/kellycaylor/dev/rcd-cui`

## Summary

Implemented Terraform configuration, cloud wrapper scripts, Makefile integration, TTL/status helper, and documentation for spec 007.

## Local Validation Performed

1. Shell syntax validation

```bash
bash -n infra/scripts/demo-cloud-up.sh infra/scripts/demo-cloud-down.sh infra/scripts/check-ttl.sh
```

Result: PASS

2. Script executable bits

```bash
chmod +x infra/scripts/demo-cloud-up.sh infra/scripts/demo-cloud-down.sh infra/scripts/check-ttl.sh
```

Result: PASS

3. Make target wiring (status target)

```bash
make demo-cloud-status
```

Result: PASS (target executes; reports missing Terraform in this environment)

## Validation Blocked in Current Environment

1. Terraform validation and formatting

```bash
cd infra/terraform
terraform fmt
terraform init -input=false
terraform validate
```

Result: BLOCKED (`terraform` not installed in this execution environment)

2. Full spin-up / scenario / teardown cycle

- `make demo-cloud-up`
- `ansible-playbook demo/playbooks/scenario-*.yml`
- `make demo-cloud-down`

Result: BLOCKED (requires installed Terraform/Ansible plus valid `HCLOUD_TOKEN` and live Hetzner account)

## Notes

- Inventory generation uses `ansible_user: root` and ProxyJump for compute nodes via `mgmt01`.
- `demo-cloud-up` blocks duplicate clusters by checking Terraform state.
- TTL warnings are surfaced on command runs through `infra/scripts/check-ttl.sh`.
- `specs/007-cloud-demo-infra/tasks.md` items still open: `T031`, `T034-T038`, and `T051`.
- `T031` is intentionally left open because `demo/vagrant/ansible.cfg` was explicitly marked as do-not-modify in the implementation request.
