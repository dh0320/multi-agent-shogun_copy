# turso-performance-audit

## 概要
Turso (libSQL) + SQLAlchemy構成のパフォーマンスを体系的に調査するスキル。接続設定、N+1クエリ検出、クエリ数カウント、インデックス検証、マイグレーション影響分析の5観点で調査し、具体的な修正提案と優先度を出力する。

## 使用場面
- アプリの応答が遅いと報告があった時
- Turso (libSQL) を使っているプロジェクトのパフォーマンスチューニング時
- 大量のfeature追加後にパフォーマンスが劣化した時
- リモートDB（HTTPS経由）のレイテンシが問題になっている時

## トリガーワード
- 「DB遅い」「パフォーマンス調査」「Turso遅延」
- 「N+1」「クエリ数削減」「レイテンシ」
- 「turso performance」「SQLAlchemy最適化」

## 前提条件
- Turso (libSQL) + SQLAlchemy 2.0 構成のプロジェクトであること
- ソースコードにアクセスできること
- alembic（マイグレーション管理）が導入されていること（推奨）

## 手順

### 観点1: DB接続設定の確認

```bash
# データベース接続ファイルを特定
Glob: **/database.py, **/db.py, **/database/*.py

# 接続設定の確認ポイント
Grep: "create_engine|create_async_engine" in app/database.py
Grep: "pool_size|max_overflow|pool_pre_ping|pool_recycle" in app/database.py
Grep: "ThreadPoolExecutor|executor" in app/database.py
```

**チェック項目**:
| 項目 | 正常 | 問題あり |
|------|------|---------|
| プール設定 | pool_size, pool_pre_ping 設定あり | 設定なし（デフォルト） |
| Executor管理 | グローバルExecutor共有 | 毎リクエストで作成/破棄 |
| 接続方式 | 適切なドライバー指定 | ドライバー未指定 |

**Turso特有の注意点**:
- TursoはHTTPS経由のリモートDB → 各クエリに100〜300msのネットワークレイテンシ
- ローカルSQLiteと違い、クエリ数がそのまま応答時間に直結する
- `pool_pre_ping=True` はTursoのHTTPS接続では効果が薄い場合がある

### 観点2: クエリパフォーマンス（N+1検出）

```bash
# 全 relationship の定義を抽出
Grep: "relationship\(" in app/models/**/*.py

# lazy loading の設定を確認
Grep: "lazy=" in app/models/**/*.py
# 結果が0件 → 全てデフォルト（lazy="select"）→ N+1リスク

# selectinload の使用箇所を確認
Grep: "selectinload|joinedload|subqueryload" in app/**/*.py

# APIエンドポイントのクエリチェーンを分析
# 1つのAPIリクエストで何回のDBクエリが発生するか数える
Grep: "db\.(get|execute|scalars|query)" in app/api/**/*.py app/services/**/*.py
```

**N+1検出パターン**:
```python
# 危険: ループ内でDBクエリ
for user in users:
    subs = db.query(Subscription).filter_by(user_id=user.id)  # N回!

# 安全: eager loading で事前取得
users = db.query(User).options(selectinload(User.subscriptions)).all()
```

**重要な分析**:
1. メイン画面（ユーザーが最初に見る画面）のAPI呼び出しチェーンを特定
2. そのAPIで実行される逐次クエリを数える
3. 推定レイテンシ = クエリ数 x Tursoレイテンシ(100-300ms)

### 観点3: インデックス検証

```bash
# インデックスの確認
Grep: "index=True|Index\(" in app/models/**/*.py

# FK列にインデックスがあるか
Grep: "ForeignKey" in app/models/**/*.py
# FK列に index=True がない → WHERE句でフルスキャン

# 複合インデックスの確認
Grep: "__table_args__" in app/models/**/*.py
```

**チェック項目**:
- [ ] 全ForeignKeyカラムに `index=True` がある
- [ ] WHERE/ORDER BY で頻繁に使うカラムにインデックスがある
- [ ] ユニーク制約が必要なカラムに `unique=True` がある

### 観点4: マイグレーション影響

```bash
# 最近のマイグレーション履歴
cd <project_root>
alembic history --verbose | head -30

# 重いマイグレーションの検出
Grep: "alter_column|drop_column|batch_alter_table" in alembic/versions/*.py

# マイグレーション数の推移（短期間に大量追加は警告）
ls -la alembic/versions/ | wc -l
```

### 観点5: 起動時の初期化処理

```bash
# アプリ起動時の処理を確認
Read: app/main.py

# lifespan/startup で重いDB処理がないか
Grep: "startup|lifespan|on_event" in app/main.py
```

### 結果の整理

```markdown
## パフォーマンス監査結果

| # | 観点 | 判定 | 詳細 |
|---|------|------|------|
| 1 | DB接続設定 | ★/△/○ | ... |
| 2 | クエリパフォーマンス | ★/△/○ | ... |
| 3 | インデックス | ★/△/○ | ... |
| 4 | マイグレーション | ★/△/○ | ... |
| 5 | 起動時処理 | ★/△/○ | ... |

★=重大問題 △=軽微 ○=問題なし

## 修正提案（優先度順）

| # | 提案 | 効果 | 工数 |
|---|------|------|------|
| 1 | クエリ統合（N→M に削減） | 大 | 小 |
| 2 | プール設定追加 | 中 | 小 |
| 3 | Executor共有化 | 中 | 小 |
| 4 | relationship lazy="selectin" | 小 | 小 |
```

## チェックリスト

### 調査
- [ ] 観点1: DB接続設定を確認した
- [ ] 観点2: N+1パターンを検出した
- [ ] 観点3: インデックスの過不足を確認した
- [ ] 観点4: 最近のマイグレーションを確認した
- [ ] 観点5: 起動時処理を確認した

### 分析
- [ ] メイン画面のAPIクエリチェーンを特定した
- [ ] 逐次クエリ数を数えた
- [ ] 推定レイテンシを計算した（クエリ数 x 100-300ms）
- [ ] 根本原因を特定した

### 修正提案
- [ ] 修正案を優先度順にリストアップした
- [ ] 各修正案の効果と工数を見積もった
- [ ] 即効性のある修正（クエリ統合、プール設定）を最優先にした

## トラブルシューティング

### SQLAlchemy echo=True でクエリログを取得する方法
```python
# database.py の engine 作成時
engine = create_engine(url, echo=True)  # 全クエリがログに出力される
```

### Tursoのレイテンシを実測する方法
```bash
# Turso CLIで簡易計測
time turso db shell <db-name> "SELECT 1"

# curlでHTTPSレイテンシ計測
curl -so /dev/null -w "%{time_starttransfer}" "https://<db-name>-<org>.turso.io"
```

## 参考実装

### NotifyFavoriteTherapistsForLine のパフォーマンス調査結果

**根本原因**: Tursoネットワークレイテンシ(100-300ms) x 逐次クエリ数(5-7) = 500〜2100ms
- ThreadPoolExecutor毎リクエスト生成（50-100ms オーバーヘッド）
- 認証で取得済みUserの重複クエリ（100-300ms 無駄）
- プール設定の欠如

**修正提案**: クエリ統合（7→3）+ プール設定追加で推定50%高速化
