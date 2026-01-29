---
title: "AIエージェント8体を操るシステムにGitHub Copilot対応を追加した"
emoji: "🏯"
type: "tech"
topics: ["ai", "claude", "copilot", "multiagent", "tmux"]
published: false
---

## はじめに

[@shio_shoppaize](https://zenn.dev/shio_shoppaize) さんが作った **multi-agent-shogun** という、複数のAIエージェントを並列で動かせるシステムがあります。

https://zenn.dev/shio_shoppaize/articles/5fee11d03a11a1

これが面白そうだったので、GitHub Copilot CLIでも動くように拡張してみました。

**拡張版リポジトリ**: https://github.com/yohey-w/multi-agent-shogun

## multi-agent-shogunって何？

戦国時代の軍制をモチーフにしたマルチエージェントシステムです。

```
      あなた（上様）
           │
           ▼ 命令を出す
    ┌─────────────┐
    │   SHOGUN    │  ← 命令を受け取り、即座に委譲
    └──────┬──────┘
           │ YAMLファイル + tmux
    ┌──────▼──────┐
    │    KARO     │  ← タスクをワーカーに分配
    └──────┬──────┘
           │
  ┌─┬─┬─┬─┴─┬─┬─┬─┐
  │1│2│3│4│5│6│7│8│  ← 8体のワーカーが並列実行
  └─┴─┴─┴─┴─┴─┴─┴─┘
      ASHIGARU
```

「JavaScriptフレームワーク上位5つを調査して」みたいな指示を出すと、家老がタスクを分解して8人の足軽が並列で調べてくれます。

元々はClaude Code CLI専用でしたが、GitHub Copilot CLIでも使えるようにしてみました。

## なぜ拡張したのか

単純に、好きなCLIを選べたら便利だと思ったからです。

- Claude と GPT を使い分けたい
- コストを最適化したい
- それぞれの強みを活かしたい

問題は、Claude CodeとGitHub Copilot CLIで起動方法が全然違うこと。

| 項目 | Claude Code | GitHub Copilot |
|------|------------|----------------|
| 起動 | `claude --dangerously-skip-permissions` | `gh copilot session --agent <名前>` |
| 指示書 | `--system-prompt` | `~/.github-copilot/agents/*.yaml` |

この違いをどう吸収するか、が課題でした。

## 実装: CLIアダプター

**lib/cli_adapter.sh** というアダプターを作って、CLIの違いを吸収するようにしました。

```bash
# lib/cli_adapter.sh の構造

起動スクリプト
    ↓
CLIアダプター（統一インターフェース）
    ↓
 Claude or Copilot
```

### コア部分

```bash
#!/bin/bash
# CLIタイプを取得
get_cli_type() {
    local agent_name="$1"
    local yaml_config="$2"

    # エージェント固有の設定があればそれを使う
    # なければデフォルト設定を使う
}

# CLIコマンドを構築
build_cli_command() {
    local agent_name="$1"
    local cli_type="$2"

    case "$cli_type" in
        claude)
            echo "claude --dangerously-skip-permissions"
            ;;
        copilot)
            echo "copilot --allow-all --allow-all-tools --allow-all-paths"
            ;;
    esac
}
```

### 設定ファイル

`config/settings.yaml` でCLIを切り替えられるようにしました。

```yaml
cli:
  default: claude  # または copilot

  agents:
    shogun:
      type: claude
    ashigaru1:
      type: copilot  # 足軽1だけCopilot
    # 指定なしはdefaultを使用
```

エージェントごとにCLIを混在させることもできます。

## 使い方

### Claude Codeで起動（デフォルト）

```bash
./shutsujin_departure.sh
```

### GitHub Copilotで起動

```bash
./shutsujin_departure.sh -c
```

### 専用スクリプト

簡単に切り替えられるスクリプトも用意しました。

```bash
./start_copilot.sh  # Copilot用設定に一時切替
./start_claude.sh   # Claude用設定に一時切替
```

## 工夫したポイント

### 1. 設定ファイル駆動

コードを変えずに、YAMLだけで動作を変更できます。

### 2. バリデーション

起動前にCLIがインストールされているかチェックして、わかりやすいエラーを出します。

```bash
validate_cli_availability() {
    case "$cli_type" in
        claude)
            if ! command -v claude &>/dev/null; then
                echo "Error: Claude Code CLI が見つかりません"
                echo "インストール: npm install -g @anthropic-ai/claude-code"
                return 1
            fi
            ;;
        copilot)
            # GitHub CLI と認証をチェック
            ;;
    esac
}
```

### 3. バックアップ機能

設定を一時的に変えるとき、自動でバックアップを作ります。

## トラブルシューティング

### Copilotが起動しない

```bash
# GitHub CLI確認
gh --version

# Copilot拡張確認
gh extension list | grep copilot

# インストール
gh extension install github/gh-copilot

# 認証
gh auth login
```

### CLIを切り替えたい

```bash
# オプションで一時切替
./shutsujin_departure.sh -c

# 設定ファイルで永続切替
vim config/settings.yaml
```

## 使ってみた感想

両方試してみた結果：

| 項目 | Claude Code | GitHub Copilot |
|------|------------|----------------|
| 速度 | 速い | 速い |
| 思考 | 深い | 実用的 |
| コード | 丁寧 | 簡潔 |
| ツール | MCP豊富 | GitHub統合強い |

用途に応じて使い分けると便利です。

## まとめ

CLIアダプターパターンで、異なるAI CLIツールを統一的に扱えるようになりました。

今後やりたいこと：
- タスクに応じた自動モデル選択
- コスト追跡機能
- Cursor CLI、Aider等への対応

## 謝辞

[@shio_shoppaize](https://zenn.dev/shio_shoppaize) さんの素晴らしいシステムがあってこその拡張です。戦国時代のメタファーとイベント駆動設計が最高でした。ありがとうございます。

## リンク

**元記事**: https://zenn.dev/shio_shoppaize/articles/5fee11d03a11a1

**拡張版リポジトリ**: https://github.com/yohey-w/multi-agent-shogun

---

**環境**
- macOS / Linux / tmux 3.0+ / Node.js v20+
- Claude Code CLI or GitHub Copilot CLI

**ライセンス**: MIT
