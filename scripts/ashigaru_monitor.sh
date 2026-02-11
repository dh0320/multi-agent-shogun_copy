#!/bin/bash
# 足軽1停止監視スクリプト（ashigaru_monitor.sh）
# 5分間隔で足軽1ペーンを監視し、停止を検知したら家老に通知

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# 設定
MONITOR_INTERVAL=300  # 5分間隔（秒）
PANE_TARGET="multiagent:0.1"  # 足軽1のペーン
STATE_FILE="./logs/ashigaru1_monitor_state.txt"
PID_FILE="./scripts/ashigaru_monitor.pid"
LOG_FILE="./logs/ashigaru_monitor.log"
ASHIGARU1_YAML="./queue/tasks/ashigaru1.yaml"

# ログ関数
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# PIDファイル作成
echo $$ > "$PID_FILE"
log "ashigaru_monitor.sh started (PID: $$)"

# 初回は状態ファイルなし
if [ ! -f "$STATE_FILE" ]; then
    touch "$STATE_FILE"
fi

# 前回の画面内容
PREV_SCREEN=""

# 通知済みフラグ（同一停止に対して繰り返し通知しない）
NOTIFIED=false

# メインループ
while true; do
    # 足軽1の画面内容を取得
    CURRENT_SCREEN=$(tmux capture-pane -t "$PANE_TARGET" -p 2>/dev/null || echo "")

    # tmuxペーンが存在しない場合はスキップ
    if [ -z "$CURRENT_SCREEN" ]; then
        log "WARNING: Pane $PANE_TARGET not found. Skipping check."
        sleep "$MONITOR_INTERVAL"
        continue
    fi

    # ashigaru1.yamlのstatus確認（idle状態なら通知不要）
    # jq禁止（F032）のためpython3で解析
    ASHIGARU_STATUS=$(python3 -c "
import yaml
try:
    with open('$ASHIGARU1_YAML') as f:
        data = yaml.safe_load(f)
        print(data.get('task', {}).get('status', 'unknown'))
except:
    print('unknown')
" 2>/dev/null || echo "unknown")

    # idle状態なら監視をスキップ（正常な待機中）
    if [ "$ASHIGARU_STATUS" = "idle" ]; then
        log "Ashigaru1 is idle (no task assigned). Skipping check."
        PREV_SCREEN="$CURRENT_SCREEN"
        NOTIFIED=false
        sleep "$MONITOR_INTERVAL"
        continue
    fi

    # 画面内容が変化しているかチェック
    if [ -n "$PREV_SCREEN" ] && [ "$PREV_SCREEN" = "$CURRENT_SCREEN" ]; then
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
        if echo "$LAST_LINE" | grep -qE '^\(足軽1\)|^\$|^>|^Claude Code'; then
            # 最終行がプロンプトまたはClaude Code待機
            # かつ、その前の行が数行しかない（作業内容が少ない）
            LINE_COUNT=$(echo "$CURRENT_SCREEN" | wc -l)
            if [ "$LINE_COUNT" -lt 10 ]; then
                PROMPT_ONLY=true
            fi
        fi

        # 通知判定（エラーまたはプロンプトのみ、かつ未通知）
        if [ "$NOTIFIED" = "false" ] && { [ "$ERROR_DETECTED" = "true" ] || [ "$PROMPT_ONLY" = "true" ]; }; then
            # 家老に通知
            REASON=""
            if [ "$ERROR_DETECTED" = "true" ]; then
                REASON="エラー検出"
            else
                REASON="プロンプト待機（作業停止）"
            fi

            log "ALERT: Ashigaru1 appears to be stopped ($REASON). Notifying Karo."
            bash "$SCRIPT_DIR/inbox_write.sh" karo \
                "足軽1停止検知（${MONITOR_INTERVAL}秒間画面変化なし・${REASON}）。状態確認・nudgeせよ。" \
                alert monitor 2>&1 | tee -a "$LOG_FILE"

            NOTIFIED=true
        else
            log "Screen unchanged but no action needed (NOTIFIED=$NOTIFIED, ERROR=$ERROR_DETECTED, PROMPT_ONLY=$PROMPT_ONLY)"
        fi
    else
        # 画面が変化している（正常動作中）
        log "Ashigaru1 screen changed. Looks active."
        NOTIFIED=false
    fi

    # 現在の画面内容を保存
    PREV_SCREEN="$CURRENT_SCREEN"
    echo "$CURRENT_SCREEN" > "$STATE_FILE"

    # 次のチェックまで待機
    sleep "$MONITOR_INTERVAL"
done
