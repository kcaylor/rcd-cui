PYTHON ?= python3
VENV ?= .venv
ANSIBLE_BUILDER ?= $(VENV)/bin/ansible-builder
ANSIBLE_PLAYBOOK ?= $(VENV)/bin/ansible-playbook
ANSIBLE_LINT ?= $(VENV)/bin/ansible-lint
YAMLLINT ?= $(VENV)/bin/yamllint
ANSIBLE_GALAXY ?= $(VENV)/bin/ansible-galaxy
CONTAINER_RUNTIME ?= $(shell command -v podman >/dev/null 2>&1 && echo podman || echo docker)
EE_IMAGE ?= rcd-cui-ee:latest
PROJECT_DIR := $(shell pwd)
EE_RUN = $(CONTAINER_RUNTIME) run --rm -v $(PROJECT_DIR):/workspace -w /workspace $(EE_IMAGE)

.PHONY: docs validate crosswalk clean test validate-schemas env collections container-check lint-ansible lint-yaml syntax-check ee-build ee-shell ee-lint ee-yamllint ee-syntax-check

env:
	./scripts/bootstrap-env.sh

collections:
	$(ANSIBLE_GALAXY) collection install -r requirements.yml

container-check:
	@$(CONTAINER_RUNTIME) info >/dev/null 2>&1 || (echo "$(CONTAINER_RUNTIME) is not available or its daemon is not running."; exit 1)

docs:
	$(PYTHON) scripts/generate_docs.py --output-dir docs/generated

validate:
	$(PYTHON) scripts/validate_glossary.py --glossary docs/glossary/terms.yml --scan-dirs docs roles templates

crosswalk:
	$(PYTHON) scripts/generate_docs.py --output-dir docs/generated --only crosswalk

clean:
	rm -f docs/generated/*.md docs/generated/*.csv

test:
	$(PYTHON) -m pytest tests/

validate-schemas:
	$(PYTHON) -m pytest tests/test_yaml_schemas.py

lint-ansible:
	$(ANSIBLE_LINT) -c tests/lint/ansible-lint.yml roles playbooks

lint-yaml:
	$(YAMLLINT) -c tests/lint/yamllint.yml inventory roles playbooks tests

syntax-check: collections
	$(ANSIBLE_PLAYBOOK) --syntax-check playbooks/site.yml

ee-build: container-check
	$(ANSIBLE_BUILDER) build -f execution-environment.yml -t $(EE_IMAGE) --container-runtime $(CONTAINER_RUNTIME)

ee-shell: container-check
	$(EE_RUN) /bin/bash

ee-lint: container-check
	$(EE_RUN) ansible-lint -c tests/lint/ansible-lint.yml roles playbooks

ee-yamllint: container-check
	$(EE_RUN) yamllint -c tests/lint/yamllint.yml inventory roles playbooks tests

ee-syntax-check: container-check
	$(EE_RUN) ansible-playbook --syntax-check playbooks/site.yml
