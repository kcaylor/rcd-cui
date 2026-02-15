# Data Model: Compliance Assessment and Reporting Layer

**Branch**: `003-compliance-assessment` | **Date**: 2026-02-14

## Entity Overview

```text
┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ AssessmentRun   │──────│ ControlResult   │──────│ SystemResult    │
│                 │ 1:N  │                 │ 1:N  │                 │
└─────────────────┘      └─────────────────┘      └─────────────────┘
        │                        │
        │                        │
        ▼                        ▼
┌─────────────────┐      ┌─────────────────┐
│ SPRSScore       │      │ EvidenceArtifact│
│                 │      │                 │
└─────────────────┘      └─────────────────┘

┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ POAMItem        │──────│ Milestone       │      │ ControlWeight   │
│                 │ 1:N  │                 │      │ (reference)     │
└─────────────────┘      └─────────────────┘      └─────────────────┘

┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│ AuditorPackage  │──────│ ControlNarrative│      │ DashboardView   │
│                 │ 1:N  │                 │      │ (generated)     │
└─────────────────┘      └─────────────────┘      └─────────────────┘
```

## Entity Definitions

### AssessmentRun

Primary record of a compliance assessment execution.

```yaml
AssessmentRun:
  assessment_id: string          # UUID, auto-generated
  timestamp: datetime            # ISO-8601, assessment start time
  enclave_name: string           # e.g., "research-enclave-prod"
  assessment_mode: enum          # "full" | "verify_only" | "evidence_only"
  coverage:
    total_systems: integer       # Systems in inventory
    assessed_systems: integer    # Successfully assessed
    not_assessed: list           # Systems not reached
      - hostname: string
        reason: string           # "unreachable" | "timeout" | "auth_failure"
        timestamp: datetime
  controls: list[ControlResult]  # Results per control
  openscap_results:
    profile: string              # "cui" | "stig" | "cis"
    pass_count: integer
    fail_count: integer
    notapplicable_count: integer
    report_path: string          # Path to HTML report
  sprs_score: integer            # Calculated score (-203 to 110)
  sprs_breakdown: SPRSScore      # Detailed breakdown
  metadata:
    tool_versions:
      ansible: string
      openscap: string
      python: string
    run_duration_seconds: integer
    initiated_by: string         # User or "scheduled"
```

### ControlResult

Assessment result for a single NIST 800-171 control.

```yaml
ControlResult:
  control_id: string             # e.g., "3.1.1", "3.5.3"
  control_title: string          # Plain-language title
  family: string                 # "AC" | "AU" | "CM" | "IA" | "SC" | "SI"
  status: enum                   # "pass" | "fail" | "not_assessed" | "not_applicable"
  status_reason: string          # Plain-language explanation if fail/not_assessed
  applicable_systems: integer    # Systems where control applies
  passing_systems: integer       # Systems that pass
  systems: list[SystemResult]    # Per-system results
  evidence_files: list[string]   # Paths to collected evidence
  verification_commands: list    # Commands executed for verification
    - command: string
      expected: string
      actual: string
```

### SystemResult

Assessment result for a control on a specific system.

```yaml
SystemResult:
  hostname: string               # FQDN
  zone: string                   # "management" | "internal" | "restricted" | "public"
  status: enum                   # "pass" | "fail" | "error" | "not_assessed"
  verification_output: string    # Raw output from verify.yml
  error_message: string          # If status is "error"
  evidence_files: list[string]   # System-specific evidence paths
  timestamp: datetime            # When this system was assessed
```

### SPRSScore

SPRS score calculation breakdown.

```yaml
SPRSScore:
  total_score: integer           # Final SPRS score (-203 to 110)
  baseline_score: integer        # 110 (maximum possible)
  total_deductions: integer      # Sum of all deductions
  by_family:                     # Breakdown per control family
    AC:
      controls_total: integer
      controls_passing: integer
      controls_failing: integer
      deduction_points: integer
    AU: ...
    CM: ...
    IA: ...
    SC: ...
    SI: ...
  deductions: list               # Individual control deductions
    - control_id: string
      control_title: string
      weight: integer            # 1, 3, or 5
      plain_language: string     # "MFA not enforced for remote access"
      poam_credit: boolean       # If POA&M reduces deduction
      effective_deduction: integer  # Actual points deducted (may be reduced by POA&M)
  poam_adjustments:
    items_with_credit: integer   # POA&M items reducing deductions
    total_credit: integer        # Points saved via POA&M
  recommendations: list          # Prioritized remediation
    - control_id: string
      control_title: string
      weight: integer
      effort_estimate: string    # "low" | "medium" | "high"
      impact_description: string # "Implementing this control adds X points"
```

### EvidenceArtifact

Individual evidence file collected during assessment.

```yaml
EvidenceArtifact:
  artifact_id: string            # UUID
  artifact_type: enum            # "config_file" | "command_output" | "log_snippet" | "openscap_report"
  source_system: string          # Hostname where collected
  source_path: string            # Original path on system
  local_path: string             # Path in evidence archive
  control_ids: list[string]      # Controls this evidence supports
  collection_timestamp: datetime
  file_size_bytes: integer
  checksum_sha256: string        # Integrity verification
  redacted: boolean              # Whether secrets were redacted
  redaction_count: integer       # Number of redactions applied
```

### POAMItem

Plan of Action and Milestones tracking record.

```yaml
POAMItem:
  id: string                     # "POAM-001", unique identifier
  control_id: string             # NIST 800-171 control ID
  control_title: string          # Control title for reference
  weakness:
    description: string          # Technical description
    plain_language: string       # PM-friendly explanation (required)
    root_cause: string           # Why the gap exists (optional)
  risk_level: enum               # "high" | "moderate" | "low"
  risk_justification: string     # Why this risk level
  milestones: list[Milestone]    # Remediation steps
  resources: list                # Assigned resources
    - name: string               # Role or person
      allocation: string         # Time estimate
  status: enum                   # "open" | "in_progress" | "completed" | "delayed" | "cancelled"
  days_overdue: integer          # Calculated, null if not overdue
  created_date: date
  last_updated: date
  completion_date: date          # Null until completed
  sprs_credit: boolean           # Whether this item provides SPRS credit
```

### Milestone

Individual milestone within a POA&M item.

```yaml
Milestone:
  id: string                     # Sequential within POA&M item
  description: string            # What needs to be done
  target_date: date
  actual_completion_date: date   # Null until completed
  status: enum                   # "open" | "in_progress" | "completed" | "delayed"
  notes: string                  # Progress notes
  blocker: string                # If delayed, what's blocking
```

### ControlWeight

Reference data for SPRS scoring (from DoD methodology).

```yaml
ControlWeight:
  control_id: string             # "3.1.1"
  weight: integer                # 1, 3, or 5
  family: string                 # "AC"
  rationale: string              # Why this weight (from DoD guidance)
```

### ControlNarrative

Generated SSP narrative for a control.

```yaml
ControlNarrative:
  control_id: string
  control_title: string
  narrative_text: string         # Plain-language paragraph
  implementation_status: enum    # "implemented" | "partially_implemented" | "planned" | "not_applicable"
  evidence_references: list      # Files that prove implementation
    - file_path: string
      description: string        # What this file shows
  responsible_role: string       # Who maintains this control
  generated_timestamp: datetime
  glossary_validated: boolean    # Passed validate_glossary.py
```

### AuditorPackage

Bundle of compliance documentation for C3PAO assessment.

```yaml
AuditorPackage:
  package_id: string             # UUID
  generation_timestamp: datetime
  enclave_name: string
  cmmc_level: string             # "Level 2"
  contents:
    crosswalk_csv: string        # Path to crosswalk file
    narratives_dir: string       # Path to narrative markdown files
    evidence_archive: string     # Path to evidence tar.gz
    sprs_report: string          # Path to SPRS breakdown
    poam_report: string          # Path to POA&M report
    hpc_tailoring: string        # Path to HPC tailoring documentation
    odp_values: string           # Path to ODP values
  coverage:
    total_controls: integer      # 110 for 800-171
    implemented_controls: integer
    planned_controls: integer    # With POA&M
    not_applicable_controls: integer
  metadata:
    organization_name: string
    assessment_date: date
    prepared_by: string
```

## Data File Locations

| Entity | Storage Location | Format |
|--------|------------------|--------|
| AssessmentRun | `data/assessment_history/YYYY-MM-DD.json` | JSON |
| ControlWeight | `data/sprs_weights.yml` | YAML |
| POAMItem | `data/poam.yml` | YAML |
| ControlNarrative | `docs/generated/narratives/` | Markdown |
| AuditorPackage | `docs/auditor_packages/YYYY-MM-DD/` | Directory |
| EvidenceArtifact | `docs/auditor_packages/YYYY-MM-DD/evidence/` | Various |

## Validation Rules

### AssessmentRun
- `assessment_id` must be valid UUID
- `timestamp` must be valid ISO-8601
- `coverage.assessed_systems` + `coverage.not_assessed.length` must equal `coverage.total_systems`
- `sprs_score` must be in range [-203, 110]

### ControlResult
- `control_id` must exist in `control_mapping.yml`
- `passing_systems` must be <= `applicable_systems`
- `status` must be "fail" if `passing_systems` < `applicable_systems`

### POAMItem
- `control_id` must exist in `control_mapping.yml`
- `weakness.plain_language` must pass `validate_glossary.py`
- At least one milestone required
- `days_overdue` calculated from earliest overdue milestone

### ControlNarrative
- `narrative_text` must pass `validate_glossary.py`
- `evidence_references` paths must exist in evidence archive

## State Transitions

### POAMItem.status
```text
open ─────► in_progress ─────► completed
  │              │
  │              ▼
  └─────────► delayed ────────► cancelled
                 │
                 ▼
              in_progress (if unblocked)
```

### ControlResult.status
```text
not_assessed ─► pass (all systems pass)
             ─► fail (any system fails)
             ─► not_applicable (control doesn't apply to zone)
```
