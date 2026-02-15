# Quickstart: CUI Compliance Data Models and Documentation

**Feature**: 001-data-models-docs-foundation
**Date**: 2026-02-14

## Purpose

This guide shows you how to use the CUI compliance data models and documentation generation tools to create audience-specific compliance documentation from YAML data sources.

---

## Prerequisites

- **Python**: 3.9 or higher
- **OS**: RHEL 9, Rocky Linux 9, or compatible Linux distribution
- **Access**: Repository cloned to local machine

---

## Installation

### 1. Install Python Dependencies

```bash
cd /path/to/rcd-cui
pip install -r requirements.txt
```

The `requirements.txt` includes:
- `pyyaml>=6.0` - YAML parsing
- `pydantic>=2.0` - Data validation
- `jinja2>=3.1` - Template rendering
- `pytest>=7.0` - Testing (development only)

### 2. Verify Installation

```bash
python --version  # Should be 3.9+
python -c "import pydantic; print(pydantic.VERSION)"  # Should be 2.x
```

---

## Quick Start: Generate Documentation

### Generate All 7 Outputs

```bash
make docs
```

This runs `scripts/generate_docs.py` and creates:
- `docs/generated/pi_guide.md` - Principal Investigator guide
- `docs/generated/researcher_quickstart.md` - Researcher onboarding
- `docs/generated/sysadmin_reference.md` - Operations manual
- `docs/generated/ciso_compliance_map.md` - Control implementation matrix
- `docs/generated/leadership_briefing.md` - Executive summary
- `docs/generated/glossary_full.md` - Complete glossary
- `docs/generated/crosswalk.csv` - Framework crosswalk (Excel-compatible)

**Expected Output**:
```
Loading YAML data models...
  ✓ roles/common/vars/control_mapping.yml (110 controls)
  ✓ docs/glossary/terms.yml (62 terms)
  ✓ docs/hpc_tailoring.yml (12 entries)
  ✓ docs/odp_values.yml (49 ODPs)

Validating schemas...
  ✓ All required fields present
  ✓ Cross-references valid

Generating documentation...
  ✓ docs/generated/pi_guide.md (1,243 lines)
  ✓ docs/generated/researcher_quickstart.md (876 lines)
  ✓ docs/generated/sysadmin_reference.md (2,104 lines)
  ✓ docs/generated/ciso_compliance_map.md (3,567 lines)
  ✓ docs/generated/leadership_briefing.md (421 lines)
  ✓ docs/generated/glossary_full.md (4,892 lines)
  ✓ docs/generated/crosswalk.csv (110 rows)

Documentation generated successfully in 4.2 seconds.
```

### Generate Only Crosswalk CSV

```bash
make crosswalk
```

Useful for importing control mappings into Excel or compliance tracking tools.

---

## Validate Glossary Coverage

### Check for Undefined Terms

```bash
make validate
```

This runs `scripts/validate_glossary.py` and scans all `.md`, `.yml`, and `.j2` files for acronyms not defined in `docs/glossary/terms.yml`.

**Example Output (Success)**:
```
Scanning for undefined terms...
  Checking docs/generated/*.md
  Checking roles/*/README.md
  Checking specs/*/*.md

✓ All terms validated (0 undefined acronyms found)
```

**Example Output (Violations)**:
```
Scanning for undefined terms...

ERROR: Undefined terms found:

  File: docs/generated/pi_guide.md
    Line 42: XYZ
    Line 87: ABC

  File: roles/access_control/README.md
    Line 15: FOOBAR

3 undefined terms. Please add to docs/glossary/terms.yml

FAILED: Glossary validation failed
```

**Fix**: Add missing terms to `docs/glossary/terms.yml` following the schema in [data-model.md](data-model.md#file-2-glossary-docsglossarytermsy ml).

---

## Editing YAML Data Models

### 1. Edit Control Mapping

Open `roles/common/vars/control_mapping.yml` and add/update controls:

```yaml
controls:
  - control_id: "3.1.1"
    title: "Access Control Policy and Procedures"
    family: "AC"
    plain_language: |
      Your 2-4 sentence plain-language explanation here...
    # ... other required fields ...
```

**Important**: Follow the Pydantic schema defined in [data-model.md](data-model.md#file-1-control-mapping-rolescommonvarscontrol_mappingyml).

### 2. Edit Glossary

Open `docs/glossary/terms.yml` and add terms:

```yaml
terms:
  "NEW_TERM":
    term: "NEW_TERM"
    full_name: "Expanded Name"
    plain_language: |
      2-4 sentence explanation anyone can understand...
    who_cares:
      pi: "Why PIs care..."
      researcher: "Why researchers care..."
      sysadmin: "Why sysadmins care..."
      ciso: "Why CISO cares..."
      leadership: "Why leadership cares..."
    see_also:
      - "RELATED_TERM"
```

**Context Tags** (for ambiguous acronyms):
```yaml
terms:
  "AC (compliance)":
    term: "AC (compliance)"
    full_name: "Access Control"
    context: "compliance"
    # ... rest of fields ...

  "AC (hardware)":
    term: "AC (hardware)"
    full_name: "Alternating Current"
    context: "hardware"
    # ... rest of fields ...
```

### 3. Edit HPC Tailoring

Open `docs/hpc_tailoring.yml` and document deviations:

```yaml
tailoring_decisions:
  - tailoring_id: "my-hpc-deviation"
    control_r2: "3.X.Y"
    control_r3: "03.XX.YY"
    title: "Short Title"
    standard_requirement: "What baseline requires..."
    hpc_challenge: "Why HPC conflicts..."
    tailored_implementation: "What we actually do..."
    compensating_controls:
      - "Alternative control 1"
      - "Alternative control 2"
    risk_acceptance: "low"  # or "medium", "high"
```

### 4. Edit ODP Values

Open `docs/odp_values.yml` and assign parameters:

```yaml
odp_values:
  - odp_id: "ODP-XX"
    control: "03.XX.YY"
    parameter_description: "What this controls"
    assigned_value: "Your value"
    rationale: "Why you chose this value"
    dod_guidance: "DoD recommended value (if known)"
    deviation_rationale: "Required if assigned_value != dod_guidance"
```

---

## Validation Workflow

### Pre-Commit Validation

Before committing YAML changes, validate schemas:

```bash
make validate-schemas  # Runs pytest tests/test_yaml_schemas.py
```

This checks:
- All required fields present
- Correct data types
- Value constraints (e.g., sprs_weight 1-5)
- Cross-references valid (hpc_tailoring_ref exists, see_also terms exist)

### CI/CD Integration

The validation tests run automatically on every pull request:

```bash
# .github/workflows/validate.yml or .gitlab-ci.yml
pytest tests/test_yaml_schemas.py
```

Pull requests fail if:
- YAML schema validation fails
- Fewer than 110 controls in control_mapping.yml
- Fewer than 60 terms in terms.yml
- Missing ODP values (must be exactly 49)
- Undefined glossary references

---

## Common Tasks

### Task 1: Add a New Control

1. Open `roles/common/vars/control_mapping.yml`
2. Add new control entry following schema
3. If HPC-specific, create tailoring entry in `docs/hpc_tailoring.yml`
4. Add related terms to `docs/glossary/terms.yml`
5. Validate: `make validate-schemas`
6. Regenerate docs: `make docs`
7. Check for undefined terms: `make validate`

### Task 2: Add HPC Tailoring Decision

1. Open `docs/hpc_tailoring.yml`
2. Create new tailoring entry with unique `tailoring_id`
3. Reference from control in `control_mapping.yml`:
   ```yaml
   hpc_tailoring_ref: "your-tailoring-id"
   ```
4. Validate and regenerate docs

### Task 3: Update ODP Value

1. Open `docs/odp_values.yml`
2. Find ODP by `odp_id` or `control`
3. Update `assigned_value` and `rationale`
4. If deviating from DoD guidance, add `deviation_rationale`
5. Validate and regenerate docs

### Task 4: Bulk Update Control Metadata

When adding automation capability flags or SPRS weights to multiple controls:

```bash
# Example: Python script to update multiple controls
python scripts/bulk_update.py --set-automatable AC-2,AC-3,AC-17 --value true
make validate-schemas
make docs
```

---

## Troubleshooting

### Error: Validation Failed

**Problem**: `pydantic.ValidationError` when running `make docs`

**Solution**: Check error message for specific field and fix YAML:
```
ValidationError: 1 validation error for SecurityControl
controls[42].sprs_weight
  Input should be greater than or equal to 1 [type=greater_than_equal, input_value=0]
```

Fix: Open `control_mapping.yml`, find entry 42, set `sprs_weight` to valid value (1-5).

### Error: Cross-Reference Not Found

**Problem**: `hpc_tailoring_ref` references non-existent entry

**Solution**: Ensure `tailoring_id` in `hpc_tailoring.yml` matches reference:
```yaml
# In control_mapping.yml
hpc_tailoring_ref: "session-timeout-compute-nodes"

# Must exist in hpc_tailoring.yml
tailoring_id: "session-timeout-compute-nodes"
```

### Error: Undefined Glossary Term

**Problem**: `make validate` reports undefined acronym

**Solution**: Add term to `docs/glossary/terms.yml` or fix typo in source file.

### Performance: Docs Take >30 Seconds

**Problem**: Documentation generation exceeds performance target (SC-004)

**Investigation**:
```bash
time python scripts/generate_docs.py --validate-only  # Check YAML load time
```

**Likely Causes**:
- YAML files >1 MB (check file sizes)
- Network file system latency (move to local disk)
- Memory constraints (increase available RAM)

---

## Next Steps

### For Developers

1. **Implement Ansible Roles**: Use control_mapping.yml to create roles (spec 002)
2. **Add Custom Validators**: Extend Pydantic models for business logic
3. **Enhance Templates**: Customize Jinja2 templates in `templates/`

### For Compliance Officers

1. **Review Generated Docs**: Check `docs/generated/` for accuracy
2. **Update ODP Values**: Align with institutional policies
3. **Document Tailoring**: Add HPC-specific deviations with compensating controls

### For System Administrators

1. **Use Sysadmin Reference**: `docs/generated/sysadmin_reference.md` is your operations manual
2. **Implement Controls**: Follow Ansible role assignments (populated in future specs)
3. **Monitor Compliance**: Use `make validate` in CI/CD

---

## Reference

- **Data Model Schemas**: [data-model.md](data-model.md)
- **Research & Decisions**: [research.md](research.md)
- **Implementation Plan**: [plan.md](plan.md)
- **Constitution**: [.specify/memory/constitution.md](../.specify/memory/constitution.md)

## Support

For questions or issues:
- Check [data-model.md](data-model.md) for schema details
- Review [research.md](research.md) for technology decisions
- File issues at [project repository]
