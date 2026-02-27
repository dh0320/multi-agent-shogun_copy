from __future__ import annotations

from datetime import datetime
from typing import Generic, TypeVar

from pydantic import BaseModel, ConfigDict, Field, field_validator
from pydantic.generics import GenericModel

VALID_STATUS = {
    "idle",
    "assigned",
    "done",
    "failed",
    "pending",
    "pending_blocked",
    "in_progress",
    "blocked",
    "todo",
}


class APIError(BaseModel):
    code: str
    message: str
    details: dict | None = None


class APIMeta(BaseModel):
    total: int | None = None
    limit: int | None = None
    offset: int | None = None
    source_root: str | None = None
    generated_at: datetime


T = TypeVar("T")


class APIResponse(GenericModel, Generic[T]):
    data: T | None = None
    meta: APIMeta
    error: APIError | None = None


class BaseEntity(BaseModel):
    model_config = ConfigDict(extra="allow")

    id: str
    status: str | None = None
    timestamp: str | None = None

    @field_validator("id")
    @classmethod
    def validate_id(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("id must not be empty")
        return value

    @field_validator("status")
    @classmethod
    def validate_status(cls, value: str | None) -> str | None:
        if value is None:
            return value
        if value not in VALID_STATUS:
            raise ValueError(f"unsupported status: {value}")
        return value

    @field_validator("timestamp")
    @classmethod
    def validate_timestamp(cls, value: str | None) -> str | None:
        if value is None:
            return value
        datetime.fromisoformat(value.replace("Z", "+00:00"))
        return value


class Command(BaseEntity):
    project: str | None = None
    purpose: str | None = None


class Task(BaseEntity):
    agent: str | None = None


class Report(BaseEntity):
    agent: str | None = None


class DashboardSummary(BaseModel):
    in_progress_count: int
    done_count: int
    action_required_count: int
    latest_updated_at: str | None = None
    latest_reports: list[Report] = Field(default_factory=list)


class DashboardPayload(BaseModel):
    summary: DashboardSummary
