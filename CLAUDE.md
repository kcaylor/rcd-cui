# RCD-CUI Development Context

Guidelines for AI assistants working on this repository.

## Project Overview

RCD-CUI is an Ansible framework for NIST 800-171 CUI compliance in research computing environments. It targets RHEL 9/Rocky Linux 9 systems with FreeIPA, Slurm, and HPC infrastructure.

## Technology Stack

- **Ansible 2.15+**: Roles, playbooks, execution environments
- **Python 3.9+**: Filter plugins, reporting scripts, Pydantic validation
- **Jinja2**: Templates for documentation and configuration
- **Container Runtime**: Podman (preferred) or Docker for execution environments

## Project Structure

```
roles/           # Ansible roles (35+) organized by NIST control family
playbooks/       # Site playbooks, assessment, onboarding/offboarding
inventory/       # Hosts and group_vars by security zone
docs/            # Data models and generated documentation
scripts/         # Python tooling (doc generation, validation)
templates/       # Jinja2 templates for documentation
tests/           # Pytest and Molecule tests
specs/           # Feature specifications (historical)
```

## Role Naming Convention

Roles follow the pattern `{family}_{function}`:
- `ac_*` - Access Control
- `au_*` - Audit and Accountability
- `cm_*` - Configuration Management
- `ia_*` - Identification and Authentication
- `sc_*` - System and Communications Protection
- `si_*` - System and Information Integrity
- `hpc_*` - HPC-specific controls

## Role Structure

Each role follows a standard pattern:
```
roles/{role_name}/
├── tasks/
│   ├── main.yml      # Implementation tasks
│   ├── verify.yml    # Compliance verification
│   └── evidence.yml  # Evidence collection
├── defaults/main.yml # Default variables
├── vars/main.yml     # Role variables
├── templates/        # Jinja2 templates
├── handlers/main.yml # Service handlers
└── meta/main.yml     # Role metadata
```

## Key Commands

```bash
make env              # Create local Python environment
make ee-build         # Build Ansible Execution Environment
make ee-lint          # Lint roles in execution environment
make ee-syntax-check  # Syntax check playbooks
make test             # Run pytest
make docs             # Generate documentation
make assess           # Run compliance assessment
```

## Code Style

- **Ansible**: Follow ansible-lint rules, use FQCN for modules
- **Python**: PEP 8, type hints, docstrings
- **YAML**: 2-space indentation, explicit string quoting

## Testing

- **Molecule**: Role-level testing with delegated driver
- **Pytest**: Schema validation and integration tests
- Run `make ee-lint` before committing changes
