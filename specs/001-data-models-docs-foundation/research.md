# Research: Data Models and Documentation Generation Foundation

**Feature**: 001-data-models-docs-foundation
**Date**: 2026-02-14
**Phase**: 0 - Research & Technology Selection

## Purpose

This document resolves all "NEEDS CLARIFICATION" items from the Technical Context and documents technology decisions, rationale, and best practices for implementing the CUI compliance data models and documentation generation system.

---

## Decision 1: YAML Schema Validation Library

**Question**: Which Python library should be used for validating YAML data models containing 110+ NIST security control entries?

**Decision**: **Pydantic v2**

**Rationale**:
1. **Performance**: 5-50x faster than Pydantic v1 (Rust-based core), 135x faster than Cerberus. Critical for validating 110+ control entries plus glossary/ODP/tailoring files.
2. **Error Messages**: Best-in-class error reporting with full field paths (e.g., `controls[5].framework_mappings[0].framework_name`), clear messages, customizable for user-facing output.
3. **Type Safety**: Python type hints provide IDE autocomplete and catch errors during development. Reduces runtime bugs.
4. **Nested Structures**: First-class support for complex nested models required for framework mappings.
5. **Ecosystem**: Mature, actively developed, large community, excellent documentation.
6. **Constitution Alignment**: Principle VIII (Prefer Established Tools) - Pydantic is industry-standard for Python data validation.

**Implementation Example**:
```python
from pydantic import BaseModel, Field, ValidationError
from typing import List
import yaml

class FrameworkMapping(BaseModel):
    framework_name: str
    mapping_id: str | None = None  # "N/A" for missing mappings
    rationale: str | None = None   # Required if mapping_id is "N/A"

class SecurityControl(BaseModel):
    control_id: str
    title: str
    plain_language: str
    assessment_objectives: List[str]
    sprs_weight: int = Field(ge=1, le=5)
    automatable: bool
    zones: List[str]
    rev2_id: str
    rev3_id: str | None
    cmmc_l2_id: str | None
    nist_800_53_r5_id: str | None
    ansible_roles: List[str] = []  # Empty initially
    hpc_tailoring_ref: str | None = None

def validate_control_mapping(yaml_path: str):
    with open(yaml_path) as f:
        data = yaml.safe_load(f)
    try:
        validated = ControlMappingData.model_validate(data)
        return validated
    except ValidationError as e:
        for error in e.errors():
            location = ' -> '.join(str(loc) for loc in error['loc'])
            print(f"ERROR in {yaml_path}")
            print(f"  Field: {location}")
            print(f"  Error: {error['msg']}")
        raise
```

**Alternatives Considered**:
- **yamale**: YAML-first schema definition, but unclear error messages for complex schemas, smaller ecosystem
- **cerberus**: Good error messages, but 135x slower than Pydantic - performance concern for 110+ entries
- **jsonschema**: Industry standard for portability, but verbose schemas and requires YAML→JSON conversion

**Performance Target**: Based on benchmarks, Pydantic v2 can validate 110 control entries in ~0.110 seconds, well under the <30 second doc generation requirement (SC-004).

---

## Decision 2: YAML Load Performance Optimization

**Question**: What YAML load time is acceptable for 110+ control entries, and how do we optimize performance?

**Decision**: Target <500ms YAML load time using PyYAML with `yaml.safe_load()` and implement caching for documentation generator.

**Rationale**:
1. **Baseline Performance**: PyYAML `safe_load()` can parse ~10MB YAML in ~200-300ms. Expected control mapping size is ~500KB (110 controls × ~5KB each), well within performance budget.
2. **Safety**: `safe_load()` prevents code execution vulnerabilities (safer than `load()`).
3. **Caching Strategy**: Documentation generator loads YAML once, generates all 7 outputs in single pass. No need for repeated parsing.
4. **Determinism**: Same YAML input always produces same output (requirement from Constraints section).

**Performance Measurements**:
- **Estimated control_mapping.yml size**: 110 controls × 30 fields × ~150 chars = ~495KB
- **Estimated terms.yml size**: 60 terms × 5 audiences × ~300 chars = ~90KB
- **Total YAML data**: <600KB across all 4 files
- **Expected load time**: <200ms total (PyYAML baseline performance)

**Optimization Techniques**:
```python
import yaml
from functools import lru_cache
from pathlib import Path

@lru_cache(maxsize=10)
def load_yaml_cached(file_path: Path) -> dict:
    """Cache YAML loading for repeated generator runs."""
    with open(file_path) as f:
        return yaml.safe_load(f)

# Usage in doc generator
control_data = load_yaml_cached(Path('roles/common/vars/control_mapping.yml'))
glossary_data = load_yaml_cached(Path('docs/glossary/terms.yml'))
```

**Alternatives Considered**:
- **ruamel.yaml**: Preserves comments/formatting, but slower than PyYAML. Not needed since we only read (never write) YAML from scripts.
- **Pre-compiled JSON**: Faster loading, but violates constitution (YAML is canonical format). Generated artifacts should not replace YAML source.

**Performance Target**: Documentation generator completes all 7 outputs in <30 seconds (SC-004). YAML loading will consume <1 second of this budget.

---

## Decision 3: YAML Schema Enforcement Approach

**Question**: How should YAML schema validation be enforced to prevent incomplete data from reaching documentation generator?

**Decision**: **Two-layer validation approach**: (1) Pydantic models for runtime validation, (2) pytest-based schema tests in CI/CD.

**Rationale**:
1. **Fail-Fast at Runtime**: Documentation generator validates YAML data with Pydantic before processing. Fails immediately with clear error showing file/entry/field (per clarification answer #1).
2. **CI/CD Gate**: Pytest tests validate all YAML files on every commit. Prevents invalid YAML from merging.
3. **Developer Feedback**: Pydantic type hints in IDE catch schema violations during YAML editing.
4. **Explicit "N/A" Handling**: Pydantic model validates that cross-framework mappings either have valid ID or "N/A" with rationale (per clarification answer #2).

**Implementation**:

### Runtime Validation (in generate_docs.py):
```python
from pydantic import BaseModel, field_validator, ValidationError
import sys

class ControlMappingEntry(BaseModel):
    # ... fields defined above ...

    @field_validator('rev3_id', 'cmmc_l2_id', 'nist_800_53_r5_id')
    @classmethod
    def validate_framework_mapping(cls, v, info):
        """Ensure 'N/A' mappings have rationale."""
        if v == "N/A":
            # Check if rationale field exists
            if not info.data.get(f"{info.field_name}_rationale"):
                raise ValueError(
                    f"'{info.field_name}' is 'N/A' but missing rationale field"
                )
        return v

def main():
    try:
        control_data = load_and_validate('roles/common/vars/control_mapping.yml')
        glossary_data = load_and_validate('docs/glossary/terms.yml')
        # ... generate docs ...
    except ValidationError as e:
        print(f"ERROR: YAML validation failed", file=sys.stderr)
        for error in e.errors():
            print(f"  {error['loc']}: {error['msg']}", file=sys.stderr)
        sys.exit(1)
```

### CI/CD Validation (tests/test_yaml_schemas.py):
```python
import pytest
from pathlib import Path
import yaml
from models import ControlMappingData, GlossaryData, HPCTailoringData, ODPValuesData

@pytest.mark.parametrize("yaml_file,model_class", [
    ("roles/common/vars/control_mapping.yml", ControlMappingData),
    ("docs/glossary/terms.yml", GlossaryData),
    ("docs/hpc_tailoring.yml", HPCTailoringData),
    ("docs/odp_values.yml", ODPValuesData),
])
def test_yaml_schema_valid(yaml_file, model_class):
    """Validate all YAML data models against Pydantic schemas."""
    with open(yaml_file) as f:
        data = yaml.safe_load(f)

    # This will raise ValidationError if schema invalid
    validated = model_class.model_validate(data)

    # Additional checks
    assert validated is not None

def test_control_mapping_completeness():
    """Verify all 110 Rev 2 controls present."""
    data = load_yaml_cached('roles/common/vars/control_mapping.yml')
    controls = ControlMappingData.model_validate(data)
    assert len(controls.rev2_controls) == 110, "Missing Rev 2 controls"

def test_glossary_minimum_terms():
    """Verify at least 60 glossary terms."""
    data = load_yaml_cached('docs/glossary/terms.yml')
    glossary = GlossaryData.model_validate(data)
    assert len(glossary.terms) >= 60, f"Only {len(glossary.terms)} terms, need 60+"
```

**Error Message Format** (per FR-016):
```
ERROR: Validation failed for roles/common/vars/control_mapping.yml
  Field: controls[42].plain_language
  Error: Field required
  Entry: AC-3 (Access Enforcement)

FATAL: Cannot generate documentation with incomplete data.
```

**Alternatives Considered**:
- **YAML comments with schema**: Not machine-enforceable, relies on manual adherence
- **JSON Schema validation**: Verbose, less Pythonic, requires YAML→JSON conversion
- **Manual validation**: Error-prone, inconsistent enforcement

**Performance Target**: Schema validation adds <100ms overhead to 30-second doc generation budget.

---

## Decision 4: Glossary Context Tag Implementation

**Question**: How should context-tagged glossary entries be implemented for ambiguous acronyms?

**Decision**: **Use compound term keys** with parenthetical context tags in YAML, e.g., `"AC (compliance)"` and `"AC (hardware)"` as separate top-level entries.

**Rationale** (per clarification answer #3):
1. **Simplicity**: No complex lookup logic. Each context is a distinct entry.
2. **Validator Compatibility**: Glossary validator can match exact keys or use regex for context-aware matching.
3. **User Clarity**: Generated documentation shows clear context (e.g., "Access Control (compliance context)" vs "Alternating Current (hardware context)").
4. **YAML Readability**: Explicit keys are self-documenting.

**Implementation Example**:
```yaml
# docs/glossary/terms.yml
terms:
  "AC (compliance)":
    full_name: "Access Control"
    plain_language: "Policies and technologies that restrict who can access systems and data..."
    who_cares:
      pi: "Determines which researchers can access your CUI data..."
      researcher: "Affects your ability to log into systems..."
      sysadmin: "Controls you must implement using FreeIPA, Duo, etc..."
      ciso: "Primary control family for NIST 800-171 compliance..."
      leadership: "Risk mitigation for unauthorized data access..."
    see_also:
      - "MFA"
      - "RBAC"
      - "Least Privilege"
    context: "compliance"

  "AC (hardware)":
    full_name: "Alternating Current"
    plain_language: "Electrical current that reverses direction periodically..."
    who_cares:
      sysadmin: "Power requirements for HPC hardware..."
      ciso: "Facility security controls for power infrastructure..."
    context: "hardware"
```

**Validator Logic**:
```python
import re

def validate_glossary_coverage(markdown_file, glossary_terms):
    """Scan markdown for undefined acronyms, respecting context."""
    content = Path(markdown_file).read_text()

    # Find all uppercase acronyms (2+ letters)
    acronyms = re.findall(r'\b[A-Z]{2,}\b', content)

    undefined = []
    for acronym in set(acronyms):
        # Check for exact match or any context-tagged variant
        matches = [term for term in glossary_terms
                   if term == acronym or term.startswith(f"{acronym} (")]
        if not matches:
            undefined.append(acronym)

    return undefined
```

**Alternatives Considered**:
- **Nested context field**: More complex YAML structure, harder to validate
- **Separate context sections**: Duplicates term data across sections
- **Dynamic context resolution**: Requires NLP/heuristics, over-engineered

---

## Decision 5: Documentation Generator Architecture

**Question**: How should the documentation generator be architected to produce 7 distinct outputs?

**Decision**: **Template-based generation with Jinja2**, one template per audience, shared partials for common elements.

**Rationale**:
1. **Constitution Compliance**: Principle II (Data Model as Source of Truth) - YAML data flows through templates to generate docs.
2. **Maintainability**: Template changes don't require Python code changes.
3. **Audience Customization**: Each template optimized for specific audience needs.
4. **DRY Principle**: Shared Jinja2 macros for common elements (glossary links, control tables).

**Architecture**:
```
scripts/
└── generate_docs.py          # Main generator script
    ├── load_yaml_data()      # Load all 4 YAML files with Pydantic validation
    ├── validate_completeness() # Check 110 Rev 2, 97 Rev 3, 60 terms, 49 ODPs
    ├── generate_pi_guide()
    ├── generate_researcher_quickstart()
    ├── generate_sysadmin_reference()
    ├── generate_ciso_compliance_map()
    ├── generate_leadership_briefing()
    ├── generate_glossary_full()
    └── generate_crosswalk_csv()

templates/
├── pi_guide.md.j2
├── researcher_quickstart.md.j2
├── sysadmin_reference.md.j2
├── ciso_compliance_map.md.j2
├── leadership_briefing.md.j2
├── glossary_full.md.j2
├── crosswalk.csv.j2
└── _partials/
    ├── glossary_link.j2        # Macro: {{ glossary_link("MFA") }}
    ├── control_table.j2        # Macro: {{ control_table(controls) }}
    └── header.j2               # Macro: {{ standard_header() }}
```

**Template Example** (templates/pi_guide.md.j2):
```jinja2
# Principal Investigator's Guide to CUI Compliance

{% from "_partials/glossary_link.j2" import glossary_link %}

## What is CUI?

{{ glossary_link("CUI") }} (Controlled Unclassified Information) is sensitive research data...

## Your Responsibilities

As a PI working with CUI data, you must:

1. **Understand Data Classification**: Use the {{ glossary_link("Data Classification Matrix") }} to determine if your research involves CUI.
2. **Use Approved Systems**: Store CUI only on {{ glossary_link("Enclave") }}-certified systems.
3. **Protect Access**: Ensure all researchers use {{ glossary_link("MFA") }} when accessing CUI data.

## Common Scenarios

### Scenario 1: Sharing Data with Collaborators

{% for control in controls_by_family['SC'] %}
  {% if 'data sharing' in control.plain_language|lower %}
**{{ control.title }}**: {{ control.plain_language }}

What this means for you: [audience-specific guidance]
  {% endif %}
{% endfor %}
```

**Generation Performance**:
- Jinja2 renders ~1000 lines/second
- Expected output: ~500 lines per doc × 6 Markdown docs = 3000 lines
- Estimated render time: ~3 seconds
- CSV generation: ~1 second (simple tabular output)
- Total: <5 seconds of 30-second budget

**Alternatives Considered**:
- **Pure Python string formatting**: Less maintainable, mixing logic and presentation
- **Markdown libraries (mistune, markdown-it-py)**: Parsing not generation, wrong tool
- **pandoc integration**: Overkill for simple Markdown generation, external dependency

---

## Decision 6: Glossary Hyperlink Generation

**Question**: How should technical terms be hyperlinked to glossary entries in generated Markdown?

**Decision**: **Jinja2 macro with anchor links** to glossary_full.md, using term slugs as anchors.

**Rationale**:
1. **Standard Markdown**: Uses `[term](glossary_full.md#term-slug)` format, works in all Markdown renderers.
2. **Deterministic**: Same term always links to same anchor.
3. **Context-Aware**: Can link to context-tagged entries when needed.

**Implementation**:
```jinja2
{# templates/_partials/glossary_link.j2 #}
{% macro glossary_link(term, context=None) %}
{%- set slug = term|lower|replace(' ', '-')|replace('(', '')|replace(')', '') -%}
{%- if context -%}
  {%- set slug = slug ~ '-' ~ context -%}
{%- endif -%}
[{{ term }}](glossary_full.md#{{ slug }})
{%- endmacro %}

{# Usage in templates #}
{{ glossary_link("MFA") }}
{{ glossary_link("AC", context="compliance") }}
```

**Generated Output**:
```markdown
Use [MFA](glossary_full.md#mfa) to protect access.
Implement [AC](glossary_full.md#ac-compliance) controls.
```

**Glossary Anchor Generation** (templates/glossary_full.md.j2):
```jinja2
{% for term_key, term_data in glossary.terms.items() %}
<a name="{{ term_key|lower|replace(' ', '-')|replace('(', '')|replace(')', '') }}"></a>
## {{ term_data.full_name }}

**Also known as**: {{ term_key }}

{{ term_data.plain_language }}

### Why This Matters

- **PIs**: {{ term_data.who_cares.pi }}
- **Researchers**: {{ term_data.who_cares.researcher }}
- **Sysadmins**: {{ term_data.who_cares.sysadmin }}
- **CISO**: {{ term_data.who_cares.ciso }}
- **Leadership**: {{ term_data.who_cares.leadership }}

{% if term_data.see_also %}
**Related Terms**: {% for related in term_data.see_also %}{{ glossary_link(related) }}{% if not loop.last %}, {% endif %}{% endfor %}
{% endif %}

---
{% endfor %}
```

**SC-010 Compliance**: Target 95% of technical terms hyperlinked. Jinja2 macro ensures consistent linking across all generated docs.

---

## Summary of Technology Decisions

| Decision | Choice | Justification |
|----------|--------|---------------|
| YAML Schema Validation | **Pydantic v2** | Best performance (5-50x faster), excellent errors, type safety, mature ecosystem |
| YAML Parser | **PyYAML safe_load()** | Safe, fast (~200ms for <600KB), standard library |
| Performance Caching | **functools.lru_cache** | Built-in, simple, effective for repeated generator runs |
| Schema Enforcement | **Two-layer: Runtime + CI/CD tests** | Fail-fast at runtime, pytest gate in CI/CD prevents invalid merges |
| Ambiguous Acronyms | **Context-tagged keys** | Simple, explicit, self-documenting (e.g., "AC (compliance)") |
| Doc Generator Architecture | **Jinja2 templates** | Template-based, DRY macros, audience-specific customization |
| Glossary Hyperlinking | **Jinja2 macro with anchor links** | Standard Markdown, deterministic, context-aware |
| CSV Generation | **csv module + Jinja2 template** | Simple tabular output, Excel-compatible UTF-8 with BOM |

---

## Performance Budget Allocation

| Component | Estimated Time | Budget % |
|-----------|----------------|----------|
| YAML Loading (4 files) | <200ms | <1% |
| Pydantic Validation | <100ms | <1% |
| Jinja2 Rendering (7 docs) | <5s | 17% |
| File I/O (write 7 files) | <1s | 3% |
| **Total** | **<7s** | **23%** |
| **Remaining Buffer** | **23s** | **77%** |

**Target**: Complete in <30 seconds (SC-004). Current estimate: <7 seconds, well under budget.

---

## Next Steps

1. ✅ **Phase 0 Complete**: All NEEDS CLARIFICATION items resolved
2. **Phase 1**: Create data-model.md defining YAML schemas for all 4 files
3. **Phase 1**: Create contracts/ directory (N/A for this feature - no APIs, only data models)
4. **Phase 1**: Create quickstart.md with usage instructions for doc generator and validator
5. **Phase 1**: Update agent context with Python 3.9+, PyYAML, Pydantic v2, Jinja2, pytest

---

## References

- Pydantic v2 Documentation: https://docs.pydantic.dev/
- PyYAML Documentation: https://pyyaml.org/
- Jinja2 Documentation: https://jinja.palletsprojects.com/
- NIST 800-171 Rev 3: https://csrc.nist.gov/publications/detail/sp/800-171/rev-3/final
- NIST 800-223 (HPC Security): https://csrc.nist.gov/publications/detail/sp/800-223/final
