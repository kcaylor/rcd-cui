# Implementation Plan: Compliance Assessment and Reporting Layer

**Branch**: `003-compliance-assessment` | **Date**: 2026-02-14 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-compliance-assessment/spec.md`

## Summary

Build the compliance assessment, evidence collection, and reporting layer for the CUI-compliant research computing enclave. This layer orchestrates verification across all 31 Ansible roles (from Spec 002), calculates SPRS scores per DoD methodology, generates SSP evidence packages with plain-language narratives, tracks POA&M items, produces audience-specific HTML dashboards, and bundles complete auditor packages for C3PAO assessments.

Technical approach: Ansible playbooks for assessment orchestration, Python scripts and filter plugins for scoring/reporting, Jinja2 templates for dashboard and narrative generation, YAML data models for POA&M tracking. All outputs are generated artifacts from structured data sources per constitution principle II.

## Technical Context

**Language/Version**: Python 3.9+ (filter plugins, reporting scripts), Ansible 2.15+ (playbooks)
**Primary Dependencies**: Ansible, Jinja2, PyYAML, JSON (standard library), OpenSCAP CLI
**Storage**: JSON files (assessment results, historical data), YAML (POA&M data model)
**Testing**: pytest (Python scripts/plugins), ansible-lint, yamllint, --check mode validation
**Target Platform**: RHEL 9 / Rocky Linux 9 execution environment (Docker/Podman container)
**Project Type**: Ansible collection extension + Python tooling
**Performance Goals**: Evidence collection < 30 minutes for 50 systems, dashboard generation < 60 seconds
**Constraints**: Non-destructive assessment only, offline dashboard (no CDN), < 100MB evidence archives
**Scale/Scope**: 110 NIST 800-171 controls, 31 roles, 4 security zones, 3 audience views

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Plain Language First | **PASS** | FR-015 requires narratives pass validate_glossary.py; FR-019 requires PM-understandable reports |
| II. Data Model as Source of Truth | **PASS** | Assessment results in JSON; POA&M in YAML; all reports generated from structured data |
| III. Compliance as Code | **PASS** | assess.yml orchestrates verify.yml tasks; results machine-readable; supports --check mode |
| IV. HPC-Aware | **PASS** | Auditor package includes HPC tailoring documentation; zone-aware assessment |
| V. Multi-Framework | **PASS** | Leverages control_mapping.yml with Rev 2/3, CMMC, 800-53 crosswalks from Spec 001 |
| VI. Audience-Aware Documentation | **PASS** | FR-023 requires leadership/CISO/auditor views from single data source |
| VII. Idempotent and Auditable | **PASS** | Assessment is read-only; evidence collection timestamped; runs support --check mode |
| VIII. Prefer Established Tools | **PASS** | Uses OpenSCAP, Ansible, Jinja2; SPRS calculation per DoD methodology |

**Gate Result**: PASS - No violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/003-compliance-assessment/
├── plan.md              # This file
├── research.md          # Phase 0 output - technology decisions
├── data-model.md        # Phase 1 output - entity schemas
├── quickstart.md        # Phase 1 output - deployment guide
├── contracts/           # Phase 1 output - API/data contracts
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
playbooks/
├── assess.yml           # NEW - Main assessment orchestration
├── ssp_evidence.yml     # NEW - SSP evidence collection
├── verify.yml           # EXISTS - Role verification (enhanced)
├── evidence.yml         # EXISTS - Role evidence collection (enhanced)
└── zone_specific/       # EXISTS - Zone-specific playbooks

plugins/
├── filter/
│   └── sprs.py          # NEW - SPRS score calculator filter plugin
└── __init__.py

scripts/
├── generate_poam_report.py    # NEW - POA&M report generator
├── generate_dashboard.py      # NEW - Compliance dashboard generator
├── generate_auditor_package.py # NEW - Auditor package bundler
├── generate_narratives.py     # NEW - Control narrative generator
├── redact_secrets.py          # NEW - Evidence redaction utility
└── validate_glossary.py       # EXISTS - Plain language validation

data/
├── poam.yml             # NEW - POA&M tracking data
├── sprs_weights.yml     # NEW - DoD SPRS control weights
└── assessment_history/  # NEW - Historical assessment results
    └── YYYY-MM-DD.json

templates/
├── dashboard/           # NEW - Dashboard HTML templates
│   ├── leadership.html.j2
│   ├── ciso.html.j2
│   ├── auditor.html.j2
│   └── assets/          # CSS, JS (offline-capable)
├── narratives/          # NEW - Control narrative templates
│   └── control_narrative.md.j2
└── reports/             # NEW - Report templates
    ├── poam_report.md.j2
    ├── poam_report.csv.j2
    └── sprs_breakdown.md.j2

docs/
├── generated/           # EXISTS - Generated documentation
└── auditor_packages/    # NEW - Generated auditor packages
    └── YYYY-MM-DD/

tests/
├── test_sprs_filter.py  # NEW - SPRS calculator tests
├── test_poam_model.py   # NEW - POA&M data model tests
├── test_redaction.py    # NEW - Secret redaction tests
└── test_narratives.py   # NEW - Narrative generation tests
```

**Structure Decision**: Extends existing Ansible collection structure. New playbooks in `playbooks/`, new filter plugin in `plugins/filter/`, new scripts in `scripts/`, new templates in `templates/`, new data files in `data/`. Follows constitution principle II (data model as source of truth) and principle VIII (prefer established Ansible patterns).

## Complexity Tracking

> No violations requiring justification. All additions follow established patterns from Specs 001/002.
