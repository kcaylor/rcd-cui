# Data Model: CI/CD Pipeline and Living Dashboard

**Feature**: 005-ci-cd-dashboard
**Date**: 2026-02-15

## Overview

This feature primarily deals with CI/CD workflow configuration and static artifact generation. The data model focuses on the JSON structures used for badge data and the workflow configuration schemas.

## Entities

### 1. BadgeData

Represents the JSON file published to GitHub Pages for dynamic badge generation.

**File**: `reports/badge-data.json` (published to `gh-pages` branch)

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `sprs_score` | integer | Current SPRS compliance score (0-110) | `87` |
| `sprs_color` | string | Badge color based on score thresholds | `"yellow"` |
| `last_assessment` | string | ISO 8601 date of last assessment | `"2026-02-15"` |
| `controls_passing` | integer | Number of controls in compliant state | `95` |
| `controls_total` | integer | Total number of assessed controls | `110` |
| `generated_at` | string | ISO 8601 timestamp of generation | `"2026-02-15T14:30:00Z"` |

**Color Thresholds**:
- `sprs_score >= 100` → `"green"`
- `sprs_score >= 80 && sprs_score < 100` → `"yellow"`
- `sprs_score < 80` → `"red"`

**Validation Rules**:
- `sprs_score`: 0 ≤ value ≤ 110
- `sprs_color`: enum ["green", "yellow", "red"]
- `last_assessment`: valid ISO 8601 date
- `controls_passing` ≤ `controls_total`

### 2. WorkflowConfig (CI)

GitHub Actions workflow configuration for PR validation.

**File**: `.github/workflows/ci.yml`

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Workflow display name |
| `on.pull_request` | object | Trigger on PR events |
| `on.pull_request.branches` | array | Target branches (main) |
| `jobs.lint` | object | ansible-lint job definition |
| `jobs.syntax-check` | object | Playbook syntax check job |
| `jobs.yaml-validation` | object | YAML lint job |

**Job Structure** (each job):
- `runs-on`: `ubuntu-latest`
- `steps`: checkout, setup-python, build EE (cached), run make target

### 3. WorkflowConfig (Deploy)

GitHub Actions workflow configuration for merge-to-main deployment.

**File**: `.github/workflows/deploy.yml`

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Workflow display name |
| `on.push.branches` | array | Trigger on push to main |
| `concurrency.group` | string | Concurrency group name |
| `concurrency.cancel-in-progress` | boolean | Whether to cancel running |
| `jobs.build` | object | Build EE and generate artifacts |
| `jobs.deploy` | object | Deploy to GitHub Pages |

**Build Job Outputs**:
- Generated documentation in `docs/generated/`
- Dashboard in `reports/dashboard/`
- Badge data in `reports/badge-data.json`
- Crosswalk CSV in `docs/generated/crosswalk.csv`

### 4. WorkflowConfig (Nightly)

GitHub Actions workflow configuration for scheduled assessment.

**File**: `.github/workflows/nightly.yml`

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Workflow display name |
| `on.schedule` | array | Cron schedule definitions |
| `on.schedule[0].cron` | string | Cron expression (`0 2 * * *`) |
| `on.workflow_dispatch` | object | Manual trigger support |

### 5. PagesDeployment

Represents the deployed GitHub Pages site structure.

**Root**: `https://<org>.github.io/rcd-cui/`

| Path | Content | Source |
|------|---------|--------|
| `/` | Redirect to dashboard | `index.html` |
| `/dashboard/` | Compliance dashboard | `reports/dashboard/` |
| `/docs/` | Generated documentation | `docs/generated/` |
| `/docs/crosswalk.csv` | Framework crosswalk | `docs/generated/crosswalk.csv` |
| `/badge-data.json` | Dynamic badge data | `reports/badge-data.json` |

### 6. BranchProtectionConfig

Repository settings for main branch protection (not a file, but configuration).

| Setting | Value | Purpose |
|---------|-------|---------|
| `required_status_checks.strict` | `true` | Branches must be up to date |
| `required_status_checks.contexts` | `["lint", "syntax-check", "yaml-validation"]` | Required CI checks |
| `required_pull_request_reviews.required_approving_review_count` | `1` | Minimum approvals |
| `enforce_admins` | `true` | No bypass for admins |
| `allow_force_pushes` | `false` | Prevent force push |
| `allow_deletions` | `false` | Prevent branch deletion |

## Relationships

```
┌─────────────────┐
│  PR Validation  │──triggers──▶ ci.yml workflow
│   (developer)   │
└─────────────────┘
         │
         │ merge (requires CI pass + approval)
         ▼
┌─────────────────┐
│   Main Branch   │──triggers──▶ deploy.yml workflow
└─────────────────┘                    │
         ▲                             │
         │                             ▼
         │                    ┌─────────────────┐
         │                    │  Build & Deploy │
         │                    │  - make docs    │
         │                    │  - make dashboard│
         │                    │  - badge-data   │
         │                    └────────┬────────┘
         │                             │
         │                             ▼
┌─────────────────┐           ┌─────────────────┐
│ Nightly Schedule│──triggers─│   gh-pages      │
│  (cron 02:00)   │           │   branch        │
└─────────────────┘           └────────┬────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │  GitHub Pages   │
                              │  Public Site    │
                              └─────────────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │ shields.io      │──reads──▶ badge-data.json
                              │ Badges          │
                              └─────────────────┘
```

## State Transitions

### Workflow Run States

```
QUEUED ──▶ IN_PROGRESS ──▶ COMPLETED (success)
                      └──▶ FAILED (failure)
                      └──▶ CANCELLED (manual/concurrency)
```

### Dashboard Update Cycle

```
STALE ──(merge to main)──▶ BUILDING ──(success)──▶ CURRENT
                                   └──(failure)──▶ STALE (unchanged)
```

## File Artifacts

| Artifact | Generated By | Published To | Format |
|----------|--------------|--------------|--------|
| `badge-data.json` | Python script (new) | `gh-pages:/badge-data.json` | JSON |
| `dashboard/index.html` | `make dashboard` | `gh-pages:/dashboard/` | HTML |
| `crosswalk.csv` | `make crosswalk` | `gh-pages:/docs/crosswalk.csv` | CSV |
| `pi_guide.md` | `make docs` | `gh-pages:/docs/pi_guide.md` | Markdown |
| `researcher_quickstart.md` | `make docs` | `gh-pages:/docs/` | Markdown |
| `sysadmin_reference.md` | `make docs` | `gh-pages:/docs/` | Markdown |
| `ciso_compliance_map.md` | `make docs` | `gh-pages:/docs/` | Markdown |
| `leadership_briefing.md` | `make docs` | `gh-pages:/docs/` | Markdown |
| `glossary_full.md` | `make docs` | `gh-pages:/docs/` | Markdown |
