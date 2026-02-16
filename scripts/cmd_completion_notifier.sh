#!/usr/bin/env bash
# cmd_completion_notifier.sh — cmd完了時の自動ntfy通知daemon
#
# shogun_to_karo.yaml を inotifywait で監視し、cmdのstatusが"done"に
# 変わったら自動的にntfy.shを呼び出す。
# inbox_watcher.shと同じ設計パターン（イベント駆動、重複防止）。
#
# Usage: bash scripts/cmd_completion_notifier.sh
#
# 依存: inotifywait (or fswatch on macOS), python3 + PyYAML
#
# 状態管理:
#   queue/notified_cmds.txt — 通知済みcmd_idを1行ずつ記録（重複送信防止）
#   logs/cmd_completion_notifier.log — ログ出力先

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUEUE_FILE="$SCRIPT_DIR/queue/shogun_to_karo.yaml"
NOTIFIED_FILE="$SCRIPT_DIR/queue/notified_cmds.txt"
LOG_FILE="$SCRIPT_DIR/logs/cmd_completion_notifier.log"
NTFY_SCRIPT="$SCRIPT_DIR/scripts/ntfy.sh"

# Testing guard: when set, skip main loop
if [ "${__CMD_NOTIFIER_TESTING__:-}" = "1" ]; then
    set +euo pipefail  # relax for test harness
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Ensure required files/dirs exist
init_files() {
    mkdir -p "$SCRIPT_DIR/logs" "$SCRIPT_DIR/queue"
    touch "$NOTIFIED_FILE"
    touch "$LOG_FILE"
}

# Extract done cmd_ids that haven't been notified yet
# Returns: lines of "cmd_id|purpose" for each newly-done cmd
get_new_done_cmds() {
    "$SCRIPT_DIR/.venv/bin/python3" - "$QUEUE_FILE" "$NOTIFIED_FILE" << 'PY'
import sys
import yaml

queue_file = sys.argv[1]
notified_file = sys.argv[2]

try:
    with open(queue_file, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
except Exception:
    sys.exit(0)

try:
    with open(notified_file, "r", encoding="utf-8") as f:
        notified = set(line.strip() for line in f if line.strip())
except Exception:
    notified = set()

commands = data.get("commands", []) or []
for cmd in commands:
    cmd_id = cmd.get("id", "")
    status = cmd.get("status", "")
    purpose = cmd.get("purpose", "")
    if status == "done" and cmd_id and cmd_id not in notified:
        # Truncate purpose to 100 chars for notification
        short_purpose = purpose[:100] if purpose else "(no description)"
        print(f"{cmd_id}|{short_purpose}")
PY
}

# Mark a cmd_id as notified
mark_notified() {
    local cmd_id="$1"
    echo "$cmd_id" >> "$NOTIFIED_FILE"
}

# Send ntfy notification for a completed cmd
send_notification() {
    local cmd_id="$1"
    local purpose="$2"
    local message="cmd完了: ${cmd_id} — ${purpose}"

    if bash "$NTFY_SCRIPT" "$message"; then
        log "SUCCESS: ntfy sent for $cmd_id"
        mark_notified "$cmd_id"
    else
        log "ERROR: ntfy failed for $cmd_id (rc=$?)"
    fi
}

# Process: check for new done cmds and send notifications
process_done_cmds() {
    if [ ! -f "$QUEUE_FILE" ]; then
        return 0
    fi

    local new_cmds
    new_cmds=$(get_new_done_cmds) || return 0

    if [ -z "$new_cmds" ]; then
        return 0
    fi

    while IFS='|' read -r cmd_id purpose; do
        [ -z "$cmd_id" ] && continue
        log "Detected done: $cmd_id"
        send_notification "$cmd_id" "$purpose"
    done <<< "$new_cmds"
}

# Skip main loop in testing mode
if [ "${__CMD_NOTIFIER_TESTING__:-}" = "1" ]; then
    return 0 2>/dev/null || true
fi

# --- Main ---
init_files
log "cmd_completion_notifier started"

# Process any existing done cmds on startup
process_done_cmds

# Detect OS and select file-watching backend
NOTIFIER_OS="$(uname -s)"
if [ "$NOTIFIER_OS" = "Darwin" ]; then
    if ! command -v fswatch &>/dev/null; then
        log "ERROR: fswatch not found. Install: brew install fswatch"
        exit 1
    fi
    WATCH_CMD="fswatch"
else
    if ! command -v inotifywait &>/dev/null; then
        log "ERROR: inotifywait not found. Install: sudo apt install inotify-tools"
        exit 1
    fi
    WATCH_CMD="inotifywait"
fi

log "File watch backend: $WATCH_CMD"

INOTIFY_TIMEOUT="${INOTIFY_TIMEOUT:-60}"

while true; do
    set +e
    if [ "$WATCH_CMD" = "fswatch" ]; then
        if command -v gtimeout &>/dev/null; then
            gtimeout "$INOTIFY_TIMEOUT" fswatch -1 --event Updated --event Renamed "$QUEUE_FILE" 2>/dev/null
        else
            fswatch -1 --event Updated --event Renamed "$QUEUE_FILE" &>/dev/null &
            FSWATCH_PID=$!
            WAITED=0
            while [ "$WAITED" -lt "$INOTIFY_TIMEOUT" ] && kill -0 "$FSWATCH_PID" 2>/dev/null; do
                sleep 1
                WAITED=$((WAITED + 1))
            done
            if kill -0 "$FSWATCH_PID" 2>/dev/null; then
                kill "$FSWATCH_PID" 2>/dev/null
                wait "$FSWATCH_PID" 2>/dev/null
            else
                wait "$FSWATCH_PID" 2>/dev/null
            fi
        fi
    else
        inotifywait -q -t "$INOTIFY_TIMEOUT" -e modify -e close_write "$QUEUE_FILE" 2>/dev/null
    fi
    set -e

    sleep 0.5
    process_done_cmds
done
