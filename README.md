# RCD CUI Compliance Automation

This repository contains data models and Ansible roles for NIST 800-171 CUI compliance in research computing environments.

## Environment Strategy

The project now uses two layers so tooling is consistent across local development, CI, and deployment pipelines:

- Local Python environment: `.venv` managed by `scripts/bootstrap-env.sh`.
- Ansible Execution Environment (container): built with `ansible-builder` from `execution-environment.yml`.

This gives repeatable installs and avoids host-to-host drift in tool versions.

## Prerequisites

- Python 3.9+
- One container runtime: `podman` (preferred) or `docker`
- `make`

## Setup

Create local tooling environment:

```bash
make env
source .venv/bin/activate
```

Build the reusable Ansible Execution Environment image:

```bash
make ee-build
```

Install required Ansible collections for local runs:

```bash
make collections
```

## Validation Commands

Run local tools from `.venv`:

```bash
make syntax-check
make lint-ansible
make lint-yaml
```

Run the same checks inside the execution environment image:

```bash
make ee-syntax-check
make ee-lint
make ee-yamllint
```

Open an interactive shell inside the execution environment:

```bash
make ee-shell
```

## Key Files

- `execution-environment.yml`: Ansible Builder definition (portable containerized toolchain)
- `requirements-ee.txt`: Python dependencies installed into the execution environment
- `bindep.txt`: System packages installed into the execution environment
- `requirements-dev.txt`: Local developer dependencies
- `scripts/bootstrap-env.sh`: Local bootstrap for `.venv`

## Existing Data/Docs Tooling

The original documentation/data-model workflow remains available:

- `make docs`
- `make validate`
- `make crosswalk`
- `make validate-schemas`
- `make test`

## Compliance Assessment and Reporting Workflow

The compliance assessment layer adds assessment orchestration, scoring, narrative generation, dashboards, and auditor package bundling:

- `make assess` runs `playbooks/assess.yml` in the execution environment and writes assessment JSON to `data/assessment_history/`
- `make evidence` runs `playbooks/ssp_evidence.yml` and creates evidence archives in `docs/auditor_packages/`
- `make sprs` generates markdown SPRS breakdown output under `reports/`
- `make poam` generates markdown and CSV POA&M status reports under `reports/`
- `make dashboard` generates the HTML dashboard at `reports/dashboard/index.html`
- `make report` runs `sprs`, `poam`, and `dashboard` together
- `make auditor-package` bundles crosswalk, narratives, evidence, SPRS, POA&M, HPC tailoring, and ODP artifacts
