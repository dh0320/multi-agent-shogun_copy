# Gmail Label Manager - スキル設計書

> **Version**: 1.0.0
> **Author**: ashigaru2 (System Architect)
> **Created**: 2026-02-11
> **Status**: Draft
> **Priority**: 高

---

## 1. スキル名

**gmail-label-manager**

```yaml
name: gmail-label-manager
description: Gmail MCP Server経由でラベルの一覧表示・作成・削除・割当操作を実行する。メール整理、自動分類の前処理、ラベル体系の整備に使用。
```

---

## 2. 目的・概要

### 解決する課題

Gmailのラベル管理を手動で行うと以下の問題が発生：

1. **ラベル体系の把握困難**: 既存ラベルの一覧化・階層構造の可視化が面倒
2. **一括操作の非効率**: 複数ラベルの作成・削除を手動で行うと時間がかかる
3. **ラベル割当の煩雑さ**: メールへのラベル付与をGUI操作で行うと手間
4. **命名規則の不統一**: ラベル名の一貫性を保つのが困難

### 本スキルの提供価値

- **一覧表示**: 全ラベルを階層構造で可視化、検索・フィルタリング可能
- **一括作成**: 複数ラベルを一度に作成、命名規則の統一
- **安全な削除**: ラベル削除前に影響範囲を確認、誤削除防止
- **効率的な割当**: メールIDまたは検索条件でラベルを一括割当

---

## 3. 入力（引数）

### サブコマンド

| サブコマンド | 説明 |
|-------------|------|
| `list` | ラベル一覧表示 |
| `create` | ラベル作成 |
| `delete` | ラベル削除 |
| `assign` | メールにラベルを割当 |
| `remove` | メールからラベルを削除 |

### 3.1 `list` サブコマンド

```bash
/gmail-label-manager list [OPTIONS]
```

| オプション | 型 | デフォルト | 説明 |
|-----------|-----|----------|------|
| `--filter` | string | なし | ラベル名でフィルタ（部分一致） |
| `--hierarchy` | boolean | `true` | 階層構造で表示 |
| `--output` | string | `terminal` | 出力形式: `terminal`, `json`, `tree` |

**使用例**:
```bash
# 全ラベル一覧
/gmail-label-manager list

# "work"を含むラベルのみ
/gmail-label-manager list --filter work

# フラットリスト形式
/gmail-label-manager list --hierarchy false
```

### 3.2 `create` サブコマンド

```bash
/gmail-label-manager create LABEL_NAME [OPTIONS]
```

| 引数/オプション | 型 | 必須 | 説明 |
|---------------|-----|------|------|
| `LABEL_NAME` | string | 必須 | 作成するラベル名（複数可、カンマ区切り） |
| `--parent` | string | 任意 | 親ラベル名（階層構造を作成） |
| `--color` | string | 任意 | ラベルカラー |

**使用例**:
```bash
# 単一ラベル作成
/gmail-label-manager create "仕事/プロジェクトA"

# 複数ラベル一括作成
/gmail-label-manager create "仕事/プロジェクトB,仕事/プロジェクトC"

# 階層構造作成
/gmail-label-manager create "サブラベル1" --parent "仕事"
```

### 3.3 `delete` サブコマンド

```bash
/gmail-label-manager delete LABEL_NAME [OPTIONS]
```

| 引数/オプション | 型 | 必須 | 説明 |
|---------------|-----|------|------|
| `LABEL_NAME` | string | 必須 | 削除するラベル名 |
| `--confirm` | boolean | `false` | 確認なしで削除（危険） |
| `--dry-run` | boolean | `false` | 削除をシミュレート（実際には削除しない） |

**使用例**:
```bash
# ドライラン（影響確認）
/gmail-label-manager delete "古いラベル" --dry-run

# 確認付き削除
/gmail-label-manager delete "古いラベル"

# 確認なし削除（注意）
/gmail-label-manager delete "古いラベル" --confirm
```

### 3.4 `assign` サブコマンド

```bash
/gmail-label-manager assign LABEL_NAME [OPTIONS]
```

| 引数/オプション | 型 | 必須 | 説明 |
|---------------|-----|------|------|
| `LABEL_NAME` | string | 必須 | 割り当てるラベル名 |
| `--message-ids` | string[] | * | メールID（カンマ区切り） |
| `--query` | string | * | Gmail検索クエリ |

*: `--message-ids` または `--query` のいずれかが必須

**使用例**:
```bash
# 特定メールにラベル割当
/gmail-label-manager assign "重要" --message-ids "18d1a2b3c4d5e6f7"

# 検索条件でラベル一括割当
/gmail-label-manager assign "仕事" --query "from:boss@example.com is:unread"
```

### 3.5 `remove` サブコマンド

```bash
/gmail-label-manager remove LABEL_NAME [OPTIONS]
```

| 引数/オプション | 型 | 必須 | 説明 |
|---------------|-----|------|------|
| `LABEL_NAME` | string | 必須 | 削除するラベル名 |
| `--message-ids` | string[] | * | メールID（カンマ区切り） |
| `--query` | string | * | Gmail検索クエリ |

**使用例**:
```bash
# 特定メールからラベル削除
/gmail-label-manager remove "未読" --message-ids "18d1a2b3c4d5e6f7"
```

---

## 4. 出力（結果）

### 4.1 `list` 出力例

```
============================================
   Gmail Label List
   Total: 25 labels
============================================

📁 仕事 (12 messages)
  └─ 📁 プロジェクトA (5 messages)
  └─ 📁 プロジェクトB (7 messages)
📁 個人 (8 messages)
  └─ 📁 家族 (3 messages)
  └─ 📁 趣味 (5 messages)
📌 重要 (15 messages)
📌 後で読む (23 messages)
```

### 4.2 `create` 出力例

```
✅ ラベル作成成功
  - 仕事/プロジェクトA
  - 仕事/プロジェクトB

階層構造:
📁 仕事
  └─ 📁 プロジェクトA
  └─ 📁 プロジェクトB
```

### 4.3 `delete` 出力例（dry-run）

```
⚠️ ドライラン: 実際には削除されません

削除対象:
  - ラベル名: "古いラベル"
  - 影響メール数: 5件
  - サブラベル: なし

実行する場合: /gmail-label-manager delete "古いラベル" --confirm
```

### 4.4 `assign` 出力例

```
✅ ラベル割当完了
  - ラベル: "重要"
  - 対象メール数: 12件
  - 検索クエリ: "from:boss@example.com is:unread"
```

---

## 5. 技術仕様

### 5.1 使用MCP Server

- **Gmail MCP Server** (推奨: GongRzhe/Gmail-MCP-Server)
- OAuth2認証経由でGmail APIにアクセス

### 5.2 必要なMCPツール

| MCP関数 | 用途 |
|---------|------|
| `mcp__gmail__list_labels` | ラベル一覧取得 |
| `mcp__gmail__create_label` | ラベル作成 |
| `mcp__gmail__delete_label` | ラベル削除 |
| `mcp__gmail__modify_message` | メールラベル変更 |
| `mcp__gmail__search_messages` | メール検索（query→ID変換） |

### 5.3 エラーハンドリング

| エラーケース | 対処 |
|-------------|------|
| ラベル名重複 | 既存ラベルを表示、上書き確認 |
| ラベル不存在 | エラーメッセージ、類似ラベル提案 |
| Gmail API制限 | リトライ処理、レート制限警告 |
| OAuth2期限切れ | 再認証を促すメッセージ |

---

## 6. 実装方針

### 6.1 階層構造の処理

Gmailのラベルは `/` 区切りで階層を表現（例: `仕事/プロジェクトA`）。本スキルでは：

- 階層を自動解析し、ツリー構造で表示
- 親ラベルが存在しない場合は自動作成を提案

### 6.2 安全性の確保

- **削除前確認**: デフォルトで影響範囲を表示、確認を求める
- **ドライラン**: `--dry-run` で実行前にシミュレーション
- **ロールバック不可の警告**: ラベル削除は元に戻せないことを明示

### 6.3 パフォーマンス最適化

- ラベル一覧はキャッシュ可能（有効期限: 5分）
- 一括操作はバッチAPIを使用
- 大量メール処理時は進捗表示

---

## 7. 今後の拡張案

- **ラベル統計**: ラベルごとのメール数推移グラフ
- **ラベル提案**: メール内容からラベルを自動提案
- **一括リネーム**: 正規表現でラベル名を一括変更
- **テンプレート**: よく使うラベルセットを保存・復元

---

## 8. 関連スキル

- **gmail-auto-sorter**: 本スキルで作成したラベルを使って自動振り分け
- **gmail-search-assistant**: 検索結果にラベルを一括割当
