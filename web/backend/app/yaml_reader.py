from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from typing import Any

import yaml


@dataclass
class YamlReadResult:
    ok: bool
    data: Any = None
    error_code: str | None = None
    error_message: str | None = None


class YamlReader:
    """Read YAML files from repo-safe locations for read-only APIs."""

    def __init__(self, repo_root: Path) -> None:
        self.repo_root = repo_root.resolve()
        self.allowed_roots = [
            (self.repo_root / "queue").resolve(),
            (self.repo_root / "projects").resolve(),
            (self.repo_root / "config").resolve(),
        ]

    def _is_allowed(self, path: Path) -> bool:
        try:
            resolved = path.resolve()
        except FileNotFoundError:
            resolved = path.parent.resolve() / path.name
        return any(str(resolved).startswith(str(root)) for root in self.allowed_roots)

    def read_yaml(self, relative_path: str) -> YamlReadResult:
        target = (self.repo_root / relative_path).resolve()

        if not self._is_allowed(target):
            return YamlReadResult(
                ok=False,
                error_code="PATH_NOT_ALLOWED",
                error_message=f"Path is outside allowed roots: {relative_path}",
            )

        if not target.exists():
            return YamlReadResult(
                ok=False,
                error_code="FILE_NOT_FOUND",
                error_message=f"File not found: {relative_path}",
            )

        try:
            with target.open("r", encoding="utf-8") as f:
                loaded = yaml.safe_load(f)
            if loaded is None:
                loaded = {}
            return YamlReadResult(ok=True, data=loaded)
        except yaml.YAMLError as exc:
            return YamlReadResult(
                ok=False,
                error_code="YAML_PARSE_ERROR",
                error_message=str(exc),
            )
        except OSError as exc:
            return YamlReadResult(
                ok=False,
                error_code="FILE_READ_ERROR",
                error_message=str(exc),
            )
