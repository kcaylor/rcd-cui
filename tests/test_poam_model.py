from __future__ import annotations

import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import generate_poam_report as poam  # noqa: E402


def test_poam_yaml_schema_valid() -> None:
    data = poam.load_poam_data(REPO_ROOT / "data" / "poam.yml")
    assert data.version
    assert data.poam_items


def test_poam_items_have_required_fields() -> None:
    data = poam.load_poam_data(REPO_ROOT / "data" / "poam.yml")
    item = data.poam_items[0]

    assert item.id.startswith("POAM-")
    assert item.control_id.startswith("3.")
    assert item.weakness.plain_language
    assert item.milestones
