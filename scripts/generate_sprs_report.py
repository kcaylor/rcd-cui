#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined

REPO_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_FILE = "reports/sprs_breakdown.md.j2"

PLUGIN_DIR = REPO_ROOT / "plugins" / "filter"
if str(PLUGIN_DIR) not in sys.path:
    sys.path.insert(0, str(PLUGIN_DIR))

import sprs  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate a markdown SPRS breakdown report")
    parser.add_argument(
        "--input",
        type=Path,
        default=None,
        help="Assessment JSON file (default: latest file in data/assessment_history)",
    )
    parser.add_argument(
        "--poam",
        type=Path,
        default=REPO_ROOT / "data" / "poam.yml",
        help="POA&M YAML file used for SPRS credit calculations",
    )
    parser.add_argument(
        "--history-dir",
        type=Path,
        default=REPO_ROOT / "data" / "assessment_history",
        help="Directory for historical assessment JSON files",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Output markdown report path (default: reports/sprs_YYYY-MM-DD.md)",
    )
    return parser.parse_args()


def _latest_assessment_file(history_dir: Path) -> Path:
    candidates = sorted(history_dir.glob("*.json"))
    if not candidates:
        raise FileNotFoundError(f"No assessment JSON files found in {history_dir}")
    return candidates[-1]


def _load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def _load_poam(path: Path) -> dict[str, Any]:
    if not path.exists():
        return {"poam_items": []}
    return yaml.safe_load(path.read_text(encoding="utf-8")) or {"poam_items": []}


def _load_trend(history_dir: Path) -> list[dict[str, Any]]:
    trend: list[dict[str, Any]] = []
    if not history_dir.exists():
        return trend

    for path in sorted(history_dir.glob("*.json")):
        try:
            data = _load_json(path)
        except Exception:  # noqa: BLE001
            continue

        score = data.get("sprs_score")
        if score is None:
            score = sprs.sprs_score(data)

        trend.append(
            {
                "timestamp": str(data.get("timestamp", path.stem)),
                "score": int(score),
                "assessment_id": data.get("assessment_id", ""),
            }
        )
    return trend


def _build_environment() -> Environment:
    return Environment(
        loader=FileSystemLoader(str(REPO_ROOT / "templates")),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )


def _render_report(context: dict[str, Any]) -> str:
    env = _build_environment()
    template = env.get_template(TEMPLATE_FILE)
    return template.render(**context)


def main() -> int:
    args = parse_args()

    history_dir = args.history_dir if args.history_dir.is_absolute() else REPO_ROOT / args.history_dir
    input_file = args.input if args.input else _latest_assessment_file(history_dir)
    if not input_file.is_absolute():
        input_file = REPO_ROOT / input_file

    if not input_file.exists():
        print(f"ERROR: Assessment file not found: {input_file}", file=sys.stderr)
        return 2

    poam_file = args.poam if args.poam.is_absolute() else REPO_ROOT / args.poam
    assessment = _load_json(input_file)
    poam_data = _load_poam(poam_file)
    breakdown = sprs.sprs_breakdown(assessment, poam_data)
    trend = _load_trend(history_dir)

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    context = {
        "assessment": assessment,
        "breakdown": breakdown,
        "poam_items": poam_data.get("poam_items", []),
        "trend": trend,
        "generated_at": generated_at,
    }

    rendered = _render_report(context)

    if args.output:
        output_file = args.output if args.output.is_absolute() else REPO_ROOT / args.output
    else:
        output_file = REPO_ROOT / "reports" / f"sprs_{datetime.now().strftime('%Y-%m-%d')}.md"

    output_file.parent.mkdir(parents=True, exist_ok=True)
    output_file.write_text(rendered, encoding="utf-8")

    print(f"Generated SPRS report: {output_file}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
