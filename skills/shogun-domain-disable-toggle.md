# domain-disable-toggle

## 概要
YAML設定ファイルの `enabled: false` フラグによるドメイン（スクレイピング対象サイト、外部API連携先等）の論理無効化パターン。物理削除ではなく論理的に無効化することで、可逆性を保ちつつ安全にドメインを停止できる。

## 使用場面
- スクレイピング対象サイトが一時的にダウンしている時
- 外部API連携先のメンテナンス時に一時停止したい時
- 新規ドメイン追加時に段階的に有効化したい時
- 問題のあるドメインを即座に停止したい時（ロールバック容易）
- テスト時に特定ドメインのみ有効にしたい時

## トリガーワード
- 「ドメイン無効化」「サイト停止」「スクレイピング停止」
- 「enabled false」「ドメイントグル」「一時停止」
- 「domain disable」「feature toggle」

## 前提条件
- YAML設定ファイルでドメイン/サイトを管理していること
- アプリケーションが `enabled` フラグをチェックするロジックを持つこと

## 手順

### Phase 1: YAML設定への enabled フラグ追加

既存のYAML設定に `enabled` フィールドを追加する。

```yaml
# config/scraping_rules.yaml （例）
domains:
  - name: "example-site-a"
    url: "https://example-a.com"
    enabled: true  # ← 追加
    strategy: "selenium"
    selectors:
      name: ".therapist-name"
      schedule: ".schedule-table"

  - name: "example-site-b"
    url: "https://example-b.com"
    enabled: false  # ← 無効化！
    strategy: "requests"
    disabled_reason: "サイトリニューアル中。2026-03月頃復旧予定"
    disabled_at: "2026-02-07"
    selectors:
      name: ".name"
      schedule: ".timetable"
```

**必須フィールド**:
| フィールド | 型 | 説明 |
|-----------|-----|------|
| `enabled` | bool | true=有効、false=無効 |
| `disabled_reason` | string | 無効化の理由（enabled: false の時のみ） |
| `disabled_at` | string | 無効化した日時 |

### Phase 2: アプリケーション側のフィルタリング

```python
# Python の場合
import yaml

def load_enabled_domains(config_path: str) -> list[dict]:
    """enabled: true のドメインのみ返す"""
    with open(config_path) as f:
        config = yaml.safe_load(f)

    enabled = [d for d in config["domains"] if d.get("enabled", True)]
    disabled = [d for d in config["domains"] if not d.get("enabled", True)]

    if disabled:
        names = [d["name"] for d in disabled]
        logger.info(f"Disabled domains (skipped): {', '.join(names)}")

    return enabled
```

```typescript
// TypeScript の場合
interface DomainConfig {
  name: string;
  url: string;
  enabled: boolean;
  disabled_reason?: string;
  disabled_at?: string;
}

function loadEnabledDomains(config: DomainConfig[]): DomainConfig[] {
  const enabled = config.filter(d => d.enabled !== false);
  const disabled = config.filter(d => d.enabled === false);

  if (disabled.length > 0) {
    console.log(`Disabled domains: ${disabled.map(d => d.name).join(', ')}`);
  }

  return enabled;
}
```

### Phase 3: 無効化の実行

```bash
# 1. 設定ファイルを編集
# enabled: true → enabled: false に変更
# disabled_reason と disabled_at を追加

# 2. 変更をコミット（理由をコミットメッセージに記載）
git add config/scraping_rules.yaml
git commit -m "config: disable example-site-b (サイトリニューアル中)"

# 3. デプロイ（設定変更のみなのでリスク低）
git push
```

### Phase 4: 復旧（再有効化）

```bash
# 1. enabled: false → enabled: true に変更
# 2. disabled_reason と disabled_at を削除
# 3. コミット・デプロイ
git commit -m "config: re-enable example-site-b (リニューアル完了)"
```

## チェックリスト

### 無効化時
- [ ] `enabled: false` に変更した
- [ ] `disabled_reason` に理由を記載した
- [ ] `disabled_at` に日時を記載した
- [ ] アプリケーションが `enabled` フラグをチェックしていることを確認した
- [ ] コミットメッセージに無効化理由を記載した
- [ ] 他のドメインに影響がないことを確認した

### 復旧時
- [ ] `enabled: true` に戻した
- [ ] `disabled_reason` と `disabled_at` を削除した
- [ ] 対象ドメインが正常に動作することを確認した
- [ ] コミットメッセージに復旧理由を記載した

## トラブルシューティング

### enabled フラグがない既存ドメインの扱い
`d.get("enabled", True)` のようにデフォルト値を `True` にすることで、既存設定に `enabled` がなくても有効として扱われる。段階的に全ドメインに `enabled: true` を明示追加していく。

### 無効化したドメインを忘れてしまう
定期的に disabled ドメインの棚卸しを行う:
```bash
# YAML から disabled ドメインを抽出
grep -B2 "enabled: false" config/scraping_rules.yaml
```

### 環境別に有効/無効を切り替えたい
環境変数で上書きするパターン:
```python
import os
# ENABLE_DOMAIN_X=false で環境別に上書き
env_override = os.getenv(f"ENABLE_{domain['name'].upper()}")
if env_override is not None:
    domain['enabled'] = env_override.lower() == 'true'
```

## 注意事項
- 物理削除（設定自体の削除）は避ける。復旧時に設定を再入力する手間が発生する
- `disabled_reason` は必ず記載する。3ヶ月後に「なぜ無効化したか」がわからなくなる
- 無効化したドメインは月次で棚卸しし、不要なら物理削除を検討する
