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

# tmux チェック
if command -v tmux &> /dev/null; then
    TMUX_VERSION=$(tmux -V | awk '{print $2}')
    echo -e "  ${GREEN}✓${NC} tmux (v$TMUX_VERSION)"
else
    echo -e "  ${RED}✗${NC} tmux が見つかりません"
    echo "    インストール: brew install tmux (macOS) / sudo apt install tmux (Ubuntu)"
    HAS_ERROR=true
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
