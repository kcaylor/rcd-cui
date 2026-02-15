#!/usr/bin/env python3
"""Synchronize CUI project ACLs with FreeIPA group membership.

This daemon polls FreeIPA group state and updates POSIX ACLs on project directories.
It is intentionally conservative and favors clear logs over optimization.
"""

from __future__ import annotations

import argparse
import logging
import subprocess
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Sync project ACLs from FreeIPA groups")
    parser.add_argument("--project-root", required=True)
    parser.add_argument("--group-prefix", default="cuiproj-")
    parser.add_argument("--interval-seconds", type=int, default=300)
    return parser.parse_args()


def run_command(cmd: list[str]) -> tuple[int, str]:
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return proc.returncode, proc.stdout.strip()


def list_project_dirs(project_root: Path) -> list[Path]:
    if not project_root.exists():
        return []
    return [item for item in project_root.iterdir() if item.is_dir()]


def sync_acl_for_project(project_dir: Path, group_name: str) -> None:
    cmd = ["setfacl", "-R", "-m", f"g:{group_name}:rwx", str(project_dir)]
    rc, _stdout = run_command(cmd)
    if rc != 0:
        raise RuntimeError(f"setfacl failed for {project_dir} group {group_name}")


def main() -> int:
    args = parse_args()
    project_root = Path(args.project_root)

    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s %(levelname)s %(message)s",
    )

    while True:
        try:
            for project_dir in list_project_dirs(project_root):
                group_name = f"{args.group_prefix}{project_dir.name}"
                sync_acl_for_project(project_dir, group_name)
                logging.info("Synced ACLs for %s using group %s", project_dir, group_name)
        except Exception as exc:  # noqa: BLE001
            logging.exception("ACL sync iteration failed: %s", exc)
        time.sleep(args.interval_seconds)


if __name__ == "__main__":
    raise SystemExit(main())
