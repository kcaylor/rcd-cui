from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
APPTAINER_TEMPLATE = REPO_ROOT / "roles" / "hpc_container_security" / "templates" / "apptainer.conf.j2"
WRAPPER_TEMPLATE = REPO_ROOT / "roles" / "hpc_container_security" / "templates" / "container_wrapper.sh.j2"


def test_apptainer_config_enforces_signatures_and_network_isolation() -> None:
    content = APPTAINER_TEMPLATE.read_text(encoding="utf-8")
    assert "allow unsigned =" in content
    assert "allow net users = no" in content
    assert "allow net network = none" in content
    assert "bind path =" in content


def test_container_wrapper_logs_and_rejects_unsigned_images() -> None:
    content = WRAPPER_TEMPLATE.read_text(encoding="utf-8")
    assert "apptainer verify --key" in content
    assert "blocked_unsigned" in content
    assert "--network=none" in content
    assert "/dev/infiniband" in content
