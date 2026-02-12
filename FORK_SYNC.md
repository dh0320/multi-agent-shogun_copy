# fork 同期手順

このドキュメントでは、fork元（upstream）の最新変更を取り込む手順を説明します。

## 前提条件

upstreamリモートが設定されていること：

```bash
git remote -v
# upstream	https://github.com/mm-su-watanabe/multi-agent-shogun.git (fetch)
# upstream	https://github.com/mm-su-watanabe/multi-agent-shogun.git (push)
```

設定されていない場合：

```bash
git remote add upstream https://github.com/mm-su-watanabe/multi-agent-shogun.git
```

## 同期手順（リモート優先・コンフリクト自動解決）

### 1. upstreamの最新を取得

```bash
git fetch upstream
```

### 2. mainブランチにいることを確認

```bash
git checkout main
```

### 3. upstreamをマージ（コンフリクトが発生する可能性あり）

```bash
git pull --tags upstream main --no-rebase
```

**コンフリクトが発生した場合**:

```bash
# リモート優先で解決
git checkout --theirs .

# ステージング
git add .

# マージコミット作成
git commit -m "Merge upstream main (theirs strategy)"
```

### 4. ローカルカスタマイズを再適用

```bash
./local_customizations/apply_local.sh
```

これにより以下が再適用されます：

- `config/settings.yaml` の `ashigaru_count` 設定
- `.git/hooks/pre-push` フック（git push禁止）
- `Makefile` の拡張コマンド

### 5. 動作確認

```bash
# セッション状態確認
make status

# 設定確認
grep ashigaru_count config/settings.yaml

# pre-push フック確認
ls -la .git/hooks/pre-push
```

### 6. コミット

ローカルカスタマイズの再適用で変更が発生した場合：

```bash
git add .
git commit -m "Re-apply local customizations after upstream merge"
```

## ローカルカスタマイズの管理

### カスタマイズ内容を追加・変更する場合

1. `local_customizations/` 内のファイルを編集
2. `./local_customizations/apply_local.sh` を実行して適用
3. 変更をコミット

```bash
# 例: 足軽人数を変更
vim local_customizations/settings_override.yaml

# 適用
./local_customizations/apply_local.sh

# コミット
git add local_customizations/
git commit -m "Update ashigaru_count to 6"
```

### カスタマイズが適用されているか確認

```bash
# ashigaru_count の確認
grep ashigaru_count config/settings.yaml

# Makefileコマンドの確認
make help | grep -A3 "ローカルカスタマイズ"

# pre-push フックの確認
cat .git/hooks/pre-push | head -10
```

## トラブルシューティング

### コンフリクト解決が複雑な場合

手動で個別ファイルを確認する場合：

```bash
# コンフリクトしているファイルを確認
git status

# 特定ファイルをリモート優先で解決
git checkout --theirs path/to/file

# 特定ファイルをローカル優先で解決
git checkout --ours path/to/file

# 解決後にステージング
git add path/to/file
```

### apply_local.sh が失敗する場合

手動で適用：

1. **config/settings.yaml**:
   ```bash
   # ashigaru_count: 4 を手動で追記
   vim config/settings.yaml
   ```

2. **.git/hooks/pre-push**:
   ```bash
   cp local_customizations/hooks/pre-push .git/hooks/
   chmod +x .git/hooks/pre-push
   ```

3. **Makefile**:
   ```bash
   # 既に含まれている場合はスキップ
   grep -q "ローカルカスタマイズ" Makefile || cat local_customizations/makefile_extensions.mk >> Makefile
   ```

## まとめ

```bash
# 完全な同期手順（1コマンド）
git fetch upstream && \
git pull --tags upstream main --no-rebase && \
git checkout --theirs . && \
git add . && \
git commit -m "Merge upstream main (theirs strategy)" && \
./local_customizations/apply_local.sh && \
make status
```

この手順により、fork元の最新変更を取り込みつつ、ローカル固有のカスタマイズを維持できます。
