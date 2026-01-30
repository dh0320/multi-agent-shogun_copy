#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# CLI Adapter - Claude Code & GitHub Copilot CLI の統一インターフェース
# ═══════════════════════════════════════════════════════════════════════════════
# 使用方法:
#   source lib/cli_adapter.sh
#   cli_type=$(get_cli_type "shogun" "config/settings.yaml")
#   cli_command=$(build_cli_command "shogun" "$cli_type" "config/settings.yaml")
# ═══════════════════════════════════════════════════════════════════════════════

# CLIタイプを取得（エージェント名から）
# 引数:
#   $1: エージェント名 (shogun, karo, ashigaru1-8)
#   $2: settings.yamlのパス
# 出力: CLIタイプ (claude または copilot)
get_cli_type() {
    local agent_name="$1"
    local yaml_config="$2"

    # ファイルが存在しない場合はデフォルト
    if [ ! -f "$yaml_config" ]; then
        echo "claude"
        return 0
    fi

    # エージェント固有の設定をチェック（厳密なインデントマッチング）
    local agent_type=$(awk -v agent="$agent_name" '
        /^cli:/ { in_cli=1; next }
        in_cli && /^  agents:/ { in_agents=1; next }
        in_agents && $0 ~ "^    " agent ":" { in_target=1; next }
        in_target && /^      type:/ { print $2; exit }
        in_target && /^    [a-z]/ { exit }
        /^[a-z]/ { in_cli=0; in_agents=0; in_target=0 }
    ' "$yaml_config" | tr -d '"' | tr -d "'")

    if [ -n "$agent_type" ]; then
        # バリデーション: claude または copilot のみ許可
        case "$agent_type" in
            claude|copilot)
                echo "$agent_type"
                ;;
            *)
                echo "claude"  # 不正値の場合はデフォルト
                ;;
        esac
    else
        # デフォルトCLIタイプを取得
        local default_type=$(awk '/^cli:/ { in_cli=1; next }
                                   in_cli && /^  default:/ { print $2; exit }
                                   /^[a-z]/ { exit }' "$yaml_config" | tr -d '"' | tr -d "'")

        # バリデーション
        case "$default_type" in
            claude|copilot)
                echo "$default_type"
                ;;
            *)
                echo "claude"  # 不正値またはデフォルト
                ;;
        esac
    fi
}

# エージェント用のCLIコマンドを構築
# 引数:
#   $1: エージェント名 (shogun, karo, ashigaru1-8)
#   $2: CLIタイプ (claude, copilot)
#   $3: settings.yamlのパス
# 出力: 実行可能なコマンド文字列
build_cli_command() {
    local agent_name="$1"
    local cli_type="$2"
    local yaml_config="$3"

    local base_cmd=""
    local options=""
    local env_vars=""

    case "$cli_type" in
        claude)
            base_cmd="claude"

            # エージェント固有の環境変数
            env_vars=$(get_agent_env "$agent_name" "$yaml_config")

            # エージェント固有のモデル設定
            local model=$(get_agent_model "$agent_name" "$yaml_config")
            if [ -n "$model" ]; then
                options="--model \"$model\""
            fi

            # デフォルトオプション追加
            options="$options --dangerously-skip-permissions"
            ;;

        copilot)
            base_cmd="copilot"

            # エージェント固有の環境変数
            env_vars=$(get_agent_env "$agent_name" "$yaml_config")

            # デフォルトオプション
            options="--allow-all --allow-all-tools --allow-all-paths"
            ;;

        *)
            echo "Error: Unknown CLI type: $cli_type" >&2
            return 1
            ;;
    esac

    # 環境変数 + コマンド + オプション
    if [ -n "$env_vars" ]; then
        echo "${env_vars} ${base_cmd} ${options}"
    else
        echo "${base_cmd} ${options}"
    fi
}

# エージェント固有のモデル設定を取得
# 引数:
#   $1: エージェント名
#   $2: settings.yamlのパス
# 出力: モデル名（なければ空文字）
get_agent_model() {
    local agent_name="$1"
    local yaml_config="$2"

    if [ ! -f "$yaml_config" ]; then
        return 0
    fi

    awk -v agent="$agent_name" '
        /^cli:/ { in_cli=1; next }
        in_cli && /^  agents:/ { in_agents=1; next }
        in_agents && $0 ~ "^    " agent ":" { in_target=1; next }
        in_target && /^      model:/ { print $2; exit }
        in_target && /^    [a-z]/ { exit }
        /^[a-z]/ { exit }
    ' "$yaml_config" | tr -d '"' | tr -d "'"
}

# エージェント固有の環境変数を取得
# 引数:
#   $1: エージェント名
#   $2: settings.yamlのパス
# 出力: 環境変数の設定文字列（例: "MAX_THINKING_TOKENS=0"）
get_agent_env() {
    local agent_name="$1"
    local yaml_config="$2"

    if [ ! -f "$yaml_config" ]; then
        return 0
    fi

    # エージェント設定ブロックを抽出
    local env_str=""
    local in_agent=false
    local in_env=false

    while IFS= read -r line; do
        # エージェントセクション開始（厳密なインデントチェック）
        if echo "$line" | grep -q "^    ${agent_name}:"; then
            in_agent=true
            continue
        fi

        # 次のエージェントセクション開始（終了）
        if [ "$in_agent" = true ] && echo "$line" | grep -q "^    [a-z]"; then
            break
        fi

        # env セクション開始
        if [ "$in_agent" = true ] && echo "$line" | grep -q "^      env:"; then
            in_env=true
            continue
        fi

        # env の値を取得
        if [ "$in_agent" = true ] && [ "$in_env" = true ]; then
            if echo "$line" | grep -q "^        [A-Z_]"; then
                local key=$(echo "$line" | awk '{print $1}' | tr -d ':')
                local value=$(echo "$line" | awk '{print $2}' | tr -d '"' | tr -d "'")

                # 環境変数の置換（${VAR_NAME} 形式）
                if echo "$value" | grep -q '^\${.*}$'; then
                    local var_name=$(echo "$value" | sed 's/\${//g' | sed 's/}//g')
                    value="${!var_name}"
                fi

                if [ -n "$env_str" ]; then
                    env_str="$env_str "
                fi
                env_str="${env_str}${key}=${value}"
            elif echo "$line" | grep -q "^      [a-z]"; then
                # env セクション終了
                break
            fi
        fi
    done < "$yaml_config"

    echo "$env_str"
}

# CLI が利用可能かチェック
# 引数:
#   $1: CLIタイプ (claude, copilot)
# 戻り値: 0=利用可能, 1=利用不可
validate_cli_availability() {
    local cli_type="$1"

    case "$cli_type" in
        claude)
            if ! command -v claude &>/dev/null; then
                echo "Error: Claude Code CLI が見つかりません" >&2
                echo "インストール: npm install -g @anthropic-ai/claude-code" >&2
                return 1
            fi
            return 0
            ;;
        copilot)
            if ! command -v copilot &>/dev/null; then
                echo "Error: GitHub Copilot CLI が見つかりません" >&2
                echo "インストール: brew install gh (or apt/yum), then gh extension install github/gh-copilot" >&2
                return 1
            fi

            # GitHub認証チェック（警告のみ）
            if ! gh auth status &>/dev/null 2>&1; then
                echo "Warning: GitHub にログインしていません" >&2
                echo "認証: gh auth login" >&2
                # 警告のみで続行
            fi
            return 0
            ;;
        *)
            echo "Error: Unknown CLI type: $cli_type" >&2
            return 1
            ;;
    esac
}

# Copilot用の指示書を生成
# 引数:
#   $1: エージェント名
#   $2: 指示書ディレクトリ (instructions/)
#   $3: 出力先 (.github/copilot-instructions-*.md)
generate_copilot_instructions() {
    local agent_name="$1"
    local instructions_dir="$2"
    local output_file="$3"

    local instruction_file="${instructions_dir}/${agent_name}.md"

    if [ ! -f "$instruction_file" ]; then
        echo "Warning: Instruction file not found: $instruction_file" >&2
        return 1
    fi

    # .github ディレクトリを作成
    mkdir -p "$(dirname "$output_file")"

    # 指示書をコピー
    cat "$instruction_file" > "$output_file"

    # グローバルコンテキストを追加（存在する場合）
    if [ -f "memory/global_context.md" ]; then
        echo "" >> "$output_file"
        echo "---" >> "$output_file"
        echo "" >> "$output_file"
        cat "memory/global_context.md" >> "$output_file"
    fi

    return 0
}
