# Scenario C: Auditor Package Generation

## Duration

8 minutes total

## Objective

Generate a complete auditor-ready package that bundles assessment outputs, evidence artifacts, and reporting summaries.

## Presenter Flow

1. Confirm Scenario B has produced recent assessment data.
2. Run audit scenario:
   ```bash
   cd demo/vagrant
   ANSIBLE_CONFIG=ansible.cfg ansible-playbook ../playbooks/scenario-c-audit.yml -i inventory/hosts.yml
   ```
3. Show generated files in `/shared/auditor`.
4. Explain package structure and how auditors consume it.

## Talking Points

- Package creation is automated and repeatable from current assessment state.
- Evidence includes both machine output and control mappings.
- SPRS and POA&M context are included for review readiness.
- Shared path publication (`/shared/auditor`) supports consistent handoff.

## Expected Output

- Fresh assessment data generated.
- Evidence package and manifest copied to `/shared/auditor` on `mgmt01`.
- Archive named with current date, for example `YYYY-MM-DD.tar.gz`.

## Verification Commands

```bash
vagrant ssh mgmt01 -c "ls -lah /shared/auditor"
vagrant ssh mgmt01 -c "tar -tzf /shared/auditor/$(date +%F).tar.gz | head -n 20"
vagrant ssh mgmt01 -c "cat /shared/auditor/manifest.json"
```

## Timing Notes

- 1 min: Setup context from prior scenarios
- 3 min: Execute scenario-c playbook
- 3 min: Inspect archive and manifest contents
- 1 min: Summarize auditor handoff workflow

## Presenter Notes

- If package generation reuses existing evidence, call out timestamped artifact naming.
- Keep the focus on traceability: assessment -> evidence -> package.
- Transition to Scenario D by framing lifecycle events as new evidence-producing changes.
