from __future__ import annotations

from pathlib import Path
from typing import Any

from fastapi import FastAPI, Query
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from .models import ApiError, ApiResponse, MetaInfo, ValidationErrorPayload
from .yaml_reader import YamlReader

app = FastAPI(title="multi-agent-shogun web backend", version="0.2.0")

REPO_ROOT = Path(__file__).resolve().parents[3]
yaml_reader = YamlReader(repo_root=REPO_ROOT)


def response_ok(data: Any, source: str = "system") -> ApiResponse[Any]:
    return ApiResponse[Any](data=data, meta=MetaInfo(source=source), error=None)


def response_error(code: str, message: str, status_code: int, details: dict[str, Any] | None = None) -> JSONResponse:
    payload = ApiResponse[Any](
        data=None,
        meta=MetaInfo(source="system"),
        error=ApiError(code=code, message=message, details=details),
    )
    return JSONResponse(status_code=status_code, content=payload.model_dump(mode="json"))


@app.exception_handler(RequestValidationError)
async def request_validation_exception_handler(_, exc: RequestValidationError) -> JSONResponse:
    details = ValidationErrorPayload(errors=exc.errors()).model_dump(mode="json")
    return response_error(
        code="REQUEST_VALIDATION_ERROR",
        message="Invalid request parameters",
        status_code=400,
        details=details,
    )


@app.get("/api/v1/health")
def health() -> ApiResponse[dict[str, str]]:
    return response_ok({"status": "ok"})


@app.get("/api/v1/system/read-yaml")
def read_yaml(relative_path: str = Query(..., description="Path under queue/, projects/, or config/")) -> JSONResponse | ApiResponse[Any]:
    result = yaml_reader.read_yaml(relative_path)
    if not result.ok:
        code_to_status = {
            "PATH_NOT_ALLOWED": 400,
            "FILE_NOT_FOUND": 404,
            "YAML_PARSE_ERROR": 409,
            "FILE_READ_ERROR": 500,
        }
        return response_error(
            code=result.error_code or "UNKNOWN_ERROR",
            message=result.error_message or "Unknown error",
            status_code=code_to_status.get(result.error_code or "", 500),
            details={"relative_path": relative_path},
        )

    return ApiResponse[Any](data=result.data, meta=MetaInfo(source="yaml"), error=None)
