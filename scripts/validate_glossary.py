#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Iterable

from pydantic import ValidationError

SCRIPT_DIR = Path(__file__).resolve().parent
if str(SCRIPT_DIR) not in sys.path:
    sys.path.insert(0, str(SCRIPT_DIR))

from models import GlossaryData, clear_yaml_cache, load_yaml_cached  # noqa: E402


REPO_ROOT = SCRIPT_DIR.parent
ACRONYM_PATTERN = re.compile(r"\b([A-Z][A-Z0-9]{1,})\b")
CONTEXT_PATTERN = re.compile(r"^(.+?)\s+\(([^)]+)\)$")

DEFAULT_SCAN_DIRS = ["docs", "roles", "templates"]
DEFAULT_FILE_TYPES = [".md", ".yml", ".j2"]

# Ignore file-format and build-system tokens that are not glossary terms.
EXCLUDED_TERMS = {
    "MD",
    "YML",
    "J2",
    "CSV",
    "UTF",
    "BOM",
    "EOF",
    "TODO",
    "README",
    "JSON",
    "API",
    "CLI",
    "CI",
    "CD",
    "URL",
    "HTTP",
    "HTTPS",
    "ISO",
    "ID",
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate acronym coverage against glossary terms.")
    parser.add_argument(
        "--glossary",
        type=Path,
        default=REPO_ROOT / "docs" / "glossary" / "terms.yml",
        help="Path to glossary YAML (default: docs/glossary/terms.yml)",
    )
    parser.add_argument(
        "--scan-dirs",
        nargs="+",
        default=DEFAULT_SCAN_DIRS,
        help="Directories to scan recursively.",
    )
    parser.add_argument(
        "--file-types",
        nargs="+",
        default=DEFAULT_FILE_TYPES,
        help="File extensions to scan.",
    )
    return parser.parse_args()


def extract_acronyms(text: str) -> set[str]:
    return {match.group(1) for match in ACRONYM_PATTERN.finditer(text)}


def _build_term_index(glossary: GlossaryData) -> tuple[set[str], dict[str, set[str]]]:
    exact: set[str] = set()
    contextual: dict[str, set[str]] = defaultdict(set)

    for key in glossary.terms:
        exact.add(key)
        match = CONTEXT_PATTERN.match(key)
        if match:
            base = match.group(1)
            context = match.group(2)
            contextual[base].add(context)

    return exact, contextual


def is_term_defined(term: str, line: str, exact: set[str], contextual: dict[str, set[str]]) -> bool:
    if term in exact:
        return True

    if term in contextual:
        for context in contextual[term]:
            if f"{term} ({context})" in line:
                return True
        return False

    return False


def iter_files(scan_dirs: Iterable[str], file_types: set[str]) -> Iterable[Path]:
    for directory in scan_dirs:
        base = Path(directory)
        if not base.is_absolute():
            base = REPO_ROOT / base
        if not base.exists():
            continue

        for path in base.rglob("*"):
            if path.is_file() and path.suffix in file_types:
                yield path


def scan_file(
    path: Path,
    exact: set[str],
    contextual: dict[str, set[str]],
) -> list[tuple[int, str]]:
    violations: list[tuple[int, str]] = []
    in_code_fence = False

    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if line.strip().startswith("```"):
            in_code_fence = not in_code_fence
            continue
        if in_code_fence:
            continue

        for term in extract_acronyms(line):
            if term in EXCLUDED_TERMS:
                continue
            if not is_term_defined(term, line, exact, contextual):
                violations.append((line_no, term))

    return violations


def load_glossary(glossary_path: Path) -> GlossaryData:
    clear_yaml_cache()
    raw = load_yaml_cached(glossary_path)
    try:
        return GlossaryData.model_validate(raw)
    except ValidationError as exc:
        details = "; ".join(
            f"{'.'.join(str(part) for part in err['loc'])}: {err['msg']}" for err in exc.errors()
        )
        raise ValueError(f"Invalid glossary schema at {glossary_path}: {details}") from exc


def main() -> int:
    args = parse_args()

    try:
        glossary = load_glossary(args.glossary)
    except Exception as exc:  # noqa: BLE001
        print(f"ERROR: {exc}", file=sys.stderr)
        return 2

    exact, contextual = _build_term_index(glossary)
    file_types = set(args.file_types)
    violations_by_file: dict[Path, list[tuple[int, str]]] = {}

    for file_path in iter_files(args.scan_dirs, file_types):
        violations = scan_file(file_path, exact, contextual)
        if violations:
            violations_by_file[file_path] = violations

    if violations_by_file:
        print("ERROR: Undefined terms found:", file=sys.stderr)
        for file_path in sorted(violations_by_file):
            print(f"\nFile: {file_path}", file=sys.stderr)
            for line_no, term in violations_by_file[file_path]:
                print(f"  line {line_no}: {term}", file=sys.stderr)
        print(
            f"\n{sum(len(v) for v in violations_by_file.values())} undefined term occurrence(s).",
            file=sys.stderr,
        )
        return 1

    print("All terms validated.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
