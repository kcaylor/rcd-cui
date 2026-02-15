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
    load_yaml_cached,
)


@pytest.mark.parametrize(
    ("file_path", "model_class"),
    [
        (REPO_ROOT / "roles/common/vars/control_mapping.yml", ControlMappingData),
        (REPO_ROOT / "docs/glossary/terms.yml", GlossaryData),
        (REPO_ROOT / "docs/hpc_tailoring.yml", HPCTailoringData),
        (REPO_ROOT / "docs/odp_values.yml", ODPValuesData),
    ],
)
def test_yaml_schema_valid(file_path: Path, model_class: type) -> None:
    data = load_yaml_cached(file_path)
    validated = model_class.model_validate(data)
    assert validated is not None


def test_control_mapping_has_exactly_110_controls(control_mapping_data: ControlMappingData) -> None:
    assert len(control_mapping_data.controls) == 110


def test_control_mapping_has_complete_framework_fields(control_mapping_data: ControlMappingData) -> None:
    for control in control_mapping_data.controls:
        mapping = control.framework_mapping
        assert mapping.rev2_id
        assert mapping.rev3_id is not None
        assert mapping.cmmc_l2_id is not None
        assert mapping.nist_800_53_r5_id


def test_na_mappings_have_rationale(control_mapping_data: ControlMappingData) -> None:
    for control in control_mapping_data.controls:
        mapping = control.framework_mapping
        if mapping.rev3_id == "N/A":
            assert mapping.rev3_rationale
        if mapping.cmmc_l2_id == "N/A":
            assert mapping.cmmc_l2_rationale


def test_glossary_minimum_size(glossary_data: GlossaryData) -> None:
    assert len(glossary_data.terms) >= 60


def test_glossary_who_cares_fields_are_complete(glossary_data: GlossaryData) -> None:
    for term in glossary_data.terms.values():
        assert term.who_cares.pi
        assert term.who_cares.researcher
        assert term.who_cares.sysadmin
        assert term.who_cares.ciso
        assert term.who_cares.leadership


def test_glossary_see_also_integrity(glossary_data: GlossaryData) -> None:
    available = set(glossary_data.terms)
    for term in glossary_data.terms.values():
        for related in term.see_also:
            assert related in available


def test_hpc_tailoring_minimum_entries(hpc_tailoring_data: HPCTailoringData) -> None:
    assert len(hpc_tailoring_data.tailoring_decisions) >= 10


def test_hpc_tailoring_compensating_controls(hpc_tailoring_data: HPCTailoringData) -> None:
    for entry in hpc_tailoring_data.tailoring_decisions:
        assert len(entry.compensating_controls) >= 1


def test_odp_values_exact_count(odp_values_data: ODPValuesData) -> None:
    assert len(odp_values_data.odp_values) == 49


def test_odp_deviation_has_rationale(odp_values_data: ODPValuesData) -> None:
    for entry in odp_values_data.odp_values:
        if entry.assigned_value != entry.dod_guidance:
            assert entry.deviation_rationale
