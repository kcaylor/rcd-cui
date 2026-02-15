#!/usr/bin/env python3
"""Redact secrets from evidence artifacts while preserving file structure."""
from __future__ import annotations

import argparse
import re
from pathlib import Path
from typing import Iterable

REDACTION_PATTERNS: list[tuple[re.Pattern[str], str | re.Callable[[re.Match[str]], str]]] = [
    (
        re.compile(
            r"(?im)\b(password|passwd|secret|token|credential)\b(\s*[=:]\s*)([\"']?)([^\"'\s#]+)(\3)"
        ),
        lambda m: f"{m.group(1)}{m.group(2)}{m.group(3)}[REDACTED]{m.group(3)}",
    ),
    (
        re.compile(r"(?im)\b(api[_-]?key|apikey|access_key|secret_key)\b(\s*[=:]\s*)([\"']?)([^\"'\s#]+)(\3)"),
        lambda m: f"{m.group(1)}{m.group(2)}{m.group(3)}[REDACTED]{m.group(3)}",
    ),
    (
        re.compile(r"(?s)-----BEGIN[ A-Z]*PRIVATE KEY-----.*?-----END[ A-Z]*PRIVATE KEY-----"),
        "[REDACTED PRIVATE KEY]",
    ),
    (re.compile(r"\b(?:AKIA|ABIA|ACCA|ASIA)[A-Z0-9]{16}\b"), "[REDACTED]"),
    (
        re.compile(r"(?im)\b(ikey|skey)\b(\s*[=:]\s*)([A-Za-z0-9]{20,})"),
        lambda m: f"{m.group(1)}{m.group(2)}[REDACTED]",
    ),
]

TEXT_FILE_SUFFIXES = {
    ".txt",
    ".cfg",
    ".conf",
    ".ini",
    ".json",
    ".yaml",
    ".yml",
    ".xml",
    ".md",
    ".log",
    ".service",
    ".rules",
    ".j2",
    ".sh",
    "",
}


def redact_text(text: str) -> tuple[str, int]:
    redaction_count = 0
    updated = text
    for pattern, replacement in REDACTION_PATTERNS:
        updated, count = pattern.subn(replacement, updated)
        redaction_count += count
    return updated, redaction_count


def redact_file(source_file: Path, destination_file: Path | None = None) -> int:
    """Redact one file and return number of replacements applied."""
    source_file = Path(source_file)
    output = Path(destination_file) if destination_file else source_file

    raw = source_file.read_text(encoding="utf-8", errors="ignore")
    redacted, count = redact_text(raw)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(redacted, encoding="utf-8")
    return count


def _iter_candidate_files(root_dir: Path) -> Iterable[Path]:
    for path in root_dir.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() in TEXT_FILE_SUFFIXES:
            yield path


def redact_directory(source_dir: Path, output_dir: Path | None = None) -> tuple[int, int]:
    """Redact all supported files under a directory.

    Returns `(files_processed, redaction_count)`.
    """
    source_dir = Path(source_dir)
    target_dir = Path(output_dir) if output_dir else source_dir

    files_processed = 0
    redaction_count = 0

    for input_file in _iter_candidate_files(source_dir):
        relative = input_file.relative_to(source_dir)
        output_file = target_dir / relative
        redaction_count += redact_file(input_file, output_file)
        files_processed += 1

    return files_processed, redaction_count


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Redact secrets from files or directories")
    parser.add_argument("path", type=Path, help="File or directory to redact")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help="Write redacted output to this directory (directory mode only).",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    target = args.path

    if not target.exists():
        print(f"ERROR: Path does not exist: {target}")
        return 2

    if target.is_file():
        count = redact_file(target)
        print(f"Redacted {count} secret value(s) in {target}")
        return 0

    files_processed, count = redact_directory(target, args.output_dir)
    mode = f" -> {args.output_dir}" if args.output_dir else " (in place)"
    print(f"Redacted {count} secret value(s) across {files_processed} file(s){mode}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
