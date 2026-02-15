# Implementation Plan: CI/CD Pipeline and Living Dashboard

**Branch**: `005-ci-cd-dashboard` | **Date**: 2026-02-15 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/005-ci-cd-dashboard/spec.md`

## Summary

Implement automated CI/CD validation and a living compliance dashboard for the rcd-cui project. GitHub Actions workflows will run lint, syntax-check, and YAML validation on PRs, build the execution environment and deploy generated documentation and compliance dashboard to GitHub Pages on merge to main, and run scheduled nightly assessments. The dashboard provides public, unauthenticated access to SPRS scores, control status, POA&M summary, and downloadable compliance artifacts. README badges display CI status, SPRS score (via dynamic JSON endpoint), and last assessment date.

## Technical Context

**Language/Version**: YAML (GitHub Actions workflows), Bash (scripts), Python 3.9+ (existing tooling)
**Primary Dependencies**: GitHub Actions, GitHub Pages, shields.io (badges), existing Makefile targets
**Storage**: Git repository, `gh-pages` branch for published artifacts, JSON files for badge data
**Testing**: Workflow validation via act (local), integration testing via test PRs
**Target Platform**: GitHub.com (Actions runners: ubuntu-latest)
**Project Type**: Infrastructure/DevOps (GitHub workflows and configuration)
**Performance Goals**: PR checks complete within 5 minutes, dashboard deployment within 5 minutes of merge
**Constraints**: Must use existing execution environment, must work with current Makefile targets
**Scale/Scope**: Single repository, ~35 roles, 5 audience-specific documents, 1 dashboard

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Plain Language First | PASS | Dashboard and docs serve non-technical stakeholders (PIs, VCR, auditors) |
| II. Data Model as Source of Truth | PASS | Dashboard generated from existing YAML data models via `make docs` |
| III. Compliance as Code | PASS | CI enforces code quality gates; dashboard shows compliance posture |
| IV. HPC-Aware | N/A | CI/CD infrastructure, not HPC control implementation |
| V. Multi-Framework | PASS | Crosswalk CSV includes all 4 framework mappings |
| VI. Audience-Aware Documentation | PASS | Publishes all 5 audience-specific documents to GitHub Pages |
| VII. Idempotent and Auditable | PASS | Workflows are deterministic; git history provides audit trail |
| VIII. Prefer Established Tools | PASS | Uses GitHub Actions (established), shields.io (established), existing EE |

**Gate Result**: PASS - No violations, proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/005-ci-cd-dashboard/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal contracts)
│   └── README.md
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
.github/
├── workflows/
│   ├── ci.yml                    # PR validation workflow
│   ├── deploy.yml                # Merge-to-main deployment workflow
│   └── nightly.yml               # Scheduled assessment workflow
└── CODEOWNERS                    # (optional) code ownership

reports/
├── dashboard/
│   └── index.html                # Compliance dashboard (existing)
├── badge-data.json               # JSON endpoint for dynamic badges (new)
└── ...                           # Other generated reports

docs/
└── generated/
    ├── pi_guide.md               # Generated PI documentation
    ├── researcher_quickstart.md  # Generated researcher documentation
    ├── sysadmin_reference.md     # Generated sysadmin documentation
    ├── ciso_compliance_map.md    # Generated CISO documentation
    ├── leadership_briefing.md    # Generated leadership documentation
    ├── glossary_full.md          # Generated glossary
    └── crosswalk.csv             # Framework crosswalk (existing)

README.md                          # Updated with badges
```

**Structure Decision**: Infrastructure project using GitHub workflows in `.github/workflows/`. No new source directories needed; leverages existing `reports/`, `docs/generated/`, and Makefile targets. Adds `badge-data.json` for dynamic badge support.

## Complexity Tracking

> No violations detected. Table not required.
