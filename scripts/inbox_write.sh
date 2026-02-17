#!/bin/bash
# inbox_write.sh — メールボックスへのメッセージ書き込み（排他ロック付き）
# Usage: bash scripts/inbox_write.sh <target_agent> <content> [type] [from]
# Example: bash scripts/inbox_write.sh karo "足軽5号、任務完了" report_received ashigaru5

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$1"
CONTENT="$2"
TYPE="${3:-wake_up}"
FROM="${4:-unknown}"

INBOX="$SCRIPT_DIR/queue/inbox/${TARGET}.yaml"
LOCKFILE="${INBOX}.lock"
PYTHON_BIN="$SCRIPT_DIR/.venv/bin/python3"

# Validate arguments
if [ -z "$TARGET" ] || [ -z "$CONTENT" ]; then
    echo "Usage: inbox_write.sh <target_agent> <content> [type] [from]" >&2
    exit 1
fi

# Initialize inbox if not exists
if [ ! -f "$INBOX" ]; then
    mkdir -p "$(dirname "$INBOX")"
    echo "messages: []" > "$INBOX"
fi

# Generate unique message ID (timestamp-based)
MSG_ID="msg_$(date +%Y%m%d_%H%M%S)_$(head -c 4 /dev/urandom | xxd -p)"
TIMESTAMP=$(date "+%Y-%m-%dT%H:%M:%S")

# Prefer project venv, but fall back to system python3.
if [ ! -x "$PYTHON_BIN" ]; then
    PYTHON_BIN="$(command -v python3 || true)"
fi
if [ -z "$PYTHON_BIN" ]; then
    echo "[inbox_write] python3 not found" >&2
    exit 1
fi

# Atomic write with an advisory lock implemented in Python (macOS lacks `flock`(1)).
# NOTE: Python is invoked with `-` (script from stdin), so message content cannot also be streamed via stdin.
# Pass content via environment variable; messages are short so this is acceptable in practice.
env INBOX="$INBOX" LOCKFILE="$LOCKFILE" MSG_ID="$MSG_ID" FROM="$FROM" TIMESTAMP="$TIMESTAMP" TYPE="$TYPE" CONTENT="$CONTENT" \
    "$PYTHON_BIN" - <<'PY'
import os, sys, time, tempfile

try:
    import yaml
except Exception as e:
    print(f"ERROR: failed to import yaml: {e}", file=sys.stderr)
    sys.exit(1)

inbox = os.environ["INBOX"]
lockfile = os.environ["LOCKFILE"]
msg_id = os.environ["MSG_ID"]
from_ = os.environ["FROM"]
timestamp = os.environ["TIMESTAMP"]
type_ = os.environ["TYPE"]
content = os.environ.get("CONTENT", "")

# Acquire an exclusive advisory lock with a timeout (5s).
try:
    import fcntl
except Exception as e:
    print(f"ERROR: fcntl unavailable: {e}", file=sys.stderr)
    sys.exit(1)

os.makedirs(os.path.dirname(inbox), exist_ok=True)

deadline = time.time() + 5.0
lock_fd = os.open(lockfile, os.O_CREAT | os.O_RDWR, 0o600)
try:
    while True:
        try:
            fcntl.flock(lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
            break
        except BlockingIOError:
            if time.time() >= deadline:
                print(f"[inbox_write] Lock timeout for {inbox}", file=sys.stderr)
                sys.exit(1)
            time.sleep(0.1)

    # Load existing inbox
    with open(inbox, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if not data:
        data = {}
    if not data.get("messages"):
        data["messages"] = []

    data["messages"].append(
        {
            "id": msg_id,
            "from": from_,
            "timestamp": timestamp,
            "type": type_,
            "content": content,
            "read": False,
        }
    )

    # Overflow protection: keep max 50 messages (all unread + newest 30 read).
    if len(data["messages"]) > 50:
        msgs = data["messages"]
        unread = [m for m in msgs if not m.get("read", False)]
        read = [m for m in msgs if m.get("read", False)]
        data["messages"] = unread + read[-30:]

    tmp_fd, tmp_path = tempfile.mkstemp(dir=os.path.dirname(inbox), suffix=".tmp")
    try:
        with os.fdopen(tmp_fd, "w", encoding="utf-8") as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True, indent=2)
        os.replace(tmp_path, inbox)
    except Exception:
        try:
            os.unlink(tmp_path)
        except Exception:
            pass
        raise

finally:
    try:
        os.close(lock_fd)
    except Exception:
        pass
PY
