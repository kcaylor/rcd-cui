from __future__ import annotations

import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "generate_narratives.py"


def test_generate_narratives_and_validate_glossary(tmp_path: Path) -> None:
    output_dir = tmp_path / "narratives"
    result = subprocess.run(
        [
            sys.executable,
            str(SCRIPT),
            "--output-dir",
            str(output_dir),
            "--evidence-dir",
            str(REPO_ROOT / "docs"),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr

    generated = sorted(output_dir.glob("control_*.md"))
    assert generated
    first = generated[0].read_text(encoding="utf-8")
    assert "Control Context" in first
    assert "Implementation Description" in first
    assert "Evidence References" in first
