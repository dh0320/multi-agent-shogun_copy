#!/bin/bash
# dashboard.md自動生成スクリプト (Phase 2)
# ヘッダー、エージェント状態、完了承認待ち、スキル化候補、進行中、保留中を自動生成
# 🚨要対応、📋運用ルールは手動管理（既存dashboard.mdから保持）

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DASHBOARD="$REPO_ROOT/dashboard.md"

cd "$REPO_ROOT"

# Python3でdashboard.mdを生成
python3 - <<'PYTHON_SCRIPT'
import yaml
import os
import re
from datetime import datetime
from pathlib import Path
from glob import glob

def read_yaml_safe(path):
    """YAMLファイルを安全に読み込む"""
    try:
        with open(path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f) or {}
    except FileNotFoundError:
        return {}
    except Exception as e:
        print(f"Warning: Failed to read {path}: {e}")
        return {}

def extract_section(content, start_marker, end_marker):
    """既存dashboard.mdからセクションを抽出"""
    # end_markerがNoneの場合は最後まで取得
    if end_marker is None:
        pattern = f"({re.escape(start_marker)}.*)"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            return match.group(1).rstrip()
    else:
        pattern = f"({re.escape(start_marker)}.*?)({re.escape(end_marker)})"
        match = re.search(pattern, content, re.DOTALL)
        if match:
            return match.group(1).rstrip()
    return None

def generate_header():
    """ヘッダーセクション生成"""
    now = datetime.now().strftime("%Y-%m-%d %H:%M")
    return f"# 📊 戦況報告\n最終更新: {now}\n"

def generate_agent_status_section(ashigaru_tasks):
    """エージェント状態セクションのみ生成"""
    section = f"### エージェント状態（{datetime.now().strftime('%Y-%m-%d %H:%M')}更新）\n"
    section += "- **家老**: 稼働中\n"

    # 足軽1〜8の状態を確認
    for i in range(1, 9):
        ashigaru_id = f"ashigaru{i}"
        if ashigaru_id in ashigaru_tasks:
            task_data = ashigaru_tasks[ashigaru_id].get('task', {})
            status = task_data.get('status', 'unknown')
            task_id = task_data.get('task_id', '')

            if status == 'assigned':
                note = "（TCC専任）" if i == 1 else ""
                section += f"- **足軽{i}**: 作業中（{task_id}）{note}\n"
            else:
                note = "（TCC専任）" if i == 1 else ""
                section += f"- **足軽{i}**: idle{note}\n"
        else:
            note = "（TCC専任）" if i == 1 else ""
            section += f"- **足軽{i}**: idle{note}\n"

    return section

def extract_other_status_memo(content):
    """📝本日の状況メモからエージェント状態以外の部分を抽出"""
    # "### エージェント状態" から次の"###"または"##"までをスキップ
    # それ以降の内容を取得
    pattern = r"## 📝 本日の状況メモ\n\n### エージェント状態.*?\n\n((?:###.*?\n|[^#].*?\n)*)"
    match = re.search(pattern, content, re.DOTALL)
    if match:
        other_content = match.group(1).strip()
        if other_content:
            return "\n\n" + other_content
    return ""

def load_dashboard_items():
    """queue/dashboard_items/ から全YAMLファイルを読み込み、section別に分類"""
    dashboard_items_dir = Path("queue/dashboard_items")
    sections = {
        "completion_pending": [],
        "skill_candidate": [],
        "in_progress": [],
        "on_hold": [],
    }

    if not dashboard_items_dir.exists():
        return sections

    yaml_files = sorted(dashboard_items_dir.glob("*.yaml"))
    for yaml_file in yaml_files:
        data = read_yaml_safe(yaml_file)
        if not data or 'section' not in data:
            continue

        section = data.get('section')
        if section in sections:
            sections[section].append(data)

    return sections

def format_completion_pending_section(items):
    """✅完了承認待ち セクション生成"""
    if not items:
        return "## ✅ 完了承認待ち - 殿のご確認をお待ちしております\n\n（なし）"

    section = "## ✅ 完了承認待ち - 殿のご確認をお待ちしております\n\n"
    for item in items:
        title = item.get('display_title', '')
        content = item.get('display_content', '').strip()
        section += f"### {title}\n{content}\n"

    return section.rstrip()

def format_skill_candidate_section(items):
    """🎯スキル化候補 セクション生成"""
    if not items:
        return "## 🎯 スキル化候補（未実装）\n（なし）"

    section = "## 🎯 スキル化候補\n\n"
    for item in items:
        title = item.get('display_title', '')
        skill_candidates = item.get('skill_candidates', [])

        section += f"### {title}\n"
        if skill_candidates:
            section += "| スキル名 | 概要 | 優先度 | 状態 |\n"
            section += "|---------|------|--------|------|\n"
            for skill in skill_candidates:
                name = skill.get('name', '')
                desc = skill.get('description', '')
                priority = skill.get('priority', '')
                status = skill.get('status', '')
                section += f"| {name} | {desc} | {priority} | {status} |\n"
        section += "\n"

    return section.rstrip()

def format_in_progress_section(items):
    """🔄進行中 セクション生成"""
    if not items:
        return "## 🔄 進行中\n\n（なし）"

    section = "## 🔄 進行中\n\n"
    for item in items:
        title = item.get('display_title', '')
        content = item.get('display_content', '').strip()
        section += f"### {title}\n{content}\n"

    return section.rstrip()

def format_on_hold_section(items):
    """⏸️保留中 セクション生成"""
    if not items:
        return "## ⏸️ 保留中タスク\n\n（なし）"

    section = "## ⏸️ 保留中タスク\n\n"
    for item in items:
        title = item.get('display_title', '')
        content = item.get('display_content', '').strip()
        section += f"### {title}\n{content}\n"

    return section.rstrip()

def main():
    # 既存dashboard.mdを読み込み
    dashboard_path = Path("dashboard.md")
    existing_content = ""
    if dashboard_path.exists():
        with open(dashboard_path, 'r', encoding='utf-8') as f:
            existing_content = f.read()

    # 手動管理セクションを既存dashboard.mdから抽出
    urgent_section = extract_section(existing_content,
                                      "## 🚨 要対応 - 殿のご判断をお待ちしております",
                                      "## ✅ 完了承認待ち")
    if not urgent_section:
        urgent_section = "## 🚨 要対応 - 殿のご判断をお待ちしております\n\n（なし）"

    rule_section = extract_section(existing_content,
                                    "## 📋 運用ルール",
                                    "## 📝 本日の状況メモ")
    if not rule_section:
        rule_section = "## 📋 運用ルール\n（なし）"

    # 📝本日の状況メモのエージェント状態以外の部分を抽出
    other_status_memo = extract_other_status_memo(existing_content)

    # 足軽タスクYAML読み込み（エージェント状態生成用）
    ashigaru_tasks = {}
    for i in range(1, 9):
        ashigaru_id = f"ashigaru{i}"
        ashigaru_path = f"queue/tasks/{ashigaru_id}.yaml"
        if Path(ashigaru_path).exists():
            ashigaru_tasks[ashigaru_id] = read_yaml_safe(ashigaru_path)

    # dashboard_items読み込み
    dashboard_items = load_dashboard_items()

    # 自動生成セクション作成
    completion_section = format_completion_pending_section(dashboard_items["completion_pending"])
    skill_section = format_skill_candidate_section(dashboard_items["skill_candidate"])
    in_progress_section = format_in_progress_section(dashboard_items["in_progress"])
    hold_section = format_on_hold_section(dashboard_items["on_hold"])

    # dashboard.md生成
    output = []
    output.append(generate_header())
    output.append(urgent_section + "\n")
    output.append(completion_section + "\n")
    output.append(skill_section + "\n")
    output.append(in_progress_section + "\n")
    output.append(hold_section + "\n")
    output.append(rule_section + "\n")
    output.append("## 📝 本日の状況メモ\n\n")
    output.append(generate_agent_status_section(ashigaru_tasks))
    output.append(other_status_memo)
    if not other_status_memo.endswith("\n"):
        output.append("\n")

    # ファイル出力
    with open(dashboard_path, 'w', encoding='utf-8') as f:
        f.write(''.join(output))

    print(f"✅ dashboard.md generated successfully at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print(f"   (Phase 2: 自動生成 - ヘッダー、エージェント状態、完了承認待ち、スキル化候補、進行中、保留中)")
    print(f"   (手動管理 - 🚨要対応、📋運用ルール)")

    # 統計情報表示
    items_count = sum(len(items) for items in dashboard_items.values())
    print(f"   Loaded {items_count} dashboard items from queue/dashboard_items/")

if __name__ == "__main__":
    main()
PYTHON_SCRIPT
