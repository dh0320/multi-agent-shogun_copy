# Web UI ローカル起動ガイド（TKT-001〜TKT-010 MVP）

読み取り専用MVPとして、TKT-001〜TKT-010（基盤/API/UI/空状態・エラー表示）を実装した構成です。

## 構成

- `backend`: FastAPI + YAML読み取りAPI
- `frontend`: モバイル優先の静的SPA

## Backend 起動

```bash
cd web/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

## Frontend 起動

```bash
cd web/frontend
python3 -m http.server 5173 --bind 127.0.0.1
```

ブラウザで `http://127.0.0.1:5173` を開きます。

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
