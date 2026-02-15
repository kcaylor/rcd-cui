from __future__ import annotations

import subprocess
import sys
import tarfile
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "generate_auditor_package.py"


def test_generate_auditor_package_contains_required_sections(tmp_path: Path) -> None:
    result = subprocess.run(
        [sys.executable, str(SCRIPT), "--output-dir", str(tmp_path)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr

    archives = sorted(tmp_path.glob("*.tar.gz"))
    assert archives, "Expected generated tar.gz archive"

    with tarfile.open(archives[-1], "r:gz") as archive:
        names = archive.getnames()

    assert any("01_crosswalk/crosswalk.csv" in name for name in names)
    assert any("02_narratives" in name for name in names)
    assert any("03_evidence" in name for name in names)
    assert any("04_sprs" in name for name in names)
    assert any("05_poam" in name for name in names)
    assert any("06_hpc_tailoring" in name for name in names)
    assert any("07_odp_values" in name for name in names)
    assert any(name.endswith("manifest.json") for name in names)
