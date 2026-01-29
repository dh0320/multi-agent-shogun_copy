#!/bin/sh
# uesama インストーラー
# curl -fsSL https://raw.githubusercontent.com/y-nishizaki/multi-agent-shogun/main/install.sh | sh
set -e

REPO_URL="https://github.com/y-nishizaki/multi-agent-shogun"
UESAMA_HOME="$HOME/.uesama"

# ソースディレクトリの決定（ローカル or リモート取得）
if [ -d "$(dirname "$0")/bin" ] && [ -d "$(dirname "$0")/.uesama" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    CLEANUP=""
else
    TMPDIR=$(mktemp -d)
    CLEANUP="$TMPDIR"
    echo ""
    echo "  ソースを取得中..."
    if command -v git >/dev/null 2>&1; then
        git clone --depth 1 "$REPO_URL.git" "$TMPDIR/uesama" >/dev/null 2>&1
        SCRIPT_DIR="$TMPDIR/uesama"
    else
        curl -fsSL "$REPO_URL/archive/refs/heads/main.tar.gz" -o "$TMPDIR/uesama.tar.gz"
        tar xzf "$TMPDIR/uesama.tar.gz" -C "$TMPDIR"
        SCRIPT_DIR="$TMPDIR/multi-agent-shogun-main"
    fi
fi

cleanup() {
    [ -n "$CLEANUP" ] && rm -rf "$CLEANUP" || true
}
trap cleanup EXIT

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  🏯 uesama インストーラー                     ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# 既存のインストールがあれば更新
if [ -d "$UESAMA_HOME" ]; then
    echo "  既存のインストールを更新します..."
    rm -rf "$UESAMA_HOME"
fi

# ディレクトリ作成
mkdir -p "$UESAMA_HOME"

# CLI ツールのインストール
cp -r "$SCRIPT_DIR/bin" "$UESAMA_HOME/"
cp -r "$SCRIPT_DIR/scripts" "$UESAMA_HOME/"

# プロジェクトデプロイ用テンプレート
mkdir -p "$UESAMA_HOME/template"
cp -r "$SCRIPT_DIR/.uesama" "$UESAMA_HOME/template/"
mkdir -p "$UESAMA_HOME/template/.claude/rules"
cp "$SCRIPT_DIR/.claude/rules/uesama.md" "$UESAMA_HOME/template/.claude/rules/uesama.md"

# config ディレクトリ作成
mkdir -p "$UESAMA_HOME/config"
if [ ! -f "$UESAMA_HOME/config/settings.yaml" ]; then
    cat > "$UESAMA_HOME/config/settings.yaml" << 'EOF'
language: ja
kashin_count: 8
EOF
fi

# 実行権限付与
chmod +x "$UESAMA_HOME/bin/"*
chmod +x "$UESAMA_HOME/scripts/"*

# PATH に追加
SHELL_RC=""
if [ -f "$HOME/.zshrc" ]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

PATH_LINE='export PATH="$HOME/.uesama/bin:$PATH"'
UESAMA_HOME_LINE='export UESAMA_HOME="$HOME/.uesama"'

if [ -n "$SHELL_RC" ]; then
    if ! grep -q '\.uesama/bin' "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# uesama multi-agent system" >> "$SHELL_RC"
        echo "$UESAMA_HOME_LINE" >> "$SHELL_RC"
        echo "$PATH_LINE" >> "$SHELL_RC"
        echo "  PATH を $SHELL_RC に追加しました"
    else
        echo "  PATH は既に設定済みです"
    fi
else
    echo "  ⚠ シェル設定ファイルが見つかりません"
    echo "  手動で以下を追加してください:"
    echo "    $UESAMA_HOME_LINE"
    echo "    $PATH_LINE"
fi

echo ""
echo "  ✅ インストール完了！"
echo ""
echo "  使い方:"
echo "    source $SHELL_RC    # PATH を反映"
echo "    cd /your/project"
echo "    uesama              # マルチエージェント起動"
echo "    uesama-daimyo       # 大名セッションに接続"
echo "    uesama-agents       # 参謀+家臣セッションに接続"
echo ""
