from __future__ import annotations

import codecs
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPT = REPO_ROOT / "scripts" / "generate_docs.py"


def run_generate(output_dir: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(SCRIPT), "--output-dir", str(output_dir)],
        cwd=REPO_ROOT,
        capture_output=True,
        text=True,
        check=False,
    )


def test_generate_docs_outputs_all_files(tmp_path: Path) -> None:
    result = run_generate(tmp_path)
    assert result.returncode == 0, result.stderr

    expected = {
        "pi_guide.md",
        "researcher_quickstart.md",
        "sysadmin_reference.md",
        "ciso_compliance_map.md",
        "leadership_briefing.md",
        "glossary_full.md",
        "crosswalk.csv",
    }
    produced = {path.name for path in tmp_path.iterdir() if path.is_file()}
    assert expected.issubset(produced)


def test_generated_markdown_contains_glossary_hyperlinks(tmp_path: Path) -> None:
    result = run_generate(tmp_path)
    assert result.returncode == 0, result.stderr

    pi_guide = (tmp_path / "pi_guide.md").read_text(encoding="utf-8")
    assert "[CUI](#term-cui)" in pi_guide


def test_crosswalk_csv_uses_utf8_bom(tmp_path: Path) -> None:
    result = run_generate(tmp_path)
    assert result.returncode == 0, result.stderr

    csv_bytes = (tmp_path / "crosswalk.csv").read_bytes()
    assert csv_bytes.startswith(codecs.BOM_UTF8)


def test_generated_docs_have_no_unexpanded_jinja_tokens(tmp_path: Path) -> None:
    result = run_generate(tmp_path)
    assert result.returncode == 0, result.stderr

    for path in tmp_path.iterdir():
        if not path.is_file():
            continue
        content = path.read_text(encoding="utf-8-sig")
        assert "{{" not in content
        assert "{%" not in content
