# Web UI ローカル起動ガイド（TKT-001）

TKT-001のDoD（backend/frontend起動、health check到達）を満たすための最小雛形です。

## 構成

- `backend`: FastAPI（本命） + 依存なしフォールバックサーバ
- `frontend`: 静的HTML（将来React/Next.jsへ差し替え可能）

## 1) Backend 起動

### A. FastAPI（推奨）

```bash
cd web/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 127.0.0.1 --port 8000
```

### B. フォールバック（依存なし）

パッケージ取得ができない環境向け。

```bash
cd web/backend
python3 dev_server.py
```

確認:

```bash
curl http://127.0.0.1:8000/api/v1/health
# => {"status":"ok"}
```

## 2) Frontend 起動

別ターミナルで:

```bash
cd web/frontend
python3 -m http.server 5173 --bind 127.0.0.1
```

ブラウザで `http://127.0.0.1:5173` を開き、`Health Check`ボタンを押してください。

## 3) DoDチェック

- backendが起動する
- frontendが起動する
- frontendまたはcurlから `/api/v1/health` にアクセスできる
