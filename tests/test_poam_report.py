from __future__ import annotations

import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "generate_poam_report.py"


def test_generate_poam_reports(tmp_path: Path) -> None:
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--input",
            str(REPO_ROOT / "data" / "poam.yml"),
            "--output-dir",
            str(tmp_path),
            "--skip-glossary-check",
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert (tmp_path / "poam.md").exists()
    assert (tmp_path / "poam.csv").exists()

    md = (tmp_path / "poam.md").read_text(encoding="utf-8")
    csv = (tmp_path / "poam.csv").read_text(encoding="utf-8")

    assert "POA&M Status Report" in md
    assert "Overdue Items" in md
    assert "control_id" in csv.splitlines()[0]
