# Instructions for Implementing the Specification Using Speckit

## Current Status

The specification is complete and ready for implementation:

✅ Constitution created (`.specify/memory/constitution.md`)
✅ Feature spec created (`specs/001-data-models-docs-foundation/spec.md`)
✅ Clarifications completed (4 questions answered)
✅ Planning complete (`plan.md`, `research.md`, `data-model.md`, `quickstart.md`)
✅ Tasks generated (`tasks.md` - 150 implementation tasks)

## Next Step: Implementation

Run the implementation command:

```
/speckit.implement
```

This will:
1. Read the tasks from `specs/001-data-models-docs-foundation/tasks.md`
2. Execute each task systematically following the dependency order
3. Create all files, write all code, populate all YAML data
4. Run tests to verify each user story works independently
5. Complete all 150 tasks organized across 10 phases

## What to Expect

The implementation agent will:

**Phase 1 (Setup)**: Create directory structure, requirements.txt, ansible.cfg, .gitignore
**Phase 2 (Foundational)**: Create all Pydantic models in `scripts/models/`
**Phase 3 (US1)**: Build control mapping with 110 NIST 800-171 controls
**Phase 4 (US2)**: Build glossary with 60+ plain-language terms
**Phase 5 (US3)**: Document 10+ HPC tailoring decisions
**Phase 6 (US4)**: Define all 49 organization-defined parameters
**Phase 7 (US5)**: Build documentation generator with 7 Jinja2 templates
**Phase 8 (US6)**: Build glossary validator
**Phase 9 (US7)**: Create Makefile, README, project skeleton
**Phase 10 (Polish)**: Add docstrings, tests, CI/CD, optimize performance

## Implementation Scope Options

### Option 1: Full Implementation (All 150 Tasks)
```
/speckit.implement
```
Implements everything including documentation generator and validators.

### Option 2: MVP Only (User Stories 1, 2, 3)
If you want just the core data models first:
```
/speckit.implement
```
Then tell the agent: "Implement only Phase 1, Phase 2, and User Stories 1, 2, 3 (tasks T001-T080). Stop after completing the MVP scope."

## Key Files the Agent Will Create

**Pydantic Models**:
- `scripts/models/__init__.py`
- `scripts/models/control_mapping.py`
- `scripts/models/glossary.py`
- `scripts/models/hpc_tailoring.py`
- `scripts/models/odp_values.py`

**YAML Data Files** (canonical source of truth):
- `roles/common/vars/control_mapping.yml` (110 controls)
- `docs/glossary/terms.yml` (60+ terms)
- `docs/hpc_tailoring.yml` (10+ tailoring decisions)
- `docs/odp_values.yml` (49 ODPs)

**Python Scripts**:
- `scripts/generate_docs.py` (documentation generator)
- `scripts/validate_glossary.py` (glossary validator)

**Jinja2 Templates** (7 total):
- `templates/pi_guide.md.j2`
- `templates/researcher_quickstart.md.j2`
- `templates/sysadmin_reference.md.j2`
- `templates/ciso_compliance_map.md.j2`
- `templates/leadership_briefing.md.j2`
- `templates/glossary_full.md.j2`
- `templates/crosswalk.csv.j2`

**Tests**:
- `tests/conftest.py`
- `tests/test_yaml_schemas.py`
- `tests/test_generate_docs.py`
- `tests/test_glossary_validator.py`

**Build System**:
- `Makefile` (with docs, validate, crosswalk, clean, test targets)
- `README.md`
- `requirements.txt`

## Verification After Implementation

Once the agent completes, verify the implementation:

```bash
# Install dependencies
pip install -r requirements.txt

# Run all tests
pytest tests/ -v

# Generate documentation
make docs

# Validate glossary coverage
make validate

# Generate crosswalk CSV
make crosswalk
```

Expected results:
- All tests pass (>90% coverage)
- 7 documentation files generated in `docs/generated/`
- Glossary validator reports no undefined terms
- CSV crosswalk opens correctly in Excel

## Important Notes

**The agent has all the information it needs**:
- Complete Pydantic schemas in `data-model.md`
- YAML examples in `data-model.md`
- 150 specific tasks in `tasks.md`
- All clarifications in `spec.md`
- Technology decisions in `research.md`
- Performance requirements in `plan.md`

**Constitutional Principles** (agent must follow):
- Plain Language First (2-4 sentence explanations for all technical terms)
- Data Model as Source of Truth (YAML canonical, docs generated)
- HPC-Aware (document all deviations with compensating controls)
- Audience-Aware (5 distinct audiences: PI, researcher, sysadmin, CISO, leadership)
- Multi-Framework (NIST 800-171 R2/R3, CMMC L2, 800-53 R5 simultaneously)

**Critical Requirements**:
- Minimum 110 controls in control_mapping.yml
- Minimum 60 terms in glossary
- Exactly 49 ODPs
- Minimum 10 HPC tailoring decisions
- Documentation generation completes in <30 seconds
- All "N/A" framework mappings must have rationale
- Test coverage >90%

## Optional: Analyze First

Before implementing, you can optionally run a consistency check:

```
/speckit.analyze
```

This performs a non-destructive analysis of spec.md, plan.md, and tasks.md to verify:
- No conflicting requirements
- All tasks map to user stories
- All acceptance criteria covered
- No missing dependencies

## Summary

To implement the specification:

1. Run `/speckit.implement`
2. Let the agent work through all 150 tasks
3. Verify with `pytest tests/ -v` and `make docs`
4. Review generated files in `docs/generated/`

That's it! The specification documents contain everything needed for complete implementation.
