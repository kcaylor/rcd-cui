# API Contracts

**Feature**: 001-data-models-docs-foundation

## Not Applicable

This feature does not expose any APIs or service endpoints. It consists of:

1. **YAML Data Models**: Static data files (`control_mapping.yml`, `terms.yml`, `hpc_tailoring.yml`, `odp_values.yml`)
2. **Python Scripts**: Command-line tools (`generate_docs.py`, `validate_glossary.py`)
3. **Makefile Targets**: Build automation (`make docs`, `make validate`, `make crosswalk`)

The "contracts" for this feature are:

- **Data Model Schemas**: Defined in [../data-model.md](../data-model.md) using Pydantic models
- **Script Interfaces**: Command-line interfaces with exit codes (0 = success, non-zero = failure)
- **Generated Outputs**: 7 documentation files (Markdown + CSV) with deterministic content

Future specs that implement Ansible roles or web services will use this directory for API specifications (OpenAPI, GraphQL schemas, etc.).

## Script Interfaces

### `scripts/generate_docs.py`

**Purpose**: Generate all 7 audience-specific documentation outputs from YAML data models.

**Interface**:
```bash
python scripts/generate_docs.py [--output-dir docs/generated] [--validate-only]

Options:
  --output-dir DIR    Output directory for generated docs (default: docs/generated)
  --validate-only     Validate YAML schemas without generating docs

Exit Codes:
  0   Success - all docs generated
  1   Validation error - YAML schema invalid
  2   Missing required YAML files
```

**Inputs** (YAML files):
- `roles/common/vars/control_mapping.yml`
- `docs/glossary/terms.yml`
- `docs/hpc_tailoring.yml`
- `docs/odp_values.yml`

**Outputs** (generated files):
- `docs/generated/pi_guide.md`
- `docs/generated/researcher_quickstart.md`
- `docs/generated/sysadmin_reference.md`
- `docs/generated/ciso_compliance_map.md`
- `docs/generated/leadership_briefing.md`
- `docs/generated/glossary_full.md`
- `docs/generated/crosswalk.csv`

### `scripts/validate_glossary.py`

**Purpose**: Scan all project files for undefined acronyms and technical terms.

**Interface**:
```bash
python scripts/validate_glossary.py [--glossary docs/glossary/terms.yml] [--scan-dirs docs/ roles/]

Options:
  --glossary FILE       Path to glossary YAML file (default: docs/glossary/terms.yml)
  --scan-dirs DIRS      Directories to scan (default: docs/ roles/ specs/)
  --file-types EXTS     File extensions to scan (default: .md .yml .j2)

Exit Codes:
  0   Success - all terms defined
  1   Undefined terms found
  2   Glossary file not found or invalid
```

**Inputs**:
- `docs/glossary/terms.yml`
- All `.md`, `.yml`, `.j2` files in scanned directories

**Outputs** (STDERR for violations):
```
ERROR: Undefined terms found:

  File: docs/generated/pi_guide.md
    - XYZ (line 42)
    - ABC (line 87)

  File: roles/access_control/README.md
    - FOO (line 15)

3 undefined terms. Please add to docs/glossary/terms.yml
```

## Makefile Targets

### `make docs`
Runs `generate_docs.py` to produce all 7 documentation outputs.

### `make validate`
Runs `validate_glossary.py` to check for undefined terms.

### `make crosswalk`
Generates only the crosswalk CSV file (subset of `make docs`).

### `make clean`
Removes all generated documentation files from `docs/generated/`.

---

**Note**: Future specs that implement web services or APIs will add OpenAPI/GraphQL schemas to this directory.
