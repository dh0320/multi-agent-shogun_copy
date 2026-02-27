from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from fastapi import FastAPI, Query

from .schemas import APIMeta, APIResponse, Command, DashboardPayload, DashboardSummary, Report, Task
from .yaml_reader import ReaderError, count_action_required, discover_root, latest_timestamp, load_commands, load_reports, load_tasks

app = FastAPI(title="multi-agent-shogun web backend", version="0.2.0")


def build_meta(total: int | None = None, limit: int | None = None, offset: int | None = None) -> APIMeta:
    return APIMeta(
        total=total,
        limit=limit,
        offset=offset,
        source_root=str(discover_root()),
        generated_at=datetime.now(timezone.utc),
    )


def ok(data: Any, *, total: int | None = None, limit: int | None = None, offset: int | None = None) -> APIResponse[Any]:
    return APIResponse(data=data, meta=build_meta(total=total, limit=limit, offset=offset), error=None)


def err(code: str, message: str, details: dict | None = None) -> APIResponse[Any]:
    return APIResponse(data=None, meta=build_meta(), error={"code": code, "message": message, "details": details})


@app.get("/api/v1/health")
def health() -> APIResponse[dict[str, str]]:
    return ok({"status": "ok"})


@app.get("/api/v1/dashboard/summary")
def dashboard_summary() -> APIResponse[DashboardPayload]:
    try:
        root = discover_root()
        commands = load_commands(root)
        tasks = load_tasks(root)
        reports = load_reports(root)
        all_items = [*commands, *tasks, *reports]
        in_progress = sum(1 for x in [*commands, *tasks] if x.status in {"assigned", "in_progress", "pending", "pending_blocked"})
        done_count = sum(1 for x in [*commands, *tasks] if x.status == "done")
        latest_reports = sorted(reports, key=lambda x: x.timestamp or "", reverse=True)[:5]

        payload = DashboardPayload(
            summary=DashboardSummary(
                in_progress_count=in_progress,
                done_count=done_count,
                action_required_count=count_action_required(root),
                latest_updated_at=latest_timestamp(all_items),
                latest_reports=latest_reports,
            )
        )
        return ok(payload)
    except ReaderError as exc:
        return err(exc.code, exc.message, exc.details)


@app.get("/api/v1/commands")
def list_commands(
    status: str | None = None,
    project: str | None = None,
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
) -> APIResponse[list[Command]]:
    try:
        items = load_commands(discover_root())
        if status:
            items = [x for x in items if x.status == status]
        if project:
            items = [x for x in items if x.project == project]
        total = len(items)
        paged = items[offset : offset + limit]
        return ok(paged, total=total, limit=limit, offset=offset)
    except ReaderError as exc:
        return err(exc.code, exc.message, exc.details)


@app.get("/api/v1/commands/{cmd_id}")
def get_command(cmd_id: str) -> APIResponse[Command]:
    try:
        items = load_commands(discover_root())
        found = next((x for x in items if x.id == cmd_id), None)
        if not found:
            return err("NOT_FOUND", f"command not found: {cmd_id}")
        return ok(found)
    except ReaderError as exc:
        return err(exc.code, exc.message, exc.details)


@app.get("/api/v1/tasks")
def list_tasks() -> APIResponse[list[Task]]:
    try:
        items = load_tasks(discover_root())
        return ok(items, total=len(items))
    except ReaderError as exc:
        return err(exc.code, exc.message, exc.details)


@app.get("/api/v1/tasks/{agent_id}")
def tasks_by_agent(agent_id: str) -> APIResponse[list[Task]]:
    try:
        items = [x for x in load_tasks(discover_root()) if x.agent == agent_id]
        return ok(items, total=len(items))
    except ReaderError as exc:
        return err(exc.code, exc.message, exc.details)


@app.get("/api/v1/reports")
def list_reports() -> APIResponse[list[Report]]:
    try:
        items = sorted(load_reports(discover_root()), key=lambda x: x.timestamp or "", reverse=True)
        return ok(items, total=len(items))
    except ReaderError as exc:
        return err(exc.code, exc.message, exc.details)


@app.get("/api/v1/reports/{agent_id}")
def reports_by_agent(agent_id: str) -> APIResponse[list[Report]]:
    try:
        items = [x for x in load_reports(discover_root()) if x.agent == agent_id]
        return ok(items, total=len(items))
    except ReaderError as exc:
        return err(exc.code, exc.message, exc.details)
