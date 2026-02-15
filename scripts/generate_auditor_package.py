#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import json
import shutil
import subprocess
import tarfile
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Bundle CMMC auditor package artifacts")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "docs" / "auditor_packages",
        help="Output directory for auditor package",
    )
    return parser.parse_args()


def _latest(pattern: str) -> Path | None:
    candidates = sorted(REPO_ROOT.glob(pattern))
    return candidates[-1] if candidates else None


def _ensure_reports() -> None:
    sprs_report = _latest("reports/sprs_*.md")
    if sprs_report is None and (REPO_ROOT / "data" / "assessment_history").exists():
        subprocess.run(
            [
                "python3",
                str(REPO_ROOT / "scripts" / "generate_sprs_report.py"),
            ],
            cwd=REPO_ROOT,
            check=False,
        )

    if not (REPO_ROOT / "reports" / "poam.md").exists():
        subprocess.run(
            ["python3", str(REPO_ROOT / "scripts" / "generate_poam_report.py")],
            cwd=REPO_ROOT,
            check=False,
        )


def _build_crosswalk_csv(destination: Path) -> int:
    mapping_path = REPO_ROOT / "roles" / "common" / "vars" / "control_mapping.yml"
    data = yaml.safe_load(mapping_path.read_text(encoding="utf-8"))
    controls = sorted(data.get("controls", []), key=lambda item: item["control_id"])

    destination.parent.mkdir(parents=True, exist_ok=True)
    with destination.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["control_id", "family", "title", "ansible_roles", "narrative_file"])
        for control in controls:
            writer.writerow(
                [
                    control["control_id"],
                    control.get("family", ""),
                    control.get("title", ""),
                    "|".join(control.get("ansible_roles", [])),
                    f"control_{control['control_id'].replace('.', '_')}.md",
                ]
            )
    return len(controls)


def _copy_tree_if_exists(source: Path, destination: Path) -> int:
    if not source.exists():
        return 0

    if source.is_file():
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
        return 1

    destination.mkdir(parents=True, exist_ok=True)
    count = 0
    for path in source.rglob("*"):
        rel = path.relative_to(source)
        out = destination / rel
        if path.is_dir():
            out.mkdir(parents=True, exist_ok=True)
            continue
        out.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, out)
        count += 1
    return count


def _manifest(path: Path, package_dir: Path, total_controls: int) -> None:
    files = [str(p.relative_to(package_dir)) for p in sorted(package_dir.rglob("*")) if p.is_file()]
    payload: dict[str, Any] = {
        "package_id": datetime.now(timezone.utc).strftime("pkg-%Y%m%d%H%M%S"),
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "cmmc_level": "Level 2",
        "total_controls": total_controls,
        "files": files,
    }
    path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


def _compress(source_dir: Path, tar_path: Path) -> None:
    with tarfile.open(tar_path, "w:gz") as archive:
        archive.add(source_dir, arcname=source_dir.name)


def main() -> int:
    args = parse_args()
    output_dir = args.output_dir if args.output_dir.is_absolute() else REPO_ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    _ensure_reports()

    stamp = datetime.now().strftime("%Y-%m-%d")
    package_dir = output_dir / stamp
    package_dir.mkdir(parents=True, exist_ok=True)

    sections = {
        "01_crosswalk": package_dir / "01_crosswalk",
        "02_narratives": package_dir / "02_narratives",
        "03_evidence": package_dir / "03_evidence",
        "04_sprs": package_dir / "04_sprs",
        "05_poam": package_dir / "05_poam",
        "06_hpc_tailoring": package_dir / "06_hpc_tailoring",
        "07_odp_values": package_dir / "07_odp_values",
    }
    for path in sections.values():
        path.mkdir(parents=True, exist_ok=True)

    total_controls = _build_crosswalk_csv(sections["01_crosswalk"] / "crosswalk.csv")

    _copy_tree_if_exists(REPO_ROOT / "docs" / "generated" / "narratives", sections["02_narratives"])

    latest_evidence_archive = _latest("docs/auditor_packages/*.tar.gz")
    if latest_evidence_archive:
        _copy_tree_if_exists(latest_evidence_archive, sections["03_evidence"] / latest_evidence_archive.name)
    else:
        (sections["03_evidence"] / "README.txt").write_text(
            "No evidence archive found. Run make evidence first.\n", encoding="utf-8"
        )

    sprs_report = _latest("reports/sprs_*.md")
    if sprs_report:
        _copy_tree_if_exists(sprs_report, sections["04_sprs"] / sprs_report.name)

    _copy_tree_if_exists(REPO_ROOT / "reports" / "poam.md", sections["05_poam"] / "poam.md")
    _copy_tree_if_exists(REPO_ROOT / "reports" / "poam.csv", sections["05_poam"] / "poam.csv")

    _copy_tree_if_exists(
        REPO_ROOT / "docs" / "hpc_tailoring.yml",
        sections["06_hpc_tailoring"] / "hpc_tailoring.yml",
    )
    _copy_tree_if_exists(REPO_ROOT / "docs" / "odp_values.yml", sections["07_odp_values"] / "odp_values.yml")

    manifest_path = package_dir / "manifest.json"
    _manifest(manifest_path, package_dir, total_controls)

    tar_path = output_dir / f"{stamp}.tar.gz"
    _compress(package_dir, tar_path)

    print(f"Generated auditor package directory: {package_dir}")
    print(f"Generated auditor package archive:   {tar_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
