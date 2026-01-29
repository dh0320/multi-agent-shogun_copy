#!/bin/bash
# uesama 開発環境セットアップ
# clone 後に一度実行すると pre-commit フックと ShellCheck が有効になる
#
# 使い方:
#   bash scripts/setup-dev.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "  🏯 uesama 開発環境セットアップ"
echo ""

# ShellCheck のインストール
if command -v shellcheck > /dev/null 2>&1; then
    SC_VERSION=$(shellcheck --version | grep '^version:' | awk '{print $2}')
    echo "  ✓ ShellCheck (v$SC_VERSION) インストール済み"
else
    echo "  ShellCheck をインストール中..."
    if [ "$(uname)" = "Darwin" ] && command -v brew > /dev/null 2>&1; then
        brew install shellcheck
    elif command -v apt-get > /dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck
    elif command -v dnf > /dev/null 2>&1; then
        sudo dnf install -y ShellCheck
    elif command -v pacman > /dev/null 2>&1; then
        sudo pacman -S --noconfirm shellcheck
    else
        echo "  ⚠ ShellCheck を自動インストールできません"
        echo "    手動でインストールしてください: https://github.com/koalaman/shellcheck#installing"
    fi

    if command -v shellcheck > /dev/null 2>&1; then
        SC_VERSION=$(shellcheck --version | grep '^version:' | awk '{print $2}')
        echo "  ✓ ShellCheck (v$SC_VERSION) をインストールしました"
    fi
fi

# pre-commit フックの設定
if [ -d "$PROJECT_ROOT/.git" ] && [ -d "$PROJECT_ROOT/.githooks" ]; then
    git -C "$PROJECT_ROOT" config --local core.hooksPath .githooks
    echo "  ✓ pre-commit フック設定完了 (core.hooksPath = .githooks)"
else
    echo "  ⚠ git リポジトリまたは .githooks が見つかりません"
    exit 1
fi

echo ""
echo "  ✅ セットアップ完了"
echo ""
