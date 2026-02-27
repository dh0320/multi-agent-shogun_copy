from fastapi import FastAPI

app = FastAPI(title="multi-agent-shogun web backend", version="0.1.0")


@app.get("/api/v1/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
