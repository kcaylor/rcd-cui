# Implementation Plan: Cloud Demo Infrastructure

**Branch**: `007-cloud-demo-infra` | **Date**: 2026-02-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/007-cloud-demo-infra/spec.md`

## Summary

On-demand cloud demo infrastructure using Terraform to provision a 4-node cluster on Hetzner Cloud, replacing local Vagrant for reliable demo experience. Reuses existing demo playbooks and roles from spec 006 unchanged - only the VM provisioning layer changes.

## Technical Context

**Language/Version**: Bash (wrapper scripts), HCL (Terraform 1.5+), Python 3.9+ (inventory generation)
**Primary Dependencies**: Terraform (Hetzner provider), Ansible 2.15+, existing demo/playbooks/*
**Storage**: Terraform state (local file, optional Terraform Cloud remote)
**Testing**: Manual validation via spin-up/teardown cycle, Ansible --check mode
**Target Platform**: macOS/Linux CLI, Hetzner Cloud US West (Hillsboro)
**Project Type**: Infrastructure-as-code, CLI tooling
**Performance Goals**: Cluster spin-up < 25 minutes, teardown < 5 minutes
**Constraints**: Single cluster at a time, TTL warning (not auto-teardown), ~€0.03/hour cost
**Scale/Scope**: 4 VMs (mgmt01, login01, compute01, compute02), single user/team usage

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Evidence |
|-----------|--------|----------|
| I. Plain Language First | PASS | Cost warnings, setup instructions, and troubleshooting guidance required (FR-017, FR-018, FR-019) |
| II. Data Model as Source of Truth | PASS | Reuses existing YAML-based control mappings from spec 006; Terraform outputs generate inventory |
| III. Compliance as Code | PASS | Reuses existing Ansible roles with control tags unchanged |
| IV. HPC-Aware | PASS | Demo environment mirrors HPC topology (mgmt, login, compute nodes); no new HPC conflicts introduced |
| V. Multi-Framework | PASS | No new compliance mapping needed - inherits from spec 006 roles |
| VI. Audience-Aware Documentation | PASS | Quickstart for operators, cost docs for budget owners, troubleshooting for all |
| VII. Idempotent and Auditable | PASS | Terraform is idempotent; existing Ansible roles already comply |
| VIII. Prefer Established Tools | PASS | Terraform (industry standard IaC), Hetzner Cloud (established provider), existing tooling reused |

**Gate Status**: PASS - No violations. Proceed to Phase 0.

## Project Structure

### Documentation (this feature)

```text
specs/007-cloud-demo-infra/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal contracts for infra)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
infra/
├── terraform/
│   ├── main.tf           # Provider config, SSH key, network
│   ├── nodes.tf          # VM definitions (mgmt01, login01, compute01, compute02)
│   ├── outputs.tf        # IPs, SSH commands, inventory path
│   ├── variables.tf      # Region, sizes, TTL, SSH key path
│   └── inventory.tpl     # Ansible inventory template
├── scripts/
│   ├── demo-cloud-up.sh  # Spin-up wrapper (terraform + ansible)
│   └── demo-cloud-down.sh # Teardown wrapper (terraform destroy)
└── README.md             # Setup, credentials, cost warnings

Makefile                  # Root Makefile with demo-cloud-up/down targets
```

**Structure Decision**: Infrastructure-as-code layout with Terraform configs in `infra/terraform/`, wrapper scripts in `infra/scripts/`, and Make targets at root for discoverability. Existing `demo/` directory from spec 006 remains unchanged.

## Complexity Tracking

No complexity violations detected. All components use established tooling (Terraform, Ansible, Bash).
