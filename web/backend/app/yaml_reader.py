from __future__ import annotations

from datetime import datetime
from pathlib import Path
from typing import Any

import yaml
from pydantic import ValidationError

from .schemas import Command, Report, Task


class ReaderError(Exception):
    def __init__(self, code: str, message: str, details: dict[str, Any] | None = None):
        self.code = code
        self.message = message
        self.details = details or {}
        super().__init__(message)


def discover_root() -> Path:
    here = Path(__file__).resolve()
    return here.parents[3]


def safe_load_yaml(path: Path) -> Any:
    try:
        if not path.exists():
            return None
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as exc:
        raise ReaderError("YAML_PARSE_ERROR", f"YAML parse error: {path}", {"path": str(path), "error": str(exc)}) from exc


def _extract_candidate_dicts(node: Any) -> list[dict[str, Any]]:
    result: list[dict[str, Any]] = []
    if isinstance(node, dict):
        if "id" in node:
            result.append(node)
        for value in node.values():
            result.extend(_extract_candidate_dicts(value))
    elif isinstance(node, list):
        for item in node:
            result.extend(_extract_candidate_dicts(item))
    return result


def _model_from_file(path: Path, model_type: str) -> list[Command | Task | Report]:
    loaded = safe_load_yaml(path)
    if loaded is None:
        return []

    if model_type == "command":
        model = Command
    elif model_type == "task":
        model = Task
    else:
        model = Report

    items: list[Command | Task | Report] = []
    candidates = _extract_candidate_dicts(loaded)

    if not candidates and isinstance(loaded, dict):
        fallback = dict(loaded)
        fallback.setdefault("id", path.stem)
        candidates = [fallback]

    for raw in candidates:
        entry = dict(raw)
        entry.setdefault("timestamp", raw.get("updated_at") or raw.get("created_at"))
        if model_type in {"task", "report"}:
            entry.setdefault("agent", path.stem.replace("_report", ""))
        try:
            items.append(model.model_validate(entry))
        except ValidationError:
            continue

    return items


def load_commands(root: Path) -> list[Command]:
    cmd_path = root / "queue/shogun_to_karo.yaml"
    return [c for c in _model_from_file(cmd_path, "command") if isinstance(c, Command)]


def load_tasks(root: Path) -> list[Task]:
    tasks_dir = root / "queue/tasks"
    if not tasks_dir.exists():
        return []
    results: list[Task] = []
    for path in sorted(tasks_dir.glob("*.yaml")):
        results.extend(t for t in _model_from_file(path, "task") if isinstance(t, Task))
    return results


def load_reports(root: Path) -> list[Report]:
    reports_dir = root / "queue/reports"
    if not reports_dir.exists():
        return []
    results: list[Report] = []
    for path in sorted(reports_dir.glob("*.yaml")):
        results.extend(r for r in _model_from_file(path, "report") if isinstance(r, Report))
    return results


def latest_timestamp(items: list[Command | Task | Report]) -> str | None:
    timestamps: list[datetime] = []
    for item in items:
        if item.timestamp:
            try:
                timestamps.append(datetime.fromisoformat(item.timestamp.replace("Z", "+00:00")))
            except ValueError:
                continue
    if not timestamps:
        return None
    return max(timestamps).isoformat()


def count_action_required(root: Path) -> int:
    dash = root / "dashboard.md"
    if not dash.exists():
        return 0
    in_section = False
    count = 0
    for line in dash.read_text(encoding="utf-8").splitlines():
        stripped = line.strip()
        if stripped.startswith("##"):
            in_section = "要対応" in stripped
            continue
        if in_section and stripped.startswith(("-", "*")):
            count += 1
    return count
