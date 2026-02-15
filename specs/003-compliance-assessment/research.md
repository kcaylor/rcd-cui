# Research: Compliance Assessment and Reporting Layer

**Branch**: `003-compliance-assessment` | **Date**: 2026-02-14

## Key Technology Decisions

### 1. SPRS Score Calculation Methodology

**Decision**: Implement DoD DFARS 252.204-7020 SPRS scoring as Ansible filter plugin

**Rationale**:
- SPRS score range: 110 (full compliance) to -203 (no compliance)
- Each of 110 NIST 800-171 controls has a DoD-assigned weight (1, 3, or 5 points)
- Score = 110 - sum(weights of unimplemented controls)
- Filter plugin enables inline calculation in playbooks: `{{ assessment_results | sprs_score }}`
- Python implementation allows unit testing with known test vectors

**Alternatives Considered**:
- External scoring service: Rejected - adds dependency, not offline-capable
- Shell script: Rejected - harder to test, less maintainable
- Ansible module: Rejected - filter plugin is simpler for data transformation

**Implementation Notes**:
- Store control weights in `data/sprs_weights.yml` (source of truth)
- Binary pass/fail per clarification: control passes only if ALL applicable systems pass
- POA&M credit: Per DoD guidance, documented POA&M items reduce deduction by 50%

### 2. Assessment Result Data Format

**Decision**: JSON with standardized schema for assessment results

**Rationale**:
- Machine-readable for downstream processing (SPRS calc, dashboard, reports)
- Human-inspectable for debugging
- Supports historical storage and trend analysis
- Native Ansible support via `to_json` filter

**Schema**:
```json
{
  "assessment_id": "uuid",
  "timestamp": "ISO-8601",
  "enclave_name": "string",
  "coverage": {
    "total_systems": int,
    "assessed_systems": int,
    "not_assessed": [{"hostname": "string", "reason": "string"}]
  },
  "controls": [
    {
      "control_id": "3.1.1",
      "title": "string",
      "status": "pass|fail|not_assessed",
      "systems": [
        {
          "hostname": "string",
          "zone": "string",
          "status": "pass|fail|error",
          "verification_output": "string",
          "evidence_files": ["path"]
        }
      ]
    }
  ],
  "openscap_results": {
    "profile": "cui",
    "pass_count": int,
    "fail_count": int,
    "report_path": "string"
  },
  "sprs_score": int,
  "sprs_breakdown": {}
}
```

**Alternatives Considered**:
- YAML: Rejected - more verbose, less common for API-style data
- XML: Rejected - harder to process, no benefit over JSON
- SQLite: Rejected - overkill for file-based storage, adds dependency

### 3. Secret Redaction Strategy

**Decision**: Regex-based pattern matching with value replacement

**Rationale**:
- Preserves configuration structure for auditor review
- Auditors can verify settings exist without seeing actual secrets
- Deterministic and testable
- Follows industry standard approach (similar to git-secrets, gitleaks)

**Patterns to Detect**:
```python
REDACTION_PATTERNS = [
    # Passwords in config files
    r'(?i)(password|passwd|secret|token|key|credential)\s*[=:]\s*["\']?([^"\'\s]+)',
    # Private keys
    r'-----BEGIN[A-Z ]+PRIVATE KEY-----[\s\S]*?-----END[A-Z ]+PRIVATE KEY-----',
    # API keys (common formats)
    r'(?i)(api[_-]?key|apikey)\s*[=:]\s*["\']?([A-Za-z0-9_-]{20,})',
    # AWS-style keys
    r'(?:AKIA|ABIA|ACCA|ASIA)[A-Z0-9]{16}',
    # Duo integration keys
    r'(ikey|skey)\s*=\s*[A-Za-z0-9]{20,}',
]
```

**Replacement**: `[REDACTED]` preserving key/setting name

**Alternatives Considered**:
- Remove entire lines: Rejected - loses context about what settings exist
- Separate archives: Rejected - complexity, access control overhead
- Manual review: Rejected - doesn't scale, error-prone

### 4. Dashboard Technology Stack

**Decision**: Static HTML generation with embedded CSS/JS (no external CDN)

**Rationale**:
- Offline-capable per constraint (no internet required to view)
- No runtime dependencies (works on any machine with browser)
- Jinja2 templates consistent with existing project patterns
- Single-file dashboards for easy distribution

**Components**:
- **Charting**: Chart.js (embedded, MIT license) - gauge charts, line charts for trends
- **Styling**: Minimal custom CSS (no framework) - ~500 lines
- **Interactivity**: Vanilla JavaScript - tab switching, drill-down, filtering

**Audience Views**:
| View | Focus | Key Elements |
|------|-------|--------------|
| Leadership | Summary | SPRS gauge (0-110), compliance %, family status (red/yellow/green) |
| CISO | Detail | Family breakdown, control list, remediation priorities |
| Auditor | Evidence | Control narratives, evidence file links, verification output |

**Alternatives Considered**:
- React/Vue SPA: Rejected - build complexity, offline challenges
- Server-rendered: Rejected - requires runtime, not portable
- PDF reports: Rejected - not interactive, harder to update

### 5. POA&M Data Model

**Decision**: YAML file with structured schema

**Rationale**:
- Human-editable (PMs can update without special tools)
- Version-controlled like other data models
- Validates with existing YAML schema testing infrastructure
- Generates both Markdown and CSV reports

**Schema**:
```yaml
poam_items:
  - id: "POAM-001"
    control_id: "3.5.3"
    control_title: "Multi-factor authentication"
    weakness:
      description: "MFA not yet deployed to compute nodes"
      plain_language: "Users can log into compute nodes with just a password, making it easier for attackers who steal passwords to access systems"
    risk_level: "high"  # high, moderate, low
    milestones:
      - description: "Deploy Duo agent to compute nodes"
        target_date: "2026-03-15"
        status: "in_progress"  # open, in_progress, completed, delayed
      - description: "Configure SSH certificate bypass for batch jobs"
        target_date: "2026-03-30"
        status: "open"
    resources:
      - name: "System Administrator"
        allocation: "20 hours"
      - name: "Security Engineer"
        allocation: "10 hours"
    created_date: "2026-02-01"
    last_updated: "2026-02-14"
```

**Alternatives Considered**:
- Database: Rejected - overkill, less portable
- Spreadsheet: Rejected - harder to version control
- GRC platform: Rejected - out of scope per spec

### 6. Evidence Archive Format

**Decision**: Timestamped directory structure with tar.gz packaging

**Rationale**:
- Consistent organization matching CMMC assessment guide sections
- Compression keeps archives under 100MB constraint
- Preserves file metadata (permissions, timestamps)
- Standard format that any system can extract

**Structure**:
```text
evidence-2026-02-14T10-30-00/
├── inventory/
│   ├── system_inventory.json
│   └── zone_assignments.json
├── by_family/
│   ├── AC/  # Access Control
│   │   ├── AC-2_user_accounts.txt
│   │   ├── AC-3_permissions.txt
│   │   └── ...
│   ├── AU/  # Audit
│   ├── CM/  # Configuration Management
│   ├── IA/  # Identification & Authentication
│   ├── SC/  # System & Communications Protection
│   └── SI/  # System & Information Integrity
├── by_system/
│   ├── login01/
│   │   ├── packages.txt
│   │   ├── services.txt
│   │   ├── sshd_config.txt
│   │   └── ...
│   └── compute001/
├── openscap/
│   ├── results.xml
│   └── report.html
├── narratives/
│   ├── control_3.1.1.md
│   ├── control_3.1.2.md
│   └── ...
└── metadata.json  # Collection timestamp, tool versions, coverage
```

**Alternatives Considered**:
- ZIP: Acceptable but tar.gz is more Unix-native
- Uncompressed: Rejected - may exceed size constraints
- Database dump: Rejected - requires tooling to inspect

### 7. Ansible Filter Plugin Architecture

**Decision**: Single filter plugin file with multiple filter functions

**Rationale**:
- Ansible filter plugins are simple Python modules
- Multiple related filters in one file (sprs_score, sprs_breakdown, control_weight)
- Unit testable outside of Ansible
- Follows Ansible best practices

**Filter Functions**:
```python
def sprs_score(assessment_results, poam_data=None):
    """Calculate SPRS score from assessment results."""

def sprs_breakdown(assessment_results, poam_data=None):
    """Return detailed breakdown by family with deductions."""

def control_weight(control_id):
    """Return DoD weight for a specific control."""

def format_deduction(control_id, weight):
    """Return plain-language explanation of deduction."""

class FilterModule:
    def filters(self):
        return {
            'sprs_score': sprs_score,
            'sprs_breakdown': sprs_breakdown,
            'control_weight': control_weight,
            'format_deduction': format_deduction,
        }
```

**Alternatives Considered**:
- Ansible module: Rejected - modules are for actions, not data transformation
- Callback plugin: Rejected - for event handling, not filtering
- External script: Rejected - less integrated with playbooks

## Dependencies

### From Spec 001 (Data Models)
- `roles/common/vars/control_mapping.yml` - Control definitions and mappings
- `docs/glossary/terms.yml` - Glossary for plain-language validation
- `docs/hpc_tailoring.yml` - HPC tailoring decisions
- `docs/odp_values.yml` - Organization-defined parameters

### From Spec 002 (Ansible Roles)
- 31 roles with `tasks/verify.yml` - Verification tasks to orchestrate
- 31 roles with `tasks/evidence.yml` - Evidence collection tasks
- `cm_openscap_baseline` role - OpenSCAP integration
- Zone-aware variable structure in `group_vars/`

### External
- OpenSCAP CLI (`oscap`) - CUI profile scanning
- Python 3.9+ - Scripts and filter plugins
- Chart.js 4.x (embedded) - Dashboard visualizations

## Open Questions Resolved

| Question | Resolution | Source |
|----------|------------|--------|
| Partial control scoring | Binary pass/fail - all systems must pass | Clarification session |
| Offline system handling | Continue, mark as "not assessed" | Clarification session |
| Secret redaction method | Pattern-based with "[REDACTED]" | Clarification session |
| Historical data storage | JSON files in `data/assessment_history/` | Spec assumption |
| Dashboard hosting | Static HTML, local viewing | Spec constraint |
