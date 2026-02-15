# Implementation Plan: Data Models and Documentation Generation Foundation

**Branch**: `001-data-models-docs-foundation` | **Date**: 2026-02-14 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-data-models-docs-foundation/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Build the foundational data models and documentation generation system for a CUI compliance Ansible framework. This feature establishes the single source of truth for all compliance data through YAML data models (control mappings, glossary, HPC tailoring, ODP values) and provides Python-based tooling for generating audience-specific documentation and validating glossary coverage. No Ansible roles are implemented—only the structured data and generation/validation scripts that all subsequent compliance implementation specs depend on.

## Technical Context

**Language/Version**: Python 3.9+ (per constitution tech stack)
**Primary Dependencies**: PyYAML (YAML parsing), Jinja2 (templating for doc generation), pytest (testing), NEEDS CLARIFICATION (YAML schema validation library)
**Storage**: File-based YAML (control_mapping.yml, terms.yml, hpc_tailoring.yml, odp_values.yml) + generated Markdown/CSV outputs
**Testing**: pytest for unit tests, YAML validation tests, doc generation integration tests
**Target Platform**: RHEL 9 / Rocky Linux 9 (per constitution), command-line tooling
**Project Type**: Data models + CLI scripts (Ansible project skeleton with Python tooling)
**Performance Goals**: Documentation generator completes all 7 outputs in <30 seconds (SC-004), NEEDS CLARIFICATION (YAML load time for 110+ controls)
**Constraints**: Deterministic output (same YAML → same docs), CI-friendly exit codes, Excel-compatible CSV, GitHub-flavored Markdown, NEEDS CLARIFICATION (YAML schema enforcement approach)
**Scale/Scope**: 110 NIST 800-171 Rev 2 controls + 97 Rev 3 requirements, 60+ glossary terms, 49 ODPs, 10+ HPC tailoring entries, 7 doc output types

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle I: Plain Language First
✅ **PASS** - Feature directly implements glossary with plain-language explanations for all 5 audiences (PI, researcher, sysadmin, CISO, leadership). Glossary validator enforces no undefined jargon.

### Principle II: Data Model as Source of Truth
✅ **PASS** - YAML files (control_mapping.yml, terms.yml, hpc_tailoring.yml, odp_values.yml) are single source; all documentation is generated, never duplicated.

### Principle III: Compliance as Code
✅ **PASS** - Control mapping includes Ansible role assignment placeholders and control tagging structure for future implementation. This feature establishes the data foundation for compliance-as-code.

### Principle IV: HPC-Aware
✅ **PASS** - hpc_tailoring.yml explicitly documents 10+ HPC/security conflicts with compensating controls, risk acceptance, and NIST 800-223 references.

### Principle V: Multi-Framework
✅ **PASS** - Control mapping covers all 4 frameworks simultaneously (NIST 800-171 Rev 2/3, CMMC L2, 800-53 R5) with explicit "N/A" + rationale for missing mappings.

### Principle VI: Audience-Aware Documentation
✅ **PASS** - Documentation generator produces 7 distinct audience-specific outputs from single YAML source (PI guide, researcher quickstart, sysadmin reference, CISO map, leadership briefing, glossary, crosswalk).

### Principle VII: Idempotent and Auditable
✅ **PASS** - Control mapping includes placeholders for verify.yml/evidence.yml task files. Doc generator is deterministic (same input → same output).

### Principle VIII: Prefer Established Tools
✅ **PASS** - Uses PyYAML (standard YAML library), Jinja2 (established templating), pytest (standard Python testing). No custom parsers/generators where established tools exist.

**Gate Status**: ✅ ALL PRINCIPLES SATISFIED - Proceed to Phase 0 Research

## Project Structure

### Documentation (this feature)

```text
specs/001-data-models-docs-foundation/
├── plan.md              # This file (implementation plan)
├── research.md          # Phase 0 output (technology decisions)
├── data-model.md        # Phase 1 output (YAML schemas)
├── quickstart.md        # Phase 1 output (usage guide)
├── contracts/           # Phase 1 output (script interfaces, no APIs)
│   └── README.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

This is an Ansible project with Python tooling. Structure follows Ansible best practices with compliance data models:

```text
rcd-cui/
├── ansible.cfg                    # Ansible configuration
├── inventory/                     # Ansible inventory
│   ├── hosts.yml
│   └── group_vars/
│       ├── all.yml
│       ├── management.yml
│       ├── internal.yml
│       └── restricted.yml
├── roles/                         # Ansible roles (empty initially, populated in future specs)
│   └── common/
│       └── vars/
│           └── control_mapping.yml  # CANONICAL DATA MODEL (110+ controls)
├── docs/                          # Documentation source and generated output
│   ├── glossary/
│   │   └── terms.yml              # CANONICAL GLOSSARY (60+ terms)
│   ├── hpc_tailoring.yml          # HPC-specific control tailoring (10+ entries)
│   ├── odp_values.yml             # Organization-Defined Parameters (49 ODPs)
│   └── generated/                 # Generated documentation (ephemeral)
│       ├── pi_guide.md
│       ├── researcher_quickstart.md
│       ├── sysadmin_reference.md
│       ├── ciso_compliance_map.md
│       ├── leadership_briefing.md
│       ├── glossary_full.md
│       └── crosswalk.csv
├── scripts/                       # Python automation scripts
│   ├── generate_docs.py           # Documentation generator
│   ├── validate_glossary.py       # Glossary coverage validator
│   └── models/                    # Pydantic data models
│       ├── __init__.py
│       ├── control_mapping.py
│       ├── glossary.py
│       ├── hpc_tailoring.py
│       └── odp_values.py
├── templates/                     # Jinja2 templates for doc generation
│   ├── pi_guide.md.j2
│   ├── researcher_quickstart.md.j2
│   ├── sysadmin_reference.md.j2
│   ├── ciso_compliance_map.md.j2
│   ├── leadership_briefing.md.j2
│   ├── glossary_full.md.j2
│   ├── crosswalk.csv.j2
│   └── _partials/
│       ├── glossary_link.j2
│       ├── control_table.j2
│       └── header.j2
├── tests/                         # Pytest tests
│   ├── test_yaml_schemas.py       # Validate all YAML data models
│   ├── test_generate_docs.py     # Doc generator integration tests
│   └── test_glossary_validator.py # Glossary validator unit tests
├── Makefile                       # Build targets (docs, validate, crosswalk, clean)
├── requirements.txt               # Python dependencies (PyYAML, Pydantic, Jinja2, pytest)
├── README.md                      # Project overview and usage
└── .specify/                      # Specify framework artifacts
    └── memory/
        └── constitution.md        # Project constitution
```

**Structure Decision**: Ansible project structure with Python tooling. This feature establishes the data foundation (4 YAML files) and documentation generation pipeline (Python scripts + Jinja2 templates). No Ansible roles are implemented yet—those come in future specs. The structure separates:

1. **Canonical Data** (`roles/common/vars/`, `docs/glossary/`, `docs/*.yml`) - Single source of truth, version-controlled
2. **Generated Artifacts** (`docs/generated/`) - Ephemeral, regenerated from YAML sources
3. **Tooling** (`scripts/`, `templates/`) - Python generators and validators
4. **Tests** (`tests/`) - Schema validation and integration tests

This aligns with Constitution Principle II (Data Model as Source of Truth) and Principle VI (Audience-Aware Documentation).

## Complexity Tracking

No constitution violations. All principles satisfied:
- ✅ Established tools (Pydantic, PyYAML, Jinja2, pytest)
- ✅ Data model as source of truth (YAML canonical, docs generated)
- ✅ Plain language first (glossary with 5-audience context)
- ✅ HPC-aware (explicit tailoring document)
- ✅ Multi-framework (4 frameworks in single data model)

No complexity justification required.
