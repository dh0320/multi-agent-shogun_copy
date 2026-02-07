# git-worktree-conflict-resolve

## 概要
git worktreeを使い、同一リポジトリで複数エージェント（足軽）が同時作業する際のコンフリクト解消パターン。ワーキングツリーを分離することで、ブランチ切り替え時の変更消失やステージング衝突を防ぐ。

## 使用場面
- 複数の足軽が同じリポジトリの異なるブランチで同時作業する時
- ブランチ切り替え時にstash/変更消失が頻発する時
- git lockファイルの競合が発生する時
- 長時間のビルド中に別ブランチの作業も進めたい時

## トリガーワード
- 「worktree」「コンフリクト解消」「同時作業」
- 「ブランチ競合」「git lock」「並列作業」
- 「マルチエージェント作業」「同一リポジトリ並列」

## 前提条件
- Git 2.15以上（worktree改善版）
- 十分なディスク容量（worktreeごとにファイルコピーが発生）
- 各worktreeのパスが衝突しないこと

## 手順

### Phase 1: worktree の作成

```bash
# メインのリポジトリ（家老または足軽1が使用）
cd /path/to/project

# 足軽2用のworktreeを作成
git worktree add ../project-ashigaru2 feature/branch-for-ashigaru2

# 足軽3用のworktreeを作成
git worktree add ../project-ashigaru3 feature/branch-for-ashigaru3

# worktree一覧の確認
git worktree list
```

**ディレクトリ構成例**:
```
/Users/user/work/
  project/                  ← メイン（家老/足軽1）
  project-ashigaru2/        ← 足軽2用worktree
  project-ashigaru3/        ← 足軽3用worktree
```

### Phase 2: 各worktreeでの作業

```bash
# 足軽2は自分専用のworktreeで作業
cd /path/to/project-ashigaru2

# 通常のgit操作が全て使える
git status
git add .
git commit -m "feat: implement feature X"
git push origin feature/branch-for-ashigaru2
```

**重要**: 各worktreeは独立したワーキングディレクトリを持つため、他のworktreeの `git checkout` や `git stash` の影響を受けない。

### Phase 3: コンフリクト解消（同じファイルを修正した場合）

```bash
# メインリポジトリに戻る
cd /path/to/project

# 足軽2のブランチをマージ試行
git checkout develop
git merge feature/branch-for-ashigaru2

# コンフリクトが発生した場合
# 1. コンフリクトファイルを確認
git status
# both modified: app/models/__init__.py

# 2. コンフリクト内容を確認
git diff

# 3. 手動で解消（両方の変更を統合）
# Edit the conflicting files

# 4. 解消を記録
git add app/models/__init__.py
git commit -m "merge: resolve conflict in __init__.py (ashigaru2 + ashigaru3 changes)"
```

### Phase 4: worktreeの削除（作業完了後）

```bash
# worktreeの削除
git worktree remove ../project-ashigaru2
git worktree remove ../project-ashigaru3

# 削除できない場合（変更が残っている）
git worktree remove --force ../project-ashigaru2

# ゴミ掃除
git worktree prune
```

## チェックリスト

### worktree作成時
- [ ] ベースブランチが最新である（`git pull` 済み）
- [ ] worktreeのパスが他と衝突しない
- [ ] 各足軽に自分のworktreeパスを通知した

### 作業中
- [ ] 各足軽が自分のworktreeでのみ作業している
- [ ] 同じファイルを複数の足軽が同時に修正していないか確認した
- [ ] `__init__.py` 等の共有ファイルは変更前に家老に報告

### マージ時
- [ ] 各ブランチをdevelopにマージする順序を決定した
- [ ] コンフリクトファイルを特定した
- [ ] 両方の変更を正しく統合した
- [ ] マージ後にテストが通ることを確認した

### 後片付け
- [ ] 全worktreeを削除した
- [ ] `git worktree prune` を実行した

## トラブルシューティング

### "fatal: is already checked out" エラー
同じブランチを複数のworktreeでcheckoutしようとした場合に発生:
```bash
# 別のworktreeで使用中のブランチを確認
git worktree list

# 新しいブランチを作って対応
git worktree add ../project-new -b feature/new-branch
```

### worktreeでnpm install/pip installが必要
各worktreeは独立したワーキングディレクトリなので、依存関係のインストールが個別に必要:
```bash
cd ../project-ashigaru2
npm install  # または pip install -r requirements.txt
```

### git lockファイルの競合
複数のworktreeが同じ `.git` ディレクトリを共有するため、同時に `git` コマンドを実行するとlockファイルの競合が起こることがある:
```bash
# lockファイルの削除（他のgitプロセスが動いていないことを確認してから）
rm -f .git/index.lock
```

## 注意事項

### shogunシステムでの推奨運用
- **家老がworktreeを管理**: 足軽は自分のworktreeパスを指定される
- **共有ファイルの変更は家老に報告**: `__init__.py`、`requirements.txt` 等
- **マージ順序は家老が決定**: コンフリクトの最小化のため
- **worktreeの作成/削除も家老が実行**: 足軽はworktree内でのみ作業

### worktree vs stash
| 観点 | worktree | stash |
|------|----------|-------|
| 並列作業 | 可能（完全分離） | 不可（1つのワーキングツリー） |
| ディスク使用量 | 多い（ファイルコピー） | 少ない |
| 依存関係 | 個別にインストール必要 | 共有 |
| 操作の安全性 | 高い | stash pop失敗のリスク |
| 適用場面 | 長時間の並列作業 | 短時間のブランチ切り替え |
