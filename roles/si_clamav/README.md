# si_clamav

## What This Does

This role implements SI family CUI controls for hosts in the {{ cui_zone }} zone.
It follows the three-mode pattern:
- tasks/main.yml: Enforces configuration.
- tasks/verify.yml: Runs read-only compliance checks.
- tasks/evidence.yml: Collects structured SSP artifacts.

## Key Notes

- Inherits shared zone validation from roles/common and fails when cui_zone is missing.
- Uses control tags r2_3.14.2 and r3_03.14.02 with family_SI and zone_{{ cui_zone }} on all tasks.
- Supports Ansible --check mode for safe dry-runs.
