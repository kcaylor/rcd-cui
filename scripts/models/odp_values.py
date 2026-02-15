from __future__ import annotations

from pydantic import BaseModel, model_validator


class ODPValue(BaseModel):
    odp_id: str
    control: str
    parameter_description: str
    assigned_value: str
    rationale: str
    dod_guidance: str
    deviation_rationale: str | None = None


class ODPValuesData(BaseModel):
    version: str
    last_updated: str
    description: str
    odp_values: list[ODPValue]

    @model_validator(mode="after")
    def validate_odp_count(self) -> "ODPValuesData":
        if len(self.odp_values) != 49:
            raise ValueError(f"Expected exactly 49 ODP entries, found {len(self.odp_values)}")

        for entry in self.odp_values:
            if entry.assigned_value != entry.dod_guidance and not entry.deviation_rationale:
                raise ValueError(
                    f"{entry.odp_id} differs from DoD guidance but has no deviation_rationale"
                )
        return self
