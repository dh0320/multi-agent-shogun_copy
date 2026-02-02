# multi-agent-kairai

<div align="center">

**Claude Code マルチエージェント統率システム**

_コマンド1つで、8体のAIエージェントが並列稼働_

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Claude Code](https://img.shields.io/badge/Claude-Code-blueviolet)](https://claude.ai)
[![tmux](https://img.shields.io/badge/tmux-required-green)](https://github.com/tmux/tmux)

[English](README.md) | [日本語](README_ja.md)

</div>

---

## これは何？

**multi-agent-kairai** は、複数の Claude Code インスタンスを同時に実行し、宮廷の階層構造のように統率するシステムです。

**なぜ使うのか？**

- 1つの命令で、8体のAIワーカーが並列で実行
- 待ち時間なし - タスクがバックグラウンドで実行中も次の命令を出せる
- AIがセッションを跨いであなたの好みを記憶（Memory MCP）
- ダッシュボードでリアルタイム進捗確認

```
      あなた（旅人）
           │
           ▼ 命令を出す
    ┌─────────────┐
    │   KAIRAI    │  ← 傀儡/KAIRAI（執行官）
    └──────┬──────┘
           │ YAMLファイル + tmux
    ┌──────▼──────┐
    │   PULONIA   │  ← プロンニア/Pulonia（執事）
    └──────┬──────┘
           │
  ┌─┬─┬─┬─┴─┬─┬─┬─┐
  │1│2│3│4│5│6│7│8│  ← 8体のワーカーが並列実行
  └─┴─┴─┴─┴─┴─┴─┴─┘
       BOSCO
```

---

## 🚀 クイックスタート

### 🪟 Windowsユーザー（最も一般的）

<table>
<tr>
<td width="60">

**Step 1**

</td>
<td>

📥 **リポジトリをダウンロード**

[ZIPダウンロード](https://github.com/yohey-w/multi-agent-kairai/archive/refs/heads/main.zip) して `C:\tools\multi-agent-kairai` に展開

_または git を使用:_ `git clone https://github.com/yohey-w/multi-agent-kairai.git C:\tools\multi-agent-kairai`

</td>
</tr>
<tr>
<td>

**Step 2**

</td>
<td>

🖱️ **`install.bat` を実行**

右クリック→「管理者として実行」（WSL2が未インストールの場合）。WSL2 + Ubuntu をセットアップします。

</td>
</tr>
<tr>
<td>

**Step 3**

</td>
<td>

🐧 **Ubuntu を開いて以下を実行**（初回のみ）

```bash
cd /mnt/c/tools/multi-agent-kairai
./first_setup.sh
```

</td>
</tr>
<tr>
<td>

**Step 4**

</td>
<td>

✅ **任務開始！**

```bash
./mission_start.sh
```

</td>
</tr>
</table>

#### 📅 毎日の起動（初回セットアップ後）

**Ubuntuターミナル**（WSL）を開いて実行：

```bash
cd /mnt/c/tools/multi-agent-kairai
./mission_start.sh
```

---

<details>
<summary>🐧 <b>Linux / Mac ユーザー</b>（クリックで展開）</summary>

### 初回セットアップ

```bash
# 1. リポジトリをクローン
git clone https://github.com/yohey-w/multi-agent-kairai.git ~/multi-agent-kairai
cd ~/multi-agent-kairai

# 2. スクリプトに実行権限を付与
chmod +x *.sh

# 3. 初回セットアップを実行
./first_setup.sh
```

### 毎日の起動

```bash
cd ~/multi-agent-kairai
./mission_start.sh
```

</details>

---

<details>
<summary>❓ <b>WSL2とは？なぜ必要？</b>（クリックで展開）</summary>

### WSL2について

**WSL2（Windows Subsystem for Linux）** は、Windows内でLinuxを実行できる機能です。このシステムは `tmux`（Linuxツール）を使って複数のAIエージェントを管理するため、WindowsではWSL2が必要です。

### WSL2がまだない場合

問題ありません！`install.bat` を実行すると：

1. WSL2がインストールされているかチェック（なければ自動インストール）
2. Ubuntuがインストールされているかチェック（なければ自動インストール）
3. 次のステップ（`first_setup.sh` の実行方法）を案内

**クイックインストールコマンド**（PowerShellを管理者として実行）：

```powershell
wsl --install
```

その後、コンピュータを再起動して `install.bat` を再実行してください。

</details>

---

<details>
<summary>🎩 <b>スクリプトリファレンス</b>（クリックで展開）</summary>

| スクリプト         | 用途                                                  | 実行タイミング |
| ------------------ | ----------------------------------------------------- | -------------- |
| `install.bat`      | Windows: WSL2 + Ubuntu のセットアップ                 | 初回のみ       |
| `first_setup.sh`   | tmux、Node.js、Claude Code CLI をインストール         | 初回のみ       |
| `mission_start.sh` | tmuxセッション作成 + Claude Code起動 + 指示書読み込み | 毎日           |

### `install.bat` が自動で行うこと：

- ✅ WSL2がインストールされているかチェック（未インストールなら案内）
- ✅ Ubuntuがインストールされているかチェック（未インストールなら案内）
- ✅ 次のステップ（`first_setup.sh` の実行方法）を案内

### `mission_start.sh` が行うこと：

- ✅ tmuxセッションを作成（kairai + multiagent）
- ✅ 全エージェントでClaude Codeを起動
- ✅ 各エージェントに指示書を自動読み込み
- ✅ キューファイルをリセットして新しい状態に

**実行後、全エージェントが即座にコマンドを受け付ける準備完了！**

</details>

---

<details>
<summary>🔧 <b>必要環境（手動セットアップの場合）</b>（クリックで展開）</summary>

依存関係を手動でインストールする場合：

| 要件            | インストール方法                           | 備考                     |
| --------------- | ------------------------------------------ | ------------------------ |
| WSL2 + Ubuntu   | PowerShellで `wsl --install`               | Windowsのみ              |
| tmux            | `sudo apt install tmux`                    | ターミナルマルチプレクサ |
| Node.js v20+    | `nvm install 20`                           | Claude Code CLIに必要    |
| Claude Code CLI | `npm install -g @anthropic-ai/claude-code` | Anthropic公式CLI         |

</details>

---

### ✅ セットアップ後の状態

どちらのオプションでも、**10体のAIエージェント**が自動起動します：

| エージェント                  | 役割                          | 数  |
| ----------------------------- | ----------------------------- | --- |
| 🫖 傀儡/KAIRAI（執行官）      | 総大将 - あなたの命令を受ける | 1   |
| 🎩 プロンニア/Pulonia（執事） | 管理者 - タスクを分配         | 1   |
| 🤖 ボスコ/Bosco（機動兵）     | ワーカー - 並列でタスク実行   | 8   |

tmuxセッションが作成されます：

- `kairai` - ここに接続してコマンドを出す
- `multiagent` - ワーカーがバックグラウンドで稼働

---

## 📖 基本的な使い方

### Step 1: 傀儡/KAIRAI（執行官）に接続

`mission_start.sh` 実行後、全エージェントが自動的に指示書を読み込み、作業準備完了となります。

新しいターミナルを開いて傀儡/KAIRAI（執行官）に接続：

```bash
tmux attach-session -t kairai
```

### Step 2: 最初の命令を出す

傀儡/KAIRAI（執行官）は既に初期化済み！そのまま命令を出せます：

```
JavaScriptフレームワーク上位5つを調査して比較表を作成せよ
```

傀儡/KAIRAI（執行官）は：

1. タスクをYAMLファイルに書き込む
2. プロンニア/Pulonia（執事）（管理者）に通知
3. 即座にあなたに制御を返す（待つ必要なし！）

その間、プロンニア/Pulonia（執事）はタスクをボスコ/Bosco（機動兵）ワーカーに分配し、並列実行します。

### Step 3: 進捗を確認

エディタで `dashboard.md` を開いてリアルタイム状況を確認：

```markdown
## 進行中

| ワーカー                 | タスク      | 状態   |
| ------------------------ | ----------- | ------ |
| ボスコ/Bosco（機動兵） 1 | React調査   | 実行中 |
| ボスコ/Bosco（機動兵） 2 | Vue調査     | 実行中 |
| ボスコ/Bosco（機動兵） 3 | Angular調査 | 完了   |
```

---

## ✨ 主な特徴

### ⚡ 1. 並列実行

1つの命令で最大8つの並列タスクを生成：

```
あなた: 「5つのMCPサーバを調査せよ」
→ 5体のボスコ/Bosco（機動兵）が同時に調査開始
→ 数時間ではなく数分で結果が出る
```

### 🔄 2. ノンブロッキングワークフロー

傀儡/KAIRAI（執行官）は即座に委譲して、あなたに制御を返します：

```
あなた: 命令 → 傀儡/KAIRAI（執行官）: 委譲 → あなた: 次の命令をすぐ出せる
                                    ↓
                    ワーカー: バックグラウンドで実行
                                    ↓
                    ダッシュボード: 結果を表示
```

長いタスクの完了を待つ必要はありません。

### 🧠 3. セッション間記憶（Memory MCP）

AIがあなたの好みを記憶します：

```
セッション1: 「シンプルな方法が好き」と伝える
            → Memory MCPに保存

セッション2: 起動時にAIがメモリを読み込む
            → 複雑な方法を提案しなくなる
```

### 📡 4. イベント駆動（ポーリングなし）

エージェントはYAMLファイルで通信し、tmux send-keysで互いを起こします。
**ポーリングループでAPIコールを浪費しません。**

### 📸 5. スクリーンショット連携

VSCode拡張のClaude Codeはスクショを貼り付けて事象を説明できます。このCLIシステムでも同等の機能を実現：

```
# config/settings.yaml でスクショフォルダを設定
screenshot:
  path: "/mnt/c/Users/あなたの名前/Pictures/Screenshots"

# 傀儡/KAIRAI（執行官）に伝えるだけ:
あなた: 「最新のスクショを見ろ」
あなた: 「スクショ2枚見ろ」
→ AIが即座にスクリーンショットを読み取って分析
```

**💡 Windowsのコツ:** `Win + Shift + S` でスクショが撮れます。保存先を `settings.yaml` のパスに合わせると、シームレスに連携できます。

こんな時に便利：

- UIのバグを視覚的に説明
- エラーメッセージを見せる
- 変更前後の状態を比較

### 📁 6. コンテキスト管理

効率的な知識共有のため、3層構造のコンテキストを採用：

| レイヤー     | 場所                         | 用途                           |
| ------------ | ---------------------------- | ------------------------------ |
| Memory MCP   | `memory/kairai_memory.jsonl` | セッションを跨ぐ長期記憶       |
| グローバル   | `memory/global_context.md`   | システム全体の設定、旅人の好み |
| プロジェクト | `context/{project}.md`       | プロジェクト固有の知見         |

この設計により：

- どのボスコ/Bosco（機動兵）でも任意のプロジェクトを担当可能
- エージェント切り替え時もコンテキスト継続
- 関心の分離が明確

### 汎用コンテキストテンプレート

すべてのプロジェクトで同じ7セクション構成のテンプレートを使用：

| セクション    | 目的                             |
| ------------- | -------------------------------- |
| What          | プロジェクトの概要説明           |
| Why           | 目的と成功の定義                 |
| Who           | 関係者と責任者                   |
| Constraints   | 期限、予算、制約                 |
| Current State | 進捗、次のアクション、ブロッカー |
| Decisions     | 決定事項と理由の記録             |
| Notes         | 自由記述のメモ・気づき           |

統一フォーマットにより、どのプロジェクトでも同じ構造で情報を参照可能。

---

### 🧠 モデル設定

| エージェント               | モデル     | 思考モード | 理由                                     |
| -------------------------- | ---------- | ---------- | ---------------------------------------- |
| 傀儡/KAIRAI（執行官）      | Opus       | 無効       | 委譲とダッシュボード更新に深い推論は不要 |
| プロンニア/Pulonia（執事） | デフォルト | 有効       | タスク分配には慎重な判断が必要           |
| ボスコ/Bosco（機動兵）     | デフォルト | 有効       | 実装作業にはフル機能が必要               |

傀儡/KAIRAI（執行官）は `MAX_THINKING_TOKENS=0` で拡張思考を無効化し、高レベルな判断にはOpusの能力を維持しつつ、レイテンシとコストを削減。

---

## 🎯 設計思想

### なぜ階層構造（傀儡/KAIRAI（執行官）→プロンニア/Pulonia（執事）→ボスコ/Bosco（機動兵））なのか

1. **単一責任**: 各役割が明確に分離され、混乱しない
2. **スケーラビリティ**: ボスコ/Bosco（機動兵）を増やしても構造が崩れない
3. **障害分離**: 1体のボスコ/Bosco（機動兵）が失敗しても他に影響しない
4. **人間への報告一元化**: 傀儡/KAIRAI（執行官）だけが人間とやり取りするため、情報が整理される

### なぜ YAML + send-keys なのか

1. **ポーリング不要**: イベント駆動でAPIコストを削減
2. **状態の永続化**: YAMLファイルでタスク状態を追跡可能
3. **デバッグ容易**: 人間がYAMLを直接読んで状況把握できる
4. **競合回避**: 各ボスコ/Bosco（機動兵）に専用ファイルを割り当て

### なぜ dashboard.md はプロンニア/Pulonia（執事）のみが更新するのか

1. **単一更新者**: 競合を防ぐため、更新責任者を1人に限定
2. **情報集約**: プロンニア/Pulonia（執事）は全ボスコ/Bosco（機動兵）の報告を受ける立場なので全体像を把握
3. **割り込み防止**: 傀儡/KAIRAI（執行官）が更新すると、旅人の入力中に割り込む恐れあり

---

## 🛠️ スキル

初期状態ではスキルはありません。
運用中にダッシュボード（dashboard.md）の「スキル化候補」から承認して増やしていきます。

スキルは `/スキル名` で呼び出し可能。傀儡/KAIRAI（執行官）に「/スキル名 を実行」と伝えるだけ。

### スキルの思想

**1. スキルはコミット対象外**

`.claude/commands/` 配下のスキルはリポジトリにコミットしない設計。理由：

- 各ユーザの業務・ワークフローは異なる
- 汎用的なスキルを押し付けるのではなく、ユーザが自分に必要なスキルを育てていく

**2. スキル取得の手順**

```
ボスコ/Bosco（機動兵）が作業中にパターンを発見
    ↓
dashboard.md の「スキル化候補」に上がる
    ↓
旅人（あなた）が内容を確認
    ↓
承認すればプロンニア/Pulonia（執事）に指示してスキルを作成
```

スキルはユーザ主導で増やすもの。自動で増えると管理不能になるため、「これは便利」と判断したものだけを残す。

---

## 🔌 MCPセットアップガイド

MCP（Model Context Protocol）サーバはClaudeの機能を拡張します。セットアップ方法：

### MCPとは？

MCPサーバはClaudeに外部ツールへのアクセスを提供します：

- **Notion MCP** → Notionページの読み書き
- **GitHub MCP** → PR作成、Issue管理
- **Memory MCP** → セッション間で記憶を保持

### MCPサーバのインストール

以下のコマンドでMCPサーバを追加：

```bash
# 1. Notion - Notionワークスペースに接続
claude mcp add notion -e NOTION_TOKEN=your_token_here -- npx -y @notionhq/notion-mcp-server

# 2. Playwright - ブラウザ自動化
claude mcp add playwright -- npx @playwright/mcp@latest
# 注意: 先に `npx playwright install chromium` を実行してください

# 3. GitHub - リポジトリ操作
claude mcp add github -e GITHUB_PERSONAL_ACCESS_TOKEN=your_pat_here -- npx -y @modelcontextprotocol/server-github

# 4. Sequential Thinking - 複雑な問題を段階的に思考
claude mcp add sequential-thinking -- npx -y @modelcontextprotocol/server-sequential-thinking

# 5. Memory - セッション間の長期記憶（推奨！）
claude mcp add memory -e MEMORY_FILE_PATH="$PWD/memory/kairai_memory.jsonl" -- npx -y @modelcontextprotocol/server-memory
```

### インストール確認

```bash
claude mcp list
```

全サーバが「Connected」ステータスで表示されるはずです。

---

## 🌍 実用例

### 例1: 調査タスク

```
あなた: 「AIコーディングアシスタント上位5つを調査して比較せよ」

実行される処理:
1. 傀儡/KAIRAI（執行官）がプロンニア/Pulonia（執事）に委譲
2. プロンニア/Pulonia（執事）が割り当て:
   - ボスコ/Bosco（機動兵）1: GitHub Copilotを調査
   - ボスコ/Bosco（機動兵）2: Cursorを調査
   - ボスコ/Bosco（機動兵）3: Claude Codeを調査
   - ボスコ/Bosco（機動兵）4: Codeiumを調査
   - ボスコ/Bosco（機動兵）5: Amazon CodeWhispererを調査
3. 5体が同時に調査
4. 結果がdashboard.mdに集約
```

### 例2: PoC準備

```
あなた: 「このNotionページのプロジェクトでPoC準備: [URL]」

実行される処理:
1. プロンニア/Pulonia（執事）がMCP経由でNotionコンテンツを取得
2. ボスコ/Bosco（機動兵）2: 確認すべき項目をリスト化
3. ボスコ/Bosco（機動兵）3: 技術的な実現可能性を調査
4. ボスコ/Bosco（機動兵）4: PoC計画書を作成
5. 全結果がdashboard.mdに集約、会議の準備完了
```

---

## ⚙️ 設定

### 言語設定

`config/settings.yaml` を編集：

```yaml
language: ja   # 日本語のみ
language: en   # 日本語 + 英訳併記
```

---

## 🛠️ 上級者向け

<details>
<summary><b>スクリプトアーキテクチャ</b>（クリックで展開）</summary>

```
┌─────────────────────────────────────────────────────────────────────┐
│                      初回セットアップ（1回だけ実行）                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  install.bat (Windows)                                              │
│      │                                                              │
│      ├── WSL2のチェック/インストール案内                              │
│      └── Ubuntuのチェック/インストール案内                            │
│                                                                     │
│  first_setup.sh (Ubuntu/WSLで手動実行)                               │
│      │                                                              │
│      ├── tmuxのチェック/インストール                                  │
│      ├── Node.js v20+のチェック/インストール (nvm経由)                │
│      └── Claude Code CLIのチェック/インストール                      │
│                                                                     │
├─────────────────────────────────────────────────────────────────────┤
│                      毎日の起動（毎日実行）                           │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  mission_start.sh                                             │
│      │                                                              │
│      ├──▶ tmuxセッションを作成                                       │
│      │         • "kairai"セッション（1ペイン）                        │
│      │         • "multiagent"セッション（9ペイン、3x3グリッド）        │
│      │                                                              │
│      ├──▶ キューファイルとダッシュボードをリセット                     │
│      │                                                              │
│      └──▶ 全エージェントでClaude Codeを起動                          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

</details>

<details>
<summary><b>mission_start.sh オプション</b>（クリックで展開）</summary>

```bash
# デフォルト: フル起動（tmuxセッション + Claude Code起動）
./mission_start.sh

# セッションセットアップのみ（Claude Code起動なし）
./mission_start.sh -s
./mission_start.sh --setup-only

# フル起動 + Windows Terminalタブを開く
./mission_start.sh -t
./mission_start.sh --terminal

# ヘルプを表示
./mission_start.sh -h
./mission_start.sh --help
```

</details>

<details>
<summary><b>よく使うワークフロー</b>（クリックで展開）</summary>

**通常の毎日の使用：**

```bash
./mission_start.sh          # 全て起動
tmux attach-session -t kairai     # 接続してコマンドを出す
```

**デバッグモード（手動制御）：**

```bash
./mission_start.sh -s       # セッションのみ作成

# 特定のエージェントでClaude Codeを手動起動
tmux send-keys -t kairai:0 'claude --dangerously-skip-permissions' Enter
tmux send-keys -t multiagent:0.0 'claude --dangerously-skip-permissions' Enter
```

**クラッシュ後の再起動：**

```bash
# 既存セッションを終了
tmux kill-session -t kairai
tmux kill-session -t multiagent

# 新しく起動
./mission_start.sh
```

</details>

<details>
<summary><b>便利なエイリアス</b>（クリックで展開）</summary>

`first_setup.sh` を実行すると、以下のエイリアスが `~/.zshrc` に自動追加されます：

```bash
alias css='cd /mnt/c/tools/multi-agent-kairai && ./mission_start.sh'  # セットアップ+任務開始
alias csm='cd /mnt/c/tools/multi-agent-kairai'                              # ディレクトリ移動のみ
```

※ エイリアスを反映するには `source ~/.zshrc` を実行するか、PowerShellで `wsl --shutdown` してからターミナルを開き直してください。

</details>

---

## 📁 ファイル構成

<details>
<summary><b>クリックでファイル構成を展開</b></summary>

```
multi-agent-kairai/
│
│  ┌─────────────────── セットアップスクリプト ───────────────────┐
├── install.bat               # Windows: 初回セットアップ
├── first_setup.sh            # Ubuntu/Mac: 初回セットアップ
├── mission_start.sh    # 毎日の起動（指示書自動読み込み）
│  └────────────────────────────────────────────────────────────┘
│
├── instructions/             # エージェント指示書
│   ├── kairai.md             # 傀儡/KAIRAI（執行官）の指示書
│   ├── pulonia.md               # プロンニア/Pulonia（執事）の指示書
│   └── bosco.md           # ボスコ/Bosco（機動兵）の指示書
│
├── config/
│   └── settings.yaml         # 言語その他の設定
│
├── queue/                    # 通信ファイル
│   ├── kairai_to_pulonia.yaml   # 傀儡/KAIRAI（執行官）からプロンニア/Pulonia（執事）へのコマンド
│   ├── tasks/                # 各ワーカーのタスクファイル
│   └── reports/              # ワーカーレポート
│
├── memory/                   # Memory MCP保存場所
├── dashboard.md              # リアルタイム状況一覧
└── CLAUDE.md                 # Claude用プロジェクトコンテキスト
```

</details>

---

## 🔧 トラブルシューティング

<details>
<summary><b>MCPツールが動作しない？</b></summary>

MCPツールは「遅延ロード」方式で、最初にロードが必要です：

```
# 間違い - ツールがロードされていない
mcp__memory__read_graph()  ← エラー！

# 正しい - 先にロード
ToolSearch("select:mcp__memory__read_graph")
mcp__memory__read_graph()  ← 動作！
```

</details>

<details>
<summary><b>エージェントが権限を求めてくる？</b></summary>

`--dangerously-skip-permissions` 付きで起動していることを確認：

```bash
claude --dangerously-skip-permissions --system-prompt "..."
```

</details>

<details>
<summary><b>ワーカーが停止している？</b></summary>

ワーカーのペインを確認：

```bash
tmux attach-session -t multiagent
# Ctrl+B の後に数字でペインを切り替え
```

</details>

---

## 📚 tmux クイックリファレンス

| コマンド                          | 説明                                  |
| --------------------------------- | ------------------------------------- |
| `tmux attach -t kairai`           | 傀儡/KAIRAI（執行官）に接続           |
| `tmux attach -t multiagent`       | ワーカーに接続                        |
| `Ctrl+B` の後 `0-8`               | ペイン間を切り替え                    |
| `Ctrl+B` の後 `d`                 | デタッチ（実行継続）                  |
| `tmux kill-session -t kairai`     | 傀儡/KAIRAI（執行官）セッションを停止 |
| `tmux kill-session -t multiagent` | ワーカーセッションを停止              |

---

## 🙏 クレジット

[Claude-Code-Communication](https://github.com/Akira-Papa/Claude-Code-Communication) by Akira-Papa をベースに開発。

---

## 📄 ライセンス

MIT License - 詳細は [LICENSE](LICENSE) を参照。

---

<div align="center">

**AIの軍勢を統率せよ。より速く構築せよ。**

</div>
