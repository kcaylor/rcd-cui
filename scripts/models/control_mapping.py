from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field, model_validator

Family = Literal[
    "AC",
    "AT",
    "AU",
    "CA",
    "CM",
    "IA",
    "IR",
    "MA",
    "MP",
    "PE",
    "PS",
    "RA",
    "SA",
    "SC",
    "SI",
]
Zone = Literal["management", "internal", "restricted", "public"]


class FrameworkMapping(BaseModel):
    rev2_id: str = Field(description="NIST 800-171 Rev 2 control identifier")
    rev3_id: str | None = Field(default=None, description="NIST 800-171 Rev 3 ID or N/A")
    rev3_rationale: str | None = Field(default=None)
    cmmc_l2_id: str | None = Field(default=None, description="CMMC L2 practice ID or N/A")
    cmmc_l2_rationale: str | None = Field(default=None)
    nist_800_53_r5_id: list[str] = Field(default_factory=list)

    @model_validator(mode="after")
    def validate_na_has_rationale(self) -> "FrameworkMapping":
        if self.rev3_id == "N/A" and not self.rev3_rationale:
            raise ValueError("rev3_rationale is required when rev3_id is 'N/A'")
        if self.cmmc_l2_id == "N/A" and not self.cmmc_l2_rationale:
            raise ValueError("cmmc_l2_rationale is required when cmmc_l2_id is 'N/A'")
        return self


class SecurityControl(BaseModel):
    control_id: str
    title: str
    family: Family
    plain_language: str
    assessment_objectives: list[str] = Field(min_length=1)
    sprs_weight: int = Field(ge=1, le=5)
    automatable: bool
    zones: list[Zone] = Field(min_length=1)
    framework_mapping: FrameworkMapping
    ansible_roles: list[str] = Field(default_factory=list)
    hpc_tailoring_ref: str | None = None


class ControlMappingData(BaseModel):
    version: str
    last_updated: str
    description: str
    controls: list[SecurityControl] = Field(min_length=110)

    @model_validator(mode="after")
    def validate_minimum_controls(self) -> "ControlMappingData":
        if len(self.controls) < 110:
            raise ValueError(f"Expected at least 110 controls, found {len(self.controls)}")
        return self
