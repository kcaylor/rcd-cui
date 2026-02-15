# Contracts: Compliance Assessment and Reporting Layer

**Branch**: `003-compliance-assessment` | **Date**: 2026-02-14

## Overview

This specification does not expose external APIs. Instead, it defines data contracts between internal components:

1. **Assessment Output Contract** - JSON schema for assessment results
2. **SPRS Filter Contract** - Filter plugin input/output specification
3. **POA&M Data Contract** - YAML schema for POA&M tracking
4. **Evidence Archive Contract** - Directory structure specification
5. **Makefile Target Contract** - Command-line interface specification

## 1. Assessment Output Contract

**Producer**: `playbooks/assess.yml`
**Consumers**: SPRS filter, dashboard generator, auditor package generator

### Schema (JSON)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "AssessmentResult",
  "type": "object",
  "required": ["assessment_id", "timestamp", "enclave_name", "coverage", "controls", "sprs_score"],
  "properties": {
    "assessment_id": {
      "type": "string",
      "pattern": "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
    },
    "timestamp": {
      "type": "string",
      "format": "date-time"
    },
    "enclave_name": {
      "type": "string",
      "minLength": 1
    },
    "coverage": {
      "type": "object",
      "required": ["total_systems", "assessed_systems"],
      "properties": {
        "total_systems": { "type": "integer", "minimum": 0 },
        "assessed_systems": { "type": "integer", "minimum": 0 },
        "not_assessed": {
          "type": "array",
          "items": {
            "type": "object",
            "required": ["hostname", "reason"],
            "properties": {
              "hostname": { "type": "string" },
              "reason": { "type": "string" },
              "timestamp": { "type": "string", "format": "date-time" }
            }
          }
        }
      }
    },
    "controls": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["control_id", "status"],
        "properties": {
          "control_id": { "type": "string", "pattern": "^3\\.[0-9]+\\.[0-9]+$" },
          "control_title": { "type": "string" },
          "family": { "type": "string", "enum": ["AC", "AU", "CM", "IA", "SC", "SI"] },
          "status": { "type": "string", "enum": ["pass", "fail", "not_assessed", "not_applicable"] },
          "status_reason": { "type": "string" },
          "systems": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["hostname", "status"],
              "properties": {
                "hostname": { "type": "string" },
                "zone": { "type": "string" },
                "status": { "type": "string", "enum": ["pass", "fail", "error", "not_assessed"] },
                "verification_output": { "type": "string" },
                "evidence_files": { "type": "array", "items": { "type": "string" } }
              }
            }
          }
        }
      }
    },
    "openscap_results": {
      "type": "object",
      "properties": {
        "profile": { "type": "string" },
        "pass_count": { "type": "integer" },
        "fail_count": { "type": "integer" },
        "report_path": { "type": "string" }
      }
    },
    "sprs_score": {
      "type": "integer",
      "minimum": -203,
      "maximum": 110
    }
  }
}
```

## 2. SPRS Filter Contract

**Location**: `plugins/filter/sprs.py`

### Input Contract

```python
# sprs_score filter
assessment_results: dict  # AssessmentResult JSON structure
poam_data: dict = None    # Optional POA&M data for credit calculation

# Returns: int (-203 to 110)
```

```python
# sprs_breakdown filter
assessment_results: dict
poam_data: dict = None

# Returns: dict with structure:
{
    "total_score": int,
    "baseline_score": 110,
    "total_deductions": int,
    "by_family": {
        "AC": {"controls_total": int, "controls_passing": int, "deduction_points": int},
        # ... other families
    },
    "deductions": [
        {
            "control_id": str,
            "control_title": str,
            "weight": int,
            "plain_language": str,
            "poam_credit": bool,
            "effective_deduction": int
        }
    ],
    "recommendations": [
        {
            "control_id": str,
            "weight": int,
            "effort_estimate": str,
            "impact_description": str
        }
    ]
}
```

### Ansible Usage

```yaml
- name: Calculate SPRS score
  set_fact:
    sprs_result: "{{ assessment_results | sprs_score(poam_data) }}"

- name: Get detailed breakdown
  set_fact:
    sprs_details: "{{ assessment_results | sprs_breakdown(poam_data) }}"
```

## 3. POA&M Data Contract

**Location**: `data/poam.yml`

### Schema (YAML)

```yaml
# JSON Schema representation for YAML validation
$schema: "http://json-schema.org/draft-07/schema#"
title: POAMData
type: object
required:
  - poam_items
properties:
  poam_items:
    type: array
    items:
      type: object
      required:
        - id
        - control_id
        - weakness
        - risk_level
        - milestones
        - status
      properties:
        id:
          type: string
          pattern: "^POAM-[0-9]{3}$"
        control_id:
          type: string
          pattern: "^3\\.[0-9]+\\.[0-9]+$"
        control_title:
          type: string
        weakness:
          type: object
          required:
            - description
            - plain_language
          properties:
            description:
              type: string
            plain_language:
              type: string
              minLength: 20
            root_cause:
              type: string
        risk_level:
          type: string
          enum: ["high", "moderate", "low"]
        milestones:
          type: array
          minItems: 1
          items:
            type: object
            required:
              - description
              - target_date
              - status
            properties:
              description:
                type: string
              target_date:
                type: string
                format: date
              status:
                type: string
                enum: ["open", "in_progress", "completed", "delayed"]
        resources:
          type: array
          items:
            type: object
            properties:
              name:
                type: string
              allocation:
                type: string
        status:
          type: string
          enum: ["open", "in_progress", "completed", "delayed", "cancelled"]
        created_date:
          type: string
          format: date
        last_updated:
          type: string
          format: date
```

## 4. Evidence Archive Contract

**Location**: `docs/auditor_packages/YYYY-MM-DD/evidence/`

### Directory Structure

```text
evidence-YYYY-MM-DDTHH-MM-SS/
├── metadata.json              # REQUIRED: Collection metadata
├── inventory/                 # REQUIRED: System inventory
│   ├── system_inventory.json
│   └── zone_assignments.json
├── by_family/                 # REQUIRED: Evidence by control family
│   ├── AC/
│   │   ├── AC-2_*.txt
│   │   └── AC-3_*.txt
│   ├── AU/
│   ├── CM/
│   ├── IA/
│   ├── SC/
│   └── SI/
├── by_system/                 # REQUIRED: Evidence by system
│   └── {hostname}/
│       ├── packages.txt
│       ├── services.txt
│       ├── sshd_config.txt
│       ├── pam_config.txt
│       ├── selinux_status.txt
│       ├── fips_status.txt
│       └── ...
├── openscap/                  # REQUIRED: OpenSCAP results
│   ├── results.xml
│   └── report.html
└── narratives/                # REQUIRED: Control narratives
    └── control_{id}.md
```

### metadata.json Schema

```json
{
  "collection_timestamp": "2026-02-14T10:30:00Z",
  "enclave_name": "research-enclave-prod",
  "systems_collected": 50,
  "tool_versions": {
    "ansible": "2.15.0",
    "openscap": "1.3.7",
    "python": "3.9.18"
  },
  "redaction_applied": true,
  "redaction_patterns_used": 5,
  "total_files": 450,
  "total_size_bytes": 52428800,
  "checksum_manifest": "checksums.sha256"
}
```

## 5. Makefile Target Contract

**Location**: `Makefile` (additions)

### Target Specifications

| Target | Description | Input | Output |
|--------|-------------|-------|--------|
| `assess` | Run full compliance assessment | Inventory, credentials | `data/assessment_history/YYYY-MM-DD.json` |
| `evidence` | Collect SSP evidence | Inventory, credentials | `docs/auditor_packages/YYYY-MM-DD/evidence/` |
| `sprs` | Calculate and display SPRS score | Assessment JSON | STDOUT + `reports/sprs_YYYY-MM-DD.md` |
| `poam` | Generate POA&M reports | `data/poam.yml` | `reports/poam.md`, `reports/poam.csv` |
| `dashboard` | Generate compliance dashboard | Assessment JSON | `reports/dashboard/index.html` |
| `report` | Generate all reports | All data sources | `reports/` directory |
| `auditor-package` | Bundle auditor package | All data sources | `docs/auditor_packages/YYYY-MM-DD.tar.gz` |

### Target Dependencies

```makefile
assess: ee-build
	$(EE_RUN) ansible-playbook playbooks/assess.yml -i inventory/hosts.yml

evidence: assess
	$(EE_RUN) ansible-playbook playbooks/ssp_evidence.yml -i inventory/hosts.yml

sprs: assess
	$(PYTHON) scripts/generate_sprs_report.py --input data/assessment_history/latest.json

poam:
	$(PYTHON) scripts/generate_poam_report.py --input data/poam.yml --output-dir reports/

dashboard: assess sprs poam
	$(PYTHON) scripts/generate_dashboard.py --output-dir reports/dashboard/

report: sprs poam dashboard

auditor-package: evidence report
	$(PYTHON) scripts/generate_auditor_package.py --output-dir docs/auditor_packages/
```

## Contract Versioning

All contracts follow semantic versioning. Breaking changes require major version bump.

| Contract | Current Version | Last Updated |
|----------|-----------------|--------------|
| Assessment Output | 1.0.0 | 2026-02-14 |
| SPRS Filter | 1.0.0 | 2026-02-14 |
| POA&M Data | 1.0.0 | 2026-02-14 |
| Evidence Archive | 1.0.0 | 2026-02-14 |
| Makefile Targets | 1.0.0 | 2026-02-14 |
