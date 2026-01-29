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
    echo "  ShellCheck が見つかりません"
    SC_INSTALL_SUCCESS=false

    # 利用可能なインストール方法を検出
    SC_OPTIONS=()
    SC_CMDS=()
    if command -v brew > /dev/null 2>&1; then
        SC_OPTIONS+=("brew (brew install shellcheck)")
        SC_CMDS+=("brew install shellcheck")
    fi
    if command -v apt-get > /dev/null 2>&1; then
        SC_OPTIONS+=("apt-get (sudo apt-get install shellcheck)")
        SC_CMDS+=("sudo apt-get update -qq && sudo apt-get install -y -qq shellcheck")
    fi
    if command -v dnf > /dev/null 2>&1; then
        SC_OPTIONS+=("dnf (sudo dnf install ShellCheck)")
        SC_CMDS+=("sudo dnf install -y ShellCheck")
    fi
    if command -v pacman > /dev/null 2>&1; then
        SC_OPTIONS+=("pacman (sudo pacman -S shellcheck)")
        SC_CMDS+=("sudo pacman -S --noconfirm shellcheck")
    fi

    if [ ${#SC_OPTIONS[@]} -gt 0 ]; then
        echo ""
        echo "    インストール方法を選択してください:"
        for i in "${!SC_OPTIONS[@]}"; do
            echo "      $((i + 1))) ${SC_OPTIONS[$i]}"
        done
        echo "      0) スキップ"
        echo ""
        read -r -p "    番号を入力 [0]: " choice
        choice="${choice:-0}"

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#SC_OPTIONS[@]} ]; then
            idx=$((choice - 1))
            echo "    インストール中..."
            eval "${SC_CMDS[$idx]}" && SC_INSTALL_SUCCESS=true
        else
            echo "    スキップしました"
        fi
    else
        echo "  ⚠ サポートされるパッケージマネージャが見つかりません"
        echo "    手動でインストールしてください: https://github.com/koalaman/shellcheck#installing"
    fi

    if [ "$SC_INSTALL_SUCCESS" = true ] && command -v shellcheck > /dev/null 2>&1; then
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
