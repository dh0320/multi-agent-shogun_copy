#!/usr/bin/env bats
# ═══════════════════════════════════════════════════════════════════════════════
# CLI Adapter ユニットテスト
# ═══════════════════════════════════════════════════════════════════════════════
# 実行方法: bats tests/test_cli_adapter.sh
# ═══════════════════════════════════════════════════════════════════════════════

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    source "$SCRIPT_DIR/lib/cli_adapter.sh"
    TEST_YAML="$BATS_TMPDIR/test_settings.yaml"
}

teardown() {
    rm -f "$TEST_YAML"
}

# ─────────────────────────────────────────────────────────────────────────────
# get_cli_type テスト
# ─────────────────────────────────────────────────────────────────────────────

@test "get_cli_type: デフォルト値 claude（設定ファイルなし）" {
    result=$(get_cli_type "shogun" "/nonexistent/path.yaml")
    [ "$result" = "claude" ]
}

@test "get_cli_type: デフォルト設定を読み取る" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  default: copilot
EOF
    result=$(get_cli_type "shogun" "$TEST_YAML")
    [ "$result" = "copilot" ]
}

@test "get_cli_type: エージェント固有設定を優先" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  default: claude
  agents:
    ashigaru1:
      type: copilot
EOF
    result=$(get_cli_type "ashigaru1" "$TEST_YAML")
    [ "$result" = "copilot" ]
}

@test "get_cli_type: 不正値はclaude にフォールバック" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  default: invalid_cli
EOF
    result=$(get_cli_type "shogun" "$TEST_YAML")
    [ "$result" = "claude" ]
}

@test "get_cli_type: コメント行をスキップ" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  # default: copilot
  default: claude
EOF
    result=$(get_cli_type "shogun" "$TEST_YAML")
    [ "$result" = "claude" ]
}

@test "get_cli_type: エージェント固有の不正値はclaude にフォールバック" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  default: copilot
  agents:
    shogun:
      type: unknown
EOF
    result=$(get_cli_type "shogun" "$TEST_YAML")
    [ "$result" = "claude" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# get_agent_model テスト
# ─────────────────────────────────────────────────────────────────────────────

@test "get_agent_model: モデル設定を取得" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  agents:
    shogun:
      type: claude
      model: opus
EOF
    result=$(get_agent_model "shogun" "$TEST_YAML")
    [ "$result" = "opus" ]
}

@test "get_agent_model: モデル未設定で空文字" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  agents:
    shogun:
      type: claude
EOF
    result=$(get_agent_model "shogun" "$TEST_YAML")
    [ "$result" = "" ]
}

@test "get_agent_model: 設定ファイルなしで空文字" {
    result=$(get_agent_model "shogun" "/nonexistent/path.yaml")
    [ "$result" = "" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# get_agent_env テスト
# ─────────────────────────────────────────────────────────────────────────────

@test "get_agent_env: 環境変数を取得" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  agents:
    shogun:
      type: claude
      env:
        MAX_THINKING_TOKENS: "0"
EOF
    result=$(get_agent_env "shogun" "$TEST_YAML")
    [ "$result" = "MAX_THINKING_TOKENS=0" ]
}

@test "get_agent_env: 複数の環境変数を取得" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  agents:
    karo:
      type: claude
      env:
        MAX_THINKING_TOKENS: "0"
        SOME_FLAG: "true"
EOF
    result=$(get_agent_env "karo" "$TEST_YAML")
    [[ "$result" == *"MAX_THINKING_TOKENS=0"* ]]
    [[ "$result" == *"SOME_FLAG=true"* ]]
}

@test "get_agent_env: 許可リスト外の変数展開を拒否" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  agents:
    shogun:
      type: claude
      env:
        SECRET: "${DANGEROUS_VAR}"
EOF
    result=$(get_agent_env "shogun" "$TEST_YAML" 2>/dev/null)
    [ "$result" = "SECRET=" ]
}

@test "get_agent_env: 許可リスト内の変数展開を許可" {
    export HOME="/test/home"
    cat > "$TEST_YAML" <<'EOF'
cli:
  agents:
    shogun:
      type: claude
      env:
        MY_HOME: "${HOME}"
EOF
    result=$(get_agent_env "shogun" "$TEST_YAML")
    [ "$result" = "MY_HOME=/test/home" ]
}

@test "get_agent_env: 設定ファイルなしで空文字" {
    result=$(get_agent_env "shogun" "/nonexistent/path.yaml")
    [ "$result" = "" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# _get_copilot_options テスト
# ─────────────────────────────────────────────────────────────────────────────

@test "_get_copilot_options: 設定値を取得" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  copilot_options: "--allow-all --allow-all-tools"
EOF
    result=$(_get_copilot_options "$TEST_YAML")
    [ "$result" = "--allow-all --allow-all-tools" ]
}

@test "_get_copilot_options: 設定なしで空文字" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  default: claude
EOF
    result=$(_get_copilot_options "$TEST_YAML")
    [ "$result" = "" ]
}

@test "_get_copilot_options: ファイルなしで空文字" {
    result=$(_get_copilot_options "/nonexistent/path.yaml")
    [ "$result" = "" ]
}

# ─────────────────────────────────────────────────────────────────────────────
# build_cli_command テスト
# ─────────────────────────────────────────────────────────────────────────────

@test "build_cli_command: claude コマンド構築" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  default: claude
EOF
    result=$(build_cli_command "shogun" "claude" "$TEST_YAML")
    [[ "$result" == *"claude"* ]]
    [[ "$result" == *"--dangerously-skip-permissions"* ]]
}

@test "build_cli_command: copilot コマンド構築" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  default: copilot
  copilot_options: "--allow-all"
EOF
    result=$(build_cli_command "shogun" "copilot" "$TEST_YAML")
    [[ "$result" == *"gh copilot"* ]]
    [[ "$result" == *"--allow-all"* ]]
}

@test "build_cli_command: 不正CLIタイプでエラー" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  default: claude
EOF
    run build_cli_command "shogun" "invalid" "$TEST_YAML"
    [ "$status" -eq 1 ]
}

@test "build_cli_command: 環境変数付きclaude コマンド" {
    cat > "$TEST_YAML" <<'EOF'
cli:
  agents:
    shogun:
      type: claude
      env:
        MAX_THINKING_TOKENS: "0"
EOF
    result=$(build_cli_command "shogun" "claude" "$TEST_YAML")
    [[ "$result" == *"export"* ]]
    [[ "$result" == *"MAX_THINKING_TOKENS=0"* ]]
    [[ "$result" == *"claude"* ]]
}

# ─────────────────────────────────────────────────────────────────────────────
# validate_cli_availability テスト
# ─────────────────────────────────────────────────────────────────────────────

@test "validate_cli_availability: 不正CLIタイプでエラー" {
    run validate_cli_availability "invalid"
    [ "$status" -eq 1 ]
}

# ─────────────────────────────────────────────────────────────────────────────
# generate_copilot_instructions テスト
# ─────────────────────────────────────────────────────────────────────────────

@test "generate_copilot_instructions: 指示書が存在しない場合エラー" {
    run generate_copilot_instructions "shogun" "/nonexistent" "$BATS_TMPDIR/out.md"
    [ "$status" -eq 1 ]
}

@test "generate_copilot_instructions: 正常に指示書を生成" {
    mkdir -p "$BATS_TMPDIR/instructions"
    echo "# Test instructions" > "$BATS_TMPDIR/instructions/shogun.md"
    run generate_copilot_instructions "shogun" "$BATS_TMPDIR/instructions" "$BATS_TMPDIR/out.md"
    [ "$status" -eq 0 ]
    [ -f "$BATS_TMPDIR/out.md" ]
    grep -q "Test instructions" "$BATS_TMPDIR/out.md"
    rm -rf "$BATS_TMPDIR/instructions" "$BATS_TMPDIR/out.md"
}

@test "generate_copilot_instructions: ashigaru番号はashigaru.mdを使用" {
    mkdir -p "$BATS_TMPDIR/instructions"
    echo "# Ashigaru instructions" > "$BATS_TMPDIR/instructions/ashigaru.md"
    run generate_copilot_instructions "ashigaru3" "$BATS_TMPDIR/instructions" "$BATS_TMPDIR/out.md"
    [ "$status" -eq 0 ]
    grep -q "Ashigaru instructions" "$BATS_TMPDIR/out.md"
    rm -rf "$BATS_TMPDIR/instructions" "$BATS_TMPDIR/out.md"
}
