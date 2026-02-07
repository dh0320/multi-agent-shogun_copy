# multi-branch-pr-creator

## 概要
複数ブランチに散らばった未コミットの変更を、ブランチ別に振り分けてコミット・プッシュ・PR作成を一括実行するスキル。stash復元、ブランチ切り替え、ファイル振り分け、PR作成までを順次自動化する。

## 使用場面
- 複数の足軽がドキュメントを修正したが未コミットの状態をまとめてPR化する時
- 1つのstashに複数ブランチ分の変更が混在している時
- 大量のファイル変更をカテゴリ別ブランチに分けてPR化する時
- マルチエージェント開発で各エージェントの成果物を一括管理する時

## トリガーワード
- 「複数ブランチPR作成」「一括PR」「ブランチ振り分け」
- 「stash復元してPR」「未コミット変更をPR化」
- 「ドキュメント一括PR」「カテゴリ別PR」

## 前提条件
- 対象リポジトリにアクセスできること
- `gh` CLI がインストール・認証済みであること
- 各featureブランチが既に作成されていること（またはベースブランチから作成可能）
- 変更がstashまたはワーキングディレクトリに存在すること

## 手順

### Phase 1: 現状把握

1. 変更の所在を確認する
```bash
# stashに変更があるか確認
git stash list

# stashの中身を確認（popせずに）
git stash show stash@{0} --stat

# 現在のワーキングディレクトリの変更を確認
git status --short

# 全ブランチのdevelopとの差分を確認
for branch in feature/branch-1 feature/branch-2; do
  echo "=== $branch ==="
  git log develop..$branch --oneline
done
```

2. ブランチ別ファイルマッピングを作成する
```markdown
| ブランチ | 対象ファイル |
|---------|-------------|
| feature/docs-update-requirements | docs/requirements.md, docs/implementation_plan.md |
| feature/docs-update-technical | docs/api-specification.md, docs/database-design.md |
| feature/docs-update-ops | docs/deployment-guide.md, docs/operation-manual.md |
```

### Phase 2: stash復元（必要な場合）

```bash
# stashがある場合、適切なブランチでpop
git checkout <最初のブランチ>
git stash pop stash@{0}

# popに失敗した場合（コンフリクト）
git stash pop --index stash@{0}
# または applyで非破壊的に適用
git stash apply stash@{0}
```

**注意**: stash popは一度だけ実行。pop後は変更がワーキングディレクトリに展開される。

### Phase 3: ブランチ別コミット・プッシュ・PR作成

各ブランチについて以下を順次実行する:

```bash
# 1. ブランチに切り替え
git checkout <branch-name>

# 2. 変更ファイルが持ち越されていることを確認
git status --short
# 注意: 全ブランチが同じbaseコミットなら変更は自動的に持ち越される

# 3. 対象ファイルのみステージング（他のファイルは触らない）
git add <file1> <file2> ...

# 4. コミット
git commit -m "<commit-message>"

# 5. プッシュ
git push origin <branch-name>

# 6. PR作成
gh pr create --base develop --title "<PR title>" --body "<PR body>"

# 7. 次のブランチへ（残りの変更は自動的に持ち越される）
```

### Phase 4: 最終確認

```bash
# 全PRが作成されたか確認
gh pr list --state open --author @me

# ワーキングディレクトリがクリーンか確認
git status --short
# クリーンでなければ残りファイルの確認が必要
```

## チェックリスト

### 事前確認
- [ ] 変更の所在を特定した（stash / ワーキングディレクトリ / 既にコミット済み）
- [ ] ブランチ別ファイルマッピングを作成した
- [ ] 全ブランチが存在する（または作成した）
- [ ] baseブランチ（develop等）が最新である

### 各ブランチの処理
- [ ] ブランチに切り替えた
- [ ] 対象ファイルの変更が存在することを確認した
- [ ] 対象ファイルのみをステージングした（git add で個別指定）
- [ ] コミットメッセージが適切である
- [ ] プッシュが成功した
- [ ] PR作成が成功した（URL記録）

### 最終確認
- [ ] 全PRのURLを記録した
- [ ] ワーキングディレクトリがクリーンである
- [ ] stashが空であるか確認した

## トラブルシューティング

### stash popでコンフリクトが発生する
```bash
# apply で非破壊的に適用（stashは残る）
git stash apply stash@{0}
# コンフリクト解消後
git stash drop stash@{0}
```

### ブランチ切り替え時に変更が消える
全ブランチが同じbaseコミットであれば、未コミットの変更はブランチ切り替え時に持ち越される。異なるbaseの場合は以下の対策:
```bash
# 一時的にstash
git stash
git checkout <target-branch>
git stash pop
```

### git addで意図しないファイルをステージングしてしまった
```bash
# 特定ファイルのステージングを取り消し
git restore --staged <file>
```

### PRのbaseブランチを間違えた
```bash
# ghコマンドでbaseを変更
gh pr edit <pr-number> --base <correct-base>
```

## 参考実装

### NotifyFavoriteTherapistsForLine ドキュメント5ブランチPR化

**状況**: 5人の足軽が5カテゴリのドキュメントを修正。変更はstash@{0}に保存されていた（20ファイル）。

**ブランチ割り当て**:
| ブランチ | ファイル数 | カテゴリ |
|---------|-----------|---------|
| feature/docs-update-requirements | 2 | 要件定義・実装計画 |
| feature/docs-update-technical | 3 | API仕様・DB設計・アーキテクチャ |
| feature/docs-update-deployment-ops | 7 | デプロイ・運用 |
| feature/docs-update-scraping-test | 6 | スクレイピング・テスト |
| feature/docs-update-marketing | 2 | マーケティング |

**結果**: 5件のPR（#123〜#127）を約5分で作成完了。
