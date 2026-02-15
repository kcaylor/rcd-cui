from __future__ import annotations

import sys
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

from models import (  # noqa: E402
    ControlMappingData,
    GlossaryData,
    HPCTailoringData,
    ODPValuesData,
    clear_yaml_cache,
    load_yaml_cached,
)


@pytest.fixture(autouse=True)
def reset_yaml_cache() -> None:
    clear_yaml_cache()


@pytest.fixture
def control_mapping_data() -> ControlMappingData:
    raw = load_yaml_cached(REPO_ROOT / "roles/common/vars/control_mapping.yml")
    return ControlMappingData.model_validate(raw)


@pytest.fixture
def glossary_data() -> GlossaryData:
    raw = load_yaml_cached(REPO_ROOT / "docs/glossary/terms.yml")
    return GlossaryData.model_validate(raw)


@pytest.fixture
def hpc_tailoring_data() -> HPCTailoringData:
    raw = load_yaml_cached(REPO_ROOT / "docs/hpc_tailoring.yml")
    return HPCTailoringData.model_validate(raw)


@pytest.fixture
def odp_values_data() -> ODPValuesData:
    raw = load_yaml_cached(REPO_ROOT / "docs/odp_values.yml")
    return ODPValuesData.model_validate(raw)
