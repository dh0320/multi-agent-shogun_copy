#!/bin/bash
# validate_dashboard.sh - dashboard.mdとYAML差分検知スクリプト
# queue/dashboard_items/のYAML数 vs dashboard.mdのエントリ数を比較し、不一致を警告

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DASHBOARD="$REPO_ROOT/dashboard.md"
DASHBOARD_ITEMS_DIR="$REPO_ROOT/queue/dashboard_items"

cd "$REPO_ROOT"

# dashboard_items/のYAML数をカウント
yaml_count=$(find "$DASHBOARD_ITEMS_DIR" -name "*.yaml" 2>/dev/null | wc -l)

# dashboard.mdの自動生成エントリ数をカウント（### で始まる行）
# セクション: ✅完了承認待ち、🎯スキル化候補、🔄進行中、⏸️保留中
# 🚨要対応と📋運用ルールは手動管理のため除外

entry_count=0

# ✅完了承認待ち セクション内の ### をカウント
completion_count=$(sed -n '/^## ✅ 完了承認待ち/,/^## /p' "$DASHBOARD" | grep -c '^### ' || true)
entry_count=$((entry_count + completion_count))

# 🎯スキル化候補 セクション内の ### をカウント
skill_count=$(sed -n '/^## 🎯 スキル化候補/,/^## /p' "$DASHBOARD" | grep -c '^### ' || true)
entry_count=$((entry_count + skill_count))

# 🔄進行中 セクション内の ### をカウント
progress_count=$(sed -n '/^## 🔄 進行中/,/^## /p' "$DASHBOARD" | grep -c '^### ' || true)
entry_count=$((entry_count + progress_count))

# ⏸️保留中 セクション内の ### をカウント
hold_count=$(sed -n '/^## ⏸️ 保留中/,/^## /p' "$DASHBOARD" | grep -c '^### ' || true)
entry_count=$((entry_count + hold_count))

echo "=== dashboard.md 検証結果 ==="
echo "dashboard_items/ YAML数: $yaml_count"
echo "dashboard.md エントリ数: $entry_count"
echo "  ├ ✅完了承認待ち: $completion_count"
echo "  ├ 🎯スキル化候補: $skill_count"
echo "  ├ 🔄進行中: $progress_count"
echo "  └ ⏸️保留中: $hold_count"

if [ "$yaml_count" -ne "$entry_count" ]; then
    echo ""
    echo "⚠️  警告: YAML数とエントリ数が不一致です"
    echo "    予想: $yaml_count"
    echo "    実際: $entry_count"
    echo "    差分: $((yaml_count - entry_count))"
    echo ""
    echo "📝 対応: bash scripts/generate_dashboard.sh を実行してください"
    exit 1
else
    echo ""
    echo "✅ OK: YAML数とエントリ数が一致しています"
    exit 0
fi
