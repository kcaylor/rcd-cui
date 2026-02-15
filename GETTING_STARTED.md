# Getting Started: Implementing the Data Models and Documentation Foundation

## Overview

This guide explains how to implement the feature specification located in `specs/001-data-models-docs-foundation/`. The spec documents contain all the information you need - this guide just points you to the right places in the right order.

---

## Step 1: Read the Specification Documents (15 minutes)

Read these files in order:

1. **`specs/001-data-models-docs-foundation/spec.md`** - Start here
   - Read the 7 user stories to understand what you're building
   - Note the priorities: P1 (critical), P2 (important), P3 (nice-to-have)
   - Review the "Clarifications" section at the top for key decisions

2. **`specs/001-data-models-docs-foundation/plan.md`**
   - See the "Project Structure" section for the complete directory layout
   - Review "Technical Context" for dependencies and constraints

3. **`specs/001-data-models-docs-foundation/data-model.md`**
   - Contains complete Pydantic schemas for all 4 YAML files
   - This is your reference when coding the Python models

4. **`specs/001-data-models-docs-foundation/tasks.md`**
   - 150 tasks organized by phase
   - This is your implementation checklist

---

## Step 2: Set Up Your Environment (10 minutes)

```bash
# Make sure you're in the project root
cd /Users/kellycaylor/dev/rcd-cui

# Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install pyyaml>=6.0 pydantic>=2.0 jinja2>=3.1 pytest>=7.0

# Or create requirements.txt first:
cat > requirements.txt << EOF
pyyaml>=6.0
pydantic>=2.0
jinja2>=3.1
pytest>=7.0
EOF

pip install -r requirements.txt
```

---

## Step 3: Choose Your Implementation Strategy

### Option A: MVP First (Recommended)
Build the minimum viable product - just the core data models:

1. **Phase 1: Setup** (tasks T001-T012)
   - Create directory structure
   - Set up basic files

2. **Phase 2: Foundational** (tasks T013-T022)
   - **CRITICAL**: Must complete before any user stories
   - Create Pydantic models
   - Set up pytest fixtures

3. **User Stories 1, 2, 3** (all P1 - highest priority)
   - US1: Control mapping (110 controls across 4 frameworks)
   - US2: Glossary (60+ terms with plain language)
   - US3: HPC tailoring (10+ deviations with compensating controls)

4. **Test independently** - verify each user story works

### Option B: Complete Implementation
Build everything including documentation generator and validators:

1. Phases 1-2 (same as MVP)
2. User Stories 1-4 (add ODPs)
3. User Story 5 (documentation generator)
4. User Story 7 (project skeleton with Makefile)
5. User Story 6 (glossary validator)
6. Polish phase

---

## Step 4: Follow the Task Checklist

Open `specs/001-data-models-docs-foundation/tasks.md` and work through it systematically.

### Phase 1: Setup (Tasks T001-T012)

**What you're doing**: Creating the directory structure and basic project files.

**Key files to reference**:
- `plan.md` - "Project Structure" section shows the complete directory tree
- `tasks.md` - Phase 1 section lists all setup tasks

**Example - Task T001**:
```bash
# Create directory structure
mkdir -p inventory/group_vars
mkdir -p roles/common/vars
mkdir -p docs/glossary
mkdir -p docs/generated
mkdir -p scripts/models
mkdir -p templates/_partials
mkdir -p tests
```

**Example - Task T006 (.gitignore)**:
```bash
cat > .gitignore << EOF
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
venv/

# Generated documentation (ephemeral)
docs/generated/

# Pytest
.pytest_cache/
.coverage
htmlcov/
EOF
```

### Phase 2: Foundational (Tasks T013-T022)

**What you're doing**: Creating the Pydantic models and shared utilities.

**Key files to reference**:
- `data-model.md` - Contains the complete Pydantic code to copy/adapt
- `research.md` - Explains why we chose Pydantic v2, PyYAML, etc.

**Example - Task T014 (FrameworkMapping model)**:

Create `scripts/models/control_mapping.py`:

```python
from pydantic import BaseModel, Field, field_validator
from typing import List, Literal

class FrameworkMapping(BaseModel):
    """Cross-framework control mapping."""
    rev2_id: str = Field(description="NIST 800-171 Rev 2 control ID (e.g., '3.1.1')")
    rev3_id: str | None = Field(
        description="NIST 800-171 Rev 3 control ID or 'N/A'",
        default=None
    )
    rev3_rationale: str | None = Field(
        description="Required if rev3_id is 'N/A'",
        default=None
    )
    # ... (copy rest from data-model.md)

    @field_validator('rev3_id', 'cmmc_l2_id')
    @classmethod
    def validate_na_has_rationale(cls, v, info):
        """Ensure 'N/A' mappings have rationale."""
        if v == "N/A":
            rationale_field = f"{info.field_name}_rationale"
            if not info.data.get(rationale_field):
                raise ValueError(
                    f"'{info.field_name}' is 'N/A' but '{rationale_field}' is missing"
                )
        return v
```

**Where to find the code**: Open `data-model.md` and search for "File 1: Control Mapping" - the complete Pydantic model is there. Just copy it into your Python file.

**Example - Task T018 (YAML loader utility)**:

Add to `scripts/models/__init__.py`:

```python
import yaml
from functools import lru_cache
from pathlib import Path

@lru_cache(maxsize=10)
def load_yaml_cached(file_path: str):
    """Load YAML file with caching for performance."""
    with open(file_path, 'r') as f:
        return yaml.safe_load(f)
```

### Phase 3: User Story 1 - Control Mapping (Tasks T023-T046)

**What you're doing**: Creating the canonical control mapping YAML file with all 110 NIST 800-171 Rev 2 controls.

**Key files to reference**:
- `data-model.md` - "File 1: Control Mapping" section has YAML examples
- `spec.md` - User Story 1 section for acceptance criteria

**Example - Task T027 (Create control_mapping.yml structure)**:

Create `roles/common/vars/control_mapping.yml`:

```yaml
version: "1.0.0"
last_updated: "2026-02-14"
description: "Canonical mapping of NIST 800-171 Rev 2/3, CMMC L2, and 800-53 R5 controls"

controls:
  - control_id: "3.1.1"
    title: "Access Control Policy and Procedures"
    family: "AC"
    plain_language: |
      Establish and maintain formal policies and procedures for controlling who can
      access your systems and data. This includes documenting access control rules,
      reviewing them regularly, and training staff on proper access management.
    assessment_objectives:
      - "Access control policy addresses purpose, scope, roles, responsibilities"
      - "Access control procedures facilitate implementation of policy"
      - "Policy and procedures reviewed and updated at least annually"
    sprs_weight: 3
    automatable: false
    zones:
      - management
      - internal
      - restricted
    framework_mapping:
      rev2_id: "3.1.1"
      rev3_id: "03.01.01"
      rev3_rationale: null
      cmmc_l2_id: "AC.L2-3.1.1"
      cmmc_l2_rationale: null
      nist_800_53_r5_id:
        - "AC-1"
    ansible_roles: []
    hpc_tailoring_ref: null
```

**Tasks T028-T042**: Continue adding all 110 controls. The data-model.md shows the format. You'll need to research the actual NIST 800-171 controls from:
- https://csrc.nist.gov/publications/detail/sp/800-171/rev-2/final

**Testing - Tasks T043-T046**:

Create `tests/test_yaml_schemas.py`:

```python
import pytest
import yaml
from scripts.models.control_mapping import ControlMappingData

def test_control_mapping_schema():
    """Validate control_mapping.yml against Pydantic model."""
    with open('roles/common/vars/control_mapping.yml') as f:
        data = yaml.safe_load(f)

    # This will raise ValidationError if schema is invalid
    control_data = ControlMappingData(**data)

    # Verify minimum 110 controls
    assert len(control_data.controls) >= 110

def test_na_mappings_have_rationale():
    """Verify 'N/A' framework mappings have rationale."""
    with open('roles/common/vars/control_mapping.yml') as f:
        data = yaml.safe_load(f)

    for control in data['controls']:
        mapping = control['framework_mapping']

        # If rev3_id is "N/A", rev3_rationale must exist
        if mapping.get('rev3_id') == 'N/A':
            assert mapping.get('rev3_rationale'), \
                f"Control {control['control_id']} has rev3_id='N/A' but no rationale"
```

Run tests:
```bash
pytest tests/test_yaml_schemas.py -v
```

---

## Step 5: Where to Find Information

### "How do I structure the YAML files?"
→ Open `data-model.md`, search for the file name (e.g., "File 2: Glossary")
→ Copy the YAML example structure

### "What fields are required in each model?"
→ Open `data-model.md`, look at the Pydantic model definition
→ Fields without `| None` and `default=None` are required

### "What are the validation rules?"
→ Open `data-model.md`, scroll to "Validation Rules" section for each file
→ Example: "Minimum 60 terms", "SPRS weight: integer 1-5 inclusive"

### "What should I build first?"
→ Open `tasks.md`, follow the phases in order
→ MVP scope is clearly marked: User Stories 1, 2, 3

### "How do I handle edge cases?"
→ Open `spec.md`, read the "Clarifications" section at the top
→ Example: Q: "How to handle missing YAML data?" A: "Fail immediately with clear error"

### "What are the performance requirements?"
→ Open `plan.md`, search for "Performance Goals"
→ Example: "Documentation generator completes all 7 outputs in <30 seconds"

### "What tests should I write?"
→ Open `tasks.md`, look for tasks with "pytest" in the description
→ Each user story phase has 3-4 test tasks at the end

---

## Step 6: Useful Commands While Implementing

### Run tests
```bash
# All tests
pytest tests/ -v

# Just schema validation
pytest tests/test_yaml_schemas.py -v

# With coverage
pytest tests/ --cov=scripts --cov-report=html
```

### Validate YAML manually
```python
# Quick test in Python REPL
import yaml
from scripts.models.control_mapping import ControlMappingData

with open('roles/common/vars/control_mapping.yml') as f:
    data = yaml.safe_load(f)

# This will show validation errors if any
validated = ControlMappingData(**data)
print(f"Loaded {len(validated.controls)} controls")
```

### Generate docs (once you implement User Story 5)
```bash
python scripts/generate_docs.py --output-dir docs/generated
```

### Validate glossary (once you implement User Story 6)
```bash
python scripts/validate_glossary.py
```

---

## Step 7: Working Through Each User Story

For each user story:

1. **Read the acceptance criteria** in `spec.md`
   - Example: User Story 1 → "All 110 controls present with complete metadata"

2. **Find the Pydantic models** in `data-model.md`
   - Copy the model code into `scripts/models/<filename>.py`

3. **Create the YAML file** following the example in `data-model.md`
   - Start with the metadata header (version, last_updated, description)
   - Add a few entries to test
   - Validate with pytest

4. **Write tests** as specified in `tasks.md`
   - Schema validation test
   - Count/completeness test
   - Business rule tests (e.g., "N/A has rationale")

5. **Run tests and fix errors**
   ```bash
   pytest tests/test_yaml_schemas.py::test_control_mapping_schema -v
   ```

6. **Complete the data population**
   - Add all 110 controls (for US1)
   - Add all 60+ terms (for US2)
   - Add all 10+ tailoring decisions (for US3)

7. **Run final validation**
   ```bash
   pytest tests/ -v
   ```

---

## Step 8: Quick Reference

### File Locations

**Pydantic Models** (copy from data-model.md):
- `scripts/models/control_mapping.py` - SecurityControl, FrameworkMapping, ControlMappingData
- `scripts/models/glossary.py` - GlossaryTerm, AudienceContext, GlossaryData
- `scripts/models/hpc_tailoring.py` - HPCTailoringEntry, HPCTailoringData
- `scripts/models/odp_values.py` - ODPValue, ODPValuesData

**YAML Data Files** (canonical data):
- `roles/common/vars/control_mapping.yml` - 110 controls
- `docs/glossary/terms.yml` - 60+ terms
- `docs/hpc_tailoring.yml` - 10+ tailoring decisions
- `docs/odp_values.yml` - 49 ODPs

**Python Scripts** (build in User Story 5 & 6):
- `scripts/generate_docs.py` - Documentation generator
- `scripts/validate_glossary.py` - Glossary validator

**Tests**:
- `tests/test_yaml_schemas.py` - Validate all YAML files
- `tests/test_generate_docs.py` - Integration tests for doc generator
- `tests/test_glossary_validator.py` - Unit tests for glossary validator

### Makefile Targets (build in User Story 7)

```makefile
.PHONY: docs validate crosswalk clean test

docs:
	python scripts/generate_docs.py --output-dir docs/generated

validate:
	python scripts/validate_glossary.py

crosswalk:
	python scripts/generate_docs.py --output-dir docs/generated
	@echo "Crosswalk CSV: docs/generated/crosswalk.csv"

clean:
	rm -rf docs/generated/*

test:
	pytest tests/ -v --cov=scripts --cov-report=html

validate-schemas:
	pytest tests/test_yaml_schemas.py -v
```

---

## Step 9: Common Questions

**Q: Do I need to populate all 110 controls immediately?**
A: No. Start with 5-10 controls to test your Pydantic models and validation logic. Then populate the rest once you know the structure works.

**Q: Where do I find the actual NIST control text?**
A: Official sources:
- NIST 800-171 Rev 2: https://csrc.nist.gov/publications/detail/sp/800-171/rev-2/final
- NIST 800-171 Rev 3: https://csrc.nist.gov/publications/detail/sp/800-171/rev-3/final
- CMMC: https://www.acq.osd.mil/cmmc/

**Q: What if I don't know the CMMC mapping for a control?**
A: Use "N/A" with a rationale like: `cmmc_l2_rationale: "No direct CMMC Level 2 equivalent - requirement covered by practice XYZ"` (per Clarification #2 in spec.md)

**Q: How detailed should the plain_language descriptions be?**
A: 2-4 sentences that a non-technical person can understand. See examples in data-model.md. The constitution principle "Plain Language First" is critical.

**Q: Can I skip the glossary validator (User Story 6)?**
A: Yes, it's P3 (lowest priority). Build US1, US2, US3 first for MVP. The validator is a nice-to-have quality gate.

**Q: How do I know if I'm done with a user story?**
A: Check the "Independent Test" in spec.md for each user story. If you can successfully perform that test, the story is complete.

---

## Step 10: Getting Unstuck

If you get stuck:

1. **Read the spec** - `spec.md` has all the requirements
2. **Check the examples** - `data-model.md` has working code
3. **Review clarifications** - The top of `spec.md` has answers to common questions
4. **Run tests** - They'll tell you what's missing
5. **Check the constitution** - `.specify/memory/constitution.md` explains the "why"

---

## Next Steps

1. Start with Phase 1 (Setup) - create the directory structure
2. Complete Phase 2 (Foundational) - build the Pydantic models
3. Implement User Stories 1, 2, 3 for MVP
4. Test thoroughly with pytest
5. Add User Stories 4, 5, 7 for full implementation

Good luck! The specification documents contain everything you need - this guide just helps you navigate them.
