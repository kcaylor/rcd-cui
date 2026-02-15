from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "generate_dashboard.py"


def _write_assessment(path: Path, timestamp: str, score: int) -> None:
    payload = {
        "assessment_id": f"id-{timestamp}",
        "timestamp": timestamp,
        "enclave_name": "dashboard-test",
        "controls": [
            {"control_id": "3.1.1", "family": "AC", "status": "pass"},
            {"control_id": "3.5.3", "family": "IA", "status": "fail"},
        ],
        "sprs_score": score,
    }
    path.write_text(json.dumps(payload), encoding="utf-8")


def test_dashboard_generation_first_run(tmp_path: Path) -> None:
    history = tmp_path / "history"
    history.mkdir()
    _write_assessment(history / "2026-02-15.json", "2026-02-15T00:00:00Z", 100)

    out = tmp_path / "dashboard"
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--history-dir",
            str(history),
            "--assessment-file",
            str(history / "2026-02-15.json"),
            "--output-dir",
            str(out),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    index = (out / "index.html").read_text(encoding="utf-8")
    assert "Compliance Dashboard" in index
    assert "Leadership" in index
    assert "First-run snapshot" in index


def test_dashboard_generation_with_history(tmp_path: Path) -> None:
    history = tmp_path / "history"
    history.mkdir()
    _write_assessment(history / "2026-02-13.json", "2026-02-13T00:00:00Z", 90)
    _write_assessment(history / "2026-02-14.json", "2026-02-14T00:00:00Z", 95)
    _write_assessment(history / "2026-02-15.json", "2026-02-15T00:00:00Z", 101)

    out = tmp_path / "dashboard"
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--history-dir",
            str(history),
            "--assessment-file",
            str(history / "2026-02-15.json"),
            "--output-dir",
            str(out),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    index = (out / "index.html").read_text(encoding="utf-8")
    assert "trendChart" in index
