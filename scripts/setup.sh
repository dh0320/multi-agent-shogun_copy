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
    echo -e "  ${YELLOW}!${NC} tmux が見つかりません"
    TMUX_INSTALL_SUCCESS=false

    # 利用可能なインストール方法を検出
    TMUX_OPTIONS=()
    TMUX_CMDS=()
    if command -v brew &> /dev/null; then
        TMUX_OPTIONS+=("brew (brew install tmux)")
        TMUX_CMDS+=("brew install tmux")
    fi
    if command -v port &> /dev/null; then
        TMUX_OPTIONS+=("MacPorts (sudo port install tmux)")
        TMUX_CMDS+=("sudo port install tmux")
    fi
    if command -v apt-get &> /dev/null; then
        TMUX_OPTIONS+=("apt-get (sudo apt-get install tmux)")
        TMUX_CMDS+=("sudo apt-get update -qq && sudo apt-get install -y -qq tmux")
    fi
    if command -v dnf &> /dev/null; then
        TMUX_OPTIONS+=("dnf (sudo dnf install tmux)")
        TMUX_CMDS+=("sudo dnf install -y tmux")
    fi
    if command -v yum &> /dev/null; then
        TMUX_OPTIONS+=("yum (sudo yum install tmux)")
        TMUX_CMDS+=("sudo yum install -y tmux")
    fi
    if command -v pacman &> /dev/null; then
        TMUX_OPTIONS+=("pacman (sudo pacman -S tmux)")
        TMUX_CMDS+=("sudo pacman -S --noconfirm tmux")
    fi
    if command -v apk &> /dev/null; then
        TMUX_OPTIONS+=("apk (sudo apk add tmux)")
        TMUX_CMDS+=("sudo apk add tmux")
    fi
    if command -v zypper &> /dev/null; then
        TMUX_OPTIONS+=("zypper (sudo zypper install tmux)")
        TMUX_CMDS+=("sudo zypper install -y tmux")
    fi

    if [ ${#TMUX_OPTIONS[@]} -gt 0 ]; then
        echo ""
        echo "    インストール方法を選択してください:"
        for i in "${!TMUX_OPTIONS[@]}"; do
            echo "      $((i + 1))) ${TMUX_OPTIONS[$i]}"
        done
        echo "      0) スキップ"
        echo ""
        read -r -p "    番号を入力 [0]: " choice
        choice="${choice:-0}"

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#TMUX_OPTIONS[@]} ]; then
            idx=$((choice - 1))
            echo "    インストール中..."
            eval "${TMUX_CMDS[$idx]}" && TMUX_INSTALL_SUCCESS=true
        else
            echo "    スキップしました"
        fi
    else
        echo -e "  ${RED}✗${NC} サポートされるパッケージマネージャが見つかりません"
        echo "    手動でインストールしてください: https://github.com/tmux/tmux/wiki/Installing"
    fi

    if [ "$TMUX_INSTALL_SUCCESS" = true ] && command -v tmux &> /dev/null; then
        TMUX_VERSION=$(tmux -V | awk '{print $2}')
        echo -e "  ${GREEN}✓${NC} tmux (v$TMUX_VERSION) をインストールしました"
    elif [ "$TMUX_INSTALL_SUCCESS" != true ]; then
        HAS_ERROR=true
    else
        echo -e "  ${RED}✗${NC} tmux のインストールに失敗しました"
        HAS_ERROR=true
    fi
fi

# Claude Code CLI チェック & 自動インストール
if command -v claude &> /dev/null; then
    echo -e "  ${GREEN}✓${NC} Claude Code CLI"
else
    echo -e "  ${YELLOW}!${NC} Claude Code CLI が見つかりません"
    CLAUDE_INSTALL_SUCCESS=false

    # 利用可能なインストール方法を検出
    INSTALL_OPTIONS=()
    INSTALL_CMDS=()
    if command -v curl &> /dev/null; then
        INSTALL_OPTIONS+=("curl (curl -fsSL https://claude.ai/install.sh | sh)")
        INSTALL_CMDS+=("curl -fsSL https://claude.ai/install.sh | sh")
    fi
    if command -v yarn &> /dev/null; then
        INSTALL_OPTIONS+=("yarn (yarn global add @anthropic-ai/claude-code)")
        INSTALL_CMDS+=("yarn global add @anthropic-ai/claude-code")
    fi
    if command -v pnpm &> /dev/null; then
        INSTALL_OPTIONS+=("pnpm (pnpm add -g @anthropic-ai/claude-code)")
        INSTALL_CMDS+=("pnpm add -g @anthropic-ai/claude-code")
    fi
    if command -v brew &> /dev/null; then
        INSTALL_OPTIONS+=("brew (brew install claude-code)")
        INSTALL_CMDS+=("brew install claude-code")
    fi
    if command -v npm &> /dev/null; then
        INSTALL_OPTIONS+=("npm (npm install -g @anthropic-ai/claude-code)")
        INSTALL_CMDS+=("npm install -g @anthropic-ai/claude-code")
    fi

    if [ ${#INSTALL_OPTIONS[@]} -gt 0 ]; then
        echo ""
        echo "    インストール方法を選択してください:"
        for i in "${!INSTALL_OPTIONS[@]}"; do
            echo "      $((i + 1))) ${INSTALL_OPTIONS[$i]}"
        done
        echo "      0) スキップ"
        echo ""
        read -r -p "    番号を入力 [0]: " choice
        choice="${choice:-0}"

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#INSTALL_OPTIONS[@]} ]; then
            idx=$((choice - 1))
            echo "    インストール中..."
            eval "${INSTALL_CMDS[$idx]}" && CLAUDE_INSTALL_SUCCESS=true
        else
            echo "    スキップしました"
        fi
    else
        echo -e "  ${RED}✗${NC} npm/yarn/pnpm/brew/curl が見つかりません"
        echo "    手動でインストールしてください: https://docs.anthropic.com/en/docs/claude-code"
    fi

    if [ "$CLAUDE_INSTALL_SUCCESS" = true ] && command -v claude &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Claude Code CLI をインストールしました"
    elif [ "$CLAUDE_INSTALL_SUCCESS" != true ]; then
        HAS_ERROR=true
    else
        echo -e "  ${RED}✗${NC} Claude Code CLI のインストールに失敗しました"
        HAS_ERROR=true
    fi
fi

echo ""

if [ "$HAS_ERROR" = true ]; then
    echo -e "  ${YELLOW}⚠ 不足している依存関係があります${NC}"
    exit 1
else
    echo -e "  ${GREEN}✅ 全ての依存関係が揃っています${NC}"
fi
