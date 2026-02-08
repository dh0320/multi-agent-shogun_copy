#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# inbox_watcher.sh — メールボックス監視＆起動シグナル配信
# Usage: bash scripts/inbox_watcher.sh <agent_id> <pane_target>
# Example: bash scripts/inbox_watcher.sh karo multiagent:0.0
#
# 設計思想:
#   メッセージ本体はファイル（inbox YAML）に書く = 確実
#   send-keys は短い起動シグナルのみ = ハング防止
#   エージェントが自分でinboxをReadして処理する
#   冪等: 2回届いてもunreadがなければ何もしない
#
# inotifywait でファイル変更を検知（イベント駆動、ポーリングではない）
# Fallback 1: 60秒タイムアウト（WSL2 inotify不発時の安全網）
# Fallback 2: rc=1処理（Claude Code atomic write = tmp+rename でinode変更時）
# ═══════════════════════════════════════════════════════════════

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_ID="$1"
PANE_TARGET="$2"

INBOX="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"
LOCKFILE="${INBOX}.lock"
SEND_KEYS_TIMEOUT=5  # seconds — prevents hang (PID 274337 incident)

# Agent mode (claude|codex). This repo runs in a single global mode.
AGENT_SETTING="claude"
if [ -f "$SCRIPT_DIR/config/settings.yaml" ]; then
    AGENT_SETTING=$(grep "^agent:" "$SCRIPT_DIR/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "claude")
fi
if [ -z "$AGENT_SETTING" ]; then
    AGENT_SETTING="claude"
fi

if [ -z "$AGENT_ID" ] || [ -z "$PANE_TARGET" ]; then
    echo "Usage: inbox_watcher.sh <agent_id> <pane_target>" >&2
    exit 1
fi

# Initialize inbox if not exists
if [ ! -f "$INBOX" ]; then
    mkdir -p "$(dirname "$INBOX")"
    echo "messages: []" > "$INBOX"
fi

echo "[$(date)] inbox_watcher started — agent: $AGENT_ID, pane: $PANE_TARGET" >&2

# Ensure inotifywait is available
if ! command -v inotifywait &>/dev/null; then
    echo "[inbox_watcher] ERROR: inotifywait not found. Install: sudo apt install inotify-tools" >&2
    exit 1
fi

# ─── Extract unread message info (lock-free read) ───
# Returns JSON lines: {"count": N, "has_special": true/false, "specials": [...]}
get_unread_info() {
    python3 -c "
import yaml, sys, json
try:
    with open('$INBOX') as f:
        data = yaml.safe_load(f)
    if not data or 'messages' not in data or not data['messages']:
        print(json.dumps({'count': 0, 'specials': []}))
        sys.exit(0)
    unread = [m for m in data['messages'] if not m.get('read', False)]
    # Special types that need direct send-keys (CLI commands, not conversation)
    special_types = ('clear_command', 'model_switch')
    specials = [m for m in unread if m.get('type') in special_types]
    # Mark specials as read immediately (they'll be delivered directly)
    if specials:
        for m in data['messages']:
            if not m.get('read', False) and m.get('type') in special_types:
                m['read'] = True
        with open('$INBOX', 'w') as f:
            yaml.dump(data, f, default_flow_style=False, allow_unicode=True)
    normal_count = len(unread) - len(specials)
    print(json.dumps({
        'count': normal_count,
        'specials': [{'type': m.get('type',''), 'content': m.get('content','')} for m in specials]
    }))
except Exception as e:
    print(json.dumps({'count': 0, 'specials': []}), file=sys.stderr)
    print(json.dumps({'count': 0, 'specials': []}))
" 2>/dev/null
}

# ─── Send CLI command directly via send-keys ───
# For /clear and /model only. These are CLI commands, not conversation messages.
send_cli_command() {
    local cmd="$1"
    echo "[$(date)] Sending CLI command to $AGENT_ID: $cmd" >&2

    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" "$cmd" 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys timed out for CLI command" >&2
        return 1
    fi
    sleep 0.3
    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys Enter timed out for CLI command" >&2
        return 1
    fi

    # /clear (claude) or /new (codex) needs extra wait time before follow-up
    if [[ "$cmd" == "/clear" || "$cmd" == "/new" ]]; then
        sleep 3
    else
        sleep 1
    fi
}

send_model_switch_codex() {
    # Codex does NOT support inline args for /model ("/model foo" is treated as a normal message).
    # We map legacy names to Codex auto presets and select via digit:
    #  1: codex-auto-fast, 2: codex-auto-balanced, 3: codex-auto-thorough
    local requested="$1"
    local requested_lc
    requested_lc=$(echo "$requested" | tr '[:upper:]' '[:lower:]')

    local preset="balanced"
    case "$requested_lc" in
        *opus*|*thorough*|*high*)
            preset="thorough"
            ;;
        *sonnet*|*fast*|*low*)
            preset="fast"
            ;;
        *balanced*|*medium*)
            preset="balanced"
            ;;
        *)
            preset="balanced"
            ;;
    esac

    send_cli_command "/model" || return 1

    local key="2"
    case "$preset" in
        fast) key="1" ;;
        balanced) key="2" ;;
        thorough) key="3" ;;
    esac

    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" "$key" 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys timed out for codex model selection key" >&2
        return 1
    fi
    sleep 0.3
}

# ─── Send wake-up nudge via send-keys ───
# ONLY sends a short nudge. Never sends message content.
# timeout prevents the 1.5-hour hang incident from recurring.
send_wakeup() {
    local unread_count="$1"
    local nudge="inbox${unread_count}"

    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" "$nudge" 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys nudge timed out ($SEND_KEYS_TIMEOUT s)" >&2
        return 1
    fi
    sleep 0.3
    if ! timeout "$SEND_KEYS_TIMEOUT" tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null; then
        echo "[$(date)] WARNING: send-keys Enter timed out ($SEND_KEYS_TIMEOUT s)" >&2
        return 1
    fi

    echo "[$(date)] Wake-up sent to $AGENT_ID (${unread_count} unread)" >&2
    return 0
}

# ─── Process cycle ───
process_unread() {
    local info
    info=$(get_unread_info)

    # Handle special CLI commands first (/clear, /model)
    local specials
    specials=$(echo "$info" | python3 -c "
import sys, json, base64
data = json.load(sys.stdin)
for s in data.get('specials', []):
    t = (s.get('type') or '').strip()
    c = (s.get('content') or '')
    b = base64.b64encode(c.encode('utf-8')).decode('ascii')
    print(f\"{t}\\t{b}\")
" 2>/dev/null || true)

    if [ -n "$specials" ]; then
        echo "$specials" | while IFS=$'\t' read -r typ b64; do
            [ -z "$typ" ] && continue

            content=""
            if [ -n "$b64" ]; then
                content=$(python3 -c "import base64,sys; print(base64.b64decode(sys.argv[1]).decode('utf-8'))" "$b64" 2>/dev/null || echo "")
            fi

            if [ "$typ" = "clear_command" ]; then
                if [ "$AGENT_SETTING" = "codex" ]; then
                    send_cli_command "/new" || true
                else
                    send_cli_command "/clear" || true
                fi
                [ -n "$content" ] && send_cli_command "$content" || true
                continue
            fi

            if [ "$typ" = "model_switch" ]; then
                if [ "$AGENT_SETTING" = "codex" ]; then
                    send_model_switch_codex "$content" || true
                else
                    [ -n "$content" ] && send_cli_command "$content" || true
                fi
                continue
            fi
        done
    fi

    # Send wake-up nudge for normal messages
    local normal_count
    normal_count=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)

    if [ "$normal_count" -gt 0 ] 2>/dev/null; then
        echo "[$(date)] $normal_count normal unread message(s) for $AGENT_ID" >&2
        send_wakeup "$normal_count"
    fi
}

# ─── Startup: process any existing unread messages ───
process_unread

# ─── Main loop: event-driven via inotifywait ───
# Timeout 60s: WSL2 /mnt/c/ can miss inotify events.
# On timeout (exit 2), check for unread messages as a safety net.
INOTIFY_TIMEOUT=60

while true; do
    # Block until file is modified OR timeout (safety net for WSL2)
    # set +e: inotifywait returns 2 on timeout, which would kill script under set -e
    set +e
    inotifywait -q -t "$INOTIFY_TIMEOUT" -e modify -e close_write "$INBOX" 2>/dev/null
    rc=$?
    set -e

    # rc=0: event fired (instant delivery)
    # rc=1: watch invalidated — Claude Code uses atomic write (tmp+rename),
    #        which replaces the inode. inotifywait sees DELETE_SELF → rc=1.
    #        File still exists with new inode. Treat as event, re-watch next loop.
    # rc=2: timeout (60s safety net for WSL2 inotify gaps)
    # All cases: check for unread, then loop back to inotifywait (re-watches new inode)
    sleep 0.3

    process_unread
done
