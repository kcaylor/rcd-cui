# Contracts: CI/CD Pipeline and Living Dashboard

**Feature**: 005-ci-cd-dashboard
**Date**: 2026-02-15

## Overview

This feature involves internal contracts between CI/CD workflow components. Since this is infrastructure code (GitHub Actions workflows), contracts are defined as workflow interfaces and file format specifications rather than API endpoints.

## Internal Contracts

### 1. Badge Data JSON Contract

**Producer**: `scripts/generate_badge_data.py` (new script)
**Consumer**: shields.io dynamic badge service

**Schema**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["sprs_score", "sprs_color", "last_assessment", "controls_passing", "controls_total", "generated_at"],
  "properties": {
    "sprs_score": {
      "type": "integer",
      "minimum": 0,
      "maximum": 110,
      "description": "Current SPRS compliance score"
    },
    "sprs_color": {
      "type": "string",
      "enum": ["green", "yellow", "red"],
      "description": "Badge color based on score thresholds"
    },
    "last_assessment": {
      "type": "string",
      "format": "date",
      "description": "Date of last compliance assessment"
    },
    "controls_passing": {
      "type": "integer",
      "minimum": 0,
      "description": "Number of controls in compliant state"
    },
    "controls_total": {
      "type": "integer",
      "minimum": 1,
      "description": "Total number of assessed controls"
    },
    "generated_at": {
      "type": "string",
      "format": "date-time",
      "description": "Timestamp when badge data was generated"
    }
  }
}
```

**Example**:
```json
{
  "sprs_score": 87,
  "sprs_color": "yellow",
  "last_assessment": "2026-02-15",
  "controls_passing": 95,
  "controls_total": 110,
  "generated_at": "2026-02-15T14:30:00Z"
}
```

### 2. CI Workflow Job Contract

**Producer**: `.github/workflows/ci.yml`
**Consumer**: GitHub Branch Protection, GitHub PR Status Checks

**Required Status Checks** (job names exposed to GitHub):
| Job Name | Description | Exit Code |
|----------|-------------|-----------|
| `lint` | ansible-lint validation | 0=pass, non-zero=fail |
| `syntax-check` | Playbook syntax validation | 0=pass, non-zero=fail |
| `yaml-validation` | yamllint validation | 0=pass, non-zero=fail |

**Contract**: Branch protection rules reference these exact job names. Renaming jobs requires updating branch protection settings.

### 3. Deploy Workflow Artifact Contract

**Producer**: `.github/workflows/deploy.yml` (build job)
**Consumer**: `.github/workflows/deploy.yml` (deploy job), GitHub Pages

**Artifacts Directory Structure**:
```
_site/                          # Root of published site
├── index.html                  # Redirect to dashboard
├── dashboard/
│   └── index.html              # Compliance dashboard
├── docs/
│   ├── pi_guide.md
│   ├── researcher_quickstart.md
│   ├── sysadmin_reference.md
│   ├── ciso_compliance_map.md
│   ├── leadership_briefing.md
│   ├── glossary_full.md
│   └── crosswalk.csv
└── badge-data.json             # Dynamic badge data
```

**Contract**: The deploy job expects this exact structure from the build job. The `peaceiris/actions-gh-pages` action publishes this directory to the `gh-pages` branch.

### 4. Makefile Target Contract

**Producer**: Existing Makefile
**Consumer**: GitHub Actions workflows

**Required Targets**:
| Target | Description | Expected Output |
|--------|-------------|-----------------|
| `make ee-build` | Build execution environment | Docker image `rcd-cui-ee:latest` |
| `make ee-lint` | Run ansible-lint in EE | Exit 0 if pass, non-zero if fail |
| `make ee-syntax-check` | Run syntax check in EE | Exit 0 if pass, non-zero if fail |
| `make ee-yamllint` | Run yamllint in EE | Exit 0 if pass, non-zero if fail |
| `make docs` | Generate documentation | Files in `docs/generated/` |
| `make dashboard` | Generate dashboard | `reports/dashboard/index.html` |
| `make crosswalk` | Generate crosswalk CSV | `docs/generated/crosswalk.csv` |

**Contract**: Workflows depend on these targets existing and functioning. Changes to target names or output locations require workflow updates.

### 5. Shields.io Badge URL Contract

**Producer**: README.md badge markup
**Consumer**: shields.io service

**Badge URLs**:

**CI Status Badge**:
```
https://github.com/<org>/rcd-cui/actions/workflows/ci.yml/badge.svg
```

**SPRS Score Badge** (dynamic):
```
https://img.shields.io/badge/dynamic/json?url=https://<org>.github.io/rcd-cui/badge-data.json&query=$.sprs_score&label=SPRS&color=auto
```

Note: Color can be derived from `$.sprs_color` or computed by shields.io based on thresholds.

**Last Assessment Badge** (dynamic):
```
https://img.shields.io/badge/dynamic/json?url=https://<org>.github.io/rcd-cui/badge-data.json&query=$.last_assessment&label=Last%20Assessment&color=blue
```

### 6. GitHub Pages Configuration Contract

**Producer**: Repository settings
**Consumer**: GitHub Pages service

**Configuration**:
| Setting | Value |
|---------|-------|
| Source | `gh-pages` branch |
| Directory | `/` (root) |
| HTTPS | Enforced |
| Custom domain | Optional (not required for this spec) |

**Contract**: The `gh-pages` branch must exist and contain valid web content. The `peaceiris/actions-gh-pages` action manages this branch.

## External Dependencies

| Service | Purpose | Failure Mode |
|---------|---------|--------------|
| GitHub Actions | Workflow execution | Workflows don't run |
| GitHub Pages | Static site hosting | Dashboard unavailable |
| shields.io | Badge rendering | Badges show error/cached |

## Versioning

These contracts are internal to the repository. Changes should be coordinated:

1. **Badge data schema changes**: Update producer script and consumer documentation
2. **Workflow job renames**: Update branch protection settings
3. **Makefile target changes**: Update workflow YAML files
4. **Directory structure changes**: Update both build and deploy jobs
