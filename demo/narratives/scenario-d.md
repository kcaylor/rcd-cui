# Scenario D: Node Lifecycle Management

## Duration

15 minutes total

## Objective

Demonstrate controlled node onboarding with compliance gating and clean decommissioning.

## Presenter Flow

1. Explain that `compute03` is defined but dormant by default.
2. Add node:
   ```bash
   cd demo/vagrant
   ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-d-lifecycle.yml -i inventory/hosts.yml --tags add
   ```
3. Run compliance gate:
   ```bash
   ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-d-lifecycle.yml -i inventory/hosts.yml --tags verify
   ```
4. Show successful cluster registration when gate passes.
5. Decommission node:
   ```bash
   ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-d-lifecycle.yml -i inventory/hosts.yml --tags remove
   ```

## Talking Points

- Nodes do not join the production partition without passing compliance checks.
- Identity and scheduler registration are automated and auditable.
- Decommissioning revokes credentials and removes scheduling access.
- Lifecycle controls reduce risk from unmanaged scale events.

## Expected Output

- `compute03` starts only during lifecycle demo.
- FreeIPA host record for `compute03.demo.lab` is created on add and removed on decommission.
- Slurm config includes `compute03` during add and removes it during decommission.
- Compliance gate reports pass/fail explicitly before join.

## Verification Commands

```bash
cd demo/vagrant && vagrant status compute03
vagrant ssh mgmt01 -c "ipa host-show compute03.demo.lab"
vagrant ssh mgmt01 -c "grep -E '^NodeName=compute03' /etc/slurm/slurm.conf"
vagrant ssh mgmt01 -c "scontrol reconfigure && scontrol show nodes"
```

## Timing Notes

- 3 min: Explain lifecycle and dormant-node model
- 4 min: Add `compute03`
- 3 min: Run and discuss compliance gate results
- 4 min: Decommission and validate cleanup
- 1 min: Summary

## Presenter Notes

- If compliance gate fails, use that as the expected safety demonstration.
- Keep focus on control points: provision -> gate -> register -> revoke.
- Link this to operational change control and incident containment narratives.
