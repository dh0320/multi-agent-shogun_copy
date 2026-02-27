# Web UI ローカル起動ガイド（TKT-001〜003）

TKT-001（雛形）に加えて、TKT-002（YAMLリーダー層）とTKT-003（共通スキーマ）の最小実装を含みます。

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

## 2) Frontend 起動

別ターミナルで:

```bash
cd web/frontend
python3 -m http.server 5173 --bind 127.0.0.1
```

ブラウザで `http://127.0.0.1:5173` を開き、`Health Check`ボタンを押してください。

## 3) API確認

### health

```bash
curl http://127.0.0.1:8000/api/v1/health
```

### YAMLリーダー（TKT-002）

許可されたパス（`queue/`, `projects/`, `config/`）のみ読み取り可能です。

```bash
curl 'http://127.0.0.1:8000/api/v1/system/read-yaml?relative_path=config/ntfy_auth.env.sample'
```

## 4) DoDチェック

- backendが起動する
- frontendが起動する
- frontendまたはcurlから `/api/v1/health` にアクセスできる
- YAMLリーダーが許可パスのみ読み取り、エラーを統一形式で返す
