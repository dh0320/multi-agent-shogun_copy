# context ディレクトリ

プロジェクト固有のコンテキストを管理するディレクトリ。

## 使い方

### 新規プロジェクト追加時
1. `context/{project_id}.md` を作成
2. テンプレート（`templates/context_template.md`）に沿って記載

### 作業開始時
1. `memory/global_context.md` を読む（システム全体の設定）
2. `context/{project_id}.md` を読む（プロジェクト固有情報）
