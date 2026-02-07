#!/usr/bin/env python3
"""ntfy Input Watcher — Python replacement for ntfy_listener.sh

Streams messages from ntfy topic, writes to inbox YAML, records to
Botsunichiroku DB, and wakes shogun via tmux send-keys.

NOT polling — uses ntfy's streaming endpoint (long-lived HTTP connection).
"""

import json
import signal
import subprocess
import sys
import time
import urllib.request
from datetime import datetime, timezone, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent.parent
SETTINGS_PATH = SCRIPT_DIR / "config" / "settings.yaml"
INBOX_PATH = SCRIPT_DIR / "queue" / "ntfy_inbox.yaml"
DB_CLI = SCRIPT_DIR / "scripts" / "botsunichiroku.py"

# JST offset for timestamps
JST = timezone(timedelta(hours=9))

# Graceful shutdown flag
_shutdown = False


def log(msg: str) -> None:
    """Log to stderr with timestamp."""
    ts = datetime.now().strftime("%a %b %d %I:%M:%S %p %Z %Y")
    print(f"[{ts}] {msg}", file=sys.stderr, flush=True)


def read_ntfy_topic() -> str:
    """Read ntfy_topic from config/settings.yaml (simple grep, no yaml lib)."""
    try:
        with open(SETTINGS_PATH) as f:
            for line in f:
                stripped = line.strip()
                if stripped.startswith("ntfy_topic:"):
                    value = stripped.split(":", 1)[1].strip().strip('"').strip("'")
                    if value:
                        return value
    except FileNotFoundError:
        pass
    return ""


def ensure_inbox() -> None:
    """Create inbox YAML if it doesn't exist."""
    if not INBOX_PATH.exists():
        INBOX_PATH.parent.mkdir(parents=True, exist_ok=True)
        INBOX_PATH.write_text("inbox:\n")


def append_to_inbox(msg_id: str, timestamp: str, message: str) -> None:
    """Append a message entry to the inbox YAML file."""
    # Escape double quotes in message for YAML safety
    safe_msg = message.replace('"', '\\"')
    entry = (
        f'  - id: "{msg_id}"\n'
        f'    timestamp: "{timestamp}"\n'
        f'    message: "{safe_msg}"\n'
        f'    status: pending\n'
    )
    with open(INBOX_PATH, "a") as f:
        f.write(entry)


def record_to_db(message: str) -> None:
    """Record the ntfy message as a cmd in Botsunichiroku DB."""
    desc = f"ntfy: {message}"
    try:
        subprocess.run(
            [
                sys.executable, str(DB_CLI),
                "cmd", "add",
                "--priority", "medium",
                "--project", "ntfy",
                desc,
            ],
            capture_output=True,
            timeout=10,
        )
    except Exception as e:
        log(f"DB record failed: {e}")


def wake_shogun(message: str) -> None:
    """Wake shogun via tmux send-keys (2-call pattern per CLAUDE.md)."""
    notify_text = "ntfyから新しいメッセージ受信。queue/ntfy_inbox.yaml を確認し処理せよ。"
    try:
        subprocess.run(
            ["tmux", "send-keys", "-t", "shogun:main", notify_text],
            capture_output=True,
            timeout=5,
        )
        time.sleep(0.5)
        subprocess.run(
            ["tmux", "send-keys", "-t", "shogun:main", "Enter"],
            capture_output=True,
            timeout=5,
        )
    except Exception as e:
        log(f"tmux send-keys failed: {e}")


def handle_message(line: str) -> None:
    """Process a single JSON line from the ntfy stream."""
    try:
        data = json.loads(line)
    except json.JSONDecodeError:
        return

    # Only process message events (skip keepalive, open, etc.)
    if data.get("event") != "message":
        return

    # Skip outbound messages (sent by our own scripts/ntfy.sh)
    tags = data.get("tags", [])
    if "outbound" in tags:
        return

    message = data.get("message", "")
    if not message:
        return

    msg_id = data.get("id", "")
    timestamp = datetime.now(JST).strftime("%Y-%m-%dT%H:%M:%S%z")
    # Insert colon in timezone offset for ISO 8601 (e.g., +0900 → +09:00)
    timestamp = timestamp[:-2] + ":" + timestamp[-2:]

    log(f"Received: {message}")

    # 1. Append to inbox YAML
    append_to_inbox(msg_id, timestamp, message)

    # 2. Record to Botsunichiroku DB
    record_to_db(message)

    # 3. Wake shogun
    wake_shogun(message)


def stream_messages(topic: str) -> None:
    """Stream messages from ntfy (long-lived HTTP connection)."""
    url = f"https://ntfy.sh/{topic}/json"
    req = urllib.request.Request(url)

    try:
        with urllib.request.urlopen(req, timeout=300) as resp:
            # Read line-by-line from the streaming response
            for raw_line in resp:
                if _shutdown:
                    return
                line = raw_line.decode("utf-8", errors="replace").strip()
                if line:
                    handle_message(line)
    except Exception as e:
        if not _shutdown:
            log(f"Connection error: {e}")


def shutdown_handler(signum, frame):
    """Handle SIGINT/SIGTERM for graceful shutdown."""
    global _shutdown
    sig_name = signal.Signals(signum).name
    log(f"Received {sig_name}, shutting down...")
    _shutdown = True


def main() -> None:
    signal.signal(signal.SIGINT, shutdown_handler)
    signal.signal(signal.SIGTERM, shutdown_handler)

    topic = read_ntfy_topic()
    if not topic:
        log("ntfy_topic not configured in config/settings.yaml")
        sys.exit(1)

    ensure_inbox()
    log(f"ntfy watcher started — topic: {topic}")

    while not _shutdown:
        stream_messages(topic)
        if _shutdown:
            break
        # Connection dropped — reconnect after brief pause
        log("Connection lost, reconnecting in 5s...")
        time.sleep(5)

    log("ntfy watcher stopped.")


if __name__ == "__main__":
    main()
