#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, StrictUndefined

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from models import ControlMappingData, load_yaml_cached  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate plain-language SSP control narratives")
    parser.add_argument(
        "--control-mapping",
        type=Path,
        default=REPO_ROOT / "roles" / "common" / "vars" / "control_mapping.yml",
        help="Path to control mapping YAML",
    )
    parser.add_argument(
        "--template",
        type=Path,
        default=REPO_ROOT / "templates" / "narratives" / "control_narrative.md.j2",
        help="Narrative template path",
    )
    parser.add_argument(
        "--evidence-dir",
        type=Path,
        default=REPO_ROOT / "docs" / "auditor_packages",
        help="Evidence root used to discover references",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=REPO_ROOT / "docs" / "generated" / "narratives",
        help="Output directory for generated narrative markdown",
    )
    parser.add_argument(
        "--skip-glossary-check",
        action="store_true",
        help="Skip validate_glossary.py invocation",
    )
    return parser.parse_args()


def _environment(template_root: Path) -> Environment:
    return Environment(
        loader=FileSystemLoader(str(template_root)),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )


def _slug(control_id: str) -> str:
    return control_id.replace(".", "_")


def _find_evidence_refs(evidence_dir: Path, family: str) -> list[dict[str, str]]:
    refs: list[dict[str, str]] = []
    if not evidence_dir.exists():
        return refs

    candidates = sorted(evidence_dir.rglob(f"*{family}*"))
    for candidate in candidates[:5]:
        if candidate.is_file():
            refs.append(
                {
                    "file_path": str(candidate.relative_to(REPO_ROOT)),
                    "description": f"Evidence artifact related to {family} control implementation",
                }
            )
    return refs


def _implementation_description(control: Any) -> str:
    roles = ", ".join(control.ansible_roles) if control.ansible_roles else "documented operational procedures"
    return (
        f"This control is implemented through {roles}. "
        f"The intent is: {control.plain_language.strip()} "
        "Evidence files listed below show verification outputs and configuration state for auditor review."
    )


def _run_glossary_validation(output_dir: Path) -> int:
    cmd = [
        sys.executable,
        str(REPO_ROOT / "scripts" / "validate_glossary.py"),
        "--glossary",
        str(REPO_ROOT / "docs" / "glossary" / "terms.yml"),
        "--scan-dirs",
        str(output_dir),
    ]
    proc = subprocess.run(cmd, cwd=REPO_ROOT, check=False, capture_output=True, text=True)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr)
    return proc.returncode


def main() -> int:
    args = parse_args()

    mapping_path = args.control_mapping if args.control_mapping.is_absolute() else REPO_ROOT / args.control_mapping
    data = load_yaml_cached(mapping_path)
    mapping = ControlMappingData.model_validate(data)

    template_path = args.template if args.template.is_absolute() else REPO_ROOT / args.template
    env = _environment(template_path.parent.parent)
    template = env.get_template("narratives/control_narrative.md.j2")

    evidence_dir = args.evidence_dir if args.evidence_dir.is_absolute() else REPO_ROOT / args.evidence_dir
    output_dir = args.output_dir if args.output_dir.is_absolute() else REPO_ROOT / args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    generated_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    for control in sorted(mapping.controls, key=lambda item: item.control_id):
        content = template.render(
            control=control,
            generated_at=generated_at,
            implementation_description=_implementation_description(control),
            evidence_references=_find_evidence_refs(evidence_dir, control.family),
        )
        output_file = output_dir / f"control_{_slug(control.control_id)}.md"
        output_file.write_text(content, encoding="utf-8")

    if not args.skip_glossary_check:
        rc = _run_glossary_validation(output_dir)
        if rc != 0:
            print("ERROR: Narrative glossary validation failed", file=sys.stderr)
            return rc

    print(f"Generated narratives: {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
