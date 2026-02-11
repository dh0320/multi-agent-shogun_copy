#!/bin/bash
# ═══════════════════════════════════════════════════════════════
# inbox_watcher.sh — メールボックス監視＆起動シグナル配信
# Usage: bash scripts/inbox_watcher.sh <agent_id> <pane_target> [cli_type]
# Example: bash scripts/inbox_watcher.sh karo multiagent:0.0 claude
#
# 設計思想:
#   メッセージ本体はファイル（inbox YAML）に書く = 確実
#   起動シグナルは tmux send-keys（テキストとEnterを分離送信）
#   エージェントが自分でinboxをReadして処理する
#   冪等: 2回届いてもunreadがなければ何もしない
#
# inotifywait でファイル変更を検知（イベント駆動、ポーリングではない）
# Fallback 1: 30秒タイムアウト（WSL2 inotify不発時の安全網）
# Fallback 2: rc=1処理（Claude Code atomic write = tmp+rename でinode変更時）
#
# エスカレーション（未読メッセージが放置されている場合）:
#   0〜2分: 通常nudge（send-keys）。ただしWorking中はスキップ
#   2〜4分: Escape×2 + nudge（カーソル位置バグ対策）
#   4分〜 : /clear送信（5分に1回まで。強制リセット+YAML再読）
# ═══════════════════════════════════════════════════════════════

# ─── Testing guard ───
# When __INBOX_WATCHER_TESTING__=1, only function definitions are loaded.
# Argument parsing, inotifywait check, and main loop are skipped.
# Test code sets variables (AGENT_ID, PANE_TARGET, CLI_TYPE, INBOX) externally.
if [ "${__INBOX_WATCHER_TESTING__:-}" != "1" ]; then
    set -euo pipefail

    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    AGENT_ID="$1"
    PANE_TARGET="$2"
    CLI_TYPE="${3:-claude}"  # CLI種別（claude/codex/copilot）。未指定→claude（後方互換）

    INBOX="$SCRIPT_DIR/queue/inbox/${AGENT_ID}.yaml"
    LOCKFILE="${INBOX}.lock"

    if [ -z "$AGENT_ID" ] || [ -z "$PANE_TARGET" ]; then
        echo "Usage: inbox_watcher.sh <agent_id> <pane_target> [cli_type]" >&2
        exit 1
    fi

    # Initialize inbox if not exists
    if [ ! -f "$INBOX" ]; then
        mkdir -p "$(dirname "$INBOX")"
        echo "messages: []" > "$INBOX"
    fi

    echo "[$(date)] inbox_watcher started — agent: $AGENT_ID, pane: $PANE_TARGET, cli: $CLI_TYPE" >&2

    # Ensure inotifywait is available
    if ! command -v inotifywait &>/dev/null; then
        echo "[inbox_watcher] ERROR: inotifywait not found. Install: sudo apt install inotify-tools" >&2
        exit 1
    fi
fi

# ─── Escalation state ───
# Time-based escalation: track how long unread messages have been waiting
FIRST_UNREAD_SEEN=${FIRST_UNREAD_SEEN:-0}
LAST_CLEAR_TS=${LAST_CLEAR_TS:-0}
ESCALATE_PHASE1=${ESCALATE_PHASE1:-120}
ESCALATE_PHASE2=${ESCALATE_PHASE2:-240}
ESCALATE_COOLDOWN=${ESCALATE_COOLDOWN:-300}

# ─── Nudge throttle ───
# Avoid spamming the same "inboxN" into the pane every timeout tick.
LAST_NUDGE_TS=${LAST_NUDGE_TS:-0}
LAST_NUDGE_COUNT=${LAST_NUDGE_COUNT:-""}
NUDGE_COOLDOWN_SEC=${NUDGE_COOLDOWN_SEC:-60}
# Codex は「思考中に入力が入ると即拾う」挙動があり、思考がループすることがあるため長めにする。
NUDGE_COOLDOWN_SEC_CODEX=${NUDGE_COOLDOWN_SEC_CODEX:-300}

# ─── Phase feature flags (cmd_107 Phase 1/2/3) ───
# ASW_PHASE:
#   1 = self-watch base (compatible)
#   2 = disable normal nudge by default
#   3 = FINAL_ESCALATION_ONLY (send-keys is fallback only)
ASW_PHASE=${ASW_PHASE:-1}
ASW_DISABLE_NORMAL_NUDGE=${ASW_DISABLE_NORMAL_NUDGE:-$([ "${ASW_PHASE}" -ge 2 ] && echo 1 || echo 0)}
ASW_FINAL_ESCALATION_ONLY=${ASW_FINAL_ESCALATION_ONLY:-$([ "${ASW_PHASE}" -ge 3 ] && echo 1 || echo 0)}
FINAL_ESCALATION_ONLY=${FINAL_ESCALATION_ONLY:-$ASW_FINAL_ESCALATION_ONLY}
ASW_NO_IDLE_FULL_READ=${ASW_NO_IDLE_FULL_READ:-1}
# Optional safety toggles:
# - ASW_DISABLE_ESCALATION=1: disable phase2/phase3 escalation actions
# - ASW_PROCESS_TIMEOUT=0: do not process unread on timeout ticks (event-only)
ASW_DISABLE_ESCALATION=${ASW_DISABLE_ESCALATION:-0}
ASW_PROCESS_TIMEOUT=${ASW_PROCESS_TIMEOUT:-1}

# ─── Metrics hooks (FR-006 / NFR-003) ───
# unread_latency_sec / read_count / estimated_tokens are intentionally explicit
READ_COUNT=${READ_COUNT:-0}
READ_BYTES_TOTAL=${READ_BYTES_TOTAL:-0}
ESTIMATED_TOKENS_TOTAL=${ESTIMATED_TOKENS_TOTAL:-0}
METRICS_FILE=${METRICS_FILE:-${SCRIPT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/queue/metrics/${AGENT_ID:-unknown}_selfwatch.yaml}

update_metrics() {
    local bytes_read="${1:-0}"
    local now
    now=$(date +%s)

    READ_COUNT=$((READ_COUNT + 1))
    READ_BYTES_TOTAL=$((READ_BYTES_TOTAL + bytes_read))
    ESTIMATED_TOKENS_TOTAL=$((ESTIMATED_TOKENS_TOTAL + ((bytes_read + 3) / 4)))

    local unread_latency_sec=0
    if [ "$FIRST_UNREAD_SEEN" -gt 0 ] 2>/dev/null; then
        unread_latency_sec=$((now - FIRST_UNREAD_SEEN))
    fi

    mkdir -p "$(dirname "$METRICS_FILE")" 2>/dev/null || true
    cat > "$METRICS_FILE" <<EOF
agent_id: "${AGENT_ID:-unknown}"
timestamp: "$(date -Iseconds)"
unread_latency_sec: $unread_latency_sec
read_count: $READ_COUNT
bytes_read: $READ_BYTES_TOTAL
estimated_tokens: $ESTIMATED_TOKENS_TOTAL
EOF
}

disable_normal_nudge() {
    [ "${ASW_DISABLE_NORMAL_NUDGE:-0}" = "1" ]
}

should_throttle_nudge() {
    local unread_count="${1:-0}"
    local now
    now=$(date +%s)

    local effective_cli
    effective_cli=$(get_effective_cli_type)

    local cooldown_sec="${NUDGE_COOLDOWN_SEC:-60}"
    if [[ "$effective_cli" == "codex" ]]; then
        cooldown_sec="${NUDGE_COOLDOWN_SEC_CODEX:-300}"
    fi

    if [ "${LAST_NUDGE_COUNT:-}" = "$unread_count" ] && [ "${LAST_NUDGE_TS:-0}" -gt 0 ]; then
        local age=$((now - LAST_NUDGE_TS))
        if [ "$age" -lt "${cooldown_sec}" ]; then
            echo "[$(date)] [SKIP] Throttling nudge for $AGENT_ID: inbox${unread_count} (${age}s < ${cooldown_sec}s, cli=$effective_cli)" >&2
            return 0
        fi
    fi

    LAST_NUDGE_COUNT="$unread_count"
    LAST_NUDGE_TS="$now"
    return 1
}

is_valid_cli_type() {
    case "${1:-}" in
        claude|codex|copilot|kimi) return 0 ;;
        *) return 1 ;;
    esac
}

get_effective_cli_type() {
    local pane_cli_raw=""
    local pane_cli=""

    pane_cli_raw=$(timeout 2 tmux show-options -p -t "$PANE_TARGET" -v @agent_cli 2>/dev/null || true)
    pane_cli=$(echo "$pane_cli_raw" | tr -d '\r' | head -n1 | tr -d '[:space:]')

    if is_valid_cli_type "$pane_cli"; then
        if is_valid_cli_type "${CLI_TYPE:-}" && [ "$pane_cli" != "${CLI_TYPE}" ]; then
            echo "[$(date)] [WARN] CLI drift detected for $AGENT_ID: arg=${CLI_TYPE}, pane=${pane_cli}. Using pane value." >&2
        fi
        echo "$pane_cli"
        return 0
    fi

    if is_valid_cli_type "${CLI_TYPE:-}"; then
        if [ -n "$pane_cli" ]; then
            echo "[$(date)] [WARN] Invalid pane @agent_cli for $AGENT_ID: '${pane_cli}'. Falling back to arg=${CLI_TYPE}." >&2
        fi
        echo "${CLI_TYPE}"
        return 0
    fi

    # Fail-closed: when CLI is unknown, take codex-safe path (no C-c, /clear->/new)
    echo "[$(date)] [WARN] CLI unresolved for $AGENT_ID (pane='${pane_cli:-<empty>}', arg='${CLI_TYPE:-<empty>}'). Fallback=codex-safe." >&2
    echo "codex"
}

normalize_special_command() {
    local msg_type="${1:-}"
    local raw_content="${2:-}"

    case "$msg_type" in
        clear_command)
            echo "/clear"
            ;;
        model_switch)
            if [[ "$raw_content" =~ ^/model[[:space:]]+[^[:space:]].* ]]; then
                echo "$raw_content"
            else
                echo "[$(date)] [SKIP] Invalid model_switch payload for $AGENT_ID: ${raw_content:-<empty>}" >&2
            fi
            ;;
    esac
}

enqueue_recovery_task_assigned() {
    (
        flock -x 200
        INBOX_PATH="$INBOX" AGENT_ID="$AGENT_ID" python3 - << 'PY'
import datetime
import os
import uuid
import yaml

inbox = os.environ.get("INBOX_PATH", "")
agent_id = os.environ.get("AGENT_ID", "agent")

try:
    with open(inbox, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    messages = data.get("messages", []) or []

    # Dedup guard: keep only one pending auto-recovery hint at a time.
    for m in reversed(messages):
        if (
            m.get("from") == "inbox_watcher"
            and m.get("type") == "task_assigned"
            and m.get("read", False) is False
            and "[auto-recovery]" in (m.get("content") or "")
        ):
            print("SKIP_DUPLICATE")
            raise SystemExit(0)

    now = datetime.datetime.now(datetime.timezone.utc).astimezone()
    msg = {
        "content": (
            f"[auto-recovery] /clear 後の再着手通知。"
            f"queue/tasks/{agent_id}.yaml を再読し、assigned タスクを即時再開せよ。"
        ),
        "from": "inbox_watcher",
        "id": f"msg_auto_recovery_{now.strftime('%Y%m%d_%H%M%S')}_{uuid.uuid4().hex[:8]}",
        "read": False,
        "timestamp": now.replace(microsecond=0).isoformat(),
        "type": "task_assigned",
    }
    messages.append(msg)
    data["messages"] = messages

    tmp_path = f"{inbox}.tmp.{os.getpid()}"
    with open(tmp_path, "w", encoding="utf-8") as f:
        yaml.safe_dump(
            data,
            f,
            default_flow_style=False,
            allow_unicode=True,
            sort_keys=False,
        )
    os.replace(tmp_path, inbox)
    print(msg["id"])
except Exception:
    # Best-effort safety net only. Primary /clear delivery must not fail here.
    print("ERROR")
PY
    ) 200>"$LOCKFILE" 2>/dev/null
}

no_idle_full_read() {
    local trigger="${1:-timeout}"
    [ "${ASW_NO_IDLE_FULL_READ:-1}" = "1" ] || return 1
    [ "$trigger" = "timeout" ] || return 1
    [ "${FIRST_UNREAD_SEEN:-0}" -eq 0 ] || return 1
    return 0
}

# summary-first: unread_count fast-path before full read
get_unread_count_fast() {
    INBOX_PATH="$INBOX" python3 - << 'PY'
import json
import os
import yaml

inbox = os.environ.get("INBOX_PATH", "")
try:
    with open(inbox, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    messages = data.get("messages", []) or []
    unread_count = sum(1 for m in messages if not m.get("read", False))
    print(json.dumps({"count": unread_count}))
except Exception:
    print(json.dumps({"count": 0}))
PY
}

# ─── Extract unread message info (lock-free read) ───
# Returns JSON lines: {"count": N, "has_special": true/false, "specials": [...]}
# Test anchor for bats awk pattern: get_unread_info\\(\\)
get_unread_info() {
    (
        flock -x 200
        INBOX_PATH="$INBOX" python3 - << 'PY'
import json
import os
import yaml

inbox = os.environ.get("INBOX_PATH", "")
try:
    with open(inbox, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}

    messages = data.get("messages", []) or []
    unread = [m for m in messages if not m.get("read", False)]
    special_types = ("clear_command", "model_switch")
    specials = [m for m in unread if m.get("type") in special_types]

    if specials:
        for m in messages:
            if not m.get("read", False) and m.get("type") in special_types:
                m["read"] = True

        tmp_path = f"{inbox}.tmp.{os.getpid()}"
        with open(tmp_path, "w", encoding="utf-8") as f:
            yaml.safe_dump(
                data,
                f,
                default_flow_style=False,
                allow_unicode=True,
                sort_keys=False,
            )
        os.replace(tmp_path, inbox)

    normal_count = len(unread) - len(specials)
    payload = {
        "count": normal_count,
        "specials": [{"type": m.get("type", ""), "content": m.get("content", "")} for m in specials],
    }
    print(json.dumps(payload))
except Exception:
    print(json.dumps({"count": 0, "specials": []}))
PY
    ) 200>"$LOCKFILE" 2>/dev/null
}

# ─── Send CLI command via pty direct write ───
# For /clear and /model only. These are CLI commands, not conversation messages.
# CLI_TYPE別分岐: claude→そのまま, codex→/clear対応・/modelスキップ,
#                  copilot→Ctrl-C+再起動・/modelスキップ
# 実行時にtmux paneの @agent_cli を再確認し、ドリフト時はpane値を優先する。
send_cli_command() {
    local cmd="$1"
    local effective_cli
    effective_cli=$(get_effective_cli_type)

    # Safety: never inject CLI commands into the shogun pane.
    # Shogun is controlled by the Lord; keystroke injection can clobber human input.
    if [ "$AGENT_ID" = "shogun" ]; then
        echo "[$(date)] [SKIP] shogun: suppressing CLI command injection ($cmd)" >&2
        return 0
    fi

    # CLI別コマンド変換
    local actual_cmd="$cmd"
    case "$effective_cli" in
        codex)
            # Codex: /clear不存在→/newで新規会話開始, /model非対応→スキップ
            # /clearはCodexでは未定義コマンドでCLI終了してしまうため、/newに変換
            if [[ "$cmd" == "/clear" ]]; then
                echo "[$(date)] [SEND-KEYS] Codex /clear→/new: starting new conversation for $AGENT_ID" >&2
                timeout 5 tmux send-keys -t "$PANE_TARGET" "/new" 2>/dev/null
                sleep 0.3
                timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null
                sleep 3
                return 0
            fi
            if [[ "$cmd" == /model* ]]; then
                echo "[$(date)] Skipping $cmd (not supported on codex)" >&2
                return 0
            fi
            ;;
        copilot)
            # Copilot: /clearはCtrl-C+再起動, /model非対応→スキップ
            if [[ "$cmd" == "/clear" ]]; then
                echo "[$(date)] [SEND-KEYS] Copilot /clear: sending Ctrl-C + restart for $AGENT_ID" >&2
                timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null
                sleep 2
                timeout 5 tmux send-keys -t "$PANE_TARGET" "copilot --yolo" 2>/dev/null
                sleep 0.3
                timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null
                sleep 3
                return 0
            fi
            if [[ "$cmd" == /model* ]]; then
                echo "[$(date)] Skipping $cmd (not supported on copilot)" >&2
                return 0
            fi
            ;;
        # claude: commands pass through as-is
    esac

    echo "[$(date)] [SEND-KEYS] Sending CLI command to $AGENT_ID ($effective_cli): $actual_cmd" >&2
    # Clear stale input first, then send command (text and Enter separated for Codex TUI)
    # Codex CLI: C-c when idle causes CLI to exit — skip it
    if [[ "$effective_cli" != "codex" ]]; then
        timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null
        sleep 0.5
    fi
    timeout 5 tmux send-keys -t "$PANE_TARGET" "$actual_cmd" 2>/dev/null
    sleep 0.3
    timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null

    # /clear needs extra wait time before follow-up
    if [[ "$actual_cmd" == "/clear" ]]; then
        sleep 3
    else
        sleep 1
    fi
}

# ─── Agent self-watch detection ───
# Check if the agent has an active inotifywait on its inbox.
# If yes, the agent will self-wake — no nudge needed.
agent_has_self_watch() {
    pgrep -f "inotifywait.*inbox/${AGENT_ID}.yaml" >/dev/null 2>&1
}

# ─── Agent busy detection ───
# Check if the agent's CLI is currently processing (Working/thinking/etc).
# Sending nudge during Working causes text to queue but Enter to be lost.
# Returns 0 (true) if agent is busy, 1 if idle.
agent_is_busy() {
    local pane_content
    # NOTE:
    # - Codex は「思考中に入力が入ると即拾う」ため、busy判定はシンプルに寄せる。
    # - Claude も含め、スピナー（見た目カスタムされがち）には依存しない。
    # - 取得行数を増やし過ぎると誤判定が増えるので、基本は直近の行だけを見る。
    pane_content=$(timeout 2 tmux capture-pane -t "$PANE_TARGET" -p -S -60 2>/dev/null | tail -60)

    # ── Idle prompt detection (early return) ──
    # Claude Code shows ❯ prompt when idle. This is the definitive idle signal.
    # Check last 5 non-empty lines — if ❯ is found, agent is idle regardless of
    # scrollback content (which may contain stale "esc to interrupt", "thought for", etc).
    local last_lines
    last_lines=$(echo "$pane_content" | grep -v '^[[:space:]]*$' | tail -5)
    if echo "$last_lines" | grep -q '^❯'; then
        return 1  # idle — Claude Code prompt visible
    fi

    # ── Busy detection (only reached when no idle prompt found) ──

    # Claude Code status bar shows "esc to interrupt" during active streaming.
    # NOTE: This text also appears in the idle status bar, but we already returned
    # idle above if ❯ prompt was found. So this only fires during actual streaming.
    if echo "$pane_content" | grep -qiF 'esc to interrupt'; then
        return 0  # busy
    fi

    # Codex sometimes shows this when a tool/terminal is running in the background.
    if echo "$pane_content" | grep -qiF 'background terminal running'; then
        return 0  # busy
    fi

    # Minimal fallbacks (no spinner dependency).
    # Only check last 10 lines to avoid scrollback contamination from previous output
    # (e.g. "thought for 3s" summary from a completed response).
    local recent_lines
    recent_lines=$(echo "$pane_content" | tail -10)
    if echo "$recent_lines" | grep -qiE '(Working|Thinking|Planning|Sending|task is in progress|Compacting conversation|thought for|思考中|考え中|計画中|送信中|処理中|実行中)'; then
        return 0  # busy
    fi
    return 1  # idle
}

# ─── Pane focus detection (human safety) ───
# If the target pane is currently active, avoid injecting keystrokes.
pane_is_active() {
    local active=""
    active=$(timeout 2 tmux display-message -p -t "$PANE_TARGET" '#{pane_active}' 2>/dev/null || true)
    [ "$active" = "1" ]
}

# ─── Send wake-up nudge ───
# Layered approach:
#   1. If agent has active inotifywait self-watch → skip (agent wakes itself)
#   2. If agent is busy (Working) → skip (nudge during Working loses Enter)
#   3. tmux send-keys (短いnudgeのみ、timeout 5s)
send_wakeup() {
    local unread_count="$1"
    local nudge="inbox${unread_count}"

    if [ "${FINAL_ESCALATION_ONLY:-0}" = "1" ]; then
        echo "[$(date)] [SKIP] FINAL_ESCALATION_ONLY=1, suppressing normal nudge for $AGENT_ID" >&2
        return 0
    fi

    # 優先度1: Agent self-watch — nudge不要（エージェントが自分で気づく）
    if agent_has_self_watch; then
        echo "[$(date)] [SKIP] Agent $AGENT_ID has active self-watch, no nudge needed" >&2
        return 0
    fi

    # 優先度2: Agent busy — nudge送信するとEnterが消失するためスキップ
    if agent_is_busy; then
        echo "[$(date)] [SKIP] Agent $AGENT_ID is busy (Working), deferring nudge" >&2
        return 0
    fi

    if should_throttle_nudge "$unread_count"; then
        return 0
    fi

    # Shogun: inject nudge even when pane is active.
    # ntfy messages come from Lord's phone → Lord is not typing at terminal.
    # Display-message is also shown as visual indicator.
    if [ "$AGENT_ID" = "shogun" ] && pane_is_active; then
        echo "[$(date)] [NUDGE] shogun pane active — injecting nudge + display: inbox${unread_count}" >&2
        timeout 2 tmux display-message -t "$PANE_TARGET" -d 3000 "📱 ntfy受信あり (inbox${unread_count})" 2>/dev/null || true
    fi

    # 優先度3: tmux send-keys（テキストとEnterを分離 — Codex TUI対策）
    echo "[$(date)] [SEND-KEYS] Sending nudge to $PANE_TARGET for $AGENT_ID" >&2
    if timeout 5 tmux send-keys -t "$PANE_TARGET" "$nudge" 2>/dev/null; then
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null
        echo "[$(date)] Wake-up sent to $AGENT_ID (${unread_count} unread)" >&2
        return 0
    fi

    echo "[$(date)] WARNING: send-keys failed or timed out for $AGENT_ID" >&2
    return 1
}

# ─── Send wake-up nudge with Escape prefix ───
# Phase 2 escalation: send Escape×2 + C-c to clear stuck input, then nudge.
# Addresses the "echo last tool call" cursor position bug and stale input.
send_wakeup_with_escape() {
    local unread_count="$1"
    local nudge="inbox${unread_count}"
    local effective_cli
    effective_cli=$(get_effective_cli_type)
    local c_ctrl_state="skipped"

    # Safety: never send Escape escalation to shogun. It can wipe the Lord's input.
    if [ "$AGENT_ID" = "shogun" ]; then
        echo "[$(date)] [SKIP] shogun: suppressing Escape escalation; sending plain nudge" >&2
        send_wakeup "$unread_count"
        return 0
    fi

    # Codex CLI: ESC は「中断」になりやすく、人間操作中の事故も多い。
    # Phase 2 の Escape エスカレーションは無効化し、通常 nudge のみに落とす。
    if [[ "$effective_cli" == "codex" ]]; then
        echo "[$(date)] [SKIP] codex: suppressing Escape escalation for $AGENT_ID; sending plain nudge" >&2
        send_wakeup "$unread_count"
        return 0
    fi

    if [ "${FINAL_ESCALATION_ONLY:-0}" = "1" ]; then
        echo "[$(date)] [SKIP] FINAL_ESCALATION_ONLY=1, suppressing phase2 nudge for $AGENT_ID" >&2
        return 0
    fi

    if agent_has_self_watch; then
        return 0
    fi

    # Phase 2 still skips if agent is busy — Escape during Working would interrupt
    if agent_is_busy; then
        echo "[$(date)] [SKIP] Agent $AGENT_ID is busy (Working), deferring Phase 2 nudge" >&2
        return 0
    fi

    echo "[$(date)] [SEND-KEYS] ESCALATION Phase 2: Escape×2 + nudge for $AGENT_ID (cli=$effective_cli)" >&2
    # Escape×2 to exit any mode
    timeout 5 tmux send-keys -t "$PANE_TARGET" Escape Escape 2>/dev/null
    sleep 0.5
    # C-c to clear stale input (but Codex CLI terminates on C-c when idle, so skip it)
    if [[ "$effective_cli" != "codex" ]]; then
        timeout 5 tmux send-keys -t "$PANE_TARGET" C-c 2>/dev/null
        sleep 0.5
        c_ctrl_state="sent"
    fi
    if timeout 5 tmux send-keys -t "$PANE_TARGET" "$nudge" 2>/dev/null; then
        sleep 0.3
        timeout 5 tmux send-keys -t "$PANE_TARGET" Enter 2>/dev/null
        echo "[$(date)] Escape+nudge sent to $AGENT_ID (${unread_count} unread, cli=$effective_cli, C-c=$c_ctrl_state)" >&2
        return 0
    fi

    echo "[$(date)] WARNING: send-keys failed for Escape+nudge ($AGENT_ID)" >&2
    return 1
}

# ─── Process cycle ───
process_unread() {
    local trigger="${1:-event}"

    # summary-first: unread_count fast-path (Phase 2/3 optimization)
    # unread_count fast-path lets us skip expensive full reads when idle.
    local fast_info
    fast_info=$(get_unread_count_fast)
    local fast_count
    fast_count=$(echo "$fast_info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)

    if no_idle_full_read "$trigger" && [ "$fast_count" -eq 0 ] 2>/dev/null; then
        # no_idle_full_read guard: unread=0 and timeout path → no full inbox read
        if [ "$FIRST_UNREAD_SEEN" -ne 0 ]; then
            echo "[$(date)] All messages read for $AGENT_ID — escalation reset (fast-path)" >&2
        fi
        FIRST_UNREAD_SEEN=0
        if ! agent_is_busy; then
            # Shogun is human-controlled; never clear the input line automatically.
            if [ "$AGENT_ID" != "shogun" ]; then
                timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null
            fi
        fi
        return 0
    fi

    local info
    info=$(get_unread_info)

    local read_bytes=0
    if [ -f "$INBOX" ]; then
        read_bytes=$(wc -c < "$INBOX" 2>/dev/null || echo 0)
    fi
    update_metrics "${read_bytes:-0}"

    # Handle special CLI commands first (/clear, /model)
    local specials
    specials=$(echo "$info" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for s in data.get('specials', []):
    t = s.get('type', '')
    c = (s.get('content', '') or '').replace('\t', ' ').replace('\n', ' ').strip()
    print(f'{t}\t{c}')
" 2>/dev/null)

    local clear_seen=0
    if [ -n "$specials" ]; then
        local msg_type msg_content cmd
        while IFS=$'\t' read -r msg_type msg_content; do
            [ -n "$msg_type" ] || continue
            if [ "$msg_type" = "clear_command" ]; then
                clear_seen=1
            fi
            cmd=$(normalize_special_command "$msg_type" "$msg_content")
            [ -n "$cmd" ] && send_cli_command "$cmd"
        done <<< "$specials"
    fi

    # /clear は Codex で /new へ変換される。再起動直後の取りこぼし防止として
    # 追加 task_assigned を自動投入し、次サイクルで確実に wake-up 可能にする。
    if [ "$clear_seen" -eq 1 ]; then
        local recovery_id
        recovery_id=$(enqueue_recovery_task_assigned)
        if [ -n "$recovery_id" ] && [ "$recovery_id" != "SKIP_DUPLICATE" ] && [ "$recovery_id" != "ERROR" ]; then
            echo "[$(date)] [AUTO-RECOVERY] queued task_assigned for $AGENT_ID ($recovery_id)" >&2
        fi
        info=$(get_unread_info)
    fi

    # Send wake-up nudge for normal messages (with escalation)
    local normal_count
    normal_count=$(echo "$info" | python3 -c "import sys,json; print(json.load(sys.stdin).get('count',0))" 2>/dev/null)

    if [ "$normal_count" -gt 0 ] 2>/dev/null; then
        local now
        now=$(date +%s)

        # When the agent is busy/thinking, do NOT escalate. Interrupting with Escape or /clear
        # can terminate the current thought. Also pause the escalation timer while busy so we
        # don't immediately jump to Phase 2/3 once it becomes idle.
        if agent_is_busy; then
            FIRST_UNREAD_SEEN=$now
            echo "[$(date)] $normal_count unread for $AGENT_ID but agent is busy — pausing escalation timer" >&2
            return 0
        fi

        # Track when we first saw unread messages
        if [ "$FIRST_UNREAD_SEEN" -eq 0 ]; then
            FIRST_UNREAD_SEEN=$now
        fi

        if [ "${ASW_DISABLE_ESCALATION:-0}" = "1" ]; then
            echo "[$(date)] $normal_count unread for $AGENT_ID (escalation disabled)" >&2
            if disable_normal_nudge; then
                echo "[$(date)] [SKIP] disable_normal_nudge=1, no normal nudge for $AGENT_ID" >&2
            else
                send_wakeup "$normal_count"
            fi
            return 0
        fi

        local age=$((now - FIRST_UNREAD_SEEN))

        if [ "$age" -lt "$ESCALATE_PHASE1" ]; then
            # Phase 1 (0-2 min): Standard nudge
            echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s)" >&2
            if disable_normal_nudge; then
                echo "[$(date)] [SKIP] disable_normal_nudge=1, deferring to escalation-only path" >&2
            else
                send_wakeup "$normal_count"
            fi
        elif [ "$age" -lt "$ESCALATE_PHASE2" ]; then
            # Phase 2 (2-4 min): Escape + nudge
            echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s — escalating: Escape+nudge)" >&2
            send_wakeup_with_escape "$normal_count"
        else
            # Phase 3 (4+ min): /clear (throttled to once per 5 min)
            if [ "$LAST_CLEAR_TS" -lt "$((now - ESCALATE_COOLDOWN))" ]; then
                local effective_cli
                effective_cli=$(get_effective_cli_type)
                if [[ "$effective_cli" == "codex" ]]; then
                    # Codex /clear -> /new は会話を切ってしまうため、安全側に倒す。
                    echo "[$(date)] ESCALATION Phase 3: $AGENT_ID unresponsive for ${age}s, but cli=codex — skipping /clear." >&2
                    FIRST_UNREAD_SEEN=$now  # Reset timer (no destructive action)
                    send_wakeup "$normal_count"
                else
                    echo "[$(date)] ESCALATION Phase 3: Agent $AGENT_ID unresponsive for ${age}s. Sending /clear." >&2
                    send_cli_command "/clear"
                    LAST_CLEAR_TS=$now
                    FIRST_UNREAD_SEEN=0  # Reset — will re-detect on next cycle
                fi
            else
                # Cooldown active — fall back to Escape+nudge
                echo "[$(date)] $normal_count unread for $AGENT_ID (${age}s — /clear cooldown, using Escape+nudge)" >&2
                send_wakeup_with_escape "$normal_count"
            fi
        fi
    else
        # No unread messages — reset escalation tracker
        if [ "$FIRST_UNREAD_SEEN" -ne 0 ]; then
            echo "[$(date)] All messages read for $AGENT_ID — escalation reset" >&2
        fi
        FIRST_UNREAD_SEEN=0
        # Clear stale nudge text from input field (Codex CLI prefills last input on idle).
        # Only send C-u when agent is idle — during Working it would be disruptive.
        if ! agent_is_busy; then
            # Shogun is human-controlled; never clear the input line automatically.
            if [ "$AGENT_ID" != "shogun" ]; then
                timeout 2 tmux send-keys -t "$PANE_TARGET" C-u 2>/dev/null
            fi
        fi
    fi
}

process_unread_once() {
    process_unread "startup"
}

# ─── Startup & Main loop (skipped in testing mode) ───
if [ "${__INBOX_WATCHER_TESTING__:-}" != "1" ]; then

# ─── Startup: process any existing unread messages ───
process_unread_once

# ─── Main loop: event-driven via inotifywait ───
# Timeout 30s: WSL2 /mnt/c/ can miss inotify events.
# Shorter timeout = faster escalation retry for stuck agents.
INOTIFY_TIMEOUT=30

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
    # rc=2: timeout (30s safety net for WSL2 inotify gaps)
    # All cases: check for unread, then loop back to inotifywait (re-watches new inode)
    sleep 0.3

    if [ "$rc" -eq 2 ]; then
        if [ "${ASW_PROCESS_TIMEOUT:-1}" = "1" ]; then
            process_unread "timeout"
        fi
    else
        process_unread "event"
    fi
done

fi  # end testing guard
