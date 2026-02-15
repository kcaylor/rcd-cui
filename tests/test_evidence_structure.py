from __future__ import annotations

from pathlib import Path

import yaml


REPO_ROOT = Path(__file__).resolve().parents[1]
PLAYBOOK = REPO_ROOT / "playbooks" / "ssp_evidence.yml"


def test_ssp_evidence_playbook_defines_required_structure() -> None:
    content = yaml.safe_load(PLAYBOOK.read_text(encoding="utf-8"))
    assert isinstance(content, list)

    play_one = content[0]
    vars_block = play_one["vars"]
    expected = {"command_artifacts", "evidence_root"}
    assert expected.issubset(vars_block.keys())

    commands = vars_block["command_artifacts"]
    command_ids = {entry["id"] for entry in commands}
    assert "system_inventory" in command_ids
    assert "packages" in command_ids
    assert "network_addr" in command_ids
    assert "firewall_rules" in command_ids
    assert "selinux_status" in command_ids
    assert "fips_status" in command_ids
    assert "audit_rules" in command_ids
    assert "sshd_config" in command_ids
    assert "pam_config" in command_ids
    assert "passwd_listing" in command_ids
    assert "group_listing" in command_ids
    assert "slurm_config" in command_ids
    assert "lsblk" in command_ids
    assert "cryptsetup_status" in command_ids
