# Quickstart: CI/CD Pipeline and Living Dashboard

**Feature**: 005-ci-cd-dashboard
**Date**: 2026-02-15

[![CI](https://github.com/kcaylor/rcd-cui/actions/workflows/ci.yml/badge.svg)](https://github.com/kcaylor/rcd-cui/actions/workflows/ci.yml)
[![Deploy](https://github.com/kcaylor/rcd-cui/actions/workflows/deploy.yml/badge.svg)](https://github.com/kcaylor/rcd-cui/actions/workflows/deploy.yml)
[![Nightly](https://github.com/kcaylor/rcd-cui/actions/workflows/nightly.yml/badge.svg)](https://github.com/kcaylor/rcd-cui/actions/workflows/nightly.yml)

## Overview

This guide covers setup and verification of the CI/CD pipeline and living dashboard for the rcd-cui project.

## Prerequisites

- GitHub repository with admin access
- GitHub Actions enabled (default for new repositories)
- GitHub Pages enabled or ability to enable it
- Local development environment with `make`, `podman`/`docker`, Python 3.9+

## Setup Steps

### 1. Enable GitHub Pages

1. Navigate to repository **Settings** → **Pages**
2. Under "Build and deployment":
   - Source: **Deploy from a branch**
   - Branch: **gh-pages** / **/ (root)**
3. Click **Save**

Note: The `gh-pages` branch will be created automatically by the first successful deployment workflow.

### 2. Verify Workflows Exist

Ensure these files are present in the repository:

```
.github/workflows/
├── ci.yml         # PR validation
├── deploy.yml     # Merge-to-main deployment
└── nightly.yml    # Scheduled assessment
```

### 3. Configure Branch Protection

Automated option (recommended for reproducibility):

```bash
# From repository root
./scripts/configure_branch_protection.sh --repo kcaylor/rcd-cui --branch main
```

Manual option:

1. Navigate to repository **Settings** → **Branches**
2. Click **Add branch protection rule**
3. Branch name pattern: `main`
4. Enable:
   - [x] Require a pull request before merging
     - [x] Require approvals: **1**
   - [x] Require status checks to pass before merging
     - [x] Require branches to be up to date before merging
     - Search and add: `lint`, `syntax-check`, `yaml-validation`
   - [x] Do not allow bypassing the above settings
5. Click **Create** or **Save changes**

### 4. Add README Badges

Add these badges to the top of `README.md`:

```markdown
[![CI](https://github.com/kcaylor/rcd-cui/actions/workflows/ci.yml/badge.svg)](https://github.com/kcaylor/rcd-cui/actions/workflows/ci.yml)
![SPRS Score](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fkcaylor.github.io%2Frcd-cui%2Fbadge-data.json&query=%24.sprs_score&label=SPRS&color=auto)
![Last Assessment](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fkcaylor.github.io%2Frcd-cui%2Fbadge-data.json&query=%24.last_assessment&label=Last%20Assessment&color=blue)
```

### 5. Trigger Initial Deployment

The deployment workflow runs automatically on merge to main. To trigger the first deployment:

1. Create a branch: `git checkout -b setup-cicd`
2. Make a small change (e.g., update README badges)
3. Commit and push: `git push -u origin setup-cicd`
4. Create a PR and wait for CI checks to pass
5. Get approval and merge

Or manually trigger via GitHub Actions UI:
1. Go to **Actions** → **Deploy Dashboard**
2. Click **Run workflow** → **Run workflow**

## Verification

### Verify PR Checks

1. Create a test branch with an intentional lint error:
   ```bash
   git checkout -b test-ci
   echo "- name: test" > roles/test_role/tasks/main.yml  # Invalid task
   git add . && git commit -m "Test CI failure"
   git push -u origin test-ci
   ```

2. Open a PR and verify:
   - CI workflow triggers automatically
   - `lint` job fails with clear error message
   - Merge button is blocked

3. Fix the error and push:
   - All checks should pass
   - Merge button becomes available

4. Clean up: close PR without merging, delete test branch

### Verify Dashboard Deployment

1. After a merge to main, wait for deploy workflow to complete
2. Navigate to `https://kcaylor.github.io/rcd-cui/`
3. Verify:
   - Dashboard loads without authentication
   - SPRS score is displayed
   - Control family breakdown is visible
   - Crosswalk CSV downloads correctly

### Verify Badges

1. View the README on GitHub
2. Verify:
   - CI badge shows "passing" or "failing" based on last run
   - SPRS score badge shows numeric value with color
   - Last Assessment badge shows date

### Verify Nightly Schedule

1. Wait for 02:00 UTC or manually trigger:
   - Go to **Actions** → **Nightly Assessment**
   - Click **Run workflow**

2. After completion, verify dashboard is updated

## Troubleshooting

### CI Checks Not Appearing

- Verify workflow files are in `.github/workflows/`
- Check workflow syntax: `gh workflow list` should show workflows
- Check Actions tab for workflow runs and errors

### Dashboard Not Updating

- Check deploy workflow run for errors
- Verify GitHub Pages is enabled and configured for `gh-pages` branch
- Check that `gh-pages` branch exists: `git branch -r | grep gh-pages`
- If the run fails with `No assessment JSON found`, trigger **Nightly Assessment** once (or run `./scripts/run_nightly_assessment.sh` locally) to seed `data/assessment_history/*.json`

### Nightly Assessment Fails in Local Dev

- Local inventory hosts in `inventory/hosts.yml` are placeholders and may be unreachable
- Use `./scripts/run_nightly_assessment.sh` to apply the built-in fallback snapshot path for dashboard continuity
- For real assessment data, run `make assess` against a reachable inventory with required host/group vars populated

### Badges Showing "Error"

- Verify `badge-data.json` exists at `https://kcaylor.github.io/rcd-cui/badge-data.json`
- Check JSON syntax is valid
- Clear browser cache or try incognito mode

### Branch Protection Blocking Legitimate Merges

- Verify all required status checks are passing
- Ensure at least one approving review exists
- Check that branch is up to date with main

## Daily Operations

### Monitoring

- Check **Actions** tab for workflow failures
- Review dashboard daily for compliance posture
- Monitor nightly assessment logs for regressions

### Maintenance

- Review and merge Dependabot PRs for action updates
- Periodically verify badges are rendering correctly
- Clear Actions cache if builds become stale: **Actions** → **Caches** → Delete

## URLs Reference

| Resource | URL |
|----------|-----|
| Dashboard | `https://kcaylor.github.io/rcd-cui/` |
| Documentation | `https://kcaylor.github.io/rcd-cui/docs/` |
| Badge Data | `https://kcaylor.github.io/rcd-cui/badge-data.json` |
| Crosswalk CSV | `https://kcaylor.github.io/rcd-cui/docs/crosswalk.csv` |
| CI Workflow | `https://github.com/kcaylor/rcd-cui/actions/workflows/ci.yml` |
| Deploy Workflow | `https://github.com/kcaylor/rcd-cui/actions/workflows/deploy.yml` |
| Nightly Workflow | `https://github.com/kcaylor/rcd-cui/actions/workflows/nightly.yml` |
