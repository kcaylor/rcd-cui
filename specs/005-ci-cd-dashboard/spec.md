# Feature Specification: CI/CD Pipeline and Living Dashboard

**Feature Branch**: `005-ci-cd-dashboard`
**Created**: 2026-02-15
**Status**: Draft
**Input**: Automated validation on every commit with a published compliance dashboard including GitHub Actions workflows, GitHub Pages dashboard, README badges, and branch protection rules.

## Clarifications

### Session 2026-02-15

- Q: What happens when the execution environment image build fails during a merge workflow? → A: Fail entire workflow immediately, no dashboard deployment occurs
- Q: What is the GitHub Pages deployment source configuration? → A: Deploy to dedicated `gh-pages` branch via GitHub Actions
- Q: How should the SPRS score badge be implemented? → A: Dynamic badge reading from JSON file published to GitHub Pages
- Q: How should GitHub Pages deployment failures be handled? → A: Fail workflow immediately, artifacts available for manual retry

## User Scenarios & Testing *(mandatory)*

### User Story 1 - PR Validation Feedback (Priority: P1)

A developer opens a pull request with Ansible role changes. The CI pipeline automatically runs linting, syntax checking, and YAML validation. Within minutes, the developer sees pass/fail status checks directly in the GitHub PR interface, allowing them to fix issues before requesting review.

**Why this priority**: This is the foundation of the CI/CD pipeline. Without automated validation on PRs, code quality cannot be enforced and all other features depend on this working correctly.

**Independent Test**: Can be tested by opening a PR with intentional lint errors and verifying the status check fails, then fixing the errors and verifying the status check passes.

**Acceptance Scenarios**:

1. **Given** a developer pushes a commit to a PR branch, **When** the CI workflow triggers, **Then** lint, syntax-check, and YAML validation jobs run automatically
2. **Given** CI jobs complete, **When** the developer views the PR, **Then** they see green checkmarks or red X marks for each validation step
3. **Given** a validation job fails, **When** the developer clicks the failed check, **Then** they see specific error messages with file paths and line numbers
4. **Given** all validation jobs pass, **When** the PR is ready for review, **Then** the "Checks passed" status is displayed

---

### User Story 2 - Live Compliance Dashboard (Priority: P1)

A team lead or CISO wants to view the current compliance posture without accessing the repository or running commands. They navigate to a public GitHub Pages URL and see an HTML dashboard showing SPRS score, control status by family, and POA&M summary. The dashboard updates automatically after each merge to main.

**Why this priority**: This is the primary deliverable for stakeholder visibility. It enables auditors and leadership to monitor compliance without technical expertise or repository access.

**Independent Test**: Can be tested by navigating to the GitHub Pages URL after a merge and verifying the dashboard displays current compliance data with no manual intervention required.

**Acceptance Scenarios**:

1. **Given** a merge to main completes, **When** the dashboard workflow runs, **Then** the GitHub Pages site updates within 5 minutes
2. **Given** a user navigates to the dashboard URL, **When** the page loads, **Then** they see the compliance dashboard without authentication
3. **Given** the dashboard is displayed, **When** the user views the page, **Then** they see SPRS score, control family breakdown, and POA&M summary
4. **Given** an auditor needs compliance artifacts, **When** they visit the dashboard, **Then** they can download the framework crosswalk CSV

---

### User Story 3 - Generated Documentation Access (Priority: P2)

A PI or researcher needs to understand CUI compliance requirements without reading technical documentation. They access the GitHub Pages site and find audience-specific guides (PI guide, researcher quickstart) written in plain language. The documentation regenerates automatically when the underlying data models change.

**Why this priority**: Supports the constitutional principle of "Plain Language First" and enables self-service access to compliance guidance for non-technical stakeholders.

**Independent Test**: Can be tested by accessing the generated PI guide on GitHub Pages and verifying it contains plain-language explanations without technical jargon.

**Acceptance Scenarios**:

1. **Given** generated docs exist on GitHub Pages, **When** a user navigates to the docs section, **Then** they see links to PI guide, researcher quickstart, sysadmin reference, and other audience-specific documents
2. **Given** the control_mapping.yml or glossary is updated, **When** a merge to main occurs, **Then** the generated documentation reflects the changes
3. **Given** a PI accesses their guide, **When** they read the content, **Then** all technical terms link to glossary definitions

---

### User Story 4 - README Status Badges (Priority: P2)

A visitor to the repository wants to quickly assess project health and compliance status. They see badges in the README showing CI status, current SPRS score, and last assessment date. The badges update automatically with each CI run.

**Why this priority**: Provides at-a-glance project status for all repository visitors, building confidence in the project's maintenance and compliance posture.

**Independent Test**: Can be tested by viewing the README and verifying badges display current status, then triggering a CI run and verifying badges reflect the new state.

**Acceptance Scenarios**:

1. **Given** the README contains badge markup, **When** a user views the repository, **Then** they see a CI status badge (passing/failing)
2. **Given** an SPRS score badge is configured, **When** the user views the README, **Then** they see the current compliance score with appropriate color coding
3. **Given** the last assessment date badge is configured, **When** the user views the README, **Then** they see when the compliance was last verified

---

### User Story 5 - Branch Protection Enforcement (Priority: P2)

A repository maintainer wants to ensure all code merged to main has passed validation. They configure branch protection rules requiring CI checks to pass and at least one approval before merge. Developers cannot bypass these requirements.

**Why this priority**: Enforces code quality gates and ensures the main branch always reflects validated, reviewed code. Supports the "Compliance as Code" principle.

**Independent Test**: Can be tested by attempting to merge a PR with failing CI or without approval and verifying GitHub blocks the merge.

**Acceptance Scenarios**:

1. **Given** branch protection is configured, **When** a PR has failing CI checks, **Then** the merge button is disabled with a message explaining why
2. **Given** branch protection requires approval, **When** a PR has no approvals, **Then** the merge button is disabled
3. **Given** a PR has passing CI and required approvals, **When** the developer clicks merge, **Then** the merge completes successfully

---

### User Story 6 - Nightly Assessment Run (Priority: P3)

A sysadmin wants to ensure compliance is continuously monitored even when no code changes occur. A scheduled workflow runs the full compliance assessment nightly against a test inventory, updating the dashboard and alerting if issues are detected.

**Why this priority**: Provides continuous compliance monitoring beyond code changes. Lower priority because it builds on the existing dashboard infrastructure.

**Independent Test**: Can be tested by checking the dashboard after a scheduled run completes (without any code changes) and verifying assessment results are updated.

**Acceptance Scenarios**:

1. **Given** the nightly schedule is configured, **When** the scheduled time arrives, **Then** the assessment workflow runs automatically
2. **Given** the nightly assessment completes, **When** results are generated, **Then** the dashboard reflects the latest assessment data
3. **Given** the nightly assessment detects a compliance regression, **When** the workflow completes, **Then** appropriate notification or logging occurs

---

### Edge Cases

- **EE Build Failure**: If execution environment image build fails during merge workflow, the entire workflow fails immediately with no dashboard deployment (ensures dashboard never shows stale data)
- **Pages Deployment Failure**: If GitHub Pages deployment fails, workflow fails immediately; generated artifacts remain available for manual retry via workflow re-run
- What happens if the scheduled assessment runs during a deployment?
- How does the system handle rate limiting from GitHub Actions?
- What happens when badge service endpoints are temporarily unavailable?

## Requirements *(mandatory)*

### Functional Requirements

**GitHub Actions Workflow**

- **FR-001**: System MUST trigger lint, syntax-check, and YAML validation jobs on every pull request
- **FR-002**: System MUST trigger execution environment build, documentation generation, and dashboard deployment on every merge to main
- **FR-003**: System MUST run a scheduled compliance assessment at a configurable time (default: nightly)
- **FR-004**: System MUST provide clear error messages with file paths and line numbers for validation failures
- **FR-005**: System MUST cache dependencies and build artifacts to minimize workflow duration
- **FR-006**: System MUST use the project's execution environment for consistent tooling across CI and local development
- **FR-006a**: System MUST fail the entire merge workflow if execution environment build fails (no partial deployment)

**GitHub Pages Dashboard**

- **FR-007**: System MUST deploy the compliance dashboard to GitHub Pages automatically after merge to main
- **FR-007a**: System MUST publish dashboard artifacts to a dedicated `gh-pages` branch via GitHub Actions workflow
- **FR-007b**: System MUST fail workflow if GitHub Pages deployment fails (artifacts preserved for manual retry)
- **FR-008**: System MUST make the dashboard publicly accessible without authentication
- **FR-009**: Dashboard MUST display current SPRS compliance score
- **FR-010**: Dashboard MUST display control status grouped by NIST control family
- **FR-011**: Dashboard MUST display POA&M summary with item count and status breakdown
- **FR-012**: Dashboard MUST provide downloadable framework crosswalk in CSV format
- **FR-013**: Dashboard MUST include links to generated audience-specific documentation
- **FR-014**: Dashboard MUST display the date/time of last update

**README Badges**

- **FR-015**: README MUST display a CI status badge showing current build status
- **FR-016**: README MUST display an SPRS score badge with color coding (green ≥100, yellow 80-99, red <80)
- **FR-016a**: System MUST publish a JSON endpoint to GitHub Pages containing current SPRS score for dynamic badge generation
- **FR-017**: README MUST display a last assessment date badge
- **FR-018**: Badges MUST update automatically when CI workflows complete

**Branch Protection**

- **FR-019**: Main branch MUST require all CI status checks to pass before merge
- **FR-020**: Main branch MUST require at least one approving review before merge
- **FR-021**: System MUST prevent direct pushes to main branch (require PR workflow)

**Documentation Generation**

- **FR-022**: System MUST generate audience-specific documentation (PI guide, researcher quickstart, sysadmin reference, CISO compliance map, leadership briefing)
- **FR-023**: System MUST generate glossary with all terms hyperlinked
- **FR-024**: Generated documentation MUST be published to GitHub Pages alongside dashboard

### Key Entities

- **Workflow Run**: Represents a single execution of a GitHub Actions workflow, including trigger type, status, duration, and artifacts produced
- **Dashboard State**: Represents the current published dashboard content including SPRS score, control statuses, POA&M items, and last update timestamp
- **Assessment Result**: Represents compliance assessment output with per-control pass/fail status and aggregate scores
- **Badge Configuration**: Represents the dynamic badge endpoints and their data sources

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: PRs display lint and syntax check status within 5 minutes of push
- **SC-002**: Dashboard updates within 5 minutes of merge to main
- **SC-003**: Team members can view current compliance posture without running any local commands
- **SC-004**: Auditors can access and download compliance artifacts without repository access or authentication
- **SC-005**: Crosswalk CSV downloads correctly and opens in standard spreadsheet applications
- **SC-006**: Generated documentation covers all 5 audience types (PI, researcher, sysadmin, CISO, leadership)
- **SC-007**: All PRs to main require passing CI checks before merge can complete
- **SC-008**: Nightly assessment runs without manual intervention and updates dashboard
- **SC-009**: README badges accurately reflect current CI status and compliance score

## Assumptions

- GitHub Actions is available and the repository has sufficient Actions minutes
- GitHub Pages is enabled for the repository (or can be enabled)
- The existing Makefile targets (`make docs`, `make dashboard`, `make crosswalk`) work correctly
- The execution environment can be built and cached in GitHub Actions
- Badge services (shields.io or similar) are available for dynamic badge generation
- Repository administrators have permission to configure branch protection rules

## Out of Scope

- Historical compliance trending (planned for Phase 3/Spec 007)
- Slack/Teams notifications for compliance regressions (planned for Phase 3)
- Integration with external ticketing systems (planned for Phase 4)
- Container-based demo environments (planned for Phase 4/Spec 008)
