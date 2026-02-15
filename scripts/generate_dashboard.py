#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path
from typing import Any

import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined

REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_DIR = REPO_ROOT / "plugins" / "filter"
if str(PLUGIN_DIR) not in sys.path:
    sys.path.insert(0, str(PLUGIN_DIR))

import sprs  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate audience-specific compliance dashboard")
    parser.add_argument(
        "--assessment-file",
        type=Path,
        default=None,
        help="Assessment JSON file (default: latest in data/assessment_history)",
    )
    parser.add_argument(
        "--history-dir",
        type=Path,
        default=REPO_ROOT / "data" / "assessment_history",
        help="Assessment history directory",
    )
    parser.add_argument(
        "--poam-file",
        type=Path,
        default=REPO_ROOT / "data" / "poam.yml",
        help="POA&M data file",
    )
    parser.add_argument(
        "--narratives-dir",
        type=Path,
        default=REPO_ROOT / "docs" / "generated" / "narratives",
        help="Narratives directory",
    )
    parser.add_argument(
        "--evidence-dir",
        type=Path,
        default=REPO_ROOT / "docs" / "auditor_packages",
        help="Evidence directory root",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "reports" / "dashboard",
        help="Dashboard output directory",
    )
    return parser.parse_args()


def _latest_json(path: Path) -> Path:
    files = sorted(path.glob("*.json"))
    if not files:
        raise FileNotFoundError(f"No assessment JSON found in {path}")
    return files[-1]


def _load_assessment(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_poam(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"poam_items": []}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {"poam_items": []}


def _trend(history_dir: Path) -> list[dict[str, Any]]:
    points: list[dict[str, Any]] = []
    if not history_dir.exists():
        return points

    for file_path in sorted(history_dir.glob("*.json")):
        try:
            data = _load_assessment(file_path)
        except Exception:  # noqa: BLE001
            continue

        points.append(
            {
                "timestamp": str(data.get("timestamp", file_path.stem))[:10],
                "score": int(data.get("sprs_score", sprs.sprs_score(data))),
            }
        )
    return points


def _family_status(breakdown: dict[str, Any]) -> dict[str, str]:
    status: dict[str, str] = {}
    for family, item in breakdown.get("by_family", {}).items():
        total = int(item.get("controls_total", 0))
        failing = int(item.get("controls_failing", 0))
        if total == 0:
            status[family] = "yellow"
        elif failing == 0:
            status[family] = "green"
        elif failing < total:
            status[family] = "yellow"
        else:
            status[family] = "red"
    return status


def _compliance_percent(assessment: dict[str, Any]) -> int:
    controls = assessment.get("controls", [])
    if not controls:
        return 0

    applicable = [c for c in controls if c.get("status") != "not_applicable"]
    if not applicable:
        return 0

    passing = [c for c in applicable if c.get("status") == "pass"]
    return int(round((len(passing) / len(applicable)) * 100))


def _collect_narratives(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    return [
        {"name": file_path.name, "path": str(file_path)}
        for file_path in sorted(path.glob("control_*.md"))[:75]
    ]


def _collect_evidence_links(path: Path) -> list[dict[str, str]]:
    if not path.exists():
        return []
    files = [p for p in sorted(path.rglob("*")) if p.is_file()]
    return [{"label": p.name, "path": str(p)} for p in files[:75]]


def _environment() -> Environment:
    return Environment(
        loader=FileSystemLoader(str(REPO_ROOT / "templates")),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )


def _copy_assets(output_dir: Path) -> None:
    source = REPO_ROOT / "templates" / "dashboard" / "assets"
    dest = output_dir / "assets"
    dest.mkdir(parents=True, exist_ok=True)
    for name in ["chart.min.js", "dashboard.css"]:
        shutil.copy2(source / name, dest / name)


def main() -> int:
    args = parse_args()

    history_dir = args.history_dir if args.history_dir.is_absolute() else REPO_ROOT / args.history_dir
    assessment_file = args.assessment_file if args.assessment_file else _latest_json(history_dir)
    if not assessment_file.is_absolute():
        assessment_file = REPO_ROOT / assessment_file

    poam_file = args.poam_file if args.poam_file.is_absolute() else REPO_ROOT / args.poam_file
    narratives_dir = args.narratives_dir if args.narratives_dir.is_absolute() else REPO_ROOT / args.narratives_dir
    evidence_dir = args.evidence_dir if args.evidence_dir.is_absolute() else REPO_ROOT / args.evidence_dir
    output_dir = args.output_dir if args.output_dir.is_absolute() else REPO_ROOT / args.output_dir

    if not assessment_file.exists():
        print(f"ERROR: Assessment file not found: {assessment_file}", file=sys.stderr)
        return 2

    assessment = _load_assessment(assessment_file)
    poam = _load_poam(poam_file)
    breakdown = sprs.sprs_breakdown(assessment, poam)
    trend = _trend(history_dir)

    context = {
        "assessment": assessment,
        "breakdown": breakdown,
        "trend": trend,
        "first_run": len(trend) <= 1,
        "family_status": _family_status(breakdown),
        "compliance_percent": _compliance_percent(assessment),
        "narratives": _collect_narratives(narratives_dir),
        "evidence_links": _collect_evidence_links(evidence_dir),
        "generated_at": datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ"),
    }

    env = _environment()
    template = env.get_template("dashboard/base.html.j2")
    rendered = template.render(**context)

    output_dir.mkdir(parents=True, exist_ok=True)
    _copy_assets(output_dir)
    (output_dir / "index.html").write_text(rendered, encoding="utf-8")

    print(f"Generated dashboard: {output_dir / 'index.html'}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
