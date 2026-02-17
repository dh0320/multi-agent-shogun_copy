#!/usr/bin/env bats
# test_cli_adapter.bats — cli_adapter.sh ユニットテスト
# Multi-CLI統合設計書 §4.1 準拠

# --- セットアップ ---

setup() {
    # テスト用のtmpディレクトリ
    TEST_TMP="$(mktemp -d)"

    # プロジェクトルート
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

    # デフォルトsettings（cliセクションなし = 後方互換テスト）
    cat > "${TEST_TMP}/settings_none.yaml" << 'YAML'
language: ja
shell: bash
display_mode: shout
YAML

    # claude only settings
    cat > "${TEST_TMP}/settings_claude_only.yaml" << 'YAML'
cli:
  default: claude
YAML

    # mixed CLI settings (dict形式)
    cat > "${TEST_TMP}/settings_mixed.yaml" << 'YAML'
cli:
  default: claude
  agents:
    shogun:
      type: claude
      model: opus
    karo:
      type: claude
      model: opus
    ashigaru1:
      type: claude
      model: sonnet
    ashigaru2:
      type: claude
      model: sonnet
    ashigaru3:
      type: claude
      model: sonnet
    ashigaru4:
      type: claude
      model: sonnet
    ashigaru5:
      type: codex
    ashigaru6:
      type: codex
    ashigaru7:
      type: copilot
    ashigaru8:
      type: copilot
YAML

    # 文字列形式のagent設定
    cat > "${TEST_TMP}/settings_string_agents.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru5: codex
    ashigaru7: copilot
YAML

    # 不正CLI名
    cat > "${TEST_TMP}/settings_invalid_cli.yaml" << 'YAML'
cli:
  default: claudee
  agents:
    ashigaru1: invalid_cli
YAML

    # codexデフォルト
    cat > "${TEST_TMP}/settings_codex_default.yaml" << 'YAML'
cli:
  default: codex
YAML

    # 空ファイル
    cat > "${TEST_TMP}/settings_empty.yaml" << 'YAML'
YAML

    # YAML構文エラー
    cat > "${TEST_TMP}/settings_broken.yaml" << 'YAML'
cli:
  default: [broken yaml
  agents: {{invalid
YAML

    # モデル指定付き
    cat > "${TEST_TMP}/settings_with_models.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru1:
      type: claude
      model: haiku
    ashigaru5:
      type: codex
      model: gpt-5
models:
  karo: sonnet
YAML

    # kimi CLI settings
    cat > "${TEST_TMP}/settings_kimi.yaml" << 'YAML'
cli:
  default: claude
  agents:
    ashigaru3:
      type: kimi
      model: k2.5
    ashigaru4:
      type: kimi
YAML

    # kimi default settings
    cat > "${TEST_TMP}/settings_kimi_default.yaml" << 'YAML'
cli:
  default: kimi
YAML
}

teardown() {
    rm -rf "$TEST_TMP"
}

# ヘルパー: 特定のsettings.yamlでcli_adapterをロード
load_adapter_with() {
    local settings_file="$1"
    export CLI_ADAPTER_SETTINGS="$settings_file"
    source "${PROJECT_ROOT}/lib/cli_adapter.sh"
}

# =============================================================================
# get_cli_type テスト
# =============================================================================

# --- 正常系 ---

@test "get_cli_type: no cli section → claude (backward compat)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_cli_type "shogun")
    [ "$result" = "claude" ]
}

@test "get_cli_type: claude only config → claude" {
    load_adapter_with "${TEST_TMP}/settings_claude_only.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: mixed config shogun → claude" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "shogun")
    [ "$result" = "claude" ]
}

@test "get_cli_type: mixed config ashigaru5 → codex" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "ashigaru5")
    [ "$result" = "codex" ]
}

@test "get_cli_type: mixed config ashigaru7 → copilot" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "ashigaru7")
    [ "$result" = "copilot" ]
}

@test "get_cli_type: mixed config ashigaru1 → claude (individual config)" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: string format ashigaru5 → codex" {
    load_adapter_with "${TEST_TMP}/settings_string_agents.yaml"
    result=$(get_cli_type "ashigaru5")
    [ "$result" = "codex" ]
}

@test "get_cli_type: string format ashigaru7 → copilot" {
    load_adapter_with "${TEST_TMP}/settings_string_agents.yaml"
    result=$(get_cli_type "ashigaru7")
    [ "$result" = "copilot" ]
}

@test "get_cli_type: kimi config ashigaru3 → kimi" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_cli_type "ashigaru3")
    [ "$result" = "kimi" ]
}

@test "get_cli_type: kimi config ashigaru4 → kimi (no model specified)" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_cli_type "ashigaru4")
    [ "$result" = "kimi" ]
}

@test "get_cli_type: kimi default config → kimi" {
    load_adapter_with "${TEST_TMP}/settings_kimi_default.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "kimi" ]
}

@test "get_cli_type: undefined agent → inherits default" {
    load_adapter_with "${TEST_TMP}/settings_codex_default.yaml"
    result=$(get_cli_type "ashigaru3")
    [ "$result" = "codex" ]
}

@test "get_cli_type: empty agent_id → claude" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_cli_type "")
    [ "$result" = "claude" ]
}

# --- 全ashigaru パターン ---

@test "get_cli_type: mixed config ashigaru1-8 all patterns" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    [ "$(get_cli_type ashigaru1)" = "claude" ]
    [ "$(get_cli_type ashigaru2)" = "claude" ]
    [ "$(get_cli_type ashigaru3)" = "claude" ]
    [ "$(get_cli_type ashigaru4)" = "claude" ]
    [ "$(get_cli_type ashigaru5)" = "codex" ]
    [ "$(get_cli_type ashigaru6)" = "codex" ]
    [ "$(get_cli_type ashigaru7)" = "copilot" ]
    [ "$(get_cli_type ashigaru8)" = "copilot" ]
}

# --- エラー系 ---

@test "get_cli_type: invalid CLI name → claude fallback" {
    load_adapter_with "${TEST_TMP}/settings_invalid_cli.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: invalid default → claude fallback" {
    load_adapter_with "${TEST_TMP}/settings_invalid_cli.yaml"
    result=$(get_cli_type "karo")
    [ "$result" = "claude" ]
}

@test "get_cli_type: empty YAML file → claude" {
    load_adapter_with "${TEST_TMP}/settings_empty.yaml"
    result=$(get_cli_type "shogun")
    [ "$result" = "claude" ]
}

@test "get_cli_type: YAML syntax error → claude" {
    load_adapter_with "${TEST_TMP}/settings_broken.yaml"
    result=$(get_cli_type "ashigaru1")
    [ "$result" = "claude" ]
}

@test "get_cli_type: missing file → claude" {
    load_adapter_with "/nonexistent/path/settings.yaml"
    result=$(get_cli_type "shogun")
    [ "$result" = "claude" ]
}

# =============================================================================
# build_cli_command テスト
# =============================================================================

@test "build_cli_command: claude + model → claude --model opus --dangerously-skip-permissions" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(build_cli_command "shogun")
    [ "$result" = "claude --model opus --dangerously-skip-permissions" ]
}

@test "build_cli_command: codex → codex --dangerously-bypass-approvals-and-sandbox --no-alt-screen" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(build_cli_command "ashigaru5")
    [ "$result" = "codex --dangerously-bypass-approvals-and-sandbox --no-alt-screen" ]
}

@test "build_cli_command: copilot → copilot --yolo" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(build_cli_command "ashigaru7")
    [ "$result" = "copilot --yolo" ]
}

@test "build_cli_command: kimi + model → kimi --yolo --model k2.5" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(build_cli_command "ashigaru3")
    [ "$result" = "kimi --yolo --model k2.5" ]
}

@test "build_cli_command: kimi (no model specified) → kimi --yolo --model k2.5" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(build_cli_command "ashigaru4")
    [ "$result" = "kimi --yolo --model k2.5" ]
}

@test "build_cli_command: no cli section → claude fallback" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(build_cli_command "ashigaru1")
    [[ "$result" == claude*--dangerously-skip-permissions ]]
}

@test "build_cli_command: settings read failed → claude fallback" {
    load_adapter_with "/nonexistent/settings.yaml"
    result=$(build_cli_command "ashigaru1")
    [[ "$result" == claude*--dangerously-skip-permissions ]]
}

# =============================================================================
# get_instruction_file テスト
# =============================================================================

@test "get_instruction_file: shogun + claude → instructions/shogun.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "shogun")
    [ "$result" = "instructions/shogun.md" ]
}

@test "get_instruction_file: karo + claude → instructions/karo.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "karo")
    [ "$result" = "instructions/karo.md" ]
}

@test "get_instruction_file: ashigaru1 + claude → instructions/ashigaru.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "ashigaru1")
    [ "$result" = "instructions/ashigaru.md" ]
}

@test "get_instruction_file: ashigaru5 + codex → instructions/codex-ashigaru.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "ashigaru5")
    [ "$result" = "instructions/codex-ashigaru.md" ]
}

@test "get_instruction_file: ashigaru7 + copilot → .github/copilot-instructions-ashigaru.md" {
    load_adapter_with "${TEST_TMP}/settings_mixed.yaml"
    result=$(get_instruction_file "ashigaru7")
    [ "$result" = ".github/copilot-instructions-ashigaru.md" ]
}

@test "get_instruction_file: ashigaru3 + kimi → instructions/generated/kimi-ashigaru.md" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_instruction_file "ashigaru3")
    [ "$result" = "instructions/generated/kimi-ashigaru.md" ]
}

@test "get_instruction_file: shogun + kimi → instructions/generated/kimi-shogun.md" {
    load_adapter_with "${TEST_TMP}/settings_kimi_default.yaml"
    result=$(get_instruction_file "shogun")
    [ "$result" = "instructions/generated/kimi-shogun.md" ]
}

@test "get_instruction_file: cli_type arg explicit (codex)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_instruction_file "shogun" "codex")
    [ "$result" = "instructions/codex-shogun.md" ]
}

@test "get_instruction_file: cli_type arg explicit (copilot)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_instruction_file "karo" "copilot")
    [ "$result" = ".github/copilot-instructions-karo.md" ]
}

@test "get_instruction_file: all CLI × all role combinations" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # claude
    [ "$(get_instruction_file shogun claude)" = "instructions/shogun.md" ]
    [ "$(get_instruction_file karo claude)" = "instructions/karo.md" ]
    [ "$(get_instruction_file ashigaru1 claude)" = "instructions/ashigaru.md" ]
    # codex
    [ "$(get_instruction_file shogun codex)" = "instructions/codex-shogun.md" ]
    [ "$(get_instruction_file karo codex)" = "instructions/codex-karo.md" ]
    [ "$(get_instruction_file ashigaru3 codex)" = "instructions/codex-ashigaru.md" ]
    # copilot
    [ "$(get_instruction_file shogun copilot)" = ".github/copilot-instructions-shogun.md" ]
    [ "$(get_instruction_file karo copilot)" = ".github/copilot-instructions-karo.md" ]
    [ "$(get_instruction_file ashigaru5 copilot)" = ".github/copilot-instructions-ashigaru.md" ]
    # kimi
    [ "$(get_instruction_file shogun kimi)" = "instructions/generated/kimi-shogun.md" ]
    [ "$(get_instruction_file karo kimi)" = "instructions/generated/kimi-karo.md" ]
    [ "$(get_instruction_file ashigaru7 kimi)" = "instructions/generated/kimi-ashigaru.md" ]
}

@test "get_instruction_file: unknown agent_id → empty string + return 1" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run get_instruction_file "unknown_agent"
    [ "$status" -eq 1 ]
}

# =============================================================================
# validate_cli_availability テスト
# =============================================================================

@test "validate_cli_availability: claude → 0 (installed)" {
    command -v claude >/dev/null 2>&1 || skip "claude not installed (CI environment)"
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability "claude"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: invalid CLI name → 1 + error message" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability "invalid_type"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown CLI type"* ]]
}

@test "validate_cli_availability: empty string → 1" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    run validate_cli_availability ""
    [ "$status" -eq 1 ]
}

@test "validate_cli_availability: codex mock (PATH manipulation)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # モックcodexコマンドを作成
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/codex"
    chmod +x "${TEST_TMP}/bin/codex"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "codex"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: copilot mock (PATH manipulation)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/copilot"
    chmod +x "${TEST_TMP}/bin/copilot"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "copilot"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: kimi-cli mock (PATH manipulation)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/kimi-cli"
    chmod +x "${TEST_TMP}/bin/kimi-cli"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "kimi"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: kimi mock (PATH manipulation)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    mkdir -p "${TEST_TMP}/bin"
    echo '#!/bin/bash' > "${TEST_TMP}/bin/kimi"
    chmod +x "${TEST_TMP}/bin/kimi"
    PATH="${TEST_TMP}/bin:$PATH" run validate_cli_availability "kimi"
    [ "$status" -eq 0 ]
}

@test "validate_cli_availability: codex not installed → 1 + error message" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    # PATHからcodexを除外（空PATHは危険なのでminimal PATHを設定）
    PATH="/usr/bin:/bin" run validate_cli_availability "codex"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Codex CLI not found"* ]]
}

@test "validate_cli_availability: kimi not installed → 1 + error message" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    PATH="/usr/bin:/bin" run validate_cli_availability "kimi"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Kimi CLI not found"* ]]
}

# =============================================================================
# get_agent_model テスト
# =============================================================================

@test "get_agent_model: no cli section shogun → opus (default)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "shogun")
    [ "$result" = "opus" ]
}

@test "get_agent_model: no cli section karo → opus (default)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "karo")
    [ "$result" = "opus" ]
}

@test "get_agent_model: no cli section ashigaru1 → sonnet (default)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "ashigaru1")
    [ "$result" = "sonnet" ]
}

@test "get_agent_model: no cli section ashigaru5 → opus (default)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "ashigaru5")
    [ "$result" = "opus" ]
}

@test "get_agent_model: YAML specified ashigaru1 → haiku (override)" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "ashigaru1")
    [ "$result" = "haiku" ]
}

@test "get_agent_model: from models section karo → sonnet" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "karo")
    [ "$result" = "sonnet" ]
}

@test "get_agent_model: codex agent model ashigaru5 → gpt-5" {
    load_adapter_with "${TEST_TMP}/settings_with_models.yaml"
    result=$(get_agent_model "ashigaru5")
    [ "$result" = "gpt-5" ]
}

@test "get_agent_model: unknown agent → sonnet (default)" {
    load_adapter_with "${TEST_TMP}/settings_none.yaml"
    result=$(get_agent_model "unknown_agent")
    [ "$result" = "sonnet" ]
}

@test "get_agent_model: kimi CLI ashigaru3 → k2.5 (YAML specified)" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_agent_model "ashigaru3")
    [ "$result" = "k2.5" ]
}

@test "get_agent_model: kimi CLI ashigaru4 → k2.5 (default)" {
    load_adapter_with "${TEST_TMP}/settings_kimi.yaml"
    result=$(get_agent_model "ashigaru4")
    [ "$result" = "k2.5" ]
}

@test "get_agent_model: kimi CLI shogun → k2.5 (default)" {
    load_adapter_with "${TEST_TMP}/settings_kimi_default.yaml"
    result=$(get_agent_model "shogun")
    [ "$result" = "k2.5" ]
}

@test "get_agent_model: kimi CLI karo → k2.5 (default)" {
    load_adapter_with "${TEST_TMP}/settings_kimi_default.yaml"
    result=$(get_agent_model "karo")
    [ "$result" = "k2.5" ]
}
