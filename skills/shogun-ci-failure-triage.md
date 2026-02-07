# ci-failure-triage

## 概要
CI/CDパイプラインの失敗を体系的にトリアージするスキル。エラー分類、根本原因のグルーピング、修正、回帰確認までを一貫して行う。GitHub Actionsを主対象とするが、他CIにも応用可能。

## 使用場面
- CIが失敗してPRがマージできない時
- 複数のテストが同時に失敗している時
- ビルドエラーの原因特定に時間がかかっている時
- CI修正後に回帰がないことを確認したい時

## トリガーワード
- 「CI失敗」「ビルド失敗」「テスト失敗」
- 「CI修正」「パイプライン修正」「GitHub Actions エラー」
- 「ci failure」「build broken」「tests failing」

## 前提条件
- `gh` CLI がインストール・認証済みであること
- CIログへのアクセス権限があること
- 対象リポジトリがクローン済みであること

## 手順

### Phase 1: エラーログの取得と分類

```bash
# 最新のCI実行結果を確認
gh run list --limit 5

# 失敗したrunの詳細を取得
gh run view <run-id> --log-failed

# または特定PRのチェック結果
gh pr checks <pr-number>
```

エラーを以下のカテゴリに分類する:

| カテゴリ | 特徴 | 例 |
|---------|------|-----|
| A: ビルドエラー | コンパイル/バンドル失敗 | TypeScript型エラー、import解決失敗 |
| B: テストエラー | テスト実行時の失敗 | アサーション失敗、タイムアウト |
| C: リントエラー | 静的解析の警告/エラー | ESLint, ruff, mypy の指摘 |
| D: 環境エラー | CI環境自体の問題 | 依存関係インストール失敗、Node.jsバージョン |
| E: フレイキーテスト | 非決定的な失敗 | レースコンディション、外部API依存 |

### Phase 2: 根本原因のグルーピング

同じ根本原因に起因するエラーをグループ化する:

```markdown
## 根本原因分析

### 原因1: [具体的な原因]
- 影響範囲: [ファイル/テスト数]
- エラー種別: [A/B/C/D/E]
- 関連エラー:
  - error_1.ts:15 - Type 'string' is not assignable to 'number'
  - error_2.ts:30 - Property 'foo' does not exist on type 'Bar'
- 推定修正箇所: [ファイルパス]

### 原因2: [具体的な原因]
...
```

**グルーピングのコツ**:
- 同じファイルの変更に起因するエラーを集める
- import/export チェーンをたどって波及先を特定する
- 型定義の変更は多くのファイルに波及しやすい

### Phase 3: 修正の実行

優先度順に修正:

1. **環境エラー（D）を最優先**: CI自体が動かないと他の修正が確認できない
2. **ビルドエラー（A）**: テスト実行の前提
3. **リントエラー（C）**: 通常は単純な修正
4. **テストエラー（B）**: ロジックの問題、工数がかかる場合あり
5. **フレイキーテスト（E）**: 最後に対処、必要なら一時無効化

```bash
# 修正後、ローカルで事前確認
npm run build        # ビルド確認
npm run lint         # リント確認
npm run test         # テスト確認

# Python の場合
ruff check .         # リント確認
mypy src/            # 型チェック
pytest               # テスト確認
```

### Phase 4: 回帰確認

```bash
# 修正をコミット・プッシュ
git add <modified-files>
git commit -m "fix: resolve CI failures (<原因の要約>)"
git push

# CIの実行を監視
gh run watch

# 全チェックが通ったか確認
gh pr checks <pr-number>
```

## チェックリスト

### トリアージ
- [ ] CIログを取得した
- [ ] エラーをカテゴリ分類した（A〜E）
- [ ] 根本原因をグルーピングした
- [ ] 修正の優先度を決定した

### 修正
- [ ] 環境エラー（D）を修正した
- [ ] ビルドエラー（A）を修正した
- [ ] リントエラー（C）を修正した
- [ ] テストエラー（B）を修正した
- [ ] フレイキーテスト（E）を対処した

### 回帰確認
- [ ] ローカルでビルド・テスト・リントが通る
- [ ] CIが全て緑になった
- [ ] 他のPRへの影響がないか確認した

## トラブルシューティング

### CIは通るがローカルで失敗する（またはその逆）
- Node.js/Pythonのバージョン差異を確認
- 環境変数の差異を確認（CI環境のsecrets）
- キャッシュの影響（`node_modules` 削除して再インストール）

### 修正してもCIが失敗し続ける
- キャッシュが古い可能性: CIのキャッシュをクリアして再実行
  ```bash
  # GitHub Actions のキャッシュを削除
  gh cache list
  gh cache delete <key>
  ```
- ベースブランチとの差分を確認（`git merge develop` で最新を取り込む）

### フレイキーテストの一時無効化
```bash
# pytest: skip マーカーを付与
@pytest.mark.skip(reason="Flaky: investigating root cause #123")

# Jest: skip
it.skip("flaky test description", () => { ... })
```

**注意**: 必ずIssueを作成して追跡すること。無期限の無効化は禁止。
