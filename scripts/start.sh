#!/bin/bash
# uesama 起動スクリプト
# tmux セッション作成 & Claude Code 起動
set -e

UESAMA_HOME="${UESAMA_HOME:-$HOME/.uesama}"
PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
KASHIN_COUNT="${UESAMA_KASHIN_COUNT:-8}"

# 言語設定を読み取り
LANG_SETTING="ja"
if [ -f "$PROJECT_DIR/.uesama/config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" "$PROJECT_DIR/.uesama/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "ja")
elif [ -f "$UESAMA_HOME/config/settings.yaml" ]; then
    LANG_SETTING=$(grep "^language:" "$UESAMA_HOME/config/settings.yaml" 2>/dev/null | awk '{print $2}' || echo "ja")
fi

# 色付きログ関数
log_info() { echo -e "\033[1;33m【報】\033[0m $1"; }
log_success() { echo -e "\033[1;32m【成】\033[0m $1"; }
log_war() { echo -e "\033[1;31m【戦】\033[0m $1"; }

# バナー表示
show_banner() {
    clear
    echo ""
    echo -e "\033[1;31m╔══════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m██╗   ██╗███████╗███████╗ █████╗ ███╗   ███╗ █████╗ \033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m██║   ██║██╔════╝██╔════╝██╔══██╗████╗ ████║██╔══██╗\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m██║   ██║█████╗  ███████╗███████║██╔████╔██║███████║\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m██║   ██║██╔══╝  ╚════██║██╔══██║██║╚██╔╝██║██╔══██║\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m╚██████╔╝███████╗███████║██║  ██║██║ ╚═╝ ██║██║  ██║\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m║\033[0m  \033[1;33m ╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝\033[0m  \033[1;31m║\033[0m"
    echo -e "\033[1;31m╠══════════════════════════════════════════════════════════╣\033[0m"
    echo -e "\033[1;31m║\033[0m    \033[1;37m出陣じゃーーー！！！\033[0m    \033[1;36m⚔\033[0m    \033[1;35m天下布武！\033[0m              \033[1;31m║\033[0m"
    echo -e "\033[1;31m╚══════════════════════════════════════════════════════════╝\033[0m"
    echo ""

    echo -e "\033[1;34m  ╔═══════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m  ║\033[0m        \033[1;37m【 家 臣 団 ・ ${KASHIN_COUNT} 名 配 備 】\033[0m                   \033[1;34m║\033[0m"
    echo -e "\033[1;34m  ╚═══════════════════════════════════════════════════════╝\033[0m"
    echo ""

    # 家臣隊列
    local flags=""
    local poles=""
    local bases=""
    local feet=""
    local labels=""
    for i in $(seq 1 $KASHIN_COUNT); do
        flags="$flags  /\\  "
        poles="$poles /||\\  "
        bases="$bases/_||\\  "
        feet="$feet  /  \\  "
        labels="$labels [臣$i] "
    done
    echo "    $flags"
    echo "    $poles"
    echo "    $bases"
    echo "    $feet"
    echo "    $labels"
    echo ""
    echo -e "              \033[1;36m「「「 はっ！！ 出陣いたす！！ 」」」\033[0m"
    echo ""
}

show_banner

echo -e "  \033[1;33m天下布武！陣立てを開始いたす\033[0m"
echo "  プロジェクト: $PROJECT_DIR"
echo ""

# ═══════════════════════════════════════════════
# STEP 1: 既存セッションクリーンアップ
# ═══════════════════════════════════════════════
log_info "既存の陣を撤収中..."
tmux kill-session -t kashindan 2>/dev/null && log_info "  └─ kashindan陣、撤収完了" || true
tmux kill-session -t daimyo 2>/dev/null && log_info "  └─ daimyo本陣、撤収完了" || true

# ═══════════════════════════════════════════════
# STEP 2: プロジェクトディレクトリに .uesama/ 初期化
# ═══════════════════════════════════════════════
log_info "プロジェクト陣地を構築中..."

PROJ_UESAMA="$PROJECT_DIR/.uesama"
mkdir -p "$PROJ_UESAMA/queue/tasks" "$PROJ_UESAMA/queue/reports" \
         "$PROJ_UESAMA/status" "$PROJ_UESAMA/config" "$PROJ_UESAMA/memory"

# テンプレートからシンボリックリンク
for dir in instructions templates; do
    if [ ! -L "$PROJ_UESAMA/$dir" ]; then
        rm -rf "$PROJ_UESAMA/$dir"
        ln -sf "$UESAMA_HOME/template/.uesama/$dir" "$PROJ_UESAMA/$dir"
    fi
done

# .claude/rules/ に uesama ルールをシンボリックリンク
mkdir -p "$PROJECT_DIR/.claude/rules"
if [ ! -L "$PROJECT_DIR/.claude/rules/uesama.md" ]; then
    rm -f "$PROJECT_DIR/.claude/rules/uesama.md"
    ln -sf "$UESAMA_HOME/template/.claude/rules/uesama.md" "$PROJECT_DIR/.claude/rules/uesama.md"
fi

# .gitignore に .uesama/ 追加
if [ -f "$PROJECT_DIR/.gitignore" ]; then
    if ! grep -q "^\.uesama/" "$PROJECT_DIR/.gitignore" 2>/dev/null; then
        echo "" >> "$PROJECT_DIR/.gitignore"
        echo "# uesama multi-agent system" >> "$PROJECT_DIR/.gitignore"
        echo ".uesama/" >> "$PROJECT_DIR/.gitignore"
    fi
else
    echo "# uesama multi-agent system" > "$PROJECT_DIR/.gitignore"
    echo ".uesama/" >> "$PROJECT_DIR/.gitignore"
fi

log_success "  └─ プロジェクト陣地構築完了"

# ═══════════════════════════════════════════════
# STEP 3: キューファイルリセット
# ═══════════════════════════════════════════════
log_info "軍議記録を初期化中..."

for i in $(seq 1 $KASHIN_COUNT); do
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

# ═══════════════════════════════════════════════
# STEP 4: ダッシュボード初期化
# ═══════════════════════════════════════════════
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
sed "s/{{TIMESTAMP}}/$TIMESTAMP/" "$UESAMA_HOME/template/.uesama/templates/dashboard.md" > "$PROJ_UESAMA/dashboard.md"

# context.md（なければテンプレートからコピー）
if [ ! -f "$PROJ_UESAMA/context.md" ]; then
    cp "$UESAMA_HOME/template/.uesama/templates/context.md" "$PROJ_UESAMA/context.md"
fi

# config/settings.yaml（なければ作成）
if [ ! -f "$PROJ_UESAMA/config/settings.yaml" ]; then
    cat > "$PROJ_UESAMA/config/settings.yaml" << EOF
language: ja
kashin_count: $KASHIN_COUNT
EOF
fi

log_success "  └─ 初期化完了"
echo ""

# ═══════════════════════════════════════════════
# STEP 5: kashindanセッション作成（参謀 + 家臣×N）
# ═══════════════════════════════════════════════
TOTAL_PANES=$((KASHIN_COUNT + 1))  # sanbo + kashin
log_war "⚔️ 参謀・家臣の陣を構築中（${TOTAL_PANES}名配備）..."

tmux new-session -d -s kashindan -n "agents" -c "$PROJECT_DIR"

# ペインを分割（3列 × N行で KASHIN_COUNT+1 ペインを作成）
COLS=3
ROWS=$(( (TOTAL_PANES + COLS - 1) / COLS ))

# まず列を作る
for ((c=1; c<COLS && c<TOTAL_PANES; c++)); do
    tmux split-window -h -t "kashindan:0"
done

# 各列を行に分割
for ((c=0; c<COLS && c<TOTAL_PANES; c++)); do
    panes_in_col=$ROWS
    # 最後の列は余りがある場合少ないかも
    remaining=$((TOTAL_PANES - c * ROWS))
    if [ $remaining -lt $ROWS ]; then
        panes_in_col=$remaining
    fi
    if [ $panes_in_col -le 0 ]; then
        break
    fi

    base_pane=$((c * ROWS))
    tmux select-pane -t "kashindan:0.$base_pane" 2>/dev/null || true
    for ((r=1; r<panes_in_col; r++)); do
        tmux split-window -v -t "kashindan:0" 2>/dev/null || true
    done
done

# ペインタイトル設定
tmux select-pane -t "kashindan:0.0" -T "sanbo"
tmux send-keys -t "kashindan:0.0" "cd '$PROJECT_DIR' && export PS1='(\[\033[1;31m\]sanbo\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear" Enter

for ((i=1; i<=KASHIN_COUNT; i++)); do
    tmux select-pane -t "kashindan:0.$i" -T "kashin$i" 2>/dev/null || true
    tmux send-keys -t "kashindan:0.$i" "cd '$PROJECT_DIR' && export PS1='(\[\033[1;34m\]kashin$i\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear" Enter 2>/dev/null || true
done

log_success "  └─ 参謀・家臣の陣、構築完了"
echo ""

# ═══════════════════════════════════════════════
# STEP 6: daimyoセッション作成（1ペイン）
# ═══════════════════════════════════════════════
log_war "👑 大名の本陣を構築中..."
tmux new-session -d -s daimyo -c "$PROJECT_DIR"
tmux send-keys -t daimyo "cd '$PROJECT_DIR' && export PS1='(\[\033[1;35m\]大名\[\033[0m\]) \[\033[1;32m\]\w\[\033[0m\]\$ ' && clear" Enter

log_success "  └─ 大名の本陣、構築完了"
echo ""

# ═══════════════════════════════════════════════
# STEP 7: Claude Code 起動
# ═══════════════════════════════════════════════
log_war "👑 全軍に Claude Code を召喚中..."

# 大名
tmux send-keys -t daimyo "MAX_THINKING_TOKENS=0 claude --model opus --dangerously-skip-permissions"
tmux send-keys -t daimyo Enter
log_info "  └─ 大名、召喚完了"

sleep 1

# 参謀 + 家臣
for ((i=0; i<=KASHIN_COUNT; i++)); do
    tmux send-keys -t "kashindan:0.$i" "claude --dangerously-skip-permissions"
    tmux send-keys -t "kashindan:0.$i" Enter
done
log_info "  └─ 参謀・家臣、召喚完了"

log_success "✅ 全軍 Claude Code 起動完了"
echo ""

# ═══════════════════════════════════════════════
# STEP 8: 指示書読み込み
# ═══════════════════════════════════════════════
log_war "📜 各エージェントに指示書を読み込ませ中..."

echo "  Claude Code の起動を待機中（最大30秒）..."
for i in {1..30}; do
    if tmux capture-pane -t daimyo -p | grep -q "bypass permissions"; then
        echo "  └─ 大名の Claude Code 起動確認完了（${i}秒）"
        break
    fi
    sleep 1
done

# 大名に指示書
log_info "  └─ 大名に指示書を伝達中..."
tmux send-keys -t daimyo ".uesama/instructions/daimyo.md を読んで役割を理解せよ。"
sleep 0.5
tmux send-keys -t daimyo Enter

# 参謀に指示書
sleep 2
log_info "  └─ 参謀に指示書を伝達中..."
tmux send-keys -t "kashindan:0.0" ".uesama/instructions/sanbo.md を読んで役割を理解せよ。"
sleep 0.5
tmux send-keys -t "kashindan:0.0" Enter

# 家臣に指示書
sleep 2
log_info "  └─ 家臣に指示書を伝達中..."
for ((i=1; i<=KASHIN_COUNT; i++)); do
    tmux send-keys -t "kashindan:0.$i" ".uesama/instructions/kashin.md を読んで役割を理解せよ。汝は家臣${i}号である。"
    sleep 0.3
    tmux send-keys -t "kashindan:0.$i" Enter
    sleep 0.5
done

log_success "✅ 全軍に指示書伝達完了"
echo ""

# ═══════════════════════════════════════════════
# 完了メッセージ
# ═══════════════════════════════════════════════
echo "  ╔══════════════════════════════════════════════════════════╗"
echo "  ║  🏯 出陣準備完了！天下布武！                              ║"
echo "  ╚══════════════════════════════════════════════════════════╝"
echo ""
echo "  次のステップ:"
echo "  ┌──────────────────────────────────────────────────────────┐"
echo "  │  大名の本陣にアタッチして命令を開始:                      │"
echo "  │     uesama-daimyo   (または: tmux attach -t daimyo)      │"
echo "  │                                                          │"
echo "  │  参謀・家臣の陣を確認する:                                │"
echo "  │     uesama-agents   (または: tmux attach -t kashindan)   │"
echo "  └──────────────────────────────────────────────────────────┘"
echo ""

# ═══════════════════════════════════════════════
# STEP 9: ターミナルウィンドウ自動起動（macOS）
# ═══════════════════════════════════════════════
if [ "$(uname)" = "Darwin" ]; then
    log_info "ターミナルウィンドウを起動中..."

    open_terminal_with_command() {
        local cmd="$1"
        local title="$2"
        if [ -d "/Applications/iTerm.app" ]; then
            osascript -e "
                tell application \"iTerm\"
                    activate
                    set newWindow to (create window with default profile)
                    tell current session of newWindow
                        write text \"$cmd\"
                    end tell
                end tell
            " 2>/dev/null
        else
            osascript -e "
                tell application \"Terminal\"
                    activate
                    do script \"$cmd\"
                end tell
            " 2>/dev/null
        fi
    }

    open_terminal_with_command "tmux attach -t daimyo" "daimyo"
    sleep 0.5
    open_terminal_with_command "tmux attach -t kashindan" "kashindan"

    log_success "  └─ ターミナルウィンドウ起動完了"
    echo ""
fi
