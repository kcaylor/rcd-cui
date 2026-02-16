# Scenario A: Project Onboarding (Project Helios)

## Duration

10 minutes total

## Objective

Show how a new research project is onboarded with identity, scheduler policy, and storage access controls in a single automated workflow.

## Presenter Flow

1. Explain starting state: cluster is running and no `helios` artifacts exist.
2. Run onboarding playbook:
   ```bash
   cd demo/vagrant
   ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-a-onboard.yml -i inventory/hosts.yml
   ```
3. Verify FreeIPA group and users.
4. Verify Slurm QOS.
5. Verify project storage path and ACL.

## Talking Points

- Identity is centralized in FreeIPA, so access revocation and auditing are consistent across nodes.
- Scheduler controls are tied to project identity (`project-helios` QOS).
- Storage ACLs are applied at onboarding time, reducing manual errors.
- The same flow can be repeated for other projects by changing `project_name`.

## Expected Output

- FreeIPA group `helios` exists.
- Users `alice_helios` and `bob_helios` exist and belong to `helios`.
- Slurm QOS `project-helios` exists.
- Directory `/shared/projects/helios` exists with ACL granting `helios` rwx access.

## Verification Commands

```bash
vagrant ssh mgmt01 -c "ipa group-show helios"
vagrant ssh mgmt01 -c "ipa user-show alice_helios"
vagrant ssh mgmt01 -c "ipa user-show bob_helios"
vagrant ssh mgmt01 -c "sacctmgr show qos project-helios"
vagrant ssh mgmt01 -c "getfacl /shared/projects/helios"
```

## Timing Notes

- 2 min: Context and pre-checks
- 4 min: Run onboarding playbook
- 3 min: Show verifications
- 1 min: Wrap-up and transition

## Presenter Notes

- Keep terminal output zoomed; focus on final state checks, not every task line.
- If user creation already exists from prior runs, call out idempotent behavior.
- Bridge to Scenario B by noting this clean baseline can be intentionally drifted.
