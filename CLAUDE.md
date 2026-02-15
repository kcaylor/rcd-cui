# rcd-cui Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-14

## Active Technologies
- Python 3.9+ (filter plugins, reporting scripts), Ansible 2.15+ (playbooks) + Ansible, Jinja2, PyYAML, JSON (standard library), OpenSCAP CLI (003-compliance-assessment)
- JSON files (assessment results, historical data), YAML (POA&M data model) (003-compliance-assessment)
- Python 3.9+, Bash (POSIX-compliant for Slurm scripts) + Ansible 2.15+, Slurm 23.x+, Apptainer 1.2+, FreeIPA client, Lustre/BeeGFS client tools (004-hpc-cui-roles)
- Lustre or BeeGFS parallel filesystem, local /tmp and /dev/shm for job scratch (004-hpc-cui-roles)

- Python 3.9+ (per constitution tech stack) (001-data-models-docs-foundation)

## Project Structure

```text
src/
tests/
```

## Commands

cd src [ONLY COMMANDS FOR ACTIVE TECHNOLOGIES][ONLY COMMANDS FOR ACTIVE TECHNOLOGIES] pytest [ONLY COMMANDS FOR ACTIVE TECHNOLOGIES][ONLY COMMANDS FOR ACTIVE TECHNOLOGIES] ruff check .

## Code Style

Python 3.9+ (per constitution tech stack): Follow standard conventions

## Recent Changes
- 004-hpc-cui-roles: Added Python 3.9+, Bash (POSIX-compliant for Slurm scripts) + Ansible 2.15+, Slurm 23.x+, Apptainer 1.2+, FreeIPA client, Lustre/BeeGFS client tools
- 003-compliance-assessment: Added Python 3.9+ (filter plugins, reporting scripts), Ansible 2.15+ (playbooks) + Ansible, Jinja2, PyYAML, JSON (standard library), OpenSCAP CLI

- 001-data-models-docs-foundation: Added Python 3.9+ (per constitution tech stack)

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
