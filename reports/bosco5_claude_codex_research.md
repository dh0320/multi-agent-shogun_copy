# Claude vs Codex AI 特性調査レポート（Codex 視点）

> **調査者**: ボスコ 5号  
> **タスク ID**: subtask_002_5  
> **調査日**: 2026-02-02

---

## 1. Claude（Anthropic）の特性

### 1.1 得意分野（公開ドキュメントに基づく特徴）

- **長文コンテキスト処理**: Claude Sonnet 4.5 は 200K トークンのコンテキストに加えて、`context-1m-2025-08-07` のベータヘッダー使用時に 1M トークンまで拡張可能です。大規模仕様・長文ドキュメントの取り込みに強みがあります。  
  参考: https://platform.claude.com/docs/en/about-claude/models/overview
- **モデル選択の幅**: Sonnet（バランス）、Haiku（高速）、Opus（高性能）といったラインで提供され、用途とコストに応じて選択しやすい設計です。  
  参考: https://platform.claude.com/docs/en/about-claude/models/overview
- **テキスト + 画像入力、マルチリンガル**: 現行モデルは text と image の入力、text 出力、multilingual と vision をサポートしています。  
  参考: https://platform.claude.com/docs/en/about-claude/models/overview

### 1.2 不得意分野・制限事項（API 制約）

- **長文コンテキストの制約**: 1M コンテキストは Sonnet 4/4.5 のみ対象かつベータ提供で、200K 超の入力は long context 料金が適用されます。  
  参考: https://platform.claude.com/docs/en/about-claude/models/overview
  参考: https://platform.claude.com/docs/en/about-claude/pricing
- **レート制限/利用制限**: 使用 Tier に応じて RPM・ITPM・OTPM が設定され、上限超過で 429 エラーが発生します。月次の支出上限も Tier で管理されます。  
  参考: https://platform.claude.com/docs/en/api/rate-limits

### 1.3 コスト特性（API）

- **モデル別トークン課金**: 例として Claude Opus 4.5 は入力 $5 / MTok、出力 $25 / MTok。Claude Sonnet 4.5 は入力 $3 / MTok、出力 $15 / MTok。Claude Haiku 4.5 は入力 $1 / MTok、出力 $5 / MTok。  
  参考: https://platform.claude.com/docs/en/about-claude/pricing
- **プロンプトキャッシュ**: 5 分/1 時間のキャッシュ書き込み倍率と、キャッシュ読取 0.1 倍の価格が明示されています。  
  参考: https://platform.claude.com/docs/en/about-claude/pricing
- **Batch API 割引**: バッチ処理は入出力ともに 50% 割引。  
  参考: https://platform.claude.com/docs/en/about-claude/pricing

---

## 2. Codex（OpenAI）の特性

### 2.1 得意分野（Codex 視点の強み）

- **ソフトウェアエンジニアリング特化のエージェント**: Codex はクラウド上の隔離サンドボックスにリポジトリを読み込み、機能追加・バグ修正・コードベース質問応答・PR 提案などのタスクを並行処理できます。タスク内でファイルの読み書きやコマンド実行（テスト等）も可能です。  
  参考: https://openai.com/index/introducing-codex/
- **ローカル統合（Codex CLI）**: Codex CLI はローカル端末で動作し、選択ディレクトリ内のコードを読み込み・変更・実行できます。  
  参考: https://developers.openai.com/codex/cli
- **低レイテンシ指向のミニモデル**: codex-mini-latest は Codex CLI 向けに最適化された fast reasoning model として提供され、200K のコンテキストウィンドウを持ちます。  
  参考: https://platform.openai.com/docs/models/codex-mini-latest

### 2.2 不得意分野・制限事項

- **研究プレビュー段階の制限**: OpenAI は Codex を research preview と位置づけ、公開時点では「frontend 向け image 入力」や「作業中の course-correct（途中介入）」が不足していると明記しています。また、リモートのエージェント委譲はインタラクティブ編集より遅く感じられる場合があります。  
  参考: https://openai.com/index/introducing-codex/
- **API レート制限**: GPT-5-Codex は Tier ごとに RPM・TPM 上限が設定されています。  
  参考: https://platform.openai.com/docs/models/gpt-5-codex/

### 2.3 API 制限・コスト特性

- **GPT-5-Codex 料金**: 入力 $1.25 / 1M tokens、キャッシュ入力 $0.125 / 1M tokens、出力 $10.00 / 1M tokens。  
  参考: https://platform.openai.com/docs/models/gpt-5-codex/
- **codex-mini-latest 料金**: Responses API で利用可能。入力 $1.50 / 1M tokens、キャッシュ入力 $0.375 / 1M tokens、出力 $6 / 1M tokens。  
  参考: https://platform.openai.com/docs/models/codex-mini-latest
  参考: https://openai.com/index/introducing-codex/
- **Tier ベースのレート制限**: GPT-5-Codex は Tier に応じて RPM・TPM が変動します。  
  参考: https://platform.openai.com/docs/models/gpt-5-codex/

---

## 3. Codex 視点の比較サマリー（要点）

- **長文コンテキスト重視なら Claude**: Sonnet 4.5 の 200K / 1M（ベータ）対応と long-context 料金体系が明示されており、長文仕様の解析に向く一方でコスト増に注意が必要です。  
  参考: https://platform.claude.com/docs/en/about-claude/models/overview
  参考: https://platform.claude.com/docs/en/about-claude/pricing
- **実装・修正・テスト中心なら Codex**: Codex はクラウド隔離環境でコード編集とコマンド実行が可能、Codex CLI ではローカルでの読解・修正・実行ができ、実装ワークフローに直結します。  
  参考: https://openai.com/index/introducing-codex/
  参考: https://developers.openai.com/codex/cli
- **コスト設計の違い**: Claude はモデルごとの固定単価 + キャッシュ/バッチ割引。Codex は GPT-5-Codex と codex-mini-latest を使い分けることで速度とコストの調整が可能です。  
  参考: https://platform.claude.com/docs/en/about-claude/pricing
  参考: https://platform.openai.com/docs/models/gpt-5-codex/
  参考: https://openai.com/index/introducing-codex/

---

## 参考情報源

- Anthropic Claude モデル概要: https://platform.claude.com/docs/en/about-claude/models/overview
- Anthropic Claude 料金: https://platform.claude.com/docs/en/about-claude/pricing
- Anthropic API レート制限: https://platform.claude.com/docs/en/api/rate-limits
- OpenAI Codex 紹介: https://openai.com/index/introducing-codex/
- OpenAI GPT-5-Codex モデル: https://platform.openai.com/docs/models/gpt-5-codex/
- OpenAI codex-mini-latest モデル: https://platform.openai.com/docs/models/codex-mini-latest
- OpenAI Codex CLI: https://developers.openai.com/codex/cli
