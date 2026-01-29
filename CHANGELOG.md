# Changelog

このプロジェクトのすべての重要な変更を記録します。
フォーマットは [Keep a Changelog](https://keepachangelog.com/ja/1.1.0/) に準拠し、
バージョニングは [Semantic Versioning](https://semver.org/lang/ja/) に従います。

## [Unreleased]

### Added
- `install.sh` を統合: curl ワンライナーとローカル実行の両方に対応
- README.md のインストール手順を curl ワンライナーに一本化

## [2.0.1] - 2026-01-29

### Added
- CONTRIBUTING.md にブランチ戦略を記載
- CHANGELOG.md を追加
- main ブランチ保護（PRレビュー1名必須、管理者にも適用）
- develop ブランチを作成

### Changed
- README.md を日本語版に統一、README_ja.md を削除

## [2.0.0] - 2026-01-29

### Changed
- multi-agent-shogun から uesama にリネーム
- デプロイ対象ファイルを `.uesama/` と `.claude/` に分離
- コンテキストテンプレートを `templates/` に移動
- 不要な CLAUDE.md を削除、install.sh とパス参照を修正
