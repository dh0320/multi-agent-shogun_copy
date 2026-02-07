# tmux Safe Rename - Skill Definition

**Skill ID**: `tmux-safe-rename`
**Category**: DevOps / Multi-Agent System Administration
**Version**: 1.0.0
**Created**: 2026-02-07
**Platform**: tmux + Claude Code (multi-agent-shogun)

---

## Overview

tmuxセッション名を変更禁止としつつ、エージェントの表示名・agent_id のみ安全に改名するスキル。
変更禁止パターンの自動検出、影響範囲の一括特定、布陣図（AA）の列幅自動調整ロジックを提供する。

cmd_092（大奥→御台所改名）の実戦知見を体系化したもの。

---

## Use Cases

- **エージェント改名**: `karo-ooku` → `midaidokoro` のような agent_id 変更
- **表示名変更**: `大奥` → `御台所` のような日本語表示名の変更
- **新規エージェント追加時の命名**: 新しいペインを追加した際のID・表示名設定
- **布陣図のレイアウト修正**: ラベル長変更に伴うAA列幅の再調整

---

## Skill Input

When invoked, this skill requires:

1. **変更対象**
   - 旧名称（agent_id, 表示名、またはその両方）
   - 新名称

2. **変更スコープ**
   - agent_id のみ / 表示名のみ / 両方
   - セッション名の変更を含むか（通常は「含まない」= 禁止）

---

## Implementation

### Phase 1: 変更禁止パターンの検出

以下のtmuxセッション名は **絶対に変更してはならない**。システム全体のペイン参照（`tmux send-keys -t SESSION:WINDOW.PANE`）が壊れる。

```
変更禁止セッション名:
  - shogun       （将軍セッション）
  - multiagent   （老中・足軽セッション）
  - ooku         （御台所・部屋子・お針子セッション）

変更禁止ウィンドウ名:
  - main          （shogun:main）
  - agents        （multiagent:agents, ooku:agents）
```

#### 禁止パターン検出コマンド

```bash
# セッション名の使用箇所を検出（変更すると全通信が壊れる）
grep -rn 'multiagent:\|ooku:\|shogun:' \
  CLAUDE.md instructions/ scripts/ shutsujin_departure.sh

# ウィンドウ名の使用箇所を検出
grep -rn ':agents\.\|:main' \
  CLAUDE.md instructions/ scripts/ shutsujin_departure.sh
```

**判定ルール**: 上記コマンドの出力が50箇所以上なら、セッション名/ウィンドウ名の変更は事実上不可能。影響範囲が大きすぎるため拒否すること。

---

### Phase 2: 安全な変更対象の特定

以下は安全に変更できる識別子:

| 識別子 | 定義場所 | 参照箇所 | 変更リスク |
|--------|----------|----------|-----------|
| `@agent_id` | shutsujin_departure.sh | CLAUDE.md, instructions/*.md | 中（文書更新必須） |
| 表示名（display_name） | init_db.py, shutsujin_departure.sh | dashboard.md, 布陣図AA | 低 |
| プロンプトラベル | shutsujin_departure.sh | ターミナル表示のみ | 低 |
| ペインタイトル | shutsujin_departure.sh | ペインボーダー表示のみ | 低 |

#### @agent_id 変更時の影響ファイル一覧

```bash
# 旧名称の使用箇所を全検出（例: karo-ooku → midaidokoro）
OLD_ID="karo-ooku"
NEW_ID="midaidokoro"

grep -rn "$OLD_ID" \
  CLAUDE.md \
  instructions/ \
  scripts/init_db.py \
  scripts/botsunichiroku.py \
  shutsujin_departure.sh \
  dashboard.md \
  config/
```

---

### Phase 3: shutsujin_departure.sh の対応箇所

shutsujin_departure.sh はシステム起動の根幹。以下の配列・変数を正確に更新する必要がある。

#### multiagent セッション関連（老中・足軽）

```bash
# 行602付近: ラベル配列（プロンプト表示用）
MA_LABELS=("karo-roju" "ashigaru1" "ashigaru2" "ashigaru3" "ashigaru4" "ashigaru5")

# 行603付近: プロンプトの色
MA_COLORS=("red" "blue" "blue" "blue" "blue" "blue")

# 行604付近: agent_id（tmuxカスタムオプション @agent_id に設定される値）
MA_AGENT_IDS=("karo-roju" "ashigaru1" "ashigaru2" "ashigaru3" "ashigaru4" "ashigaru5")

# 行607-611付近: ペインタイトル（決戦/平時で分岐）
MA_TITLES=("karo-roju(Opus)" "ashigaru1(Sonnet)" ...)
```

#### ooku セッション関連（御台所・部屋子・お針子）

```bash
# 行655付近: ラベル配列
OOKU_LABELS=("midaidokoro" "heyago1" "heyago2" "heyago3" "ohariko")

# 行656付近: プロンプトの色
OOKU_COLORS=("magenta" "cyan" "cyan" "cyan" "yellow")

# 行657付近: agent_id
OOKU_AGENT_IDS=("midaidokoro" "ashigaru6" "ashigaru7" "ashigaru8" "ohariko")

# 行660-664付近: ペインタイトル（決戦/平時で分岐）
OOKU_TITLES=("midaidokoro(Opus)" "heyago1(Opus)" ...)

# 行968付近: 部屋子の日本語名
HEYAGO_NAMES=("部屋子1" "部屋子2" "部屋子3")
HEYAGO_ASHIGARU_NUMS=(6 7 8)
```

#### 配列変更の注意事項

- **インデックスの対応を崩すな**: `MA_LABELS[0]` と `MA_AGENT_IDS[0]` と `MA_COLORS[0]` は同一ペインを指す
- **決戦モードと平時モードの両方を更新**: TITLES配列は if/else で2箇所ある
- **generate_prompt 呼び出しも確認**: ラベルと色を渡している

---

### Phase 4: CLAUDE.md / instructions/*.md のペイン参照一括置換

#### 検出コマンド

```bash
# CLAUDE.md 内の旧名称
OLD_DISPLAY="大奥"
NEW_DISPLAY="御台所"

grep -n "$OLD_DISPLAY" CLAUDE.md
grep -n "$OLD_DISPLAY" instructions/karo.md instructions/shogun.md \
  instructions/ashigaru.md instructions/ohariko.md
```

#### 置換対象パターン（典型例）

| パターン | 例 | 置換先 |
|----------|-----|--------|
| ペイン対応表 | `大奥=ooku:agents.0` | `御台所=ooku:agents.0` |
| 階層構造図 | `KARO-OOKU (大奥)` | `MIDAIDOKORO (御台所)` |
| 通信プロトコル | `家老→大奥` | `家老→御台所` |
| 口調表 | `大奥・部屋子` | `御台所・部屋子` |
| コンパクション復帰表 | `大奥: ooku:agents.0` | `御台所: ooku:agents.0` |

#### 置換時の注意

- **セッション名 `ooku` は変更しない**: `ooku:agents.0` の `ooku` 部分はセッション名であり変更禁止
- **コマンド例中のペインターゲットに注意**: `tmux send-keys -t ooku:agents.0` の `ooku` は残す
- **歴史的記録は変更しない**: dashboard.md のログ内にある旧名称（例: `cmd_092 大奥→御台所改名`）は記録として残す

---

### Phase 5: scripts/init_db.py の更新

```python
# DEFAULT_AGENTS 配列（行126付近）を更新
# フォーマット: (id, role, display_name, model, status, current_task_id, pane_target)

# 変更前:
("karo-ooku", "karo", "大奥", "opus", "idle", None, "ooku:agents.0"),

# 変更後:
("midaidokoro", "karo", "御台所", "opus", "idle", None, "ooku:agents.0"),
#  ↑ id変更     ↑roleはそのまま  ↑表示名変更                  ↑セッション名は不変
```

**DB更新**: init_db.py は `INSERT OR IGNORE` のため、既存DBに対しては手動でUPDATEが必要:

```sql
-- 既存DBの agent レコードを更新
UPDATE agents SET id = 'midaidokoro', display_name = '御台所' WHERE id = 'karo-ooku';
```

---

### Phase 6: 布陣図（AA）の列幅自動調整

shutsujin_departure.sh の STEP 7 に布陣図（ASCII Art）がある。ラベル長が変わると列幅の調整が必要。

#### 列幅計算ロジック

```bash
# ラベルの表示幅を計算（全角=2, 半角=1）
calc_display_width() {
    local str="$1"
    local width=0
    for ((i=0; i<${#str}; i++)); do
        local char="${str:$i:1}"
        # UTF-8マルチバイト文字（日本語等）は幅2
        if [[ $(printf '%d' "'$char") -gt 127 ]]; then
            width=$((width + 2))
        else
            width=$((width + 1))
        fi
    done
    echo $width
}

# セル幅 = max(ラベル幅 + パディング2, 最小幅8)
cell_width() {
    local label="$1"
    local min_width=${2:-8}
    local label_width=$(calc_display_width "$label")
    local padded=$((label_width + 2))
    echo $(( padded > min_width ? padded : min_width ))
}
```

#### 布陣図テンプレート（ookuセッション例）

```
# 変更前（karo-ooku = 9文字、midaidokoro = 11文字）
┌───────────┬──────────┬──────────┐
│           │ heyago1  │          │
│           │ (部屋子1)│          │
│           ├──────────┤          │
│midaidokoro│ heyago2  │ ohariko  │
│ (御台所)  │ (部屋子2)│(お針子)  │
│           ├──────────┤          │
│           │ heyago3  │          │
│           │ (部屋子3)│          │
└───────────┴──────────┴──────────┘
```

#### 列幅調整手順

1. 新ラベルの表示幅を計算
2. 各列の最大幅を求める（ラベル幅 + パディング）
3. 罫線（`─`）の本数を幅に合わせる
4. 各行のラベルをセンタリングまたは左寄せ
5. 全行の合計幅が一致することを確認

---

## Pre-flight Checklist

改名作業を開始する前に、以下を必ず確認:

```
□ 変更対象がセッション名ではないことを確認
□ grep で旧名称の使用箇所を全検出済み
□ shutsujin_departure.sh の配列対応を確認（ラベル・ID・色・タイトルの4配列）
□ 決戦モード/平時モード両方のタイトル配列を確認
□ instructions/*.md のペイン対応表を確認
□ init_db.py の DEFAULT_AGENTS を確認
□ 既存DBのUPDATEクエリを準備（init_db は IGNORE のため）
□ 布陣図の列幅計算済み
□ 歴史的記録（dashboard.md のログ等）は変更しない方針を確認
```

---

## Execution Order

作業は以下の順序で実施する（依存関係を考慮）:

```
1. shutsujin_departure.sh
   └─ 配列（LABELS, AGENT_IDS, TITLES, COLORS）
   └─ generate_prompt 呼び出し
   └─ 布陣図（AA）
   └─ 指示書伝達メッセージ

2. scripts/init_db.py
   └─ DEFAULT_AGENTS

3. CLAUDE.md
   └─ ペイン対応表、階層構造図、通信プロトコル

4. instructions/karo.md
   └─ ペインターゲット、通信ルール

5. instructions/shogun.md
   └─ 状態確認コマンド、ペイン参照

6. instructions/ashigaru.md
   └─ assigned_by マッピング、報告先

7. instructions/ohariko.md
   └─ ペインターゲット

8. 既存DB更新（手動SQL）
   └─ UPDATE agents SET ...

9. 布陣図列幅の最終調整
   └─ shutsujin_departure.sh の echo 文
```

---

## Parallelization Strategy

改名タスクは以下の単位で並列化可能（3名並列の例）:

| Worker | 担当ファイル | 競合リスク |
|--------|-------------|-----------|
| Worker 1 | CLAUDE.md + dashboard.md + init_db.py + botsunichiroku.py | なし |
| Worker 2 | instructions/karo.md + shogun.md + ashigaru.md + ohariko.md | なし |
| Worker 3 | shutsujin_departure.sh（配列 + 布陣図 + メッセージ） | なし |

**重要**: 同一ファイルを複数Workerが触らないように分割すること（RACE-001回避）。

---

## Anti-Patterns

| NG | 理由 | 正しい方法 |
|----|------|-----------|
| セッション名 `ooku` を `midaidokoro` に変更 | 全ペイン参照が壊れる（50箇所以上） | セッション名は不変、agent_id のみ変更 |
| `sed -i 's/旧/新/g'` で一括置換 | セッション名まで置換される危険 | grep で事前確認後、ファイルごとに精密置換 |
| dashboard.md の過去ログも置換 | 歴史記録の改竄 | ログ内の旧名称は記録として保持 |
| init_db.py だけ更新してDB未更新 | `INSERT OR IGNORE` のため既存レコードは変わらない | init_db.py + SQLのUPDATE文を両方実行 |

---

## Validation

改名完了後の検証手順:

```bash
# 1. 旧名称が残っていないことを確認（歴史記録除く）
OLD="旧名称"
grep -rn "$OLD" CLAUDE.md instructions/ scripts/ shutsujin_departure.sh \
  | grep -v 'dashboard.md' | grep -v 'archive'

# 2. shutsujin_departure.sh の配列長が一致することを確認
grep -c 'MA_LABELS\|MA_AGENT_IDS\|MA_COLORS\|MA_TITLES' shutsujin_departure.sh

# 3. init_db.py の DEFAULT_AGENTS 件数確認
grep -c "ashigaru\|shogun\|roju\|midaidokoro\|ohariko" scripts/init_db.py

# 4. テスト実行（テストがあれば）
python3 -m pytest tests/ -v
```

---

## References

- cmd_092: 大奥→御台所改名（本スキルの元となった実戦タスク）
- CLAUDE.md: システム構成の正式ドキュメント
- shutsujin_departure.sh: tmuxセッション起動スクリプト
- scripts/init_db.py: DB初期化・エージェント定義

---

**Skill Author**: 部屋子3号（cmd_092 実戦知見より）
**Documented by**: 部屋子1号（ashigaru6）
**Last Updated**: 2026-02-07
**License**: Internal (multi-agent-shogun system)
