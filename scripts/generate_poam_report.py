#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import io
import subprocess
import sys
from dataclasses import dataclass
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any

import yaml
from jinja2 import Environment, FileSystemLoader, StrictUndefined
from pydantic import BaseModel, Field, ValidationError

REPO_ROOT = Path(__file__).resolve().parents[1]


class Milestone(BaseModel):
    id: str | None = None
    description: str
    target_date: date
    actual_completion_date: date | None = None
    status: str
    notes: str | None = None
    blocker: str | None = None


class Weakness(BaseModel):
    description: str
    plain_language: str = Field(min_length=20)
    root_cause: str | None = None


class Resource(BaseModel):
    name: str
    allocation: str


class POAMItem(BaseModel):
    id: str
    control_id: str
    control_title: str
    weakness: Weakness
    risk_level: str
    risk_justification: str | None = None
    milestones: list[Milestone] = Field(min_length=1)
    resources: list[Resource] = Field(default_factory=list)
    status: str
    days_overdue: int | None = None
    created_date: date
    last_updated: date
    completion_date: date | None = None
    sprs_credit: bool = False


class POAMData(BaseModel):
    version: str
    last_updated: str
    description: str
    poam_items: list[POAMItem]


@dataclass(slots=True)
class GroupedPOAM:
    overdue: list[dict[str, Any]]
    in_progress: list[dict[str, Any]]
    completed: list[dict[str, Any]]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate POA&M markdown and CSV reports")
    parser.add_argument(
        "--input",
        type=Path,
        default=REPO_ROOT / "data" / "poam.yml",
        help="Path to POA&M YAML data",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "reports",
        help="Directory where poam.md and poam.csv are written",
    )
    parser.add_argument(
        "--skip-glossary-check",
        action="store_true",
        help="Skip validate_glossary.py run over generated markdown",
    )
    return parser.parse_args()


def load_poam_data(path: Path) -> POAMData:
    raw = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    try:
        return POAMData.model_validate(raw)
    except ValidationError as exc:
        details = "; ".join(
            f"{'.'.join(str(part) for part in err['loc'])}: {err['msg']}" for err in exc.errors()
        )
        raise ValueError(f"Invalid POA&M schema at {path}: {details}") from exc


def _days_overdue(item: POAMItem, today: date) -> int | None:
    if item.status in {"completed", "cancelled"}:
        return None

    overdue_days: list[int] = []
    for milestone in item.milestones:
        if milestone.status == "completed":
            continue
        delta = (today - milestone.target_date).days
        if delta > 0:
            overdue_days.append(delta)

    return max(overdue_days) if overdue_days else None


def _next_milestone(item: POAMItem) -> Milestone | None:
    pending = [m for m in item.milestones if m.status != "completed"]
    if not pending:
        return None
    return sorted(pending, key=lambda m: m.target_date)[0]


def enrich_items(data: POAMData) -> list[dict[str, Any]]:
    today = date.today()
    enriched: list[dict[str, Any]] = []

    for item in data.poam_items:
        overdue = _days_overdue(item, today)
        next_m = _next_milestone(item)
        resource_summary = "; ".join(f"{r.name} ({r.allocation})" for r in item.resources)

        enriched.append(
            {
                **item.model_dump(),
                "days_overdue": overdue,
                "next_milestone": next_m.description if next_m else "none",
                "target_date": str(next_m.target_date) if next_m else "",
                "resource_summary": resource_summary,
            }
        )
    return enriched


def group_items(items: list[dict[str, Any]]) -> GroupedPOAM:
    overdue: list[dict[str, Any]] = []
    in_progress: list[dict[str, Any]] = []
    completed: list[dict[str, Any]] = []

    for item in items:
        if item["status"] == "completed":
            completed.append(item)
            continue
        if item["days_overdue"] is not None:
            overdue.append(item)
            continue
        in_progress.append(item)

    return GroupedPOAM(overdue=overdue, in_progress=in_progress, completed=completed)


def _environment() -> Environment:
    return Environment(
        loader=FileSystemLoader(str(REPO_ROOT / "templates")),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )


def render_markdown(items: list[dict[str, Any]], grouped: GroupedPOAM) -> str:
    env = _environment()
    template = env.get_template("reports/poam_report.md.j2")
    return template.render(
        items=items,
        grouped={
            "overdue": grouped.overdue,
            "in_progress": grouped.in_progress,
            "completed": grouped.completed,
        },
        generated_at=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    )


def render_csv(items: list[dict[str, Any]]) -> str:
    env = _environment()
    template = env.get_template("reports/poam_report.csv.j2")
    content = template.render(items=items)

    # Ensure syntactic CSV correctness.
    _ = list(csv.reader(io.StringIO(content)))
    return content


def run_glossary_check(markdown_path: Path) -> int:
    cmd = [
        sys.executable,
        str(REPO_ROOT / "scripts" / "validate_glossary.py"),
        "--glossary",
        str(REPO_ROOT / "docs" / "glossary" / "terms.yml"),
        "--scan-dirs",
        str(markdown_path.parent),
        "--file-types",
        ".md",
    ]
    proc = subprocess.run(cmd, cwd=REPO_ROOT, check=False, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
    return proc.returncode


def main() -> int:
    args = parse_args()

    input_path = args.input if args.input.is_absolute() else REPO_ROOT / args.input
    if not input_path.exists():
        print(f"ERROR: Missing POA&M input file: {input_path}", file=sys.stderr)
        return 2

    output_dir = args.output_dir if args.output_dir.is_absolute() else REPO_ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    try:
        data = load_poam_data(input_path)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    items = enrich_items(data)
    grouped = group_items(items)

    markdown = render_markdown(items, grouped)
    csv_output = render_csv(items)

    markdown_path = output_dir / "poam.md"
    csv_path = output_dir / "poam.csv"

    markdown_path.write_text(markdown, encoding="utf-8")
    csv_path.write_text(csv_output, encoding="utf-8", newline="")

    if not args.skip_glossary_check:
        rc = run_glossary_check(markdown_path)
        if rc != 0:
            print("ERROR: POA&M plain-language glossary validation failed", file=sys.stderr)
            return rc

    print(f"Generated POA&M reports: {markdown_path}, {csv_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
