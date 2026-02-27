from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Generic, Literal, TypeVar

from pydantic import BaseModel, Field, field_validator
from pydantic.generics import GenericModel

DataT = TypeVar("DataT")


class ApiError(BaseModel):
    code: str
    message: str
    details: dict[str, Any] | None = None


class MetaInfo(BaseModel):
    source: Literal["yaml", "system"] = "yaml"
    generated_at: datetime = Field(default_factory=lambda: datetime.now(timezone.utc))


class ApiResponse(GenericModel, Generic[DataT]):
    data: DataT | None
    meta: MetaInfo
    error: ApiError | None = None


class Command(BaseModel):
    id: str
    timestamp: datetime | None = None
    purpose: str | None = None
    acceptance_criteria: list[str] | None = None
    command: str | None = None
    project: str | None = None
    priority: str | None = None
    status: str

    @field_validator("id", "status")
    @classmethod
    def not_blank(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("must not be blank")
        return value


class Task(BaseModel):
    task_id: str | None = None
    assignee: str | None = None
    status: str
    title: str | None = None
    project: str | None = None


class Report(BaseModel):
    report_id: str | None = None
    assignee: str | None = None
    status: str | None = None
    summary: str | None = None
    project: str | None = None


class ValidationErrorPayload(BaseModel):
    errors: list[dict[str, Any]]
