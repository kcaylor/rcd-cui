# Quickstart: Compliance Assessment and Reporting Layer

**Branch**: `003-compliance-assessment` | **Date**: 2026-02-14

## Prerequisites

Before using the compliance assessment tools, ensure:

1. **Spec 001 Complete**: Data models (control_mapping.yml, glossary, ODP values) exist in `docs/`
2. **Spec 002 Complete**: All 31 Ansible roles deployed with verify.yml and evidence.yml tasks
3. **Execution Environment Built**: `make ee-build` completed successfully
4. **Inventory Configured**: `inventory/hosts.yml` populated with target systems
5. **Credentials Available**: SSH keys or vault credentials for target systems

## Quick Commands

### Run Full Compliance Assessment

```bash
# Assess all systems and generate SPRS score
make assess

# View assessment results
cat data/assessment_history/$(date +%Y-%m-%d).json | jq '.sprs_score'
```

### Generate SPRS Score Report

```bash
# After running assessment
make sprs

# View score breakdown
cat reports/sprs_$(date +%Y-%m-%d).md
```

### Collect Evidence for SSP

```bash
# Collect all evidence artifacts
make evidence

# Evidence archive location
ls docs/auditor_packages/$(date +%Y-%m-%d)/evidence/
```

### Generate POA&M Report

```bash
# Edit POA&M items
vi data/poam.yml

# Generate reports
make poam

# View reports
cat reports/poam.md
cat reports/poam.csv
```

### Generate Compliance Dashboard

```bash
# Generate all dashboard views
make dashboard

# Open in browser
open reports/dashboard/index.html
```

### Generate Complete Auditor Package

```bash
# Generate everything for C3PAO assessment
make auditor-package

# Package location
ls docs/auditor_packages/$(date +%Y-%m-%d).tar.gz
```

## Typical Workflow

### 1. Pre-Assessment (Weekly)

```bash
# Verify infrastructure is healthy
make ee-syntax-check

# Run verification only (no evidence collection)
ansible-playbook playbooks/verify.yml -i inventory/hosts.yml --check
```

### 2. Full Assessment (Monthly or Pre-Audit)

```bash
# Complete assessment with evidence collection
make assess
make evidence
make report

# Review SPRS score
make sprs
```

### 3. Update POA&M (As Needed)

```bash
# Edit POA&M tracking file
vi data/poam.yml

# Regenerate reports
make poam

# Recalculate SPRS with POA&M credit
make sprs
```

### 4. Pre-Audit Preparation

```bash
# Generate complete auditor package
make auditor-package

# Verify package contents
tar tzf docs/auditor_packages/YYYY-MM-DD.tar.gz

# Extract and review
cd docs/auditor_packages/
tar xzf YYYY-MM-DD.tar.gz
```

## Dashboard Views

### Leadership View

Shows high-level compliance posture:
- SPRS score gauge (0-110 scale)
- Overall compliance percentage
- Control family status (green/yellow/red)

```bash
open reports/dashboard/index.html#leadership
```

### CISO View

Shows detailed breakdown for remediation planning:
- Per-family control status
- Failing controls with verification output
- Remediation priority list

```bash
open reports/dashboard/index.html#ciso
```

### Auditor View

Shows evidence links for external assessors:
- Control narratives
- Evidence file links
- Verification command outputs

```bash
open reports/dashboard/index.html#auditor
```

## POA&M Management

### Adding a New POA&M Item

Edit `data/poam.yml`:

```yaml
poam_items:
  - id: "POAM-001"
    control_id: "3.5.3"
    control_title: "Multi-factor authentication"
    weakness:
      description: "MFA not deployed to compute nodes"
      plain_language: >
        Users can log into compute nodes with only a password.
        This makes it easier for attackers who steal passwords
        to access systems containing research data.
    risk_level: "high"
    milestones:
      - description: "Deploy Duo agent to compute nodes"
        target_date: "2026-03-15"
        status: "in_progress"
    resources:
      - name: "System Administrator"
        allocation: "20 hours"
    status: "in_progress"
    created_date: "2026-02-01"
    last_updated: "2026-02-14"
```

### Updating POA&M Status

```bash
# Update milestone status
vi data/poam.yml
# Change status from "in_progress" to "completed"
# Add actual_completion_date

# Regenerate reports
make poam
```

## Troubleshooting

### Assessment Fails on Some Systems

```bash
# Check which systems failed
cat data/assessment_history/YYYY-MM-DD.json | jq '.coverage.not_assessed'

# Run against specific hosts
ansible-playbook playbooks/assess.yml -i inventory/hosts.yml --limit "login01,compute001"
```

### SPRS Score Doesn't Match Expectations

```bash
# View detailed breakdown
cat reports/sprs_YYYY-MM-DD.md

# Check specific control
cat data/assessment_history/YYYY-MM-DD.json | jq '.controls[] | select(.control_id == "3.5.3")'
```

### Evidence Files Too Large

```bash
# Check archive size
du -sh docs/auditor_packages/YYYY-MM-DD/evidence/

# Large files often in audit logs
find docs/auditor_packages/YYYY-MM-DD/evidence/ -size +10M -ls

# Consider truncating logs (last 30 days)
# Edit evidence collection to limit log capture
```

### Narrative Fails Glossary Validation

```bash
# Run validation
make validate

# Check specific terms
python scripts/validate_glossary.py --glossary docs/glossary/terms.yml \
  --scan-file reports/narratives/control_3.5.3.md

# Add missing terms to glossary
vi docs/glossary/terms.yml
```

## Integration with CI/CD

### Scheduled Assessment

```yaml
# .github/workflows/compliance.yml
name: Weekly Compliance Check
on:
  schedule:
    - cron: '0 6 * * 1'  # Monday 6am
jobs:
  assess:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - run: make ee-build
      - run: make assess
      - run: make report
      - uses: actions/upload-artifact@v4
        with:
          name: compliance-report
          path: reports/
```

### PR Validation

```yaml
# Verify no syntax errors
name: PR Validation
on: pull_request
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: make ee-build
      - run: make ee-lint
      - run: make ee-yamllint
```

## File Locations Summary

| Purpose | Location |
|---------|----------|
| Assessment playbook | `playbooks/assess.yml` |
| Evidence playbook | `playbooks/ssp_evidence.yml` |
| SPRS weights | `data/sprs_weights.yml` |
| POA&M data | `data/poam.yml` |
| Assessment history | `data/assessment_history/` |
| Dashboard output | `reports/dashboard/` |
| Auditor packages | `docs/auditor_packages/` |
| SPRS filter plugin | `plugins/filter/sprs.py` |
