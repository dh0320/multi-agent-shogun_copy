#!/bin/bash
# 足軽・家老監視スクリプト（ashigaru_monitor.sh）
# 5分間隔で全足軽ペーンと家老ペーンを監視
# 足軽: 停止を検知したら家老に通知
# 家老: idle+低コンテキストを検知したら自動/clear

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 設定
MONITOR_INTERVAL=300  # 5分間隔（秒）
ASHIGARU_PANES=("multiagent:0.1" "multiagent:0.2" "multiagent:0.3" "multiagent:0.4" "multiagent:0.5" "multiagent:0.6" "multiagent:0.7" "multiagent:0.8")  # 足軽1-8
ASHIGARU_IDS=("ashigaru1" "ashigaru2" "ashigaru3" "ashigaru4" "ashigaru5" "ashigaru6" "ashigaru7" "ashigaru8")
KARO_PANE="multiagent:0.0"  # 家老ペーン
KARO_ID="karo"
CONTEXT_THRESHOLD=10  # コンテキスト閾値（%）
STATE_DIR="./logs/monitor_state"
CAPTURE_DIR="./logs/monitor_captures"
PID_FILE="./scripts/ashigaru_monitor.pid"
LOG_FILE="./logs/ashigaru_monitor.log"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# 状態ディレクトリ作成
mkdir -p "$STATE_DIR"
mkdir -p "$CAPTURE_DIR"

# PIDファイル作成
echo $$ > "$PID_FILE"
log "ashigaru_monitor.sh started (PID: $$, monitoring ${#ASHIGARU_PANES[@]} ashigaru + 1 karo)"

# ═══════════════════════════════════════════════════════════════════════════════
# ペーン死亡検知 + 自動respawn関数
# remain-on-exitが有効な環境で、プロセス死亡（OOM Kill等）を検知し自動復旧する
# 家老ペーン（multiagent:0.0）は対象外（手動対応のみ）
# ═══════════════════════════════════════════════════════════════════════════════
check_and_respawn_pane() {
    local pane="$1"
    local agent_id="$2"

    # #{pane_dead} が "1" ならプロセスは終了済み（ペーンはremain-on-exitで残存）
    local pane_dead
    pane_dead=$(tmux display-message -t "$pane" -p '#{pane_dead}' 2>/dev/null || echo "")

    if [ "$pane_dead" != "1" ]; then
        return 1  # 生存中 — 何もしない
    fi

    log "RESPAWN: $agent_id pane is dead. Initiating auto-respawn."

    # ペーンオプションを取得（respawn-paneはペーンオブジェクトを保持するため設定は残る）
    local model_name agent_cli
    model_name=$(tmux show-options -p -t "$pane" -v @model_name 2>/dev/null || echo "Sonnet")
    agent_cli=$(tmux show-options -p -t "$pane" -v @agent_cli 2>/dev/null || echo "claude")

    # CLI起動コマンドを構築
    local cli_cmd=""
    case "$agent_cli" in
        claude)
            local model_flag="sonnet"
            case "$model_name" in
                [Oo]pus*) model_flag="opus" ;;
                [Ss]onnet*) model_flag="sonnet" ;;
            esac
            cli_cmd="claude --model $model_flag --dangerously-skip-permissions"
            ;;
        codex*)
            cli_cmd="codex --full-auto"
            ;;
        *)
            cli_cmd="claude --model sonnet --dangerously-skip-permissions"
            ;;
    esac

    # respawnログ保存
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local respawn_log="$CAPTURE_DIR/respawn_${agent_id}_${timestamp}.log"
    {
        echo "=== Pane Respawn Log ==="
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
        echo "Agent: $agent_id"
        echo "Pane: $pane"
        echo "CLI type: $agent_cli"
        echo "Model: $model_name"
        echo "Command: $cli_cmd"
        echo "========================"
    } > "$respawn_log"

    # ペーンをrespawn（新しいシェルを起動）
    if ! tmux respawn-pane -t "$pane" 2>>"$respawn_log"; then
        log "RESPAWN: FAILED to respawn $agent_id pane. See $respawn_log"
        return 0
    fi
    sleep 2

    # 環境セットアップ（cd + bashrc + clear）
    local project_dir
    project_dir=$(pwd)
    tmux send-keys -t "$pane" "cd \"${project_dir}\" && source ~/.bashrc && clear" Enter
    sleep 1

    # Claude Code起動
    tmux send-keys -t "$pane" "$cli_cmd" Enter

    log "RESPAWN: $agent_id respawned with '$cli_cmd'. Log: $respawn_log"

    # 家老に通知
    bash "$SCRIPT_DIR/inbox_write.sh" karo \
        "${agent_id}ペーン死亡検知→自動respawn実行。CLI=${agent_cli}, Model=${model_name}。ログ: ${respawn_log}" \
        alert monitor 2>&1 | tee -a "$LOG_FILE"

    # 監視状態をリセット
    NOTIFIED_FLAGS[$agent_id]=false
    NOTIFIED_FLAGS[${agent_id}_noclaude]=false
    UNCHANGED_COUNTS[$agent_id]=0
    NOCLAUDE_COUNTS[$agent_id]=0
    PREV_SCREENS[$agent_id]=""

    return 0  # 死亡→respawn実行済み
}

# ═══════════════════════════════════════════════════════════════════════════════
# Claude Code未起動検知
# ペーンは生きているがClaude Codeプロセスが動いていないケースを検知する
# ペーン死亡（check_and_respawn_pane）とは異なるケース
# ═══════════════════════════════════════════════════════════════════════════════
check_claude_code_running() {
    local pane="$1"

    # ペーンのシェルPIDを取得
    local pane_pid
    pane_pid=$(tmux display-message -t "$pane" -p '#{pane_pid}' 2>/dev/null || echo "")

    if [ -z "$pane_pid" ]; then
        return 0  # 判定不能 — 誤報防止のため「起動中」扱い
    fi

    # claude または codex プロセスがペーンのシェルの子プロセスとして存在するか確認
    if pgrep -f "claude" -P "$pane_pid" >/dev/null 2>&1; then
        return 0  # Claude Code起動中
    fi
    if pgrep -f "codex" -P "$pane_pid" >/dev/null 2>&1; then
        return 0  # Codex起動中
    fi

    # いずれも見つからない — Claude Code未起動
    return 1
}

# 各足軽の前回画面内容と通知フラグ・変化なしカウンタを保持
declare -A PREV_SCREENS
declare -A NOTIFIED_FLAGS
declare -A UNCHANGED_COUNTS
declare -A NOCLAUDE_COUNTS

# 初期化
for id in "${ASHIGARU_IDS[@]}"; do
    NOTIFIED_FLAGS[$id]=false
    UNCHANGED_COUNTS[$id]=0
    NOCLAUDE_COUNTS[$id]=0
    STATE_FILE="$STATE_DIR/${id}_state.txt"
    if [ -f "$STATE_FILE" ]; then
        PREV_SCREENS[$id]=$(cat "$STATE_FILE")
    else
        PREV_SCREENS[$id]=""
    fi
done

# 家老の状態も初期化
NOTIFIED_FLAGS[$KARO_ID]=false
UNCHANGED_COUNTS[$KARO_ID]=0
KARO_STATE_FILE="$STATE_DIR/${KARO_ID}_state.txt"
if [ -f "$KARO_STATE_FILE" ]; then
    PREV_SCREENS[$KARO_ID]=$(cat "$KARO_STATE_FILE")
else
    PREV_SCREENS[$KARO_ID]=""
fi

# メインループ
while true; do
    for i in "${!ASHIGARU_PANES[@]}"; do
        PANE="${ASHIGARU_PANES[$i]}"
        ID="${ASHIGARU_IDS[$i]}"
        YAML_FILE="./queue/tasks/${ID}.yaml"
        STATE_FILE="$STATE_DIR/${ID}_state.txt"

        # ペーン死亡検知（最優先チェック）
        if check_and_respawn_pane "$PANE" "$ID"; then
            continue  # 死亡→respawn済み。次サイクルで正常監視再開
        fi

        # Claude Code未起動検知（ペーン生存だがCLIプロセスなし）
        if ! check_claude_code_running "$PANE"; then
            NOCLAUDE_COUNTS[$ID]=$((${NOCLAUDE_COUNTS[$ID]} + 1))

            if [ "${NOCLAUDE_COUNTS[$ID]}" -ge 2 ] && [ "${NOTIFIED_FLAGS[${ID}_noclaude]:-false}" = "false" ]; then
                log "ALERT: $ID pane alive but Claude Code NOT running (${NOCLAUDE_COUNTS[$ID]} cycles). Notifying karo."

                # ペインログ保存
                TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
                CAPTURE_FILE="$CAPTURE_DIR/${ID}_noclaude_${TIMESTAMP}.txt"
                NOCLAUDE_SCREEN=$(tmux capture-pane -t "$PANE" -p 2>/dev/null || echo "")
                echo "$NOCLAUDE_SCREEN" > "$CAPTURE_FILE"
                log "Saved pane capture to $CAPTURE_FILE"

                bash "$SCRIPT_DIR/inbox_write.sh" karo \
                    "${ID}ペーンは生存だがClaude Code未起動（${NOCLAUDE_COUNTS[$ID]}サイクル連続検知）。ペインログ: $CAPTURE_FILE。確認せよ。" \
                    alert monitor 2>&1 | tee -a "$LOG_FILE"

                NOTIFIED_FLAGS[${ID}_noclaude]=true
            else
                log "$ID: Claude Code not running, cycle ${NOCLAUDE_COUNTS[$ID]} (notified=${NOTIFIED_FLAGS[${ID}_noclaude]:-false})"
            fi
            continue  # CLIが起動していないので画面監視はスキップ
        fi

        # Claude Code起動中 — 未起動カウンタをリセット
        NOCLAUDE_COUNTS[$ID]=0
        NOTIFIED_FLAGS[${ID}_noclaude]=false

        # 足軽の画面内容を取得
        CURRENT_SCREEN=$(tmux capture-pane -t "$PANE" -p 2>/dev/null || echo "")

        # tmuxペーンが存在しない場合はスキップ
        if [ -z "$CURRENT_SCREEN" ]; then
            log "WARNING: Pane $PANE ($ID) not found. Skipping check."
            continue
        fi

        # YAMLのstatus確認（idle状態なら通知不要）
        ASHIGARU_STATUS=$(python3 -c "
import yaml
try:
    with open('$YAML_FILE') as f:
        data = yaml.safe_load(f)
        print(data.get('task', {}).get('status', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

        # idle状態なら監視をスキップ（正常な待機中）
        if [ "$ASHIGARU_STATUS" = "idle" ]; then
            if [ "${NOTIFIED_FLAGS[$ID]}" = "true" ]; then
                log "$ID became idle (no task assigned). Resetting notification flag."
            fi
            PREV_SCREENS[$ID]="$CURRENT_SCREEN"
            NOTIFIED_FLAGS[$ID]=false
            UNCHANGED_COUNTS[$ID]=0
            echo "$CURRENT_SCREEN" > "$STATE_FILE"
            continue
        fi

        # 画面内容が変化しているかチェック
        if [ -n "${PREV_SCREENS[$ID]}" ] && [ "${PREV_SCREENS[$ID]}" = "$CURRENT_SCREEN" ]; then
            # 画面が変化していない（停止の可能性）

            # エラーメッセージの検出
            ERROR_DETECTED=false
            if echo "$CURRENT_SCREEN" | grep -qi "error\|exception\|failed\|traceback"; then
                ERROR_DETECTED=true
            fi

            # プロンプト行のみ（作業していない）の検出
            # Claude Code待ち受け状態やシェルプロンプトのみの状態
            LAST_LINE=$(echo "$CURRENT_SCREEN" | tail -1)
            PROMPT_ONLY=false

            # (B) 待機パターン検出
            if echo "$CURRENT_SCREEN" | grep -qE "Waiting for|Sautéed for [5-9][0-9]*m|idle"; then
                PROMPT_ONLY=true
            fi

            if echo "$LAST_LINE" | grep -qE '^\(足軽[1-8]\)|^\$|^>|^❯|^Claude Code'; then
                # 最終行がプロンプトまたはClaude Code待機
                # かつ、その前の行が数行しかない（作業内容が少ない）
                LINE_COUNT=$(echo "$CURRENT_SCREEN" | wc -l)
                # (A) LINE_COUNT閾値引き上げ: 10→30
                if [ "$LINE_COUNT" -lt 30 ]; then
                    PROMPT_ONLY=true
                fi
            fi

            # (C) 2サイクル連続変化なし判定
            UNCHANGED_COUNTS[$ID]=$((${UNCHANGED_COUNTS[$ID]} + 1))

            # 通知判定（エラーまたはプロンプトのみ、2サイクル連続、かつ未通知）
            if [ "${NOTIFIED_FLAGS[$ID]}" = "false" ] && [ "${UNCHANGED_COUNTS[$ID]}" -ge 2 ] && { [ "$ERROR_DETECTED" = "true" ] || [ "$PROMPT_ONLY" = "true" ]; }; then
                # 家老に通知
                REASON=""
                if [ "$ERROR_DETECTED" = "true" ]; then
                    REASON="エラー検出"
                else
                    REASON="プロンプト待機（作業停止）"
                fi

                log "ALERT: $ID appears to be stopped ($REASON, ${UNCHANGED_COUNTS[$ID]} cycles). Notifying Karo."

                # (D) 停止検知時にペインログを保存
                TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
                CAPTURE_FILE="$CAPTURE_DIR/${ID}_${TIMESTAMP}.txt"
                echo "$CURRENT_SCREEN" > "$CAPTURE_FILE"
                log "Saved pane capture to $CAPTURE_FILE"

                bash "$SCRIPT_DIR/inbox_write.sh" karo \
                    "${ID}停止検知（${UNCHANGED_COUNTS[$ID]}サイクル連続変化なし・${REASON}）。ペインログ: $CAPTURE_FILE。状態確認・nudgeせよ。" \
                    alert monitor 2>&1 | tee -a "$LOG_FILE"

                NOTIFIED_FLAGS[$ID]=true
            else
                log "$ID: Screen unchanged cycle ${UNCHANGED_COUNTS[$ID]} (NOTIFIED=${NOTIFIED_FLAGS[$ID]}, ERROR=$ERROR_DETECTED, PROMPT_ONLY=$PROMPT_ONLY)"
            fi
        else
            # 画面が変化している（正常動作中）
            if [ -n "${PREV_SCREENS[$ID]}" ]; then
                log "$ID: Screen changed. Looks active."
            fi
            NOTIFIED_FLAGS[$ID]=false
            UNCHANGED_COUNTS[$ID]=0
        fi

        # 現在の画面内容を保存
        PREV_SCREENS[$ID]="$CURRENT_SCREEN"
        echo "$CURRENT_SCREEN" > "$STATE_FILE"
    done

    # ========================================
    # 家老（karo）監視ロジック
    # ========================================
    # 家老ペーン死亡検知（自動respawn対象外 — ログ記録のみ）
    KARO_DEAD=$(tmux display-message -t "$KARO_PANE" -p '#{pane_dead}' 2>/dev/null || echo "")
    if [ "$KARO_DEAD" = "1" ]; then
        if [ "${NOTIFIED_FLAGS[karo_dead]:-false}" = "false" ]; then
            log "CRITICAL: Karo pane is dead! Manual intervention required."
            TIMESTAMP_KARO=$(date '+%Y%m%d_%H%M%S')
            {
                echo "=== CRITICAL: Karo Pane Death Detected ==="
                echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
                echo "Pane: $KARO_PANE"
                echo "Action required: Manual respawn (auto-respawn disabled for karo)"
                echo "Command: tmux respawn-pane -t $KARO_PANE"
            } > "$CAPTURE_DIR/respawn_karo_${TIMESTAMP_KARO}.log"
            NOTIFIED_FLAGS[karo_dead]=true
        fi
    else
        NOTIFIED_FLAGS[karo_dead]=false
    fi

    KARO_SCREEN=$(tmux capture-pane -t "$KARO_PANE" -p 2>/dev/null || echo "")

    if [ -n "$KARO_SCREEN" ]; then
        # idle状態の検出（Claude Codeプロンプト ❯ が表示されている）
        KARO_IDLE=false
        if echo "$KARO_SCREEN" | tail -5 | grep -qE '^❯|^Claude Code'; then
            KARO_IDLE=true
        fi

        # コンテキスト残量の検出（例: "12345/200000" のようなパターン）
        KARO_LOW_CONTEXT=false
        CONTEXT_LINE=$(echo "$KARO_SCREEN" | grep -oE '[0-9]+/[0-9]+' | tail -1 || echo "")
        if [ -n "$CONTEXT_LINE" ]; then
            USED=$(echo "$CONTEXT_LINE" | cut -d'/' -f1)
            TOTAL=$(echo "$CONTEXT_LINE" | cut -d'/' -f2)
            if [ "$USED" -gt 0 ] && [ "$TOTAL" -gt 0 ]; then
                CONTEXT_PERCENT=$((100 * ($TOTAL - $USED) / $TOTAL))
                if [ "$CONTEXT_PERCENT" -le "$CONTEXT_THRESHOLD" ]; then
                    KARO_LOW_CONTEXT=true
                fi
                log "karo: context=$CONTEXT_PERCENT% remaining (idle=$KARO_IDLE)"
            fi
        fi

        # 画面変化チェック
        if [ -n "${PREV_SCREENS[$KARO_ID]}" ] && [ "${PREV_SCREENS[$KARO_ID]}" = "$KARO_SCREEN" ]; then
            # 画面が変化していない
            UNCHANGED_COUNTS[$KARO_ID]=$((${UNCHANGED_COUNTS[$KARO_ID]} + 1))

            # idle + 低コンテキスト + 2サイクル連続変化なし + 未通知 → /clear送信
            if [ "$KARO_IDLE" = "true" ] && [ "$KARO_LOW_CONTEXT" = "true" ] && \
               [ "${UNCHANGED_COUNTS[$KARO_ID]}" -ge 2 ] && [ "${NOTIFIED_FLAGS[$KARO_ID]}" = "false" ]; then

                log "ACTION: karo idle + low context detected (${UNCHANGED_COUNTS[$KARO_ID]} cycles). Sending /clear."

                # ペインログ保存
                TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
                CAPTURE_FILE="$CAPTURE_DIR/karo_${TIMESTAMP}.txt"
                echo "$KARO_SCREEN" > "$CAPTURE_FILE"
                log "Saved karo pane capture to $CAPTURE_FILE"

                # /clearを送信（家老ペインに）
                tmux send-keys -t "$KARO_PANE" "/clear" Enter 2>&1 | tee -a "$LOG_FILE"

                NOTIFIED_FLAGS[$KARO_ID]=true
                log "Sent /clear to karo pane."
            else
                log "karo: unchanged cycle ${UNCHANGED_COUNTS[$KARO_ID]} (idle=$KARO_IDLE, low_context=$KARO_LOW_CONTEXT, notified=${NOTIFIED_FLAGS[$KARO_ID]})"
            fi
        else
            # 画面が変化している（作業中）
            if [ -n "${PREV_SCREENS[$KARO_ID]}" ] && [ "${UNCHANGED_COUNTS[$KARO_ID]}" -gt 0 ]; then
                log "karo: Screen changed. Active. Resetting counters."
            fi
            NOTIFIED_FLAGS[$KARO_ID]=false
            UNCHANGED_COUNTS[$KARO_ID]=0
        fi

        # 現在の画面内容を保存
        PREV_SCREENS[$KARO_ID]="$KARO_SCREEN"
        echo "$KARO_SCREEN" > "$KARO_STATE_FILE"
    else
        log "WARNING: Karo pane $KARO_PANE not found. Skipping karo check."
    fi

    # 次のチェックまで待機
    sleep "$MONITOR_INTERVAL"
done
