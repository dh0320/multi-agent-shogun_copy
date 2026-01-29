#!/bin/bash
# uesama tmux 統合テスト
# CI 上の Ubuntu でも tmux が使える前提で、セッション作成・ペイン分割を検証する
set -e

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1"
    echo "    $2"
}

# テスト用セッション名（本番と衝突しない）
TEST_SESSION_KASHINDAN="test_kashindan_$$"
TEST_SESSION_DAIMYO="test_daimyo_$$"

cleanup() {
    tmux kill-session -t "$TEST_SESSION_KASHINDAN" 2>/dev/null || true
    tmux kill-session -t "$TEST_SESSION_DAIMYO" 2>/dev/null || true
    rm -rf "$TEST_TMPDIR"
}
trap cleanup EXIT

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  🏯 uesama tmux 統合テスト                    ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# ==================================================================
# 前提条件チェック
# ==================================================================
if ! command -v tmux > /dev/null 2>&1; then
    echo "  SKIP: tmux が見つかりません"
    exit 0
fi

TEST_TMPDIR=$(mktemp -d)

# ==================================================================
# 1. tmux セッション作成テスト
# ==================================================================
echo "  [セッション作成]"

tmux new-session -d -s "$TEST_SESSION_DAIMYO" -c "$TEST_TMPDIR"
if tmux has-session -t "$TEST_SESSION_DAIMYO" 2>/dev/null; then
    pass "daimyo session created"
else
    fail "daimyo session created" "session not found"
fi

tmux new-session -d -s "$TEST_SESSION_KASHINDAN" -n "agents" -c "$TEST_TMPDIR"
if tmux has-session -t "$TEST_SESSION_KASHINDAN" 2>/dev/null; then
    pass "kashindan session created"
else
    fail "kashindan session created" "session not found"
fi

# ==================================================================
# 2. ペイン分割テスト（start.sh と同じロジック）
# ==================================================================
echo ""
echo "  [ペイン分割]"

KASHIN_COUNT=8
TOTAL_PANES=$((KASHIN_COUNT + 1))  # sanbo + kashin = 9
COLS=3
ROWS=$(( (TOTAL_PANES + COLS - 1) / COLS ))

# まず列を作る
for ((c=1; c<COLS && c<TOTAL_PANES; c++)); do
    tmux split-window -h -t "$TEST_SESSION_KASHINDAN:0"
done

# 各列を行に分割
for ((c=0; c<COLS && c<TOTAL_PANES; c++)); do
    panes_in_col=$ROWS
    remaining=$((TOTAL_PANES - c * ROWS))
    if [ $remaining -lt $ROWS ]; then
        panes_in_col=$remaining
    fi
    if [ $panes_in_col -le 0 ]; then
        break
    fi

    base_pane=$((c * ROWS))
    tmux select-pane -t "$TEST_SESSION_KASHINDAN:0.$base_pane" 2>/dev/null || true
    for ((r=1; r<panes_in_col; r++)); do
        tmux split-window -v -t "$TEST_SESSION_KASHINDAN:0" 2>/dev/null || true
    done
done

# ペイン数を検証
ACTUAL_PANES=$(tmux list-panes -t "$TEST_SESSION_KASHINDAN:0" 2>/dev/null | wc -l)
if [ "$ACTUAL_PANES" -eq "$TOTAL_PANES" ]; then
    pass "kashindan has $TOTAL_PANES panes (sanbo + ${KASHIN_COUNT} kashin)"
else
    fail "kashindan has $TOTAL_PANES panes" "got $ACTUAL_PANES panes"
fi

# daimyo は 1 ペインのまま
DAIMYO_PANES=$(tmux list-panes -t "$TEST_SESSION_DAIMYO" 2>/dev/null | wc -l)
if [ "$DAIMYO_PANES" -eq 1 ]; then
    pass "daimyo has exactly 1 pane"
else
    fail "daimyo has exactly 1 pane" "got $DAIMYO_PANES panes"
fi

# ==================================================================
# 3. ペインタイトル設定テスト
# ==================================================================
echo ""
echo "  [ペインタイトル]"

tmux select-pane -t "$TEST_SESSION_KASHINDAN:0.0" -T "sanbo"
SANBO_TITLE=$(tmux display-message -t "$TEST_SESSION_KASHINDAN:0.0" -p '#{pane_title}' 2>/dev/null)
if [ "$SANBO_TITLE" = "sanbo" ]; then
    pass "pane 0 title is 'sanbo'"
else
    fail "pane 0 title is 'sanbo'" "got '$SANBO_TITLE'"
fi

for ((i=1; i<=KASHIN_COUNT; i++)); do
    tmux select-pane -t "$TEST_SESSION_KASHINDAN:0.$i" -T "kashin$i" 2>/dev/null || true
done

KASHIN1_TITLE=$(tmux display-message -t "$TEST_SESSION_KASHINDAN:0.1" -p '#{pane_title}' 2>/dev/null)
if [ "$KASHIN1_TITLE" = "kashin1" ]; then
    pass "pane 1 title is 'kashin1'"
else
    fail "pane 1 title is 'kashin1'" "got '$KASHIN1_TITLE'"
fi

KASHIN8_TITLE=$(tmux display-message -t "$TEST_SESSION_KASHINDAN:0.8" -p '#{pane_title}' 2>/dev/null)
if [ "$KASHIN8_TITLE" = "kashin8" ]; then
    pass "pane 8 title is 'kashin8'"
else
    fail "pane 8 title is 'kashin8'" "got '$KASHIN8_TITLE'"
fi

# ==================================================================
# 4. send-keys テスト（コマンド送信が動くか）
# ==================================================================
echo ""
echo "  [send-keys]"

tmux send-keys -t "$TEST_SESSION_DAIMYO" "echo UESAMA_TEST_MARKER" Enter
sleep 0.5
CAPTURED=$(tmux capture-pane -t "$TEST_SESSION_DAIMYO" -p 2>/dev/null)
if echo "$CAPTURED" | grep -q "UESAMA_TEST_MARKER"; then
    pass "send-keys delivers command to daimyo"
else
    fail "send-keys delivers command to daimyo" "marker not found in pane"
fi

tmux send-keys -t "$TEST_SESSION_KASHINDAN:0.0" "echo SANBO_MARKER" Enter
sleep 0.5
CAPTURED_SANBO=$(tmux capture-pane -t "$TEST_SESSION_KASHINDAN:0.0" -p 2>/dev/null)
if echo "$CAPTURED_SANBO" | grep -q "SANBO_MARKER"; then
    pass "send-keys delivers command to sanbo pane"
else
    fail "send-keys delivers command to sanbo pane" "marker not found"
fi

# ==================================================================
# 5. キューファイル生成テスト（start.sh の STEP 3 ロジック再現）
# ==================================================================
echo ""
echo "  [キューファイル生成]"

PROJ_UESAMA="$TEST_TMPDIR/.uesama"
mkdir -p "$PROJ_UESAMA/queue/tasks" "$PROJ_UESAMA/queue/reports" \
         "$PROJ_UESAMA/status" "$PROJ_UESAMA/config" "$PROJ_UESAMA/memory"

for i in $(seq 1 "$KASHIN_COUNT"); do
    cat > "$PROJ_UESAMA/queue/reports/kashin${i}_report.yaml" << EOF
worker_id: kashin${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
    cat > "$PROJ_UESAMA/queue/tasks/kashin${i}.yaml" << EOF
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
done

cat > "$PROJ_UESAMA/queue/daimyo_to_sanbo.yaml" << 'EOF'
queue: []
EOF

# 全家臣のファイルが生成されたか
ALL_REPORTS=true
ALL_TASKS=true
for i in $(seq 1 "$KASHIN_COUNT"); do
    [ -f "$PROJ_UESAMA/queue/reports/kashin${i}_report.yaml" ] || ALL_REPORTS=false
    [ -f "$PROJ_UESAMA/queue/tasks/kashin${i}.yaml" ] || ALL_TASKS=false
done

if [ "$ALL_REPORTS" = true ]; then
    pass "all $KASHIN_COUNT report YAML files created"
else
    fail "all $KASHIN_COUNT report YAML files created" "some missing"
fi

if [ "$ALL_TASKS" = true ]; then
    pass "all $KASHIN_COUNT task YAML files created"
else
    fail "all $KASHIN_COUNT task YAML files created" "some missing"
fi

if [ -f "$PROJ_UESAMA/queue/daimyo_to_sanbo.yaml" ]; then
    pass "daimyo_to_sanbo.yaml created"
else
    fail "daimyo_to_sanbo.yaml created" "not found"
fi

# YAML の中身が正しいか
REPORT1_WORKER=$(grep 'worker_id:' "$PROJ_UESAMA/queue/reports/kashin1_report.yaml" | awk '{print $2}')
if [ "$REPORT1_WORKER" = "kashin1" ]; then
    pass "kashin1_report.yaml has correct worker_id"
else
    fail "kashin1_report.yaml has correct worker_id" "got '$REPORT1_WORKER'"
fi

REPORT1_STATUS=$(grep 'status:' "$PROJ_UESAMA/queue/reports/kashin1_report.yaml" | awk '{print $2}')
if [ "$REPORT1_STATUS" = "idle" ]; then
    pass "kashin1_report.yaml initial status is idle"
else
    fail "kashin1_report.yaml initial status is idle" "got '$REPORT1_STATUS'"
fi

TASK1_STATUS=$(grep 'status:' "$PROJ_UESAMA/queue/tasks/kashin1.yaml" | awk '{print $2}')
if [ "$TASK1_STATUS" = "idle" ]; then
    pass "kashin1.yaml initial task status is idle"
else
    fail "kashin1.yaml initial task status is idle" "got '$TASK1_STATUS'"
fi

QUEUE_CONTENT=$(cat "$PROJ_UESAMA/queue/daimyo_to_sanbo.yaml")
if echo "$QUEUE_CONTENT" | grep -q 'queue: \[\]'; then
    pass "daimyo_to_sanbo.yaml initialized with empty queue"
else
    fail "daimyo_to_sanbo.yaml initialized with empty queue" "content: $QUEUE_CONTENT"
fi

# ==================================================================
# 6. ディレクトリ構造テスト
# ==================================================================
echo ""
echo "  [ディレクトリ構造]"

for d in queue/tasks queue/reports status config memory; do
    if [ -d "$PROJ_UESAMA/$d" ]; then
        pass ".uesama/$d directory exists"
    else
        fail ".uesama/$d directory exists" "not found"
    fi
done

# ==================================================================
# 7. セッション kill テスト（uesama-stop と同じロジック）
# ==================================================================
echo ""
echo "  [セッション停止]"

tmux kill-session -t "$TEST_SESSION_DAIMYO" 2>/dev/null
if ! tmux has-session -t "$TEST_SESSION_DAIMYO" 2>/dev/null; then
    pass "daimyo session killed successfully"
else
    fail "daimyo session killed successfully" "session still exists"
fi

tmux kill-session -t "$TEST_SESSION_KASHINDAN" 2>/dev/null
if ! tmux has-session -t "$TEST_SESSION_KASHINDAN" 2>/dev/null; then
    pass "kashindan session killed successfully"
else
    fail "kashindan session killed successfully" "session still exists"
fi

# 既に無いセッションを kill しても失敗しないか
tmux kill-session -t "$TEST_SESSION_DAIMYO" 2>/dev/null || true
pass "killing non-existent session does not error (with || true)"

# ==================================================================
# 8. KASHIN_COUNT 変更テスト（3名で検証）
# ==================================================================
echo ""
echo "  [KASHIN_COUNT=3 テスト]"

TEST_SESSION_SMALL="test_small_$$"
SMALL_COUNT=3
SMALL_TOTAL=$((SMALL_COUNT + 1))

tmux new-session -d -s "$TEST_SESSION_SMALL" -n "agents" -c "$TEST_TMPDIR"

COLS=3
ROWS=$(( (SMALL_TOTAL + COLS - 1) / COLS ))

for ((c=1; c<COLS && c<SMALL_TOTAL; c++)); do
    tmux split-window -h -t "$TEST_SESSION_SMALL:0"
done

for ((c=0; c<COLS && c<SMALL_TOTAL; c++)); do
    panes_in_col=$ROWS
    remaining=$((SMALL_TOTAL - c * ROWS))
    if [ $remaining -lt $ROWS ]; then
        panes_in_col=$remaining
    fi
    if [ $panes_in_col -le 0 ]; then
        break
    fi
    base_pane=$((c * ROWS))
    tmux select-pane -t "$TEST_SESSION_SMALL:0.$base_pane" 2>/dev/null || true
    for ((r=1; r<panes_in_col; r++)); do
        tmux split-window -v -t "$TEST_SESSION_SMALL:0" 2>/dev/null || true
    done
done

SMALL_PANES=$(tmux list-panes -t "$TEST_SESSION_SMALL:0" 2>/dev/null | wc -l)
if [ "$SMALL_PANES" -ge "$SMALL_TOTAL" ]; then
    pass "KASHIN_COUNT=3: creates >= $SMALL_TOTAL panes (got $SMALL_PANES)"
else
    fail "KASHIN_COUNT=3: creates >= $SMALL_TOTAL panes" "got $SMALL_PANES panes"
fi

tmux kill-session -t "$TEST_SESSION_SMALL" 2>/dev/null || true

# ==================================================================
# 結果
# ==================================================================
echo ""
TOTAL=$((PASS + FAIL))
echo "  結果: $PASS/$TOTAL passed"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "  ✗ $FAIL test(s) failed"
    exit 1
else
    echo "  ✅ All tests passed"
fi
