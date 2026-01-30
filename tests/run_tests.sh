#!/bin/bash
# uesama テストランナー
set -e

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

pass() {
    PASS=$((PASS + 1))
    echo "  ✓ $1"
}

fail() {
    FAIL=$((FAIL + 1))
    echo "  ✗ $1"
    echo "    $2"
}

echo ""
echo "  ╔══════════════════════════════════════════════╗"
echo "  ║  🏯 uesama テスト                             ║"
echo "  ╚══════════════════════════════════════════════╝"
echo ""

# ==================================================================
# 1. 必須ファイルの存在チェック
# ==================================================================
echo "  [必須ファイル]"
for f in \
    bin/uesama \
    bin/uesama-daimyo \
    bin/uesama-agents \
    bin/uesama-stop \
    scripts/start.sh \
    scripts/setup.sh \
    install.sh \
    uninstall.sh \
    .uesama/instructions/daimyo.md \
    .uesama/instructions/sanbo.md \
    .uesama/instructions/kashin.md \
    .uesama/templates/context.md \
    .claude/rules/uesama.md; do
    if [ -f "$PROJECT_ROOT/$f" ]; then
        pass "$f exists"
    else
        fail "$f exists" "file not found"
    fi
done

# ==================================================================
# 2. 実行権限チェック
# ==================================================================
echo ""
echo "  [実行権限]"
for f in bin/uesama bin/uesama-daimyo bin/uesama-agents bin/uesama-stop \
         scripts/start.sh scripts/setup.sh install.sh uninstall.sh; do
    if [ -x "$PROJECT_ROOT/$f" ]; then
        pass "$f is executable"
    else
        fail "$f is executable" "missing execute permission"
    fi
done

# ==================================================================
# 3. シェバン行チェック
# ==================================================================
echo ""
echo "  [シェバン行]"
for f in bin/uesama bin/uesama-daimyo bin/uesama-agents bin/uesama-stop \
         scripts/start.sh scripts/setup.sh install.sh uninstall.sh; do
    first_line=$(head -1 "$PROJECT_ROOT/$f")
    if echo "$first_line" | grep -qE '^#!/bin/(ba)?sh'; then
        pass "$f has valid shebang"
    else
        fail "$f has valid shebang" "got: $first_line"
    fi
done

# ==================================================================
# 4. install.sh の構造チェック
# ==================================================================
echo ""
echo "  [install.sh 構造]"
if grep -q 'UESAMA_HOME' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh sets UESAMA_HOME"
else
    fail "install.sh sets UESAMA_HOME" "UESAMA_HOME not found"
fi

if grep -q 'chmod +x' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh sets execute permissions"
else
    fail "install.sh sets execute permissions" "chmod +x not found"
fi

if grep -q 'trap' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh has cleanup trap"
else
    fail "install.sh has cleanup trap" "trap not found"
fi

# ==================================================================
# 5. start.sh の構造チェック
# ==================================================================
echo ""
echo "  [start.sh 構造]"
if grep -q 'tmux new-session' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh creates tmux sessions"
else
    fail "start.sh creates tmux sessions" "tmux new-session not found"
fi

if grep -q 'kashindan' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh references kashindan session"
else
    fail "start.sh references kashindan session" "kashindan not found"
fi

if grep -q 'daimyo' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh references daimyo session"
else
    fail "start.sh references daimyo session" "daimyo not found"
fi

# ==================================================================
# 6. テンプレートファイルチェック
# ==================================================================
echo ""
echo "  [テンプレート]"
if grep -q 'DAIMYO\|daimyo\|大名' "$PROJECT_ROOT/.uesama/instructions/daimyo.md"; then
    pass "daimyo.md contains daimyo instructions"
else
    fail "daimyo.md contains daimyo instructions" "content mismatch"
fi

if grep -q 'SANBO\|sanbo\|参謀' "$PROJECT_ROOT/.uesama/instructions/sanbo.md"; then
    pass "sanbo.md contains sanbo instructions"
else
    fail "sanbo.md contains sanbo instructions" "content mismatch"
fi

if grep -q 'kashin\|家臣' "$PROJECT_ROOT/.uesama/instructions/kashin.md"; then
    pass "kashin.md contains kashin instructions"
else
    fail "kashin.md contains kashin instructions" "content mismatch"
fi

# ==================================================================
# 7. install.sh 実動テスト（隔離環境）
# ==================================================================
echo ""
echo "  [install.sh 実動テスト]"
INSTALL_TMPDIR=$(mktemp -d)
FAKE_HOME="$INSTALL_TMPDIR/fakehome"
mkdir -p "$FAKE_HOME"

# .bashrc を用意しておく（PATH 追加のため）
touch "$FAKE_HOME/.bashrc"

(
    export HOME="$FAKE_HOME"
    cd "$PROJECT_ROOT"
    bash install.sh > "$INSTALL_TMPDIR/install_out.txt" 2>&1
)
INSTALL_RC=$?

if [ "$INSTALL_RC" -eq 0 ]; then
    pass "install.sh exits 0"
else
    fail "install.sh exits 0" "exit code: $INSTALL_RC"
fi

if [ -d "$FAKE_HOME/.uesama" ]; then
    pass "install.sh creates ~/.uesama"
else
    fail "install.sh creates ~/.uesama" "directory not found"
fi

if [ -d "$FAKE_HOME/.uesama/bin" ]; then
    pass "install.sh copies bin/"
else
    fail "install.sh copies bin/" "bin/ not found"
fi

if [ -d "$FAKE_HOME/.uesama/scripts" ]; then
    pass "install.sh copies scripts/"
else
    fail "install.sh copies scripts/" "scripts/ not found"
fi

if [ -x "$FAKE_HOME/.uesama/bin/uesama" ]; then
    pass "install.sh makes bin/uesama executable"
else
    fail "install.sh makes bin/uesama executable" "not executable"
fi

if [ -d "$FAKE_HOME/.uesama/template/.uesama/instructions" ]; then
    pass "install.sh copies template/instructions"
else
    fail "install.sh copies template/instructions" "not found"
fi

if [ -f "$FAKE_HOME/.uesama/config/settings.yaml" ]; then
    pass "install.sh creates config/settings.yaml"
else
    fail "install.sh creates config/settings.yaml" "not found"
fi

if grep -q '\.uesama/bin' "$FAKE_HOME/.bashrc" 2>/dev/null; then
    pass "install.sh adds PATH to .bashrc"
else
    fail "install.sh adds PATH to .bashrc" "PATH entry not found"
fi

if grep -q 'UESAMA_HOME' "$FAKE_HOME/.bashrc" 2>/dev/null; then
    pass "install.sh adds UESAMA_HOME to .bashrc"
else
    fail "install.sh adds UESAMA_HOME to .bashrc" "UESAMA_HOME not found"
fi

# 再実行しても壊れないか（冪等性テスト）
(
    export HOME="$FAKE_HOME"
    cd "$PROJECT_ROOT"
    bash install.sh > "$INSTALL_TMPDIR/install_out2.txt" 2>&1
)
if [ $? -eq 0 ]; then
    pass "install.sh is idempotent (2nd run exits 0)"
else
    fail "install.sh is idempotent (2nd run exits 0)" "failed on 2nd run"
fi

# PATH が二重追加されていないか
PATH_COUNT=$(grep -c '\.uesama/bin' "$FAKE_HOME/.bashrc" 2>/dev/null || echo 0)
if [ "$PATH_COUNT" -le 2 ]; then
    pass "install.sh does not duplicate PATH entry"
else
    fail "install.sh does not duplicate PATH entry" "found $PATH_COUNT entries"
fi

rm -rf "$INSTALL_TMPDIR"

# ==================================================================
# 8. uninstall.sh 実動テスト
# ==================================================================
echo ""
echo "  [uninstall.sh 実動テスト]"
UNINSTALL_TMPDIR=$(mktemp -d)
FAKE_HOME2="$UNINSTALL_TMPDIR/fakehome"
mkdir -p "$FAKE_HOME2"
touch "$FAKE_HOME2/.bashrc"

# まずインストール
(
    export HOME="$FAKE_HOME2"
    cd "$PROJECT_ROOT"
    bash install.sh > /dev/null 2>&1
)

# アンインストール
(
    export HOME="$FAKE_HOME2"
    bash "$PROJECT_ROOT/uninstall.sh" > "$UNINSTALL_TMPDIR/uninstall_out.txt" 2>&1
)
UNINSTALL_RC=$?

if [ "$UNINSTALL_RC" -eq 0 ]; then
    pass "uninstall.sh exits 0"
else
    fail "uninstall.sh exits 0" "exit code: $UNINSTALL_RC"
fi

if [ ! -d "$FAKE_HOME2/.uesama" ]; then
    pass "uninstall.sh removes ~/.uesama"
else
    fail "uninstall.sh removes ~/.uesama" "directory still exists"
fi

# 存在しない状態で実行しても壊れないか
(
    export HOME="$FAKE_HOME2"
    bash "$PROJECT_ROOT/uninstall.sh" > /dev/null 2>&1
)
if [ $? -eq 0 ]; then
    pass "uninstall.sh handles missing ~/.uesama gracefully"
else
    fail "uninstall.sh handles missing ~/.uesama gracefully" "non-zero exit"
fi

rm -rf "$UNINSTALL_TMPDIR"

# ==================================================================
# 9. setup.sh の依存チェック動作テスト
# ==================================================================
echo ""
echo "  [setup.sh 依存チェック]"

# tmux が入っていればPATH上で見つかることを確認
if command -v tmux > /dev/null 2>&1; then
    SETUP_OUT=$(bash "$PROJECT_ROOT/scripts/setup.sh" 2>&1) || true
    if echo "$SETUP_OUT" | grep -q 'tmux'; then
        pass "setup.sh detects tmux"
    else
        fail "setup.sh detects tmux" "tmux not mentioned in output"
    fi
fi

# claude コマンドが無い環境ならエラーを返すことを確認
SETUP_TMPDIR=$(mktemp -d)
(
    export PATH="$SETUP_TMPDIR"
    bash "$PROJECT_ROOT/scripts/setup.sh" > "$SETUP_TMPDIR/out.txt" 2>&1
) && SETUP_RC=0 || SETUP_RC=$?

if [ "$SETUP_RC" -ne 0 ]; then
    pass "setup.sh fails when dependencies are missing"
else
    # tmux と claude が両方見つかった場合は成功して良い
    if command -v tmux > /dev/null 2>&1 && command -v claude > /dev/null 2>&1; then
        pass "setup.sh succeeds (all deps present)"
    else
        fail "setup.sh fails when dependencies are missing" "exit code: $SETUP_RC"
    fi
fi
rm -rf "$SETUP_TMPDIR"

# ==================================================================
# 10. uesama CLI の UESAMA_HOME チェック
# ==================================================================
echo ""
echo "  [uesama CLI]"
UESAMA_OUT=$(UESAMA_HOME="/nonexistent" bash "$PROJECT_ROOT/bin/uesama" 2>&1) && UESAMA_RC=0 || UESAMA_RC=$?

if [ "$UESAMA_RC" -ne 0 ]; then
    pass "uesama exits non-zero when UESAMA_HOME is invalid"
else
    fail "uesama exits non-zero when UESAMA_HOME is invalid" "exit code: $UESAMA_RC"
fi

if echo "$UESAMA_OUT" | grep -qi 'インストール\|install\|エラー\|error'; then
    pass "uesama shows install message when UESAMA_HOME missing"
else
    fail "uesama shows install message when UESAMA_HOME missing" "output: $UESAMA_OUT"
fi

# ==================================================================
# 11. start.sh の KASHIN_COUNT 変数チェック
# ==================================================================
echo ""
echo "  [start.sh 設定]"
if grep -q 'KASHIN_COUNT' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh supports KASHIN_COUNT configuration"
else
    fail "start.sh supports KASHIN_COUNT configuration" "KASHIN_COUNT not found"
fi

if grep -q 'UESAMA_KASHIN_COUNT' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh reads UESAMA_KASHIN_COUNT env var"
else
    fail "start.sh reads UESAMA_KASHIN_COUNT env var" "env var not found"
fi

if grep -q 'LANG_SETTING\|language' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh handles language setting"
else
    fail "start.sh handles language setting" "language handling not found"
fi

# ==================================================================
# 12. キューファイルテンプレートの構造チェック
# ==================================================================
echo ""
echo "  [キューファイル構造]"
# start.sh がキューファイルを正しい形式で生成するか（YAMLのキーが含まれているか）
if grep -q 'worker_id:' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh generates report YAML with worker_id"
else
    fail "start.sh generates report YAML with worker_id" "worker_id not found"
fi

if grep -q 'task_id:' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh generates task YAML with task_id"
else
    fail "start.sh generates task YAML with task_id" "task_id not found"
fi

if grep -q 'status:' "$PROJECT_ROOT/scripts/start.sh"; then
    pass "start.sh generates YAML with status field"
else
    fail "start.sh generates YAML with status field" "status not found"
fi

# ==================================================================
# 13. セキュリティチェック
# ==================================================================
echo ""
echo "  [セキュリティ]"

# set -e が全スクリプトにあるか
for f in bin/uesama bin/uesama-stop scripts/start.sh scripts/setup.sh install.sh uninstall.sh; do
    if grep -q 'set -e' "$PROJECT_ROOT/$f"; then
        pass "$f has set -e"
    else
        fail "$f has set -e" "missing set -e (unsafe on error)"
    fi
done

# eval が無いことを確認（インジェクション防止）
SCRIPTS_WITH_EVAL=""
for f in bin/uesama bin/uesama-daimyo bin/uesama-agents bin/uesama-stop \
         scripts/start.sh scripts/setup.sh install.sh uninstall.sh; do
    if grep -qE '^\s*eval ' "$PROJECT_ROOT/$f"; then
        SCRIPTS_WITH_EVAL="$SCRIPTS_WITH_EVAL $f"
    fi
done
if [ -z "$SCRIPTS_WITH_EVAL" ]; then
    pass "no scripts use eval"
else
    fail "no scripts use eval" "found in:$SCRIPTS_WITH_EVAL"
fi

# ==================================================================
# 14. pre-commit フックチェック
# ==================================================================
echo ""
echo "  [pre-commit フック]"

if [ -f "$PROJECT_ROOT/.githooks/pre-commit" ]; then
    pass ".githooks/pre-commit exists"
else
    fail ".githooks/pre-commit exists" "not found"
fi

if [ -x "$PROJECT_ROOT/.githooks/pre-commit" ]; then
    pass ".githooks/pre-commit is executable"
else
    fail ".githooks/pre-commit is executable" "missing execute permission"
fi

HOOK_FIRST=$(head -1 "$PROJECT_ROOT/.githooks/pre-commit")
if echo "$HOOK_FIRST" | grep -qE '^#!/bin/(ba)?sh'; then
    pass ".githooks/pre-commit has valid shebang"
else
    fail ".githooks/pre-commit has valid shebang" "got: $HOOK_FIRST"
fi

if grep -q 'shellcheck' "$PROJECT_ROOT/.githooks/pre-commit"; then
    pass "pre-commit hook runs shellcheck"
else
    fail "pre-commit hook runs shellcheck" "shellcheck not found in hook"
fi

if grep -q 'bash -n' "$PROJECT_ROOT/.githooks/pre-commit"; then
    pass "pre-commit hook runs syntax check"
else
    fail "pre-commit hook runs syntax check" "bash -n not found in hook"
fi

if grep -q 'install.sh' "$PROJECT_ROOT/install.sh" && grep -q 'githooks' "$PROJECT_ROOT/install.sh"; then
    pass "install.sh copies .githooks"
else
    fail "install.sh copies .githooks" "githooks not referenced in install.sh"
fi

if grep -q 'core.hooksPath' "$PROJECT_ROOT/scripts/setup-dev.sh"; then
    pass "setup-dev.sh sets core.hooksPath"
else
    fail "setup-dev.sh sets core.hooksPath" "core.hooksPath not found in setup-dev.sh"
fi

if [ -x "$PROJECT_ROOT/scripts/setup-dev.sh" ]; then
    pass "setup-dev.sh is executable"
else
    fail "setup-dev.sh is executable" "missing execute permission"
fi

if grep -q 'shellcheck' "$PROJECT_ROOT/scripts/setup-dev.sh" && \
   grep -q 'apt-get\|brew\|dnf\|pacman' "$PROJECT_ROOT/scripts/setup-dev.sh"; then
    pass "setup-dev.sh auto-installs ShellCheck"
else
    fail "setup-dev.sh auto-installs ShellCheck" "install logic not found"
fi

# install 実動テストで .githooks がコピーされるか
HOOK_TMPDIR=$(mktemp -d)
HOOK_HOME="$HOOK_TMPDIR/fakehome"
mkdir -p "$HOOK_HOME"
touch "$HOOK_HOME/.bashrc"

(
    export HOME="$HOOK_HOME"
    cd "$PROJECT_ROOT"
    bash install.sh > /dev/null 2>&1
)

if [ -x "$HOOK_HOME/.uesama/.githooks/pre-commit" ]; then
    pass "install.sh installs pre-commit hook with exec permission"
else
    fail "install.sh installs pre-commit hook with exec permission" "not found or not executable"
fi

rm -rf "$HOOK_TMPDIR"

# ==================================================================
# 結果
# ==================================================================
echo ""
TOTAL=$((PASS + FAIL))
echo "  結果: $PASS/$TOTAL passed"
echo ""

if [ "$FAIL" -gt 0 ]; then
    echo "  ✗ $FAIL test(s) failed"
    exit 1
else
    echo "  ✅ All tests passed"
fi
