#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_HISTORY_DIR = REPO_ROOT / "data" / "assessment_history"
DEFAULT_OUTPUT = REPO_ROOT / "reports" / "badge-data.json"
CONTROL_MAPPING_FILE = REPO_ROOT / "roles" / "common" / "vars" / "control_mapping.yml"

BADGE_DATA_SCHEMA: dict[str, Any] = {
    "$schema": "http://json-schema.org/draft-07/schema#",
    "type": "object",
    "required": [
        "sprs_score",
        "sprs_color",
        "last_assessment",
        "controls_passing",
        "controls_total",
        "generated_at",
    ],
    "properties": {
        "sprs_score": {
            "type": "integer",
            "minimum": 0,
            "maximum": 110,
            "description": "Current SPRS compliance score",
        },
        "sprs_color": {
            "type": "string",
            "enum": ["green", "yellow", "red"],
            "description": "Badge color based on score thresholds",
        },
        "last_assessment": {
            "type": "string",
            "format": "date",
            "description": "Date of last compliance assessment",
        },
        "controls_passing": {
            "type": "integer",
            "minimum": 0,
            "description": "Number of controls in compliant state",
        },
        "controls_total": {
            "type": "integer",
            "minimum": 1,
            "description": "Total number of assessed controls",
        },
        "generated_at": {
            "type": "string",
            "format": "date-time",
            "description": "Timestamp when badge data was generated",
        },
    },
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate badge-data.json for dynamic README badges")
    parser.add_argument(
        "--assessment-file",
        type=Path,
        default=None,
        help="Explicit assessment JSON file (default: latest in data/assessment_history)",
    )
    parser.add_argument(
        "--history-dir",
        type=Path,
        default=DEFAULT_HISTORY_DIR,
        help="Assessment history directory (default: data/assessment_history)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Output path for badge data JSON (default: reports/badge-data.json)",
    )
    return parser.parse_args()


def _latest_json(path: Path) -> Path | None:
    if not path.exists():
        return None
    files = sorted(candidate for candidate in path.glob("*.json") if candidate.is_file())
    return files[-1] if files else None


def _clamp_sprs_score(score: int) -> int:
    return max(0, min(110, score))


def _sprs_color(score: int) -> str:
    if score >= 100:
        return "green"
    if score >= 80:
        return "yellow"
    return "red"


def _safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _default_controls_total() -> int:
    if not CONTROL_MAPPING_FILE.exists():
        return 110
    try:
        data = yaml.safe_load(CONTROL_MAPPING_FILE.read_text(encoding="utf-8")) or {}
    except yaml.YAMLError:
        return 110

    controls = data.get("controls", [])
    if isinstance(controls, list) and controls:
        return len(controls)
    return 110


def _derive_counts(assessment: dict[str, Any]) -> tuple[int, int]:
    controls = assessment.get("controls", [])
    if not isinstance(controls, list):
        total = _default_controls_total()
        return 0, total

    applicable = [
        control
        for control in controls
        if isinstance(control, dict) and str(control.get("status", "")).lower() != "not_applicable"
    ]
    total = len(applicable)
    passing = sum(1 for control in applicable if str(control.get("status", "")).lower() == "pass")

    if total == 0:
        total = _default_controls_total()
        passing = 0

    return passing, total


def _extract_last_assessment(assessment: dict[str, Any], source_path: Path | None) -> str:
    timestamp = str(assessment.get("timestamp", "")).strip()
    if timestamp:
        try:
            return datetime.fromisoformat(timestamp.replace("Z", "+00:00")).date().isoformat()
        except ValueError:
            pass

    if source_path is not None:
        stem = source_path.stem
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", stem):
            return stem

    return datetime.now(timezone.utc).date().isoformat()


def _load_assessment(path: Path) -> dict[str, Any]:
    content = path.read_text(encoding="utf-8")
    payload = json.loads(content)
    if not isinstance(payload, dict):
        raise ValueError(f"Assessment file must contain a JSON object: {path}")
    return payload


def _validate_badge_data(payload: dict[str, Any]) -> None:
    required = BADGE_DATA_SCHEMA["required"]
    for key in required:
        if key not in payload:
            raise ValueError(f"Missing required badge-data field: {key}")

    if not isinstance(payload["sprs_score"], int) or not (0 <= payload["sprs_score"] <= 110):
        raise ValueError("sprs_score must be an integer between 0 and 110")

    if payload["sprs_color"] not in {"green", "yellow", "red"}:
        raise ValueError("sprs_color must be one of: green, yellow, red")

    if not isinstance(payload["controls_passing"], int) or payload["controls_passing"] < 0:
        raise ValueError("controls_passing must be a non-negative integer")

    if not isinstance(payload["controls_total"], int) or payload["controls_total"] < 1:
        raise ValueError("controls_total must be an integer >= 1")

    if payload["controls_passing"] > payload["controls_total"]:
        raise ValueError("controls_passing cannot exceed controls_total")

    datetime.fromisoformat(payload["last_assessment"])
    datetime.fromisoformat(payload["generated_at"].replace("Z", "+00:00"))


def _fallback_badge_data() -> dict[str, Any]:
    score = 0
    total_controls = _default_controls_total()
    now = datetime.now(timezone.utc)
    return {
        "sprs_score": score,
        "sprs_color": _sprs_color(score),
        "last_assessment": now.date().isoformat(),
        "controls_passing": 0,
        "controls_total": total_controls,
        "generated_at": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def build_badge_data(assessment: dict[str, Any], source_path: Path | None) -> dict[str, Any]:
    score = _clamp_sprs_score(_safe_int(assessment.get("sprs_score"), 0))
    controls_passing, controls_total = _derive_counts(assessment)
    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    payload = {
        "sprs_score": score,
        "sprs_color": _sprs_color(score),
        "last_assessment": _extract_last_assessment(assessment, source_path),
        "controls_passing": controls_passing,
        "controls_total": controls_total,
        "generated_at": generated_at,
    }
    _validate_badge_data(payload)
    return payload


def main() -> int:
    args = parse_args()

    history_dir = args.history_dir if args.history_dir.is_absolute() else REPO_ROOT / args.history_dir
    output_path = args.output if args.output.is_absolute() else REPO_ROOT / args.output

    source_file: Path | None
    if args.assessment_file:
        source_file = args.assessment_file if args.assessment_file.is_absolute() else REPO_ROOT / args.assessment_file
    else:
        source_file = _latest_json(history_dir)

    if source_file is None:
        badge_data = _fallback_badge_data()
        print("No assessment JSON found; writing fallback badge data.")
    else:
        if not source_file.exists():
            print(f"ERROR: Assessment file not found: {source_file}", file=sys.stderr)
            return 2
        assessment = _load_assessment(source_file)
        badge_data = build_badge_data(assessment, source_file)

    _validate_badge_data(badge_data)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(badge_data, indent=2) + "\n", encoding="utf-8")

    print(f"Generated badge data: {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
