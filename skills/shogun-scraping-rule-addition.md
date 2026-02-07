# scraping-rule-addition

## 概要
新しいスクレイピング対象サイトのルール追加を半自動化するスキル。curl でHTML取得→構造分析→strategy判定→CSSセレクタ特定→YAML設定追記→テスト更新までを体系的に行う。

## 使用場面
- 新しいスクレイピング対象サイトを追加する時
- 既存サイトのHTML構造が変わってルール更新が必要な時
- スクレイピング対象サイトの一括追加時

## トリガーワード
- 「スクレイピングルール追加」「サイト追加」「クロール設定」
- 「セレクタ特定」「HTML構造分析」「scraping rule」
- 「新規サイト対応」「スクレイピング設定」

## 前提条件
- curl がインストール済みであること
- 対象サイトにアクセス可能であること（VPN/プロキシが必要な場合あり）
- プロジェクトのスクレイピング設定ファイル（YAML）の場所を把握していること
- beautifulsoup4 等のHTMLパーサーが利用可能（解析時）

## 手順

### Phase 1: 対象サイトの事前調査

```bash
# 1. サイトの応答確認
curl -sI "https://target-site.com" | head -10

# 2. HTMLの取得（全体）
curl -s "https://target-site.com/therapist-page" -o /tmp/target.html

# 3. HTMLのサイズ・文字コード確認
file /tmp/target.html
wc -c /tmp/target.html

# 4. JavaScriptレンダリングが必要か判定
# HTMLにデータが含まれていれば requests (静的)、
# 含まれていなければ selenium/playwright (動的) が必要
grep -c "therapist-name-pattern" /tmp/target.html
```

### Phase 2: strategy 判定

| 判定基準 | strategy | 説明 |
|---------|----------|------|
| HTML内にデータがある | `requests` | 静的取得で十分 |
| JSで動的にレンダリング | `selenium` | ブラウザレンダリング必要 |
| API経由でJSON取得可能 | `api` | APIを直接叩く |
| Cloudflare等のWAFあり | `selenium` + 回避策 | 追加設定が必要 |

```bash
# JavaScript依存の判定
# 1. curlで取得したHTMLにデータがあるか
grep -c "class=\"therapist\"" /tmp/target.html

# 2. ない場合、ブラウザでDevTools → Network → XHR を確認
# APIエンドポイントが見つかればstrategy: api

# 3. API もない場合 → strategy: selenium
```

### Phase 3: CSSセレクタの特定

```python
# HTMLパーサーで構造を分析
from bs4 import BeautifulSoup

with open("/tmp/target.html") as f:
    soup = BeautifulSoup(f, "html.parser")

# セラピスト名のセレクタ候補を探す
for tag in soup.find_all(class_=True):
    classes = " ".join(tag.get("class", []))
    text = tag.get_text(strip=True)[:50]
    if text:  # テキストがある要素のみ
        print(f"{tag.name}.{classes} → {text}")
```

**特定すべきセレクタ一覧**:
| 項目 | 説明 | 例 |
|------|------|-----|
| name | セラピスト名 | `.therapist-name`, `h2.name` |
| schedule | スケジュール表 | `.schedule-table`, `table.timetable` |
| profile_url | プロフィールURL | `a.therapist-link[href]` |
| image | 画像URL | `img.therapist-photo[src]` |
| status | 出勤状態 | `.status-badge`, `.working-now` |

### Phase 4: YAML設定の追記

```yaml
# config/scraping_rules.yaml に追加
- name: "target-site"
  url: "https://target-site.com"
  enabled: true
  strategy: "requests"  # or "selenium" or "api"
  encoding: "utf-8"     # or "shift_jis" etc.
  rate_limit: 2.0       # リクエスト間隔（秒）
  selectors:
    list_page: "https://target-site.com/therapists"
    therapist_item: ".therapist-card"
    name: ".therapist-name"
    schedule: ".schedule-table td"
    profile_url: "a.profile-link"
    image: "img.therapist-photo"
  schedule_parsing:
    format: "table"     # "table" / "list" / "text"
    time_format: "%H:%M"
    date_header: "th"
  notes: "2026-02-08 追加。rate_limit=2.0で設定。"
```

### Phase 5: テストの作成・更新

```python
# tests/test_scraping_target_site.py
import pytest

class TestTargetSiteScraping:
    """target-site のスクレイピングルールテスト"""

    def test_selector_name(self):
        """セラピスト名セレクタが正しく動作する"""
        html = '<div class="therapist-name">テスト太郎</div>'
        soup = BeautifulSoup(html, "html.parser")
        result = soup.select_one(".therapist-name")
        assert result is not None
        assert result.text == "テスト太郎"

    def test_selector_schedule(self):
        """スケジュールセレクタが正しく動作する"""
        # テストHTMLを用意してセレクタを検証
        pass

    def test_rate_limit(self):
        """レートリミットが設定されている"""
        config = load_scraping_config()
        site = next(s for s in config if s["name"] == "target-site")
        assert site["rate_limit"] >= 1.0  # 最低1秒間隔
```

### Phase 6: 動作確認

```bash
# ドライラン（実際のスクレイピングを実行してデータを確認）
python -m app.services.scraping_service --site target-site --dry-run

# 取得データの確認
# - セラピスト名が正しく取得できているか
# - スケジュールが正しくパースできているか
# - 文字化けがないか
```

## チェックリスト

### 事前調査
- [ ] サイトにアクセスできることを確認した
- [ ] HTMLを取得してデータの有無を確認した
- [ ] strategy を判定した（requests / selenium / api）
- [ ] 文字コードを確認した

### セレクタ特定
- [ ] セラピスト名のセレクタを特定した
- [ ] スケジュールのセレクタを特定した
- [ ] プロフィールURLのセレクタを特定した
- [ ] 複数ページ（一覧/詳細）のセレクタを特定した

### 設定追加
- [ ] YAML設定ファイルに追記した
- [ ] rate_limit を適切に設定した（最低1秒、推奨2秒以上）
- [ ] enabled: true を設定した
- [ ] notes にメモを記載した

### テスト
- [ ] セレクタのユニットテストを作成した
- [ ] ドライランで正しくデータが取得できた
- [ ] 文字化けがないことを確認した

## トラブルシューティング

### curlでHTMLが取得できない
- User-Agentを設定する: `curl -H "User-Agent: Mozilla/5.0 ..." ...`
- Cookieが必要な場合: `curl -b "session=xxx" ...`
- CloudflareのWAF: selenium + undetected-chromedriver を検討

### 文字化けする
- `encoding` を正しく設定する（`shift_jis`, `euc-jp` 等）
- metaタグの charset を確認: `grep -i charset /tmp/target.html`

### セレクタが不安定（サイト更新で壊れやすい）
- クラス名よりも構造的なセレクタを使う（`div > ul > li:nth-child(2)`）
- data属性があれば活用する（`[data-therapist-id]`）
- 複数のフォールバックセレクタを設定する

## 注意事項
- **robots.txt を必ず確認**: クロールが許可されているパスのみ対象にする
- **レートリミットは必須**: サーバーに過負荷をかけない（最低1秒間隔）
- **利用規約を確認**: スクレイピングが禁止されていないか
- **個人情報の取り扱い**: 取得したデータの保管・利用は適切に
