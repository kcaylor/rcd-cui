#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any

from jinja2 import Environment, FileSystemLoader, StrictUndefined
from pydantic import ValidationError

# Ensure local imports resolve when script is run from repo root.
SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from models import (  # noqa: E402
    ControlMappingData,
    GlossaryData,
    HPCTailoringData,
    ODPValuesData,
    clear_yaml_cache,
    load_yaml_cached,
)


REPO_ROOT = SCRIPT_DIR.parent
DEFAULT_OUTPUT_DIR = REPO_ROOT / "docs" / "generated"
TEMPLATE_DIR = REPO_ROOT / "templates"

YAML_SOURCES = {
    "control_mapping": REPO_ROOT / "roles" / "common" / "vars" / "control_mapping.yml",
    "glossary": REPO_ROOT / "docs" / "glossary" / "terms.yml",
    "hpc_tailoring": REPO_ROOT / "docs" / "hpc_tailoring.yml",
    "odp_values": REPO_ROOT / "docs" / "odp_values.yml",
}

TEMPLATE_OUTPUTS = {
    "pi_guide.md.j2": "pi_guide.md",
    "researcher_quickstart.md.j2": "researcher_quickstart.md",
    "sysadmin_reference.md.j2": "sysadmin_reference.md",
    "ciso_compliance_map.md.j2": "ciso_compliance_map.md",
    "leadership_briefing.md.j2": "leadership_briefing.md",
    "glossary_full.md.j2": "glossary_full.md",
    "crosswalk.csv.j2": "crosswalk.csv",
}

ACRONYM_PATTERN = re.compile(r"\b([A-Z][A-Z0-9]{1,})\b")


class DataValidationError(RuntimeError):
    pass


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Generate audience-specific compliance documentation.")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory for generated files (default: docs/generated)",
    )
    parser.add_argument(
        "--validate-only",
        action="store_true",
        help="Validate YAML models without generating outputs.",
    )
    parser.add_argument(
        "--only",
        choices=["all", "crosswalk"],
        default="all",
        help="Generate all outputs (default) or only the crosswalk CSV.",
    )
    return parser.parse_args()


def _entry_id_from_error(data: dict[str, Any], loc: tuple[Any, ...]) -> str | None:
    if not loc:
        return None

    root = loc[0]
    if root == "controls" and len(loc) > 1 and isinstance(loc[1], int):
        idx = loc[1]
        controls = data.get("controls", [])
        if 0 <= idx < len(controls):
            return controls[idx].get("control_id")

    if root == "terms" and len(loc) > 1:
        key = loc[1]
        if isinstance(key, str):
            return key

    if root == "tailoring_decisions" and len(loc) > 1 and isinstance(loc[1], int):
        idx = loc[1]
        entries = data.get("tailoring_decisions", [])
        if 0 <= idx < len(entries):
            return entries[idx].get("tailoring_id")

    if root == "odp_values" and len(loc) > 1 and isinstance(loc[1], int):
        idx = loc[1]
        entries = data.get("odp_values", [])
        if 0 <= idx < len(entries):
            return entries[idx].get("odp_id")

    return None


def _format_validation_error(path: Path, data: dict[str, Any], exc: ValidationError) -> str:
    lines = [f"ERROR: Validation failed for {path}"]
    for error in exc.errors():
        loc = tuple(error.get("loc", ()))
        field = ".".join(str(part) for part in loc) if loc else "<root>"
        entry = _entry_id_from_error(data, loc)
        entry_text = f" | entry={entry}" if entry else ""
        lines.append(f"  field={field}{entry_text} | error={error['msg']}")
    return "\n".join(lines)


def load_and_validate(path: Path, model_class: type[Any]) -> Any:
    raw = load_yaml_cached(path)
    try:
        return model_class.model_validate(raw)
    except ValidationError as exc:
        raise DataValidationError(_format_validation_error(path, raw, exc)) from exc


def slugify(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return f"term-{slug}" if slug else "term"


def build_term_anchor_map(glossary: GlossaryData) -> dict[str, str]:
    mapping: dict[str, str] = {}
    for key, term in sorted(glossary.terms.items()):
        anchor = slugify(key)
        mapping[key] = anchor

        # Allow acronym lookup to resolve to compliance context by default.
        context_match = re.match(r"^(.+?)\s+\(([^)]+)\)$", key)
        if context_match:
            base = context_match.group(1)
            context = context_match.group(2)
            if context == "compliance" or base not in mapping:
                mapping[base] = anchor
    return mapping


def link_terms(text: str, term_anchors: dict[str, str]) -> str:
    def _replace(match: re.Match[str]) -> str:
        token = match.group(1)
        start = match.start(1)
        if start > 0 and text[start - 1] == "[":
            return token

        anchor = term_anchors.get(token)
        if not anchor:
            return token
        return f"[{token}](glossary_full.md#{anchor})"

    return ACRONYM_PATTERN.sub(_replace, text)


def create_environment(glossary: GlossaryData) -> Environment:
    env = Environment(
        loader=FileSystemLoader(str(TEMPLATE_DIR)),
        undefined=StrictUndefined,
        trim_blocks=True,
        lstrip_blocks=True,
        keep_trailing_newline=True,
    )

    term_anchors = build_term_anchor_map(glossary)
    env.filters["link_terms"] = lambda value: link_terms(str(value), term_anchors)
    env.filters["slugify"] = slugify
    return env


def _sorted_controls(control_data: ControlMappingData) -> list[Any]:
    return sorted(control_data.controls, key=lambda item: item.control_id)


def _sorted_terms(glossary_data: GlossaryData) -> list[tuple[str, Any]]:
    return sorted(glossary_data.terms.items(), key=lambda item: item[0].lower())


def build_context(
    control_data: ControlMappingData,
    glossary_data: GlossaryData,
    hpc_data: HPCTailoringData,
    odp_data: ODPValuesData,
) -> dict[str, Any]:
    return {
        "control_data": control_data,
        "controls": _sorted_controls(control_data),
        "glossary_data": glossary_data,
        "terms": _sorted_terms(glossary_data),
        "hpc_data": hpc_data,
        "hpc_entries": sorted(hpc_data.tailoring_decisions, key=lambda item: item.tailoring_id),
        "odp_data": odp_data,
        "odp_entries": sorted(odp_data.odp_values, key=lambda item: item.odp_id),
    }


def render_documents(env: Environment, context: dict[str, Any], only: str = "all") -> dict[str, str]:
    outputs: dict[str, str] = {}
    for template_name, output_name in TEMPLATE_OUTPUTS.items():
        if only == "crosswalk" and output_name != "crosswalk.csv":
            continue
        template = env.get_template(template_name)
        outputs[output_name] = template.render(**context)
    return outputs


def verify_deterministic(env: Environment, context: dict[str, Any], only: str = "all") -> None:
    first = render_documents(env, context, only)
    second = render_documents(env, context, only)
    if first != second:
        raise RuntimeError("Deterministic output verification failed: repeated renders differ")


def write_outputs(output_dir: Path, rendered: dict[str, str]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for filename, content in sorted(rendered.items()):
        output_path = output_dir / filename
        if filename.endswith(".csv"):
            output_path.write_text(content, encoding="utf-8-sig", newline="")
        else:
            output_path.write_text(content, encoding="utf-8")


def main() -> int:
    args = parse_args()

    missing = [str(path) for path in YAML_SOURCES.values() if not path.exists()]
    if missing:
        print("ERROR: Missing required YAML files:", file=sys.stderr)
        for item in missing:
            print(f"  - {item}", file=sys.stderr)
        return 2

    clear_yaml_cache()
    try:
        control_data = load_and_validate(YAML_SOURCES["control_mapping"], ControlMappingData)
        glossary_data = load_and_validate(YAML_SOURCES["glossary"], GlossaryData)
        hpc_data = load_and_validate(YAML_SOURCES["hpc_tailoring"], HPCTailoringData)
        odp_data = load_and_validate(YAML_SOURCES["odp_values"], ODPValuesData)
    except DataValidationError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if args.validate_only:
        print("Validation successful.")
        return 0

    env = create_environment(glossary_data)
    context = build_context(control_data, glossary_data, hpc_data, odp_data)

    verify_deterministic(env, context, args.only)
    rendered = render_documents(env, context, args.only)
    write_outputs(args.output_dir, rendered)

    print(f"Generated {len(rendered)} file(s) in {args.output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
