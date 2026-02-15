from __future__ import annotations

from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
ACL_SYNC = REPO_ROOT / "roles" / "hpc_storage_security" / "files" / "acl_sync.py"
MAIN_TASKS = REPO_ROOT / "roles" / "hpc_storage_security" / "tasks" / "main.yml"
SANITIZE_TEMPLATE = REPO_ROOT / "roles" / "hpc_storage_security" / "templates" / "sanitize_project.sh.j2"


def test_acl_sync_daemon_present_and_sets_acls() -> None:
    content = ACL_SYNC.read_text(encoding="utf-8")
    assert "setfacl" in content
    assert "group-prefix" in content


def test_storage_main_configures_quota_and_encryption_checks() -> None:
    content = MAIN_TASKS.read_text(encoding="utf-8")
    assert "quota_exceeded_mode: readonly" in content
    assert "Verify encryption at rest status" in content
    assert "Verify backup encryption status" in content


def test_sanitization_template_uses_shred() -> None:
    content = SANITIZE_TEMPLATE.read_text(encoding="utf-8")
    assert "shred -vzn 1" in content
