#!/usr/bin/env python3
"""Dependency-free local server for TKT-001 smoke testing.

Preferred runtime is FastAPI (`app/main.py`), but this fallback keeps local checks
possible even when package installation is blocked.
"""

from http.server import BaseHTTPRequestHandler, HTTPServer
import json


class Handler(BaseHTTPRequestHandler):
    def do_GET(self) -> None:  # noqa: N802
        if self.path == "/api/v1/health":
            payload = json.dumps({"status": "ok"}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            return

        self.send_response(404)
        self.end_headers()


if __name__ == "__main__":
    server = HTTPServer(("127.0.0.1", 8000), Handler)
    print("fallback backend listening on http://127.0.0.1:8000")
    server.serve_forever()
