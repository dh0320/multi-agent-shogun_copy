#!/bin/bash
# uesama アンインストールスクリプト
set -e

UESAMA_HOME="$HOME/.uesama"

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  🏯 uesama アンインストーラー                 ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# tmux セッション停止
tmux kill-session -t daimyo 2>/dev/null || true
tmux kill-session -t kashindan 2>/dev/null || true

# ディレクトリ削除
if [ -d "$UESAMA_HOME" ]; then
    rm -rf "$UESAMA_HOME"
    echo "  ✅ $UESAMA_HOME を削除しました"
else
    echo "  ⚠ $UESAMA_HOME が見つかりません"
fi

# PATH から除去（コメント表示のみ）
echo ""
echo "  以下のシェル設定ファイルから uesama 関連の行を手動で削除してください:"
echo ""

for RC in "$HOME/.zshrc" "$HOME/.bashrc"; do
    if [ -f "$RC" ] && grep -q '\.uesama' "$RC" 2>/dev/null; then
        echo "    $RC:"
        grep -n '\.uesama\|# uesama' "$RC" | sed 's/^/      /'
        echo ""
    fi
done

echo "  アンインストール完了"
echo ""
