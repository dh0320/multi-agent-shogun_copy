# Gmail Auto Sorter - スキル設計書

> **Version**: 1.0.0
> **Author**: ashigaru2 (System Architect)
> **Created**: 2026-02-11
> **Status**: Draft
> **Priority**: 高

---

## 1. スキル名

**gmail-auto-sorter**

```yaml
name: gmail-auto-sorter
description: Gmail MCP Server経由で条件ベースの自動振り分けルールを設定・管理する。受信メールを差出人、件名、本文キーワード等で判定し、ラベル割当・アーカイブ・既読化を自動実行。
```

---

## 2. 目的・概要

### 解決する課題

Gmailの手動振り分けは以下の問題を抱える：

1. **ルール設定の煩雑さ**: GmailのフィルタUIは複雑で設定に時間がかかる
2. **条件の可視化困難**: 既存フィルタの一覧化・編集が面倒
3. **複雑な条件の実現困難**: AND/OR/NOTの組み合わせが直感的でない
4. **ルールの再利用性なし**: 類似ルールを複製・カスタマイズしにくい

### 本スキルの提供価値

- **宣言的なルール記述**: YAML形式で条件とアクションを明確に定義
- **ルールのバージョン管理**: Git管理可能な形式でルールを保存
- **テンプレート機能**: 頻出パターンのテンプレートを提供
- **ドライラン**: 実際に適用する前にマッチ結果を確認
- **一括管理**: 複数ルールを一度にインポート/エクスポート

---

## 3. 入力（引数）

### サブコマンド

| サブコマンド | 説明 |
|-------------|------|
| `list` | 振り分けルール一覧表示 |
| `add` | 新規ルール追加 |
| `edit` | 既存ルール編集 |
| `delete` | ルール削除 |
| `test` | ルールのドライラン |
| `apply` | ルールを適用（既存メールに遡って適用） |
| `export` | ルールをYAMLファイルにエクスポート |
| `import` | YAMLファイルからルールをインポート |

### 3.1 `list` サブコマンド

```bash
/gmail-auto-sorter list [OPTIONS]
```

| オプション | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `--filter` | string | なし | ルール名でフィルタ |
| `--output` | string | `terminal` | 出力形式: `terminal`, `json`, `yaml` |

**使用例**:
```bash
# 全ルール一覧
/gmail-auto-sorter list

# "work"を含むルールのみ
/gmail-auto-sorter list --filter work
```

### 3.2 `add` サブコマンド

```bash
/gmail-auto-sorter add [OPTIONS]
```

| オプション | 型 | 必須 | 説明 |
|-----------|-----|------|------|
| `--name` | string | 必須 | ルール名 |
| `--from` | string | * | 差出人条件 |
| `--to` | string | * | 宛先条件 |
| `--subject` | string | * | 件名条件（部分一致） |
| `--body` | string | * | 本文条件（部分一致） |
| `--has-attachment` | boolean | 任意 | 添付ファイルの有無 |
| `--label` | string | ** | 適用するラベル名 |
| `--archive` | boolean | ** | アーカイブする |
| `--mark-read` | boolean | ** | 既読にする |
| `--star` | boolean | ** | スターを付ける |

*: 条件は最低1つ必須
**: アクションは最低1つ必須

**使用例**:
```bash
# 上司からのメールを「重要」ラベルに
/gmail-auto-sorter add --name "上司メール" --from "boss@example.com" --label "重要" --star true

# ニュースレターを自動アーカイブ
/gmail-auto-sorter add --name "ニュースレター" --from "newsletter@example.com" --archive true --mark-read true

# 件名に"請求書"を含むメールをラベル付け
/gmail-auto-sorter add --name "請求書" --subject "請求書" --label "経理/請求書"
```

### 3.3 `test` サブコマンド

```bash
/gmail-auto-sorter test RULE_NAME [OPTIONS]
```

| 引数/オプション | 型 | 必須 | 説明 |
|---------------|-----|------|------|
| `RULE_NAME` | string | 必須 | テストするルール名 |
| `--limit` | number | `10` | 検索対象メール数の上限 |
| `--period` | string | `7d` | 検索期間（例: `7d`, `1m`, `1y`） |

**使用例**:
```bash
# ルールのドライラン（過去7日間のメールで検証）
/gmail-auto-sorter test "上司メール"

# 過去30日間で検証
/gmail-auto-sorter test "ニュースレター" --period 30d
```

### 3.4 `apply` サブコマンド

```bash
/gmail-auto-sorter apply RULE_NAME [OPTIONS]
```

| 引数/オプション | 型 | 必須 | 説明 |
|---------------|-----|------|------|
| `RULE_NAME` | string | 必須 | 適用するルール名 |
| `--period` | string | `7d` | 適用期間（例: `7d`, `1m`, `all`） |
| `--confirm` | boolean | `false` | 確認なしで適用 |

**使用例**:
```bash
# 過去7日間のメールにルールを適用
/gmail-auto-sorter apply "上司メール"

# 全メールに適用（注意）
/gmail-auto-sorter apply "ニュースレター" --period all --confirm
```

### 3.5 `export` / `import` サブコマンド

```bash
/gmail-auto-sorter export [--output FILE]
/gmail-auto-sorter import --file FILE
```

**使用例**:
```bash
# ルールをYAMLファイルにエクスポート
/gmail-auto-sorter export --output ~/gmail-rules.yaml

# YAMLファイルからインポート
/gmail-auto-sorter import --file ~/gmail-rules.yaml
```

---

## 4. 出力（結果）

### 4.1 `list` 出力例

```
============================================
   Gmail Auto-Sorter Rules
   Total: 5 rules
============================================

📌 上司メール (active)
   条件: from:boss@example.com
   アクション: label:"重要", star:true

📌 ニュースレター (active)
   条件: from:newsletter@example.com
   アクション: archive:true, mark-read:true

📌 請求書 (active)
   条件: subject:"請求書"
   アクション: label:"経理/請求書"

📌 プロジェクトA (paused)
   条件: subject:"ProjectA"
   アクション: label:"仕事/プロジェクトA"
```

### 4.2 `test` 出力例

```
============================================
   Dry Run: "上司メール"
   Period: Past 7 days
============================================

マッチ件数: 12件

サンプル（最初の5件）:
  [✓] 2026-02-10 15:30 | boss@example.com | プロジェクト進捗確認
  [✓] 2026-02-09 09:15 | boss@example.com | 月次報告の提出期限について
  [✓] 2026-02-08 14:20 | boss@example.com | 来週のミーティング日程
  [✓] 2026-02-07 11:45 | boss@example.com | 予算承認の件
  [✓] 2026-02-06 16:00 | boss@example.com | 新規プロジェクト提案

適用予定のアクション:
  - ラベル: "重要"
  - スター: ON

実行する場合: /gmail-auto-sorter apply "上司メール"
```

### 4.3 `apply` 出力例

```
✅ ルール適用完了
  - ルール名: "上司メール"
  - 対象期間: 過去7日間
  - 適用件数: 12件

処理詳細:
  - ラベル付与: 12件
  - スター付与: 12件
```

---

## 5. ルール定義形式（YAML）

### 5.1 ルールファイルの例

```yaml
# ~/gmail-rules.yaml
rules:
  - name: "上司メール"
    enabled: true
    conditions:
      from: "boss@example.com"
    actions:
      label: "重要"
      star: true

  - name: "ニュースレター"
    enabled: true
    conditions:
      from: "newsletter@example.com"
    actions:
      archive: true
      mark_read: true

  - name: "請求書"
    enabled: true
    conditions:
      subject: "請求書"
    actions:
      label: "経理/請求書"

  - name: "プロジェクトA"
    enabled: false  # 一時停止
    conditions:
      subject: "ProjectA"
      has_attachment: true
    actions:
      label: "仕事/プロジェクトA"
      star: true
```

### 5.2 複雑な条件の例

```yaml
rules:
  - name: "重要顧客からの緊急メール"
    enabled: true
    conditions:
      any_of:  # OR条件
        - from: "vip1@example.com"
        - from: "vip2@example.com"
      all_of:  # AND条件
        - subject: "緊急"
        - has_attachment: true
      none_of:  # NOT条件
        - body: "自動送信"
    actions:
      label: "重要/VIP"
      star: true
      notify: true  # (将来拡張: ntfy通知)
```

---

## 6. 技術仕様

### 6.1 使用MCP Server

- **Gmail MCP Server** (推奨: GongRzhe/Gmail-MCP-Server)

### 6.2 必要なMCPツール

| MCP関数 | 用途 |
|---------|------|
| `mcp__gmail__search_messages` | 条件マッチング |
| `mcp__gmail__modify_message` | ラベル・フラグ変更 |
| `mcp__gmail__list_labels` | ラベル存在確認 |

### 6.3 ルール保存場所

- **デフォルト**: `~/.multi-agent-shogun/gmail-rules.yaml`
- Git管理推奨（個人情報に注意）

---

## 7. 実装方針

### 7.1 条件マッチングアルゴリズム

1. 条件をGmail検索クエリに変換
2. `mcp__gmail__search_messages` で対象メールを取得
3. 取得結果にアクションを適用

### 7.2 安全性の確保

- **ドライラン必須**: 初回は必ずtestコマンドで確認
- **部分適用**: 一度に大量のメールを処理しない（100件ずつ）
- **ログ記録**: 適用履歴をログファイルに保存

---

## 8. 今後の拡張案

- **AI条件判定**: Claude APIで本文を分析し、ラベルを自動判定
- **スケジュール実行**: cron連携で定期的に自動振り分け
- **通知連携**: マッチ時にntfy経由でスマホ通知
- **統計レポート**: ルールごとの適用件数推移

---

## 9. 関連スキル

- **gmail-label-manager**: 本スキルで使用するラベルを事前作成
- **gmail-search-assistant**: 検索結果をルール条件に変換
