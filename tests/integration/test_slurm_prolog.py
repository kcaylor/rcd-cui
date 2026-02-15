from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PROLOG_TEMPLATE = REPO_ROOT / "roles" / "hpc_slurm_cui" / "templates" / "slurm_prolog.sh.j2"
EPILOG_TEMPLATE = REPO_ROOT / "roles" / "hpc_slurm_cui" / "templates" / "slurm_epilog.sh.j2"


def test_slurm_prolog_template_contains_authorization_and_training_checks() -> None:
    content = PROLOG_TEMPLATE.read_text(encoding="utf-8")
    assert "ldapsearch" in content
    assert "cuiTrainingExpiry" in content
    assert "Authorization service temporarily unavailable" in content
    assert "CUI_TAG" in content


def test_slurm_epilog_template_contains_sanitization_and_drain_logic() -> None:
    content = EPILOG_TEMPLATE.read_text(encoding="utf-8")
    assert "/dev/shm" in content
    assert "find /tmp" in content
    assert "nvidia-smi --gpu-reset" in content
    assert "State=DRAIN" in content
