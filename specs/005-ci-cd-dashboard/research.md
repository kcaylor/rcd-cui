# Research: CI/CD Pipeline and Living Dashboard

**Feature**: 005-ci-cd-dashboard
**Date**: 2026-02-15
**Status**: Complete

## Technology Decisions

### 1. GitHub Actions Workflow Structure

**Decision**: Use three separate workflow files (ci.yml, deploy.yml, nightly.yml) rather than a single monolithic workflow.

**Rationale**:
- Clear separation of concerns: PR validation, deployment, and scheduled runs have different triggers and requirements
- Independent failure isolation: a failing nightly run doesn't affect PR checks
- Easier maintenance: each workflow is focused and readable
- Better GitHub UI presentation: separate workflow runs in Actions tab

**Alternatives Considered**:
- Single workflow with conditional jobs: Rejected due to complexity and poor visibility
- Reusable workflows: Considered but added unnecessary abstraction for this scope

### 2. Execution Environment Build in CI

**Decision**: Build EE from `execution-environment.yml` using `ansible-builder` in the deploy workflow, with layer caching.

**Rationale**:
- Ensures CI uses identical tooling to local development
- `ansible-builder` is the standard tool for Ansible EE creation
- Docker layer caching reduces build time on subsequent runs
- Consistent with existing `make ee-build` local workflow

**Alternatives Considered**:
- Pre-built EE image in container registry: Adds registry dependency, version sync complexity
- Install tools directly on runner: Inconsistent with local development, harder to maintain

### 3. GitHub Pages Deployment Method

**Decision**: Use `peaceiris/actions-gh-pages` action to deploy to `gh-pages` branch.

**Rationale**:
- Most widely-used GitHub Pages deployment action (10k+ stars, actively maintained)
- Handles branch creation, force push, and cleanup automatically
- Supports custom CNAME, excludes, and other common configurations
- Well-documented error handling and retry behavior

**Alternatives Considered**:
- `actions/deploy-pages`: Requires Pages API setup, more complex configuration
- Manual git push to gh-pages: Error-prone, requires careful branch handling
- Deploy from `docs/` on main: Pollutes main branch with generated artifacts

### 4. Dynamic Badge Implementation

**Decision**: Generate `badge-data.json` during workflow, publish to GitHub Pages, use shields.io dynamic badge endpoint.

**Rationale**:
- No external service dependencies beyond shields.io (widely trusted)
- JSON endpoint allows multiple badge values from single file
- shields.io handles badge rendering, caching, and CDN distribution
- Format: `https://img.shields.io/badge/dynamic/json?url=...&query=$.sprs_score&label=SPRS`

**Alternatives Considered**:
- GitHub Actions workflow badge API: Only shows pass/fail, not custom values
- Custom badge server: Unnecessary infrastructure complexity
- Static badge updated via commit: Requires commit on every change, clutters history

### 5. Badge Data JSON Schema

**Decision**: Single `badge-data.json` file with flat structure for all badge values.

**Rationale**:
- Simple JSONPath queries for shields.io (`$.sprs_score`, `$.last_assessment`)
- Easy to extend with additional badges in future phases
- Human-readable for debugging

**Schema**:
```json
{
  "sprs_score": 87,
  "sprs_color": "yellow",
  "last_assessment": "2026-02-15",
  "controls_passing": 95,
  "controls_total": 110
}
```

### 6. PR Validation Jobs

**Decision**: Run three parallel jobs: lint, syntax-check, yaml-validation.

**Rationale**:
- Parallel execution reduces total CI time
- Independent jobs provide clear feedback on which check failed
- Maps directly to existing Makefile targets: `make ee-lint`, `make ee-syntax-check`, `make ee-yamllint`
- Fail-fast disabled: all checks run even if one fails (more complete feedback)

**Alternatives Considered**:
- Sequential jobs: Slower, no benefit
- Single job with multiple steps: Harder to identify which check failed at a glance

### 7. Workflow Caching Strategy

**Decision**: Cache Docker layers for EE build, cache Python dependencies via pip cache.

**Rationale**:
- Docker layer caching via `docker/build-push-action` with `cache-from`/`cache-to`
- Python pip cache via `actions/setup-python` cache key
- Reduces average workflow time by 60-70% on cache hits

**Cache Keys**:
- EE: `ee-${{ hashFiles('execution-environment.yml', 'requirements-ee.txt', 'bindep.txt') }}`
- Python: `pip-${{ hashFiles('requirements-dev.txt') }}`

### 8. Nightly Schedule Configuration

**Decision**: Run nightly assessment at 02:00 UTC using cron schedule.

**Rationale**:
- 02:00 UTC is off-peak for US-based team (evening Pacific, night Eastern)
- Avoids conflict with typical work-hour deployments
- GitHub Actions cron is timezone-agnostic (always UTC)
- Single daily run balances monitoring frequency with Actions quota usage

**Alternatives Considered**:
- Hourly: Excessive for compliance monitoring, wastes Actions minutes
- Weekly: Too infrequent for meaningful continuous monitoring
- On-demand only: Defeats purpose of continuous compliance

### 9. Branch Protection Configuration

**Decision**: Configure via repository settings (manual or via GitHub API/Terraform), not via workflow.

**Rationale**:
- Branch protection is repository configuration, not workflow logic
- GitHub API or Terraform can codify settings for reproducibility
- Manual setup is acceptable for single-repository scope
- Documented in quickstart.md for operators

**Settings**:
- Require status checks: `lint`, `syntax-check`, `yaml-validation`
- Require 1 approving review
- Require branches to be up to date before merging
- Do not allow bypassing

### 10. Concurrency Handling

**Decision**: Use GitHub Actions concurrency groups to prevent overlapping deployments.

**Rationale**:
- `concurrency: { group: "pages", cancel-in-progress: false }` ensures only one deployment runs
- Subsequent deployments queue rather than cancel (preserves all changes)
- Prevents race conditions between scheduled and merge-triggered deployments

**Alternatives Considered**:
- Cancel in-progress: Could lose legitimate deployment if timing is unlucky
- No concurrency control: Risk of partial/corrupted deployments

## Dependencies

| Dependency | Version/Source | Purpose |
|------------|----------------|---------|
| `ansible-builder` | Latest via pip | Build execution environment |
| `peaceiris/actions-gh-pages` | v4 | Deploy to GitHub Pages |
| `actions/checkout` | v4 | Checkout repository |
| `actions/setup-python` | v5 | Python environment with caching |
| `docker/setup-buildx-action` | v3 | Docker buildx for layer caching |
| `docker/build-push-action` | v5 | Build EE with caching |
| shields.io | External service | Dynamic badge rendering |

## Open Questions Resolved

All technical questions from the specification have been addressed:

1. **EE build failure handling**: Fail workflow immediately (per clarification)
2. **GitHub Pages deployment source**: `gh-pages` branch (per clarification)
3. **SPRS badge implementation**: Dynamic JSON endpoint (per clarification)
4. **Pages deployment failure**: Fail workflow, artifacts preserved (per clarification)
5. **Scheduled assessment during deployment**: Concurrency groups prevent overlap
6. **Rate limiting**: GitHub Actions has built-in retry; unlikely with current scale
7. **Badge service unavailability**: Graceful degradation (shields.io returns cached badge)
