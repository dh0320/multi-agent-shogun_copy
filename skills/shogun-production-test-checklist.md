# production-test-checklist

## 概要
本番デプロイ後の疎通・パフォーマンス・セキュリティヘッダーを一括チェックするスキル。curlベースの自動テストで、Vercel+Next.js固有の項目も含む包括的な本番検証を行う。

## 使用場面
- 本番デプロイ直後の動作確認
- カスタムドメイン設定後のSSL・ヘッダー検証
- 定期的な本番環境ヘルスチェック
- インフラ変更後のリグレッション確認
- セキュリティ監査時のヘッダーチェック

## トリガーワード
- 「本番テスト」「本番確認」「デプロイ後チェック」
- 「疎通確認」「ヘルスチェック」「セキュリティヘッダー確認」
- 「production test」「post-deploy check」

## 前提条件
- curl がインストール済みであること
- 対象URLにアクセス可能であること
- jq がインストール済みであること（JSON応答の解析に使用）

## 手順

### Phase 1: 基本疎通チェック

```bash
BASE_URL="https://your-domain.com"

# 1. トップページの応答確認
echo "=== 基本疎通 ==="
STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE_URL")
echo "Top page: $STATUS"
[ "$STATUS" = "200" ] && echo "  PASS" || echo "  FAIL"

# 2. API ヘルスチェック（エンドポイントがある場合）
STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE_URL/api/health")
echo "Health API: $STATUS"
[ "$STATUS" = "200" ] && echo "  PASS" || echo "  FAIL"

# 3. リダイレクト確認（www → non-www、http → https）
echo ""
echo "=== リダイレクト ==="
curl -sI "http://$BASE_URL" 2>/dev/null | head -3
curl -sI "http://www.$(echo $BASE_URL | sed 's|https://||')" 2>/dev/null | head -3
```

### Phase 2: パフォーマンスチェック

```bash
echo "=== パフォーマンス ==="

# レスポンスタイム計測
curl -so /dev/null -w \
  "DNS:      %{time_namelookup}s\nConnect:   %{time_connect}s\nTLS:       %{time_appconnect}s\nTTFB:      %{time_starttransfer}s\nTotal:     %{time_total}s\nSize:      %{size_download} bytes\n" \
  "$BASE_URL"

# 判定基準
# DNS:    < 0.1s
# TTFB:   < 0.5s (Vercel Edge: < 0.1s)
# Total:  < 2.0s
# Size:   初期HTML < 100KB

# API レスポンスタイム
echo ""
echo "=== API パフォーマンス ==="
for endpoint in "/api/health" "/api/auth/status"; do
  TTFB=$(curl -so /dev/null -w "%{time_starttransfer}" "$BASE_URL$endpoint" 2>/dev/null)
  echo "$endpoint TTFB: ${TTFB}s"
done
```

### Phase 3: セキュリティヘッダーチェック

```bash
echo "=== セキュリティヘッダー ==="
HEADERS=$(curl -sI "$BASE_URL")

# 必須ヘッダー
check_header() {
  local name="$1"
  local expected="$2"
  local value=$(echo "$HEADERS" | grep -i "^$name:" | head -1)
  if [ -n "$value" ]; then
    echo "  PASS: $value"
  else
    echo "  FAIL: $name ヘッダーなし（推奨: $expected）"
  fi
}

check_header "Strict-Transport-Security" "max-age=31536000; includeSubDomains"
check_header "X-Content-Type-Options" "nosniff"
check_header "X-Frame-Options" "DENY or SAMEORIGIN"
check_header "X-XSS-Protection" "1; mode=block"
check_header "Referrer-Policy" "strict-origin-when-cross-origin"
check_header "Content-Security-Policy" "default-src 'self'"

# Vercel固有ヘッダー
echo ""
echo "=== Vercel固有 ==="
check_header "X-Vercel-Cache" "HIT or MISS"
check_header "X-Vercel-Id" "(deployment ID)"

# 危険なヘッダーの検出
echo ""
echo "=== 危険ヘッダー検出 ==="
echo "$HEADERS" | grep -i "x-powered-by" && echo "  WARN: X-Powered-By が露出" || echo "  PASS: X-Powered-By なし"
echo "$HEADERS" | grep -i "server:" && echo "  INFO: Server ヘッダーあり" || echo "  PASS: Server ヘッダーなし"
```

### Phase 4: CORS チェック

```bash
echo "=== CORS ==="
ORIGIN="https://your-domain.com"

# Preflight リクエスト
CORS_HEADERS=$(curl -sI -X OPTIONS "$BASE_URL/api/health" \
  -H "Origin: $ORIGIN" \
  -H "Access-Control-Request-Method: GET" \
  -H "Access-Control-Request-Headers: Content-Type,Authorization")

echo "$CORS_HEADERS" | grep -i "access-control"

# ワイルドカード検出（本番NG）
if echo "$CORS_HEADERS" | grep -qi "access-control-allow-origin: \*"; then
  echo "  FAIL: Access-Control-Allow-Origin: * は本番では禁止"
else
  echo "  PASS: ワイルドカードなし"
fi
```

### Phase 5: SSL/TLS チェック

```bash
echo "=== SSL/TLS ==="
DOMAIN=$(echo "$BASE_URL" | sed 's|https://||')

# 証明書情報
echo | openssl s_client -connect "$DOMAIN:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -dates -subject -issuer 2>/dev/null

# TLSバージョン確認
curl -sI --tlsv1.2 "$BASE_URL" > /dev/null 2>&1 && echo "  TLS 1.2: OK" || echo "  TLS 1.2: FAIL"
curl -sI --tlsv1.3 "$BASE_URL" > /dev/null 2>&1 && echo "  TLS 1.3: OK" || echo "  TLS 1.3: N/A"
```

### Phase 6: Next.js 固有チェック

```bash
echo "=== Next.js 固有 ==="

# _next/static の存在確認
STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE_URL/_next/static/chunks/webpack.js" 2>/dev/null)
echo "Static assets: $STATUS"

# PWA manifest（PWA対応の場合）
STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE_URL/manifest.json" 2>/dev/null)
echo "PWA manifest: $STATUS"

# robots.txt
STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE_URL/robots.txt" 2>/dev/null)
echo "robots.txt: $STATUS"

# sitemap.xml
STATUS=$(curl -so /dev/null -w "%{http_code}" "$BASE_URL/sitemap.xml" 2>/dev/null)
echo "sitemap.xml: $STATUS"
```

## チェックリスト

### 基本疎通
- [ ] トップページが200を返す
- [ ] APIヘルスチェックが200を返す
- [ ] http → https リダイレクトが動作する

### パフォーマンス
- [ ] TTFB < 500ms
- [ ] Total < 2.0s
- [ ] APIレスポンス < 200ms

### セキュリティヘッダー
- [ ] Strict-Transport-Security が設定されている
- [ ] X-Content-Type-Options: nosniff
- [ ] X-Frame-Options が設定されている
- [ ] CORSにワイルドカード(*)を使っていない
- [ ] X-Powered-By が露出していない

### SSL/TLS
- [ ] 証明書が有効期限内
- [ ] TLS 1.2以上をサポート

### Next.js固有
- [ ] 静的アセットが配信されている
- [ ] robots.txtが存在する

## トラブルシューティング

### TTFB が遅い（> 500ms）
- Vercelのリージョン設定を確認（日本向けなら `hnd1`）
- Serverless Functionsのコールドスタートの可能性（初回アクセス）
- 外部API/DB呼び出しのレイテンシを確認

### セキュリティヘッダーが設定されていない
Next.jsの `next.config.js` または Vercelの `vercel.json` でヘッダーを追加:
```js
// next.config.js
async headers() {
  return [{
    source: '/(.*)',
    headers: [
      { key: 'X-Content-Type-Options', value: 'nosniff' },
      { key: 'X-Frame-Options', value: 'DENY' },
    ],
  }]
}
```

### CORSエラー
`vercel.json` の headers セクションでAPI routeにCORSヘッダーを設定する。本番ドメインを明示的に指定し、`*` は使わない。
