from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
SCRIPTS_DIR = REPO_ROOT / "scripts"
if str(SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPTS_DIR))

import redact_secrets  # noqa: E402


def test_redact_file_replaces_secret_values(tmp_path: Path) -> None:
    evidence = tmp_path / "evidence.conf"
    evidence.write_text(
        """
password = hunter2
api_key = abcdefghijklmnopqrstuvwxyz12345
ikey = DIABCDEFGHIJKLMNOPQRST
-----BEGIN PRIVATE KEY-----
SUPERSECRETKEY
-----END PRIVATE KEY-----
""".strip()
        + "\n",
        encoding="utf-8",
    )

    count = redact_secrets.redact_file(evidence)
    content = evidence.read_text(encoding="utf-8")

    assert count >= 3
    assert "hunter2" not in content
    assert "abcdefghijklmnopqrstuvwxyz12345" not in content
    assert "SUPERSECRETKEY" not in content
    assert "[REDACTED]" in content or "[REDACTED PRIVATE KEY]" in content


def test_redact_directory_preserves_structure(tmp_path: Path) -> None:
    src = tmp_path / "src"
    out = tmp_path / "out"
    nested = src / "nested"
    nested.mkdir(parents=True)

    (nested / "app.conf").write_text("token: supertokenvalue\n", encoding="utf-8")
    (nested / "notes.txt").write_text("No secrets here.\n", encoding="utf-8")

    files_processed, redaction_count = redact_secrets.redact_directory(src, out)

    assert files_processed == 2
    assert redaction_count >= 1
    assert (out / "nested" / "app.conf").exists()
    assert "supertokenvalue" not in (out / "nested" / "app.conf").read_text(encoding="utf-8")
