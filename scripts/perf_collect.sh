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
# b) タスク完了時間（shogun_to_karo.yamlのstatus:doneからtimestampベース概算）
# ============================================================

CMDS_COMPLETED_24H=0
AVG_COMPLETION_MIN=0
MAX_COMPLETION_MIN=0

SHOGUN_KARO_YAML="$SCRIPT_DIR/queue/shogun_to_karo.yaml"
if [ -f "$SHOGUN_KARO_YAML" ]; then
    NOW_EPOCH="$(date +%s)"
    CUTOFF_EPOCH=$(( NOW_EPOCH - 86400 ))

    # done cmdsのtimestampを抽出（awk: timestamp行を記憶し status: done で出力）
    # 注意: macOS awkは[[:space:]]非対応のため[ \t]*を使用し、クォート除去はtrで実施
    DONE_TIMESTAMPS=$(awk '
        /^[ \t]*timestamp:/ { ts = $2 }
        /^[ \t]*status:[ \t]*done/ { if (length(ts) > 0) { print ts; ts = "" } }
    ' "$SHOGUN_KARO_YAML" 2>/dev/null | tr -d "\"'" || true)

    # 24h以内のdoneエポック時刻を収集（スペース区切り）
    EPOCH_LIST=""
    while IFS= read -r ts; do
        [ -z "$ts" ] && continue
        # タイムゾーン除去（macOS dateは+09:00形式を扱えない）
        ts_clean="${ts%%+*}"
        ts_clean="${ts_clean%%Z*}"
        ep=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$ts_clean" "+%s" 2>/dev/null) || continue
        if [ "$ep" -ge "$CUTOFF_EPOCH" ]; then
            EPOCH_LIST="${EPOCH_LIST}${ep} "
            CMDS_COMPLETED_24H=$(( CMDS_COMPLETED_24H + 1 ))
        fi
    done <<< "$DONE_TIMESTAMPS"

    # 2件以上あれば連続するtimestamp間の差分平均を計算
    if [ "$CMDS_COMPLETED_24H" -ge 2 ]; then
        SORTED_EPOCHS="$(echo "$EPOCH_LIST" | tr ' ' '\n' | grep -v '^$' | sort -n | tr '\n' ' ')"
        EPOCH_ARR=()
        if [ -n "$SORTED_EPOCHS" ]; then
            read -ra EPOCH_ARR <<< "$SORTED_EPOCHS"
        fi
        PREV_EP=""
        TOTAL_GAP=0
        GAP_COUNT=0
        MAX_GAP=0
        for ep in "${EPOCH_ARR[@]}"; do
            if [ -n "$PREV_EP" ]; then
                GAP=$(( (ep - PREV_EP) / 60 ))
                TOTAL_GAP=$(( TOTAL_GAP + GAP ))
                GAP_COUNT=$(( GAP_COUNT + 1 ))
                if [ "$GAP" -gt "$MAX_GAP" ]; then
                    MAX_GAP="$GAP"
                fi
            fi
            PREV_EP="$ep"
        done
        if [ "$GAP_COUNT" -gt 0 ]; then
            AVG_COMPLETION_MIN=$(( TOTAL_GAP / GAP_COUNT ))
            MAX_COMPLETION_MIN="$MAX_GAP"
        fi
    fi
fi

# ============================================================
# c) コンパクション頻度（全pane動的収集、bash 3.2互換）
# ============================================================

# エージェント名とカウントをスペース区切りで並行管理
AGENT_NAMES_LIST=""
AGENT_COUNTS_LIST=""

while IFS=' ' read -r pane_id agent_id; do
    [ -z "$agent_id" ] && continue
    count=0
    if tmux_output=$(tmux capture-pane -t "$pane_id" -p -S -1000 2>/dev/null); then
        # grep -c が 0件(exit 1)の場合、|| count=0 でフォールバック（二重出力を防ぐ）
        count=$(echo "$tmux_output" | grep -ciE "compressed|compaction|context limit|context was compressed" 2>/dev/null) || count=0
    fi
    AGENT_NAMES_LIST="${AGENT_NAMES_LIST}${agent_id} "
    AGENT_COUNTS_LIST="${AGENT_COUNTS_LIST}${count} "
done < <(tmux list-panes -a -F '#{pane_id} #{@agent_id}' 2>/dev/null || true)

# 並行配列に変換（空リスト対応）
AGENT_NAMES_ARR=()
AGENT_COUNTS_ARR=()
if [ -n "$AGENT_NAMES_LIST" ]; then
    read -ra AGENT_NAMES_ARR <<< "$AGENT_NAMES_LIST"
    read -ra AGENT_COUNTS_ARR <<< "$AGENT_COUNTS_LIST"
fi

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
# アラート生成（複数アラートを配列として蓄積）
# ============================================================

ALERTS_YAML_LINES=""   # YAML list形式で蓄積（実際の改行を使用）
ALERT_MESSAGES=""
ALERT_COUNT=0

_add_alert() {
    local level="$1"
    local metric="$2"
    local value="$3"
    local threshold="$4"
    local agent="${5:-all}"
    ALERT_MESSAGES="${ALERT_MESSAGES}⚠️ パフォーマンス警告: ${metric} が閾値超過 現在値: ${value} / 閾値: ${threshold} 対象: ${agent}
"
    ALERTS_YAML_LINES="${ALERTS_YAML_LINES}    - level: ${level}
      metric: ${metric}
      value: ${value}
      threshold: ${threshold}
      agent: ${agent}
"
    ALERT_COUNT=$(( ALERT_COUNT + 1 ))
}

# コンテキストサイズチェック（全instructionsの合計）
TOTAL_CONTEXT_KB=$(echo "$SHOGUN_KB + $KARO_KB + $GUNSHI_KB + $ASHIGARU_KB + $CLAUDE_MD_KB + $MEMORY_MD_KB" | bc)

if [ -n "$THRESH_CONTEXT_CRIT" ] && [ "$(echo "$TOTAL_CONTEXT_KB > $THRESH_CONTEXT_CRIT" | bc)" = "1" ]; then
    _add_alert "critical" "context_size_kb" "${TOTAL_CONTEXT_KB}KB" "${THRESH_CONTEXT_CRIT}KB" "全エージェント共通"
elif [ -n "$THRESH_CONTEXT_WARN" ] && [ "$(echo "$TOTAL_CONTEXT_KB > $THRESH_CONTEXT_WARN" | bc)" = "1" ]; then
    _add_alert "warn" "context_size_kb" "${TOTAL_CONTEXT_KB}KB" "${THRESH_CONTEXT_WARN}KB" "全エージェント共通"
fi

# コンパクション頻度チェック（動的エージェント全件）
for i in "${!AGENT_NAMES_ARR[@]}"; do
    agent_name="${AGENT_NAMES_ARR[$i]}"
    comp_val="${AGENT_COUNTS_ARR[$i]}"
    if [ -n "$THRESH_COMPACTION_CRIT" ] && [ "$comp_val" -ge "$THRESH_COMPACTION_CRIT" ] 2>/dev/null; then
        _add_alert "critical" "compaction_per_session" "$comp_val" "$THRESH_COMPACTION_CRIT" "$agent_name"
    elif [ -n "$THRESH_COMPACTION_WARN" ] && [ "$comp_val" -ge "$THRESH_COMPACTION_WARN" ] 2>/dev/null; then
        _add_alert "warn" "compaction_per_session" "$comp_val" "$THRESH_COMPACTION_WARN" "$agent_name"
    fi
done

# タスク完了時間チェック（AVG_COMPLETION_MINが取得できている場合のみ）
if [ "$AVG_COMPLETION_MIN" -gt 0 ] 2>/dev/null; then
    if [ -n "$THRESH_TASK_CRIT" ] && [ "$AVG_COMPLETION_MIN" -ge "$THRESH_TASK_CRIT" ] 2>/dev/null; then
        _add_alert "critical" "task_completion_minutes" "${AVG_COMPLETION_MIN}分" "${THRESH_TASK_CRIT}分" "全エージェント"
    elif [ -n "$THRESH_TASK_WARN" ] && [ "$AVG_COMPLETION_MIN" -ge "$THRESH_TASK_WARN" ] 2>/dev/null; then
        _add_alert "warn" "task_completion_minutes" "${AVG_COMPLETION_MIN}分" "${THRESH_TASK_WARN}分" "全エージェント"
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
    done <<< "$ALERT_MESSAGES"
fi

# ============================================================
# queue/perf_metrics.yaml への追記
# ============================================================

# compaction_counts セクションを動的生成
COMPACTION_SECTION="    compaction_counts:"
if [ "${#AGENT_NAMES_ARR[@]}" -eq 0 ]; then
    COMPACTION_SECTION="${COMPACTION_SECTION} {}"
else
    for i in "${!AGENT_NAMES_ARR[@]}"; do
        COMPACTION_SECTION="${COMPACTION_SECTION}
      ${AGENT_NAMES_ARR[$i]}: ${AGENT_COUNTS_ARR[$i]}"
    done
fi

# alerts セクションを動的生成（複数アラート対応）
if [ -z "$ALERTS_YAML_LINES" ]; then
    ALERTS_SECTION="    alerts: []"
else
    ALERTS_SECTION="    alerts:
${ALERTS_YAML_LINES}"
fi

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
${COMPACTION_SECTION}
${ALERTS_SECTION}"

# snapshots: [] を snapshots:\n<新スナップ> に置換、または末尾追記
if grep -q "^snapshots: \[\]" "$METRICS_FILE"; then
    printf 'snapshots:\n%s\n' "$SNAPSHOT" > "$METRICS_FILE"
else
    printf '%s\n' "$SNAPSHOT" >> "$METRICS_FILE"
fi

echo "[perf_collect] 収集完了: ${DATE_TODAY} ${COLLECTED_AT} | total_context=${TOTAL_CONTEXT_KB}KB | alerts=${ALERT_COUNT}"
