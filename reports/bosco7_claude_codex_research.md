# Claude と Codex の推奨振り分けパターン調査（Codex 視点）

> **調査者**: ボスコ 7 号
> **タスクID**: subtask_002_7
> **調査日**: 2026-02-02

---

## 1. 最新情報（根拠の要約）

- Codex CLI はコード生成・修正・レビュー、コマンド実行、Web Search などを統合した開発向け CLI として提供されている。Web Search は `live` と `cached` のモードがあり、最新情報が必要な場合は `live` を推奨とされる。 
- Codex CLI には承認モード（例: `suggest` / `auto`) があり、変更適用の自動化やレビュー中心運用の切り替えが可能。 
- Claude Code はデフォルトで read-only から開始し、必要時のみ書き込みやコマンド実行を許可する設計。許可はディレクトリ単位で管理でき、セキュリティと意図しない変更の抑制を重視している。 

（出典は末尾参照）

---

## 2. 推奨される振り分けパターン

### 2.1 基本原則

- **Claude**: 仕様理解、長文ドキュメント、全体設計、レビュー、リスク分析
- **Codex**: 実装、リファクタ、テスト実行、ビルド・検証、CLI 操作が必要な作業

### 2.2 タスク種別の判断マトリクス

| タスク種別 | 推奨担当 | 理由 |
| --- | --- | --- |
| 要件解釈・仕様整理 | Claude | 長文読解と自然言語の整合性評価に強い |
| アーキテクチャ設計 | Claude | 俯瞰的な構造化と設計レビューに適合 |
| 具体実装・修正 | Codex | リポジトリ操作・パッチ作成・テスト実行が得意 |
| 既存コードの局所修正 | Codex | コマンド実行と編集が一連で可能 |
| コードレビュー | Claude → Codex | Claude が設計観点で評価し、Codex が修正反映 |
| CI 失敗対応 | Codex | 端末操作で再現・修正が可能 |
| 最新情報の調査 | Codex（Web Search live）+ Claude（統合） | Codex で取得し Claude で整理 |

---

## 3. 並列作業時の組み合わせ方

### 3.1 推奨パターン

1. **Plan / Implement**
   - Claude が仕様・設計方針を提示
   - Codex が実装・テストを実施

2. **Research / Execute**
   - Codex が Web Search を使い最新情報を取得（`live`）
   - Claude が要約・方針化して指示を出す

3. **Review / Fix**
   - Claude が設計・品質観点のレビュー
   - Codex が修正パッチを適用

### 3.2 並列時の注意点

- **ファイル分割**: 同一ファイルへの同時書き込みを避ける
- **インターフェース合意**: 変更対象・関数シグネチャを先に固定
- **承認モード統一**: Codex CLI の `suggest` / `auto` をタスクに応じて明示

---

## 4. ハイブリッド運用のベストプラクティス

### 4.1 Claude + Codex の相互補完シナリオ

- **Claude → Codex**: 設計方針、品質基準、受け入れ条件を提示
- **Codex → Claude**: 実装結果、テストログ、差分要約を返却

### 4.2 セキュリティと品質のための運用ルール

- **Claude Code は read-only 開始を前提**: 必要時のみ書き込み許可
- **Codex CLI は `suggest` をデフォルト**: 変更内容のレビューを前提
- **Web Search は live を明示**: 最新情報が必要な調査のみ live
- **差分粒度の管理**: Codex で大規模パッチを作る前に Claude に設計確認

---

## 5. 典型シナリオ別の配分例

| シナリオ | Claude | Codex |
| --- | --- | --- |
| 大規模リファクタ | リスク分析・方針策定 | 変更の実施・テスト |
| 仕様追加 | 要件整理・影響範囲特定 | 実装・既存テスト更新 |
| バグ調査 | 再現手順と原因仮説 | 再現、修正、回帰テスト |
| 最新 API 追随 | 公式情報の読み解き | 実装と検証 |

---

## 6. まとめ（Codex 視点）

- Codex は **実装・検証の実働役** として最適。
- Claude は **設計・レビュー・整理の司令塔** として最適。
- 並列運用では **「Claude が計画 → Codex が実装」** の単方向フローが最も安定。
- 最新情報が必要な調査は Codex の Web Search を活用し、Claude が方針化する。

---

## 参考情報源

- OpenAI Codex CLI Overview（機能・Web Search・承認モード）
  - https://developers.openai.com/codex/cli/
  - https://developers.openai.com/codex/cli/features/
- OpenAI Codex CLI Web Search（live/cached）
  - https://developers.openai.com/codex/cli/web-search/
- Anthropic Claude Code Security & Permissions（read-only と許可管理）
  - https://docs.anthropic.com/en/docs/claude-code/security
  - https://docs.anthropic.com/en/docs/claude-code/permissions
