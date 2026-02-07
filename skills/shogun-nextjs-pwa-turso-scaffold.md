# nextjs-pwa-turso-scaffold

## 概要
Next.js + PWA + Turso (libSQL) + Claude SDK の新規プロジェクトを一括初期化するスキル。create-next-app によるプロジェクト生成から、PWA設定、Turso DB接続、Claude API統合、Vercel連携までを体系的にセットアップする。

## 使用場面
- Next.js + Turso + AI機能の新規プロジェクトを立ち上げる時
- PWA対応のWebアプリを新規作成する時
- Claude SDKを使ったAI機能付きアプリを構築する時
- Vercelにデプロイする前提のNext.jsプロジェクトを初期化する時

## トリガーワード
- 「Next.js新規プロジェクト」「PWAアプリ作成」
- 「Turso + Next.js セットアップ」
- 「Claude SDK統合」「AIアプリ初期化」
- 「nextjs scaffold」「pwa setup」

## 前提条件
- Node.js 18+ インストール済み
- npm または yarn インストール済み
- `gh` CLI インストール・認証済み
- Turso CLIインストール・認証済み（`turso auth login`）
- Vercel CLI インストール済み（`npm i -g vercel`）
- Anthropic API Keyを取得済み

## 手順

### Step 1: GitHubリポジトリ作成

```bash
PROJECT_NAME="my-ai-app"
DESCRIPTION="AI-powered PWA application"

# リポジトリ作成
gh repo create $PROJECT_NAME --private --description "$DESCRIPTION" --clone
cd $PROJECT_NAME
```

### Step 2: Next.js初期化

```bash
# 一時ディレクトリで初期化（大文字のディレクトリ名対策）
TEMP_DIR=$(mktemp -d)
npx create-next-app@latest "$TEMP_DIR/app" \
  --typescript \
  --tailwind \
  --eslint \
  --app \
  --src-dir \
  --import-alias "@/*" \
  --turbopack

# ファイルをコピー（.gitは除く）
cp -r "$TEMP_DIR/app/"* .
cp "$TEMP_DIR/app/".* . 2>/dev/null || true
rm -rf "$TEMP_DIR"

# package.json の name を修正（小文字ケバブケース）
# "name": "PROJECT_NAME" → "name": "project-name"
```

**注意**: Next.js 16ではTurbopackがデフォルト。PWAプラグインとの互換性のため `next.config.ts` に `turbopack: {}` を追加する場合がある。

### Step 3: PWA設定

```bash
# PWAプラグインインストール
npm install @ducanh2912/next-pwa
```

```typescript
// next.config.ts
import withPWA from "@ducanh2912/next-pwa";

const nextConfig = withPWA({
  dest: "public",
  register: true,
  skipWaiting: true,
})({
  // Next.js config
});

export default nextConfig;
```

```json
// public/manifest.json
{
  "name": "PROJECT_NAME",
  "short_name": "PROJECT",
  "description": "DESCRIPTION",
  "start_url": "/",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#000000",
  "icons": [
    { "src": "/icons/icon-192x192.png", "sizes": "192x192", "type": "image/png" },
    { "src": "/icons/icon-512x512.png", "sizes": "512x512", "type": "image/png" }
  ]
}
```

```bash
# プレースホルダーアイコンを作成
mkdir -p public/icons
# 192x192 と 512x512 のPNGアイコンを配置
```

### Step 4: Turso DB設定

```bash
# Turso データベース作成
turso db create $PROJECT_NAME

# 接続情報の取得
turso db show $PROJECT_NAME --url    # → TURSO_DATABASE_URL
turso db tokens create $PROJECT_NAME  # → TURSO_AUTH_TOKEN

# クライアントライブラリインストール
npm install @libsql/client
```

```typescript
// src/lib/db.ts
import { createClient } from "@libsql/client";

export const db = createClient({
  url: process.env.TURSO_DATABASE_URL!,
  authToken: process.env.TURSO_AUTH_TOKEN,
});
```

```sql
-- migrations/001_initial.sql
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  email TEXT UNIQUE,
  name TEXT,
  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);
```

### Step 5: Claude SDK統合

```bash
# Anthropic SDK インストール
npm install @anthropic-ai/sdk
```

```typescript
// src/lib/claude.ts
import Anthropic from "@anthropic-ai/sdk";

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

export async function chat(messages: { role: string; content: string }[]) {
  const response = await anthropic.messages.create({
    model: "claude-sonnet-4-5-20250929",
    max_tokens: 4096,
    messages: messages as any,
  });
  return response;
}
```

```typescript
// src/app/api/chat/route.ts
import { NextRequest, NextResponse } from "next/server";
import { chat } from "@/lib/claude";

export async function POST(req: NextRequest) {
  const { messages } = await req.json();
  const response = await chat(messages);
  return NextResponse.json(response);
}
```

### Step 6: 環境変数設定

```bash
# .env.local を作成
cat > .env.local << 'EOF'
TURSO_DATABASE_URL=libsql://your-db.turso.io
TURSO_AUTH_TOKEN=your-token
ANTHROPIC_API_KEY=sk-ant-your-key
EOF

# .env.example を作成（キー名のみ）
cat > .env.example << 'EOF'
TURSO_DATABASE_URL=
TURSO_AUTH_TOKEN=
ANTHROPIC_API_KEY=
EOF

# .gitignore に .env* があることを確認
grep ".env" .gitignore || echo -e "\n.env*\n.env.local" >> .gitignore
```

### Step 7: layout.tsx の設定

```typescript
// src/app/layout.tsx
import type { Metadata, Viewport } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "PROJECT_NAME",
  description: "DESCRIPTION",
  manifest: "/manifest.json",
};

export const viewport: Viewport = {
  themeColor: "#000000",
  width: "device-width",
  initialScale: 1,
  maximumScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ja">
      <body>{children}</body>
    </html>
  );
}
```

### Step 8: ビルド確認・Vercel連携

```bash
# ビルド確認
npm run build

# Vercel連携
vercel link

# 環境変数をVercelに設定
vercel env add TURSO_DATABASE_URL production
vercel env add TURSO_AUTH_TOKEN production
vercel env add ANTHROPIC_API_KEY production

# 初期コミット
git add .
git commit -m "chore: initial project scaffold (Next.js + PWA + Turso + Claude SDK)"
git push -u origin main
```

### Step 9: CLAUDE.md 作成

```markdown
# PROJECT_NAME

## 技術スタック
- Next.js 16 (App Router, TypeScript, Tailwind CSS 4)
- PWA (@ducanh2912/next-pwa)
- Turso (libSQL) - データベース
- Anthropic Claude SDK - AI機能
- Vercel - ホスティング

## ディレクトリ構成
src/app/        # ページ・APIルート
src/lib/        # ユーティリティ（db.ts, claude.ts）
src/components/ # UIコンポーネント
migrations/     # SQLマイグレーション
public/         # 静的ファイル・PWAマニフェスト

## 開発ルール
- TDD方式で実装
- 型アノテーション必須
- Turso/SQLiteの制約: JSONB不可、配列型不可
```

## チェックリスト

### プロジェクト初期化
- [ ] GitHubリポジトリを作成した
- [ ] create-next-app でNext.jsを初期化した
- [ ] TypeScript, Tailwind, App Router, src ディレクトリを有効化した

### PWA
- [ ] @ducanh2912/next-pwa をインストールした
- [ ] next.config.ts にPWA設定を追加した
- [ ] manifest.json を作成した
- [ ] アイコンを配置した

### Turso
- [ ] turso db create でデータベースを作成した
- [ ] 接続URL・トークンを取得した
- [ ] @libsql/client をインストールした
- [ ] src/lib/db.ts を作成した
- [ ] 初期マイグレーションSQLを作成した

### Claude SDK
- [ ] @anthropic-ai/sdk をインストールした
- [ ] src/lib/claude.ts を作成した
- [ ] APIルート（/api/chat）を作成した

### 環境・デプロイ
- [ ] .env.local に環境変数を設定した
- [ ] .env.example を作成した
- [ ] .gitignore に .env* を追加した
- [ ] npm run build が成功する
- [ ] Vercel にリンクした
- [ ] Vercel に環境変数を設定した

## トラブルシューティング

### create-next-app で大文字ディレクトリ名がエラーになる
npmのpackage name制約で大文字が使えない。一時ディレクトリで初期化してファイルをコピーする。

### PWAプラグインがTurbopackと競合する
next.config.ts に `turbopack: {}` の空設定を追加することで回避。

### Turso接続がタイムアウトする
- TURSO_DATABASE_URL の形式を確認: `libsql://db-name-org.turso.io`
- TURSO_AUTH_TOKEN が有効期限切れでないか確認
- Vercelのリージョンと Turso のリージョンを近い場所に設定

## 関連スキル
- `/shogun-new-project-scaffold` - Python版の新規プロジェクトスキャフォールディング
- `/shogun-vercel-production-deploy` - Vercel本番デプロイ手順
