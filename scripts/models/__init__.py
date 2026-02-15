from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any, TypeVar

import yaml
from pydantic import BaseModel, ValidationError

from .control_mapping import ControlMappingData, FrameworkMapping, SecurityControl
from .glossary import AudienceContext, GlossaryData, GlossaryTerm
from .hpc_tailoring import HPCTailoringData, HPCTailoringEntry
from .odp_values import ODPValue, ODPValuesData


ModelT = TypeVar("ModelT", bound=BaseModel)
REPO_ROOT = Path(__file__).resolve().parents[2]


@lru_cache(maxsize=32)
def load_yaml_cached(file_path: str | Path) -> dict[str, Any]:
    path = Path(file_path)
    if not path.is_absolute():
        path = REPO_ROOT / path

    with path.open("r", encoding="utf-8") as handle:
        content = yaml.safe_load(handle) or {}

    if not isinstance(content, dict):
        raise ValueError(f"{path} did not contain a YAML mapping at the root")
    return content


def clear_yaml_cache() -> None:
    load_yaml_cached.cache_clear()


def validate_yaml(file_path: str | Path, model_class: type[ModelT]) -> ModelT:
    data = load_yaml_cached(file_path)
    try:
        return model_class.model_validate(data)
    except ValidationError as exc:
        lines: list[str] = [f"Validation failed for {file_path}:"]
        for error in exc.errors():
            location = ".".join(str(part) for part in error["loc"])
            lines.append(f"  - {location}: {error['msg']}")
        raise ValueError("\n".join(lines)) from exc


__all__ = [
    "AudienceContext",
    "ControlMappingData",
    "FrameworkMapping",
    "GlossaryData",
    "GlossaryTerm",
    "HPCTailoringData",
    "HPCTailoringEntry",
    "ODPValue",
    "ODPValuesData",
    "SecurityControl",
    "clear_yaml_cache",
    "load_yaml_cached",
    "validate_yaml",
]
