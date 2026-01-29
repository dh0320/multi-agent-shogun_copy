# コントリビューションガイド

## ブランチ戦略

シンプルなGitHub Flowを採用。

```
main ← develop ← feature/xxx
```

- `main`: 本番相当。ブランチ保護あり（PRレビュー1名必須、管理者にも適用）
- `develop`: 開発統合ブランチ。feature ブランチのマージ先
- feature ブランチは `develop` から切り、PRで `develop` にマージ
- リリース時に `develop` → `main` へPR

### ブランチ命名規則

| 種類 | 命名 | 例 |
|------|------|----|
| 機能追加 | `feature/xxx` | `feature/add-health-check` |
| バグ修正 | `fix/xxx` | `fix/yaml-parse-error` |
| リファクタ | `refactor/xxx` | `refactor/queue-system` |
| ドキュメント | `docs/xxx` | `docs/update-readme` |
