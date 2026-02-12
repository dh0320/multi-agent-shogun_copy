# ローカルカスタマイズ

このフォルダには、fork元と同期する際に上書きされたくないローカル固有のカスタマイズを保存します。

## 構成

```
local_customizations/
├── README.md              # このファイル
├── apply_local.sh         # カスタマイズを適用するスクリプト
├── settings_override.yaml # config/settings.yaml への上書き設定
└── hooks/                 # Gitフック
    └── pre-push          # git push 禁止フック
```

## 使用方法

### 1. fork元と同期した後

```bash
# fork元からpullした後、ローカルカスタマイズを再適用
./local_customizations/apply_local.sh
```

### 2. 新しいカスタマイズを追加

1. このフォルダ内のファイルを編集
2. `apply_local.sh` を実行して適用
3. このフォルダをコミット（`.gitignore` には含めない）

## カスタマイズ内容

### 1. git push 禁止フック
- `hooks/pre-push` でリモートへのpushをブロック
- 殿の許可なくpushできないようにする

### 2. Makefile 拡張
- 操作コマンドを追加（setup, shutsujin, stop, status, attach-*）

## 同期手順

```bash
# 1. fork元の最新を取得
git fetch upstream
git merge upstream/main

# 2. コンフリクトがあればリモート優先で解決
git checkout --theirs .
git add .
git commit -m "Merge upstream changes"

# 3. ローカルカスタマイズを再適用
./local_customizations/apply_local.sh

# 4. 動作確認
make status
```
