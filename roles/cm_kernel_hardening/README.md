# cm_kernel_hardening

## What This Does

This role implements CM family CUI controls for hosts in the {{ cui_zone }} zone.
It follows the three-mode pattern:
- tasks/main.yml: Enforces configuration.
- tasks/verify.yml: Runs read-only compliance checks.
- tasks/evidence.yml: Collects structured SSP artifacts.

## Key Notes

- Inherits shared zone validation from roles/common and fails when cui_zone is missing.
- Uses control tags r2_3.4.8 and r3_03.04.08 with family_CM and zone_{{ cui_zone }} on all tasks.
- Supports Ansible --check mode for safe dry-runs.
