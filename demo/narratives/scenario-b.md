# Scenario B: Compliance Drift Detection and Remediation

## Duration

12 minutes total

## Objective

Demonstrate intentional compliance drift, detection of failing controls, and automated remediation.

## Presenter Flow

1. Start from compliant baseline (`demo-setup.sh` or `demo-reset.sh`).
2. Introduce violations:
   ```bash
   ./demo/scripts/demo-break.sh
   ```
3. Run drift scenario detection:
   ```bash
   cd demo/vagrant
   ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-b-drift.yml -i inventory/hosts.yml --tags detect
   ```
4. Remediate:
   ```bash
   ./demo/scripts/demo-fix.sh
   ```
5. Re-run detection to show controls return to pass state.

## Talking Points

- Drift is inevitable in real operations; detection speed matters.
- Findings map directly to control IDs (3.1.1, 3.3.1, 3.1.2, 3.13.1).
- Remediation is policy-driven and repeatable.
- Same workflow supports both engineering and audit audiences.

## Expected Output

- Break phase introduces:
  - `PermitRootLogin yes`
  - `auditd` stopped
  - `/etc/shadow` mode `644`
  - `firewalld` stopped
- Detect phase reports failing control entries.
- Fix phase restores:
  - `PermitRootLogin no`
  - `auditd` active
  - `/etc/shadow` mode `000`
  - `firewalld` active

## Verification Commands

```bash
vagrant ssh mgmt01 -c "grep -E '^PermitRootLogin' /etc/ssh/sshd_config"
vagrant ssh mgmt01 -c "systemctl is-active auditd"
vagrant ssh mgmt01 -c "stat -c %a /etc/shadow"
vagrant ssh mgmt01 -c "systemctl is-active firewalld"
```

## Timing Notes

- 2 min: Explain baseline and violation plan
- 3 min: Execute break workflow
- 3 min: Run detection and review failing controls
- 3 min: Run remediation
- 1 min: Confirm restored compliance

## Presenter Notes

- Keep the control IDs visible when discussing findings.
- If a service restart takes longer, narrate that this reflects real ops conditions.
- Transition to Scenario C by highlighting that the same findings become evidence artifacts.
