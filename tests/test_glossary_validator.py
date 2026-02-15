from __future__ import annotations

import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import validate_glossary as validator  # noqa: E402


def test_extract_acronyms_regex() -> None:
    found = validator.extract_acronyms("Use MFA with SSH for CUI and SIEM alerts.")
    assert {"MFA", "SSH", "CUI", "SIEM"}.issubset(found)


def test_context_tagged_term_matching() -> None:
    exact = {"CUI", "AC (compliance)", "AC (hardware)"}
    contextual = {"AC": {"compliance", "hardware"}}

    assert validator.is_term_defined("AC", "Apply AC (compliance) policy", exact, contextual)
    assert not validator.is_term_defined("AC", "Apply AC policy", exact, contextual)


def test_validator_flags_undefined_terms(tmp_path: Path) -> None:
    sample = tmp_path / "sample.md"
    sample.write_text("This sentence introduces XYZTERM without a definition.\n", encoding="utf-8")

    result = subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "scripts" / "validate_glossary.py"),
            "--glossary",
            str(REPO_ROOT / "docs/glossary/terms.yml"),
            "--scan-dirs",
            str(tmp_path),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 1
    assert "XYZTERM" in result.stderr


def test_validator_succeeds_when_terms_are_defined(tmp_path: Path) -> None:
    sample = tmp_path / "sample.md"
    sample.write_text("Researchers handling CUI use MFA and SSP documentation.\n", encoding="utf-8")

    result = subprocess.run(
        [
            sys.executable,
            str(REPO_ROOT / "scripts" / "validate_glossary.py"),
            "--glossary",
            str(REPO_ROOT / "docs/glossary/terms.yml"),
            "--scan-dirs",
            str(tmp_path),
        ],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0
    assert "All terms validated." in result.stdout
