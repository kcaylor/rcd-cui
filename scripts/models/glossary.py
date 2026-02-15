from __future__ import annotations

from pydantic import BaseModel, Field, model_validator


class AudienceContext(BaseModel):
    pi: str
    researcher: str
    sysadmin: str
    ciso: str
    leadership: str


class GlossaryTerm(BaseModel):
    term: str
    full_name: str
    plain_language: str
    who_cares: AudienceContext
    see_also: list[str] = Field(default_factory=list)
    context: str | None = None


class GlossaryData(BaseModel):
    version: str
    last_updated: str
    description: str
    terms: dict[str, GlossaryTerm]

    @model_validator(mode="after")
    def validate_terms(self) -> "GlossaryData":
        if len(self.terms) < 60:
            raise ValueError(f"Expected at least 60 terms, found {len(self.terms)}")

        available = set(self.terms.keys())
        for key, term in self.terms.items():
            if term.term != key:
                raise ValueError(f"Glossary key '{key}' must match term.term '{term.term}'")
            for related in term.see_also:
                if related not in available:
                    raise ValueError(f"Glossary term '{key}' references missing see_also term '{related}'")
        return self
