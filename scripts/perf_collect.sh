#!/usr/bin/env bash
# perf_collect.sh — パフォーマンス定点監視スクリプト
# 毎日08:30 JSTにlaunchdから呼び出す

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THRESHOLDS_FILE="$SCRIPT_DIR/config/perf_thresholds.yaml"
METRICS_FILE="$SCRIPT_DIR/queue/perf_metrics.yaml"
COLLECTED_AT="$(date +%Y-%m-%dT%H:%M:%S%z)"
DATE_TODAY="$(date +%Y-%m-%d)"

# ============================================================
# 閾値読み込み（grep + awk、PyYAML不使用、bash 3.2互換）
# ============================================================

_get_threshold() {
    local section="$1"
    local key="$2"
    grep -A2 "${section}:" "$THRESHOLDS_FILE" | grep "${key}:" | awk '{print $2}' | head -1
}

THRESH_COMPACTION_WARN="$(_get_threshold "compaction_per_session" "warn")"
THRESH_COMPACTION_CRIT="$(_get_threshold "compaction_per_session" "critical")"
THRESH_CONTEXT_WARN="$(_get_threshold "context_size_kb" "warn")"
THRESH_CONTEXT_CRIT="$(_get_threshold "context_size_kb" "critical")"
THRESH_TASK_WARN="$(_get_threshold "task_completion_minutes" "warn")"
THRESH_TASK_CRIT="$(_get_threshold "task_completion_minutes" "critical")"

# ============================================================
# a) 起動時コンテキストサイズ収集
# ============================================================

_bytes_to_kb() {
    echo "scale=1; $1 / 1024" | bc
}

_file_kb() {
    local f="$1"
    if [ -f "$f" ]; then
        _bytes_to_kb "$(wc -c < "$f")"
    else
        echo "0.0"
    fi
}

SHOGUN_KB="$(_file_kb "$SCRIPT_DIR/instructions/shogun.md")"
KARO_KB="$(_file_kb "$SCRIPT_DIR/instructions/karo.md")"
GUNSHI_KB="$(_file_kb "$SCRIPT_DIR/instructions/gunshi.md")"
ASHIGARU_KB="$(_file_kb "$SCRIPT_DIR/instructions/ashigaru.md")"
CLAUDE_MD_KB="$(_file_kb "$SCRIPT_DIR/CLAUDE.md")"
MEMORY_MD_KB="$(_file_kb "$HOME/.claude/projects/-Users-idehara-repos-multi-agent-shogun/memory/MEMORY.md")"

# ============================================================
# b) タスク完了時間（直近24時間のcmd概算）
# ============================================================

CMDS_COMPLETED_24H=0
AVG_COMPLETION_MIN=0
MAX_COMPLETION_MIN=0

DASHBOARD_MD="$SCRIPT_DIR/dashboard.md"

if [ -f "$DASHBOARD_MD" ]; then
    # doneのcmd数を概算（dashboard.mdの「完了」行をカウント）
    CMDS_COMPLETED_24H=$(grep -c "完了\|✅\|done" "$DASHBOARD_MD" 2>/dev/null || echo "0")
    # 最大値は合理的な上限に制限
    if [ "$CMDS_COMPLETED_24H" -gt 50 ]; then
        CMDS_COMPLETED_24H=0
    fi
fi

# ============================================================
# c) コンパクション頻度（tmux pane スキャン、bash 3.2互換）
# ============================================================

# エージェント別カウント変数（連想配列の代わりに個別変数）
COMP_SHOGUN=0
COMP_KARO=0
COMP_ASHIGARU1=0
COMP_ASHIGARU2=0
COMP_GUNSHI=0

# pane一覧を動的取得して各エージェントのコンパクション回数を計測
while IFS=' ' read -r pane_id agent_id; do
    if [ -z "$agent_id" ]; then
        continue
    fi
    count=0
    if tmux_output=$(tmux capture-pane -t "$pane_id" -p -S -1000 2>/dev/null); then
        # grep -c が 0件(exit 1)の場合、|| count=0 でフォールバック（二重出力を防ぐ）
        count=$(echo "$tmux_output" | grep -ciE "compressed|compaction|context limit|context was compressed" 2>/dev/null) || count=0
    fi
    case "$agent_id" in
        shogun)    COMP_SHOGUN="$count" ;;
        karo)      COMP_KARO="$count" ;;
        ashigaru1) COMP_ASHIGARU1="$count" ;;
        ashigaru2) COMP_ASHIGARU2="$count" ;;
        gunshi)    COMP_GUNSHI="$count" ;;
        *)         : ;;
    esac
done < <(tmux list-panes -a -F '#{pane_id} #{@agent_id}' 2>/dev/null || true)

# ============================================================
# d) エージェント稼働状態（定義のみ。現在は収集対象外）
# ============================================================

# idle判定: 最終行がプロンプトならidle（将来の拡張用）
_agent_status() {
    local pane_id="$1"
    local last_line
    last_line=$(tmux capture-pane -t "$pane_id" -p 2>/dev/null | grep -v '^$' | tail -1 || echo "")
    if echo "$last_line" | grep -qE '^\s*[\$>]\s*$|Human:|claude>'; then
        echo "idle"
    else
        echo "active"
    fi
}

# ============================================================
# アラート生成
# ============================================================

ALERTS="[]"
ALERT_MESSAGES=""
ALERT_COUNT=0

# コンテキストサイズチェック（全instructionsの合計）
TOTAL_CONTEXT_KB=$(echo "$SHOGUN_KB + $KARO_KB + $GUNSHI_KB + $ASHIGARU_KB + $CLAUDE_MD_KB + $MEMORY_MD_KB" | bc)

if [ -n "$THRESH_CONTEXT_CRIT" ] && [ "$(echo "$TOTAL_CONTEXT_KB > $THRESH_CONTEXT_CRIT" | bc)" = "1" ]; then
    MSG="⚠️ パフォーマンス警告: context_size_kb が閾値超過 現在値: ${TOTAL_CONTEXT_KB}KB / 閾値: ${THRESH_CONTEXT_CRIT}KB 対象: 全エージェント共通"
    ALERT_MESSAGES="${ALERT_MESSAGES}${MSG}\n"
    ALERT_COUNT=$((ALERT_COUNT + 1))
    ALERTS="[{level: critical, metric: context_size_kb, value: ${TOTAL_CONTEXT_KB}, threshold: ${THRESH_CONTEXT_CRIT}}]"
elif [ -n "$THRESH_CONTEXT_WARN" ] && [ "$(echo "$TOTAL_CONTEXT_KB > $THRESH_CONTEXT_WARN" | bc)" = "1" ]; then
    MSG="⚠️ パフォーマンス警告: context_size_kb が閾値超過 現在値: ${TOTAL_CONTEXT_KB}KB / 閾値: ${THRESH_CONTEXT_WARN}KB 対象: 全エージェント共通"
    ALERT_MESSAGES="${ALERT_MESSAGES}${MSG}\n"
    ALERT_COUNT=$((ALERT_COUNT + 1))
    ALERTS="[{level: warn, metric: context_size_kb, value: ${TOTAL_CONTEXT_KB}, threshold: ${THRESH_CONTEXT_WARN}}]"
fi

# コンパクション頻度チェック
for agent_name in shogun karo ashigaru1 ashigaru2 gunshi; do
    case "$agent_name" in
        shogun)    comp_val="$COMP_SHOGUN" ;;
        karo)      comp_val="$COMP_KARO" ;;
        ashigaru1) comp_val="$COMP_ASHIGARU1" ;;
        ashigaru2) comp_val="$COMP_ASHIGARU2" ;;
        gunshi)    comp_val="$COMP_GUNSHI" ;;
        *)         comp_val=0 ;;
    esac
    if [ -n "$THRESH_COMPACTION_CRIT" ] && [ "$comp_val" -ge "$THRESH_COMPACTION_CRIT" ] 2>/dev/null; then
        MSG="⚠️ パフォーマンス警告: compaction_per_session が閾値超過 現在値: ${comp_val} / 閾値: ${THRESH_COMPACTION_CRIT} 対象: ${agent_name}"
        ALERT_MESSAGES="${ALERT_MESSAGES}${MSG}\n"
        ALERT_COUNT=$((ALERT_COUNT + 1))
    elif [ -n "$THRESH_COMPACTION_WARN" ] && [ "$comp_val" -ge "$THRESH_COMPACTION_WARN" ] 2>/dev/null; then
        MSG="⚠️ パフォーマンス警告: compaction_per_session が閾値超過 現在値: ${comp_val} / 閾値: ${THRESH_COMPACTION_WARN} 対象: ${agent_name}"
        ALERT_MESSAGES="${ALERT_MESSAGES}${MSG}\n"
        ALERT_COUNT=$((ALERT_COUNT + 1))
    fi
done

# タスク完了時間チェック（AVG_COMPLETION_MINが取得できている場合のみ）
if [ "$AVG_COMPLETION_MIN" -gt 0 ] 2>/dev/null; then
    if [ -n "$THRESH_TASK_CRIT" ] && [ "$AVG_COMPLETION_MIN" -ge "$THRESH_TASK_CRIT" ] 2>/dev/null; then
        MSG="⚠️ パフォーマンス警告: task_completion_minutes が閾値超過 現在値: ${AVG_COMPLETION_MIN}分 / 閾値: ${THRESH_TASK_CRIT}分 対象: 全エージェント"
        ALERT_MESSAGES="${ALERT_MESSAGES}${MSG}\n"
        ALERT_COUNT=$((ALERT_COUNT + 1))
    elif [ -n "$THRESH_TASK_WARN" ] && [ "$AVG_COMPLETION_MIN" -ge "$THRESH_TASK_WARN" ] 2>/dev/null; then
        MSG="⚠️ パフォーマンス警告: task_completion_minutes が閾値超過 現在値: ${AVG_COMPLETION_MIN}分 / 閾値: ${THRESH_TASK_WARN}分 対象: 全エージェント"
        ALERT_MESSAGES="${ALERT_MESSAGES}${MSG}\n"
        ALERT_COUNT=$((ALERT_COUNT + 1))
    fi
fi

# ============================================================
# Slack通知（アラートがある場合のみ）
# ============================================================

SLACK_POST="$SCRIPT_DIR/scripts/slack_post.sh"
if [ "$ALERT_COUNT" -gt 0 ] && [ -f "$SLACK_POST" ]; then
    while IFS= read -r alert_line; do
        if [ -n "$alert_line" ]; then
            bash "$SLACK_POST" --channel "C048QLDLBF0" "$alert_line" || true
        fi
    done <<< "$(printf '%b' "$ALERT_MESSAGES")"
fi

# ============================================================
# queue/perf_metrics.yaml への追記
# ============================================================

SNAPSHOT="  - date: \"${DATE_TODAY}\"
    collected_at: \"${COLLECTED_AT}\"
    context_sizes:
      shogun_instructions_kb: ${SHOGUN_KB}
      karo_instructions_kb: ${KARO_KB}
      gunshi_instructions_kb: ${GUNSHI_KB}
      ashigaru_instructions_kb: ${ASHIGARU_KB}
      claude_md_kb: ${CLAUDE_MD_KB}
      memory_md_kb: ${MEMORY_MD_KB}
      total_kb: ${TOTAL_CONTEXT_KB}
    task_metrics:
      cmds_completed_24h: ${CMDS_COMPLETED_24H}
      avg_completion_minutes: ${AVG_COMPLETION_MIN}
      max_completion_minutes: ${MAX_COMPLETION_MIN}
    compaction_counts:
      shogun: ${COMP_SHOGUN}
      karo: ${COMP_KARO}
      ashigaru1: ${COMP_ASHIGARU1}
      ashigaru2: ${COMP_ASHIGARU2}
      gunshi: ${COMP_GUNSHI}
    alerts: ${ALERTS}"

# snapshots: [] を snapshots:\n<新スナップ> に置換、または末尾追記
if grep -q "^snapshots: \[\]" "$METRICS_FILE"; then
    printf 'snapshots:\n%s\n' "$SNAPSHOT" > "$METRICS_FILE"
else
    printf '%s\n' "$SNAPSHOT" >> "$METRICS_FILE"
fi

echo "[perf_collect] 収集完了: ${DATE_TODAY} ${COLLECTED_AT} | total_context=${TOTAL_CONTEXT_KB}KB | alerts=${ALERT_COUNT}"
