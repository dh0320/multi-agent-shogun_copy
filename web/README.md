# Web UI ローカル起動ガイド（TKT-001〜TKT-010 MVP）

読み取り専用MVPとして、TKT-001〜TKT-010（基盤/API/UI/空状態・エラー表示）を実装した構成です。

## 構成

- `backend`: FastAPI + YAML読み取りAPI
- `frontend`: モバイル優先の静的SPA

## ローカルで確認する

### 1) Backend 起動

```bash
cd web/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### 2) Frontend 起動

```bash
cd web/frontend
python3 -m http.server 5173 --bind 127.0.0.1
```

ブラウザで `http://127.0.0.1:5173` を開きます。

## GitHub Pages で確認する

`main` ブランチに push されると、`web/frontend` が GitHub Pages に自動デプロイされます（workflow: `.github/workflows/deploy-web-ui.yml`）。

1. GitHub リポジトリの **Settings → Pages** で Source を **GitHub Actions** にする
2. `main` に push する
3. Actions の `Deploy Web UI to GitHub Pages` が成功したら公開URLを開く


### デプロイ時によくあるエラー（404: Failed to create deployment）

`actions/deploy-pages` で 404 が出る場合は、ほぼ未設定が原因です。

1. `https://github.com/<owner>/<repo>/settings/pages` を開く
2. **Build and deployment → Source** を **GitHub Actions** に設定
3. リポジトリの **Actions permissions** が無効化されていないか確認
4. `Deploy Web UI to GitHub Pages` を **Re-run jobs** する

このリポジトリでは workflow に `actions/configure-pages@v5` を追加済みです。

### Pages上でAPI接続先を変える

Pages上ではローカルAPI (`127.0.0.1`) へは繋がらないため、デフォルトでモック表示になります。

外部公開済みAPIに接続する場合は URL に `apiBase` を指定します。

```text
https://<user>.github.io/<repo>/?apiBase=https://<your-api-host>
```

一度指定すると `localStorage` に保存され、次回以降も同じAPIを利用します。

## 主要API

- `GET /api/v1/health`
- `GET /api/v1/dashboard/summary`
- `GET /api/v1/commands?status=&project=&limit=&offset=`
- `GET /api/v1/commands/{cmdId}`
- `GET /api/v1/tasks`
- `GET /api/v1/tasks/{agentId}`
- `GET /api/v1/reports`
- `GET /api/v1/reports/{agentId}`

すべて `data/meta/error` の統一レスポンス形式。

## DoD確認例

```bash
curl http://127.0.0.1:8000/api/v1/dashboard/summary
curl "http://127.0.0.1:8000/api/v1/commands?limit=20"
curl http://127.0.0.1:8000/api/v1/tasks
curl http://127.0.0.1:8000/api/v1/reports
```

`queue/` がない環境では空データが返り、UIは空状態テンプレートを表示します。
