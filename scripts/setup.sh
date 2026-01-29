#!/bin/bash
# uesama 依存チェックスクリプト
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

HAS_ERROR=false

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  🏯 uesama 依存チェック                       ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# tmux チェック & 自動インストール
if command -v tmux &> /dev/null; then
    TMUX_VERSION=$(tmux -V | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} tmux (v$TMUX_VERSION)"
else
    echo -e "  ${YELLOW}!${NC} tmux が見つかりません。自動インストールを試みます..."
    INSTALL_SUCCESS=false
    if [ "$(uname)" = "Darwin" ]; then
        if command -v brew &> /dev/null; then
            echo "    brew でインストール中..."
            brew install tmux && INSTALL_SUCCESS=true
        elif command -v port &> /dev/null; then
            echo "    MacPorts でインストール中..."
            sudo port install tmux && INSTALL_SUCCESS=true
        else
            echo -e "  ${YELLOW}!${NC} macOS でパッケージマネージャが見つかりません"
            echo "    brew または MacPorts をインストールしてから再実行してください"
        fi
    elif command -v apt-get &> /dev/null; then
        echo "    apt-get でインストール中..."
        sudo apt-get update -qq && sudo apt-get install -y -qq tmux && INSTALL_SUCCESS=true
    elif command -v dnf &> /dev/null; then
        echo "    dnf でインストール中..."
        sudo dnf install -y tmux && INSTALL_SUCCESS=true
    elif command -v yum &> /dev/null; then
        echo "    yum でインストール中..."
        sudo yum install -y tmux && INSTALL_SUCCESS=true
    elif command -v pacman &> /dev/null; then
        echo "    pacman でインストール中..."
        sudo pacman -S --noconfirm tmux && INSTALL_SUCCESS=true
    elif command -v apk &> /dev/null; then
        echo "    apk でインストール中..."
        sudo apk add tmux && INSTALL_SUCCESS=true
    elif command -v zypper &> /dev/null; then
        echo "    zypper でインストール中..."
        sudo zypper install -y tmux && INSTALL_SUCCESS=true
    else
        echo -e "  ${RED}✗${NC} サポートされるパッケージマネージャが見つかりません"
        echo "    手動でインストールしてください: https://github.com/tmux/tmux/wiki/Installing"
    fi

    if [ "$INSTALL_SUCCESS" = true ] && command -v tmux &> /dev/null; then
        TMUX_VERSION=$(tmux -V | awk '{print $2}')
        echo -e "  ${GREEN}✓${NC} tmux (v$TMUX_VERSION) をインストールしました"
    elif [ "$INSTALL_SUCCESS" = true ]; then
        echo -e "  ${RED}✗${NC} tmux のインストールに失敗しました"
        HAS_ERROR=true
    else
        HAS_ERROR=true
    fi
fi

# Claude Code CLI チェック
if command -v claude &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Claude Code CLI"
else
    echo -e "  ${RED}✗${NC} Claude Code CLI が見つかりません"
    echo "    インストール: npm install -g @anthropic-ai/claude-code"
    HAS_ERROR=true
fi

echo ""

if [ "$HAS_ERROR" = true ]; then
    echo -e "  ${YELLOW}⚠ 不足している依存関係があります${NC}"
    exit 1
else
    echo -e "  ${GREEN}✅ 全ての依存関係が揃っています${NC}"
fi
