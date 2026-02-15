from __future__ import annotations

import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
PLUGIN_DIR = REPO_ROOT / "plugins" / "filter"
if str(PLUGIN_DIR) not in sys.path:
    sys.path.insert(0, str(PLUGIN_DIR))

import sprs  # noqa: E402


def _assessment_with_status(status_by_control: dict[str, str]) -> dict[str, object]:
    return {
        "assessment_id": "00000000-0000-0000-0000-000000000001",
        "timestamp": "2026-02-15T00:00:00Z",
        "enclave_name": "test-enclave",
        "controls": [
            {
                "control_id": control_id,
                "control_title": f"Control {control_id}",
                "family": "AC",
                "status": status,
            }
            for control_id, status in status_by_control.items()
        ],
    }


def test_load_control_weights_contains_all_controls() -> None:
    weights = sprs.load_control_weights()
    assert len(weights) == 110


def test_sprs_score_matches_manual_calculation_for_10_pass_5_fail() -> None:
    weights = sprs.load_control_weights()
    controls = sorted(weights.keys())[:15]

    passing = controls[:10]
    failing = controls[10:]

    status_by_control = {cid: "pass" for cid in passing}
    status_by_control.update({cid: "fail" for cid in failing})

    assessment = _assessment_with_status(status_by_control)
    expected_deductions = sum(sprs.control_weight(cid, weights) for cid in failing)
    expected_score = max(-203, 110 - expected_deductions)

    assert sprs.sprs_score(assessment) == expected_score


def test_sprs_breakdown_reports_poam_credit_adjustment() -> None:
    weights = sprs.load_control_weights()
    control_id = sorted(weights.keys())[0]

    assessment = _assessment_with_status({control_id: "fail"})
    poam_data = {
        "poam_items": [
            {
                "id": "POAM-900",
                "control_id": control_id,
                "status": "in_progress",
                "sprs_credit": True,
            }
        ]
    }

    breakdown = sprs.sprs_breakdown(assessment, poam_data)
    assert breakdown["poam_adjustments"]["items_with_credit"] == 1
    assert breakdown["deductions"][0]["poam_credit"] is True
    assert breakdown["deductions"][0]["effective_deduction"] <= breakdown["deductions"][0]["weight"]


def test_format_deduction_plain_language() -> None:
    msg = sprs.format_deduction("3.5.3", 5, "Multi-factor authentication")
    assert "3.5.3" in msg
    assert "-5 points" in msg
