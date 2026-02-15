from __future__ import annotations

import json
import re
import shutil
import subprocess
from pathlib import Path

import pytest


REPO_ROOT = Path(__file__).resolve().parents[1]
ASSESSMENT_FIXTURE = REPO_ROOT / "tests" / "fixtures" / "assessment_sample.json"
UUID_RE = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$")


def test_assessment_json_contract_shape() -> None:
    data = json.loads(ASSESSMENT_FIXTURE.read_text(encoding="utf-8"))

    assert UUID_RE.match(data["assessment_id"])
    assert "T" in data["timestamp"]
    assert data["coverage"]["assessed_systems"] <= data["coverage"]["total_systems"]
    assert data["sprs_score"] >= -203
    assert data["sprs_score"] <= 110

    for control in data["controls"]:
        assert re.match(r"^3\.[0-9]+\.[0-9]+$", control["control_id"])
        assert control["status"] in {"pass", "fail", "not_assessed", "not_applicable"}


def test_assessment_coverage_math() -> None:
    data = json.loads(ASSESSMENT_FIXTURE.read_text(encoding="utf-8"))
    total = data["coverage"]["total_systems"]
    assessed = data["coverage"]["assessed_systems"]
    not_assessed = len(data["coverage"].get("not_assessed", []))
    assert assessed + not_assessed == total


@pytest.mark.skipif(shutil.which("ansible-playbook") is None, reason="ansible-playbook not installed")
def test_assess_playbook_syntax() -> None:
    result = subprocess.run(
        [
            "ansible-playbook",
            "--syntax-check",
            "tests/playbooks/test_assess.yml",
            "-i",
            "inventory/hosts.yml",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    assert result.returncode == 0, result.stderr
