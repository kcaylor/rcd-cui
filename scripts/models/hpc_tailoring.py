from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator


RiskAcceptance = Literal["low", "medium", "high"]


class HPCTailoringEntry(BaseModel):
    tailoring_id: str
    control_r2: str
    control_r3: str
    title: str
    standard_requirement: str
    hpc_challenge: str
    tailored_implementation: str
    compensating_controls: list[str] = Field(min_length=1)
    risk_acceptance: RiskAcceptance
    nist_800_223_reference: str
    performance_impact: str


class HPCTailoringData(BaseModel):
    version: str
    last_updated: str
    description: str
    tailoring_decisions: list[HPCTailoringEntry]

    @model_validator(mode="after")
    def validate_minimum_entries(self) -> "HPCTailoringData":
        if len(self.tailoring_decisions) < 10:
            raise ValueError(
                f"Expected at least 10 tailoring decisions, found {len(self.tailoring_decisions)}"
            )
        return self
