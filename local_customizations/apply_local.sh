#!/bin/bash
# =============================================================================
# ローカルカスタマイズ適用スクリプト
# =============================================================================
# fork元と同期した後、このスクリプトを実行してローカル固有の変更を再適用
# =============================================================================

set -e

# スクリプトのディレクトリを取得
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🏯 ローカルカスタマイズ適用"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# -----------------------------------------------------------------------------
# 1. config/settings.yaml に上書き設定をマージ
# -----------------------------------------------------------------------------
echo "📝 [1/3] config/settings.yaml にカスタマイズをマージ中..."

if [ -f "$SCRIPT_DIR/settings_override.yaml" ]; then
    # Python で YAML をマージ（python3-yaml が必要）
    if command -v python3 >/dev/null 2>&1 && python3 -c "import yaml" 2>/dev/null; then
        python3 << 'PYTHON_EOF'
import yaml
import sys

# ベース設定を読み込み
with open("config/settings.yaml", "r") as f:
    base = yaml.safe_load(f)

# 上書き設定を読み込み
with open("local_customizations/settings_override.yaml", "r") as f:
    override = yaml.safe_load(f)

# マージ（Noneでないものだけ）
if override:
    base.update(override)

    # 書き出し
    with open("config/settings.yaml", "w") as f:
        yaml.dump(base, f, default_flow_style=False, allow_unicode=True, sort_keys=False)

    print("✅ config/settings.yaml を更新しました")
else:
    print("ℹ️  カスタマイズ項目がありません")
PYTHON_EOF
    else
        # Python が使えない場合
        echo "ℹ️  Python3 + PyYAML が見つかりません（カスタマイズ項目がなければ問題なし）"
    fi
else
    echo "⚠️  settings_override.yaml が見つかりません。スキップします。"
fi

echo ""

# -----------------------------------------------------------------------------
# 2. Git フックをインストール
# -----------------------------------------------------------------------------
echo "🪝 [2/3] Gitフックをインストール中..."

if [ -d "$SCRIPT_DIR/hooks" ]; then
    for hook in "$SCRIPT_DIR/hooks"/*; do
        if [ -f "$hook" ]; then
            hook_name=$(basename "$hook")
            cp "$hook" "$REPO_ROOT/.git/hooks/$hook_name"
            chmod +x "$REPO_ROOT/.git/hooks/$hook_name"
            echo "   ✅ $hook_name をインストールしました"
        fi
    done
else
    echo "⚠️  hooks/ フォルダが見つかりません。スキップします。"
fi

echo ""

# -----------------------------------------------------------------------------
# 3. Makefile を拡張
# -----------------------------------------------------------------------------
echo "🔧 [3/3] Makefile を拡張中..."

if [ -f "$SCRIPT_DIR/makefile_extensions.mk" ]; then
    # 既存のMakefileに追加コマンドがあるかチェック
    if ! grep -q "# ローカルカスタマイズ" "$REPO_ROOT/Makefile" 2>/dev/null; then
        # Makefileの末尾に追記
        cat >> "$REPO_ROOT/Makefile" << 'MAKEFILE_APPEND'

# =============================================================================
# ローカルカスタマイズ（local_customizations/ から自動追加）
# =============================================================================
MAKEFILE_APPEND
        cat "$SCRIPT_DIR/makefile_extensions.mk" >> "$REPO_ROOT/Makefile"
        echo "   ✅ Makefile にカスタマイズコマンドを追加しました"
    else
        echo "   ℹ️  Makefile には既にカスタマイズが含まれています"
    fi
else
    echo "⚠️  makefile_extensions.mk が見つかりません。スキップします。"
fi

echo ""

# -----------------------------------------------------------------------------
# 完了メッセージ
# -----------------------------------------------------------------------------
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ ローカルカスタマイズの適用が完了しました"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 適用された内容:"
echo "   1. config/settings.yaml: カスタマイズ設定（あれば）"
echo "   2. .git/hooks/: git push 禁止フック"
echo "   3. Makefile: 操作コマンドの追加"
echo ""
echo "🚀 次のステップ:"
echo "   make status    # セッション状態を確認"
echo "   make shutsujin # 出陣（全エージェント起動）"
echo ""
