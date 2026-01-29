# 残タスク

## GitHub Actions CI / ブランチ保護

- [ ] PR を作成してCIが動くことを確認する
- [ ] mainブランチ保護ルールを設定する
  - Settings → Branches → Add rule
  - Branch name pattern: `main`
  - ✅ Require a pull request before merging（レビューは不要）
  - ✅ Require status checks to pass before merging → `shellcheck` を選択
  - ✅ Require branches to be up to date before merging

## 将来の改善（余裕が出たら）

- [ ] ShellCheck severity を `warning` に引き上げる
- [ ] カバレッジ / テストの追加
- [ ] dependabot 導入
- [ ] セキュリティスキャン
