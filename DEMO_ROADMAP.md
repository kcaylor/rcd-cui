# RCD-CUI Demo Roadmap

A phased implementation plan for demonstrating rcd-cui capabilities to the RCD team and stakeholders.

## Goals

1. **Visibility**: Provide living artifacts that showcase compliance posture without manual effort
2. **Reproducibility**: Enable repeatable demos that work on any developer's machine
3. **Realism**: Demonstrate actual HPC/CUI workflows, not just config management
4. **Education**: Help team members understand NIST 800-171 through hands-on interaction

## Demo Scenarios

All phases build toward supporting these four demonstration scenarios:

| Scenario | Description | Primary Audience |
|----------|-------------|------------------|
| **A: Project Onboarding** | End-to-end CUI project setup | PIs, Researchers, Leadership |
| **B: Compliance Drift** | Detect and remediate configuration drift | Sysadmins, CISO |
| **C: Auditor Walkthrough** | Generate and review audit evidence package | CISO, External Auditors |
| **D: Node Lifecycle** | Provision, validate, and decommission compute nodes | Sysadmins, Security Team |

---

## Phase 1: CI/CD and Living Dashboard (Immediate)

**Objective**: Automated validation on every commit with a published compliance dashboard.

### Deliverables

1. **GitHub Actions Workflow** (`.github/workflows/ci.yml`)
   - Trigger on PR: lint, syntax-check, YAML validation
   - Trigger on merge to main: build EE image, generate docs, publish dashboard
   - Nightly schedule: full assessment against test inventory

2. **GitHub Pages Dashboard**
   - Published at `https://<org>.github.io/rcd-cui/`
   - Auto-updated on each merge to main
   - Contents:
     - Compliance dashboard (`reports/dashboard/index.html`)
     - Framework crosswalk (downloadable CSV)
     - Generated documentation (PI guide, researcher quickstart, etc.)

3. **README Badges**
   - CI status badge
   - SPRS score badge (static initially, dynamic in Phase 3)
   - Last assessment date badge

4. **Branch Protection Rules**
   - Require CI pass before merge
   - Require at least one approval

### Success Criteria

- [ ] PRs show lint/syntax status checks
- [ ] Dashboard URL is live and updates within 5 minutes of merge
- [ ] Team members can view current compliance posture without running any commands
- [ ] Crosswalk CSV downloads correctly and opens in Excel

### Supports Scenarios

- **C (Auditor Walkthrough)**: Auditor can access dashboard and download artifacts without repository access

---

## Phase 2: Local Demo Lab (Short-term)

**Objective**: Reproducible multi-VM environment for interactive demonstrations.

### Deliverables

1. **Vagrant Lab Environment** (`demo/vagrant/`)
   - `Vagrantfile` defining 3-4 Rocky Linux 9 VMs:
     - `mgmt01`: FreeIPA server, Wazuh manager (management zone)
     - `login01`: Login/submit node (internal zone)
     - `compute01`, `compute02`: Compute nodes (restricted zone)
   - Minimal Slurm cluster (slurmctld on mgmt, slurmd on compute)
   - Shared storage via NFS (simulating Lustre/BeeGFS)

2. **Demo Orchestration Scripts** (`demo/scripts/`)
   - `demo-setup.sh`: Bring up lab, run initial provisioning
   - `demo-reset.sh`: Reset to baseline state between demos
   - `demo-break.sh`: Introduce compliance violations for Scenario B
   - `demo-fix.sh`: Run remediation playbooks

3. **Scenario Playbooks** (`demo/playbooks/`)
   - `scenario-a-onboard.yml`: Onboard fictional "Project Helios" with users
   - `scenario-b-drift.yml`: Orchestrated break/detect/fix cycle
   - `scenario-c-audit.yml`: Generate full auditor package
   - `scenario-d-lifecycle.yml`: Add new node, validate, decommission

4. **Demo Narrative Scripts** (`demo/narratives/`)
   - Markdown guides for each scenario with talking points
   - Expected outputs and screenshots
   - Timing estimates for presentations

### Lab Specifications

| VM | vCPUs | RAM | Disk | Role |
|----|-------|-----|------|------|
| mgmt01 | 2 | 4GB | 40GB | FreeIPA, Wazuh, Slurmctld |
| login01 | 2 | 2GB | 20GB | Login node, submit host |
| compute01 | 2 | 2GB | 20GB | Compute node |
| compute02 | 2 | 2GB | 20GB | Compute node |

**Total resources**: 8 vCPUs, 10GB RAM (fits on modern laptop with 16GB+)

### Success Criteria

- [ ] `vagrant up` completes in under 30 minutes on first run
- [ ] `demo-reset.sh` returns to baseline in under 5 minutes
- [ ] All four scenarios can be demonstrated without internet access
- [ ] Lab works on macOS (Apple Silicon + Intel) and Linux hosts

### Supports Scenarios

- **A (Onboarding)**: Create project group in FreeIPA, add Slurm QOS, set storage ACLs
- **B (Drift)**: Break SSH config, disable auditd, show detection and remediation
- **D (Lifecycle)**: Simulate new node addition with compliance gate

---

## Phase 3: Compliance Trending and Analytics (Medium-term)

**Objective**: Historical tracking of compliance posture with trend visualization.

### Deliverables

1. **Assessment History Storage**
   - JSON files in `data/assessment_history/YYYY-MM-DD.json`
   - Git-tracked for audit trail
   - Schema-validated with Pydantic

2. **SPRS Trend Tracking**
   - Historical SPRS scores stored per assessment
   - Trend line visualization on dashboard
   - Per-control family breakdown over time

3. **Enhanced Dashboard**
   - Interactive charts (Chart.js or similar)
   - Date range selector for historical views
   - Control-level drill-down
   - POA&M burndown chart
   - "Days in current state" metrics

4. **Compliance Alerts**
   - GitHub Actions workflow detects score drops
   - Creates GitHub Issue for significant regressions
   - Optional: Slack/Teams webhook notifications

5. **Dynamic README Badge**
   - Shields.io badge pulling from latest assessment
   - Shows current SPRS score with color coding:
     - Green: 110 (perfect)
     - Yellow: 80-109
     - Red: <80

### Data Model

```yaml
# data/assessment_history/2026-02-15.json
{
  "assessment_date": "2026-02-15T14:30:00Z",
  "sprs_score": 87,
  "controls_assessed": 110,
  "controls_passing": 95,
  "controls_failing": 12,
  "controls_not_applicable": 3,
  "by_family": {
    "AC": {"passing": 18, "failing": 2},
    "AU": {"passing": 12, "failing": 1},
    ...
  },
  "poam_items": 8,
  "execution_environment_version": "1.2.0",
  "commit_sha": "abc123"
}
```

### Success Criteria

- [ ] Dashboard shows 30-day trend line
- [ ] Score drops of >5 points create GitHub Issues
- [ ] README badge reflects current SPRS score
- [ ] Assessment history survives across branches (main only)

### Supports Scenarios

- **B (Drift)**: Show historical trend, demonstrate score drop and recovery
- **C (Auditor)**: Provide historical compliance evidence for audit period

---

## Phase 4: Integration Demo Environment (Long-term)

**Objective**: Production-like environment with full observability stack.

### Deliverables

1. **Kubernetes/Podman Compose Stack**
   - Alternative to Vagrant for container-native demos
   - Faster startup, lower resource usage
   - Suitable for cloud deployment (workshop environments)

2. **Grafana Integration**
   - Import assessment data as Grafana data source
   - Pre-built compliance dashboards
   - Unified view with infrastructure metrics

3. **Wazuh Correlation**
   - Security events linked to compliance controls
   - Real-time alerting for control violations
   - Demonstrate SIEM integration for auditors

4. **ServiceNow/Jira Integration**
   - Auto-create tickets for new POA&M items
   - Link remediation commits to tickets
   - Demonstrate enterprise workflow integration

5. **Cloud Deployment Option**
   - Terraform modules for AWS/GCP/Azure
   - Ephemeral demo environments on demand
   - Cost tracking and auto-teardown

### Success Criteria

- [ ] Container stack starts in under 5 minutes
- [ ] Grafana dashboards pre-populated on first boot
- [ ] Demo can run entirely in cloud for remote presentations
- [ ] Integration patterns documented for production adoption

### Supports Scenarios

- **All scenarios**: Full production-like environment
- **Extensibility**: Template for real deployment planning

---

## Implementation Order

```
Phase 1 ─────────────────────────────────────────────────────────►
         CI/CD Pipeline │ GitHub Pages │ Badges │ Branch Protection
                        │
Phase 2 ────────────────┴────────────────────────────────────────►
         Vagrant Lab │ Demo Scripts │ Scenario Playbooks │ Narratives
                                     │
Phase 3 ─────────────────────────────┴───────────────────────────►
         Assessment History │ Trend Charts │ Alerts │ Dynamic Badges
                                            │
Phase 4 ────────────────────────────────────┴────────────────────►
         Container Stack │ Grafana │ Wazuh │ Cloud Deploy
```

## Speckit Specifications

Each phase should be implemented as a separate speckit specification:

| Spec | Phase | Name | Key Deliverables |
|------|-------|------|------------------|
| 005 | 1 | CI/CD Pipeline and Living Dashboard | GitHub Actions, Pages, badges |
| 006 | 2 | Local Demo Lab Environment | Vagrant, demo scripts, narratives |
| 007 | 3 | Compliance Trending and Analytics | History storage, charts, alerts |
| 008 | 4 | Integration Demo Environment | Containers, Grafana, cloud deploy |

## Resource Requirements

### Development Time (Estimates)

| Phase | Specification | Implementation | Testing | Total |
|-------|---------------|----------------|---------|-------|
| 1 | 2 hours | 4 hours | 2 hours | 8 hours |
| 2 | 4 hours | 16 hours | 8 hours | 28 hours |
| 3 | 3 hours | 12 hours | 6 hours | 21 hours |
| 4 | 4 hours | 20 hours | 10 hours | 34 hours |

### Infrastructure

| Phase | Local Resources | Cloud Resources |
|-------|-----------------|-----------------|
| 1 | None (CI runs in GitHub) | GitHub Actions minutes |
| 2 | 10GB RAM, 100GB disk | None |
| 3 | Same as Phase 1 | Same as Phase 1 |
| 4 | 16GB RAM or cloud | Optional cloud instances |

## Getting Started

To begin implementation:

1. Review this roadmap with the RCD team
2. Prioritize phases based on upcoming demo needs
3. Create spec 005 for Phase 1 using `/speckit.specify`
4. Implement iteratively, demoing progress at each phase

## Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Time to first demo | < 2 weeks | Phase 1 complete |
| Demo setup time | < 10 minutes | `vagrant up` or container start |
| Dashboard freshness | < 1 hour | Auto-update on merge |
| Team adoption | 100% | All team members can run demo locally |
| Stakeholder feedback | Positive | Post-demo surveys |
