# 残タスク

## GitHub Actions CI / ブランチ保護

- [ ] PR を作成してCIが動くことを確認する
- [ ] mainブランチ保護ルールを設定する（GitHub UI で手動設定）
  - Settings → Branches → Add rule
  - Branch name pattern: `main`
  - ✅ Require a pull request before merging（レビューは不要）
  - ✅ Require status checks to pass before merging → `shellcheck`, `actionlint`, `test`, `test-tmux` を選択
  - ✅ Require branches to be up to date before merging

## 完了済み

- [x] ShellCheck severity を `warning` に引き上げる
- [x] ユニットテストの追加 (`tests/run_tests.sh` — 69項目)
- [x] tmux 統合テストの追加 (`tests/test_tmux_integration.sh` — 25項目)
- [x] dependabot 導入 (GitHub Actions の自動更新)
- [x] actionlint によるワークフロー検証
