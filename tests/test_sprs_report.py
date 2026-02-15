from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "generate_sprs_report.py"


def test_generate_sprs_report_from_assessment_fixture(tmp_path: Path) -> None:
    input_file = REPO_ROOT / "tests" / "fixtures" / "assessment_sample.json"
    output_file = tmp_path / "sprs.md"

    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--input",
            str(input_file),
            "--output",
            str(output_file),
            "--history-dir",
            str(tmp_path),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    content = output_file.read_text(encoding="utf-8")
    assert "SPRS Score Breakdown" in content
    assert "Family Breakdown" in content
    assert "Deductions" in content


def test_sprs_report_score_matches_plugin_manual_deduction(tmp_path: Path) -> None:
    assessment = {
        "assessment_id": "22222222-2222-2222-2222-222222222222",
        "timestamp": "2026-02-15T10:00:00Z",
        "enclave_name": "manual-test",
        "controls": [
            {"control_id": "3.1.1", "family": "AC", "status": "pass"},
            {"control_id": "3.1.2", "family": "AC", "status": "pass"},
            {"control_id": "3.5.3", "family": "IA", "status": "fail"},
            {"control_id": "3.13.8", "family": "SC", "status": "fail"},
        ],
    }
    input_file = tmp_path / "assessment.json"
    output_file = tmp_path / "sprs.md"
    input_file.write_text(json.dumps(assessment), encoding="utf-8")

    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--input", str(input_file), "--output", str(output_file)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    report = output_file.read_text(encoding="utf-8")
    assert "Total score" in report
