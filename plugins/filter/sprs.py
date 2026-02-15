"""SPRS scoring filters for compliance assessment data."""
from __future__ import annotations

import math
from pathlib import Path
from typing import Any

import yaml

REPO_ROOT = Path(__file__).resolve().parents[2]
DEFAULT_WEIGHTS_FILE = REPO_ROOT / "data" / "sprs_weights.yml"
DEFAULT_POAM_FILE = REPO_ROOT / "data" / "poam.yml"
BASELINE_SCORE = 110

FAIL_STATUSES = {"fail", "not_assessed", "error", "partial"}
PASS_STATUSES = {"pass"}
SKIP_STATUSES = {"not_applicable"}


def _normalize_control_id(control_id: str) -> str:
    return str(control_id).strip()


def load_control_weights(weights_path: str | Path | None = None) -> dict[str, dict[str, Any]]:
    """Load control weights from YAML and return mapping keyed by control_id."""
    source = Path(weights_path) if weights_path else DEFAULT_WEIGHTS_FILE
    if not source.is_absolute():
        source = REPO_ROOT / source

    if not source.exists():
        return {}

    with source.open("r", encoding="utf-8") as handle:
        data = yaml.safe_load(handle) or {}

    weight_entries = data.get("weights", [])
    mapping: dict[str, dict[str, Any]] = {}
    for entry in weight_entries:
        control_id = _normalize_control_id(entry.get("control_id", ""))
        if not control_id:
            continue
        mapping[control_id] = {
            "weight": int(entry.get("weight", 1)),
            "family": str(entry.get("family", control_id.split(".", 1)[0])).upper(),
            "rationale": str(entry.get("rationale", "")),
        }
    return mapping


def _load_poam(poam_data: dict[str, Any] | None = None) -> dict[str, Any]:
    if poam_data is not None:
        return poam_data
    if not DEFAULT_POAM_FILE.exists():
        return {"poam_items": []}

    with DEFAULT_POAM_FILE.open("r", encoding="utf-8") as handle:
        return yaml.safe_load(handle) or {"poam_items": []}


def _poam_credit_controls(poam_data: dict[str, Any] | None = None) -> set[str]:
    poam = _load_poam(poam_data)
    credit_controls: set[str] = set()
    for item in poam.get("poam_items", []):
        status = str(item.get("status", "")).lower()
        if status in {"completed", "cancelled"}:
            continue
        if not item.get("sprs_credit", False):
            continue
        control_id = _normalize_control_id(item.get("control_id", ""))
        if control_id:
            credit_controls.add(control_id)
    return credit_controls


def control_weight(
    control_id: str,
    weights: dict[str, dict[str, Any]] | None = None,
) -> int:
    """Return configured SPRS deduction weight for a control ID."""
    weight_map = weights if weights is not None else load_control_weights()
    control_id = _normalize_control_id(control_id)
    if control_id in weight_map:
        return int(weight_map[control_id]["weight"])
    return 1


def format_deduction(control_id: str, weight: int, control_title: str | None = None) -> str:
    """Return plain-language deduction summary."""
    title = f" ({control_title})" if control_title else ""
    return f"Control {control_id}{title} is not fully implemented: -{weight} points"


def _family_for_control(control_id: str, weights: dict[str, dict[str, Any]], fallback: str | None) -> str:
    if fallback:
        return str(fallback).upper()
    if control_id in weights:
        return str(weights[control_id].get("family", "UNASSIGNED")).upper()
    try:
        return control_id.split(".", 2)[0].upper()
    except Exception:  # noqa: BLE001
        return "UNASSIGNED"


def _effort_estimate(weight: int) -> str:
    if weight >= 5:
        return "high"
    if weight >= 3:
        return "medium"
    return "low"


def _controls_from_assessment(assessment_results: dict[str, Any]) -> list[dict[str, Any]]:
    if not isinstance(assessment_results, dict):
        return []
    controls = assessment_results.get("controls", [])
    if isinstance(controls, list):
        return [item for item in controls if isinstance(item, dict)]
    return []


def sprs_breakdown(
    assessment_results: dict[str, Any],
    poam_data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Return detailed SPRS deductions, family rollups, and recommendations."""
    weights = load_control_weights()
    credit_controls = _poam_credit_controls(poam_data)

    by_family: dict[str, dict[str, int]] = {}
    deductions: list[dict[str, Any]] = []
    recommendations: list[dict[str, Any]] = []

    for control in _controls_from_assessment(assessment_results):
        control_id = _normalize_control_id(control.get("control_id", ""))
        if not control_id:
            continue

        status = str(control.get("status", "")).lower()
        family = _family_for_control(control_id, weights, control.get("family"))
        weight = control_weight(control_id, weights)

        if family not in by_family:
            by_family[family] = {
                "controls_total": 0,
                "controls_passing": 0,
                "controls_failing": 0,
                "deduction_points": 0,
            }

        by_family[family]["controls_total"] += 1

        if status in PASS_STATUSES:
            by_family[family]["controls_passing"] += 1
            continue

        if status in SKIP_STATUSES:
            continue

        if status not in FAIL_STATUSES:
            status = "fail"

        by_family[family]["controls_failing"] += 1

        has_poam_credit = control_id in credit_controls
        effective_deduction = weight
        if has_poam_credit:
            effective_deduction = int(math.ceil(weight / 2.0))

        by_family[family]["deduction_points"] += effective_deduction

        control_title = str(control.get("control_title") or control.get("title") or "")
        deduction = {
            "control_id": control_id,
            "control_title": control_title,
            "family": family,
            "weight": weight,
            "plain_language": format_deduction(control_id, weight, control_title),
            "poam_credit": has_poam_credit,
            "effective_deduction": effective_deduction,
            "status": status,
        }
        deductions.append(deduction)

        recommendations.append(
            {
                "control_id": control_id,
                "control_title": control_title,
                "weight": weight,
                "effort_estimate": _effort_estimate(weight),
                "impact_description": (
                    f"Implementing control {control_id} can recover up to {weight} SPRS points."
                ),
            }
        )

    total_deductions = sum(item["effective_deduction"] for item in deductions)
    total_credit = sum(item["weight"] - item["effective_deduction"] for item in deductions)
    total_score = BASELINE_SCORE - total_deductions
    total_score = max(-203, min(BASELINE_SCORE, total_score))

    recommendations = sorted(recommendations, key=lambda item: item["weight"], reverse=True)

    return {
        "total_score": int(total_score),
        "baseline_score": BASELINE_SCORE,
        "total_deductions": int(total_deductions),
        "by_family": dict(sorted(by_family.items())),
        "deductions": deductions,
        "poam_adjustments": {
            "items_with_credit": sum(1 for item in deductions if item["poam_credit"]),
            "total_credit": int(total_credit),
        },
        "recommendations": recommendations,
    }


def sprs_score(assessment_results: dict[str, Any], poam_data: dict[str, Any] | None = None) -> int:
    """Calculate SPRS score from assessment results and optional POA&M credit data."""
    return int(sprs_breakdown(assessment_results, poam_data)["total_score"])


class FilterModule:
    """Ansible filter plugin entrypoint."""

    def filters(self) -> dict[str, Any]:
        return {
            "sprs_score": sprs_score,
            "sprs_breakdown": sprs_breakdown,
            "control_weight": control_weight,
            "format_deduction": format_deduction,
            "load_control_weights": load_control_weights,
        }
