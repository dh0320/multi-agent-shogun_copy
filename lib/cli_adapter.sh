#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# CLI Adapter - Claude Code & GitHub Copilot CLI の統一インターフェース
# ═══════════════════════════════════════════════════════════════════════════════
# 使用方法:
#   source lib/cli_adapter.sh
#   cli_type=$(get_cli_type "shogun" "config/settings.yaml")
#   cli_command=$(build_cli_command "shogun" "$cli_type" "config/settings.yaml")
# ═══════════════════════════════════════════════════════════════════════════════

# 間接変数展開の許可リスト
# セキュリティ上、展開可能な変数名をここに列挙する
_ALLOWED_VAR_EXPANSIONS="ANTHROPIC_API_KEY GITHUB_TOKEN OPENAI_API_KEY HOME USER PATH"

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
        /^[[:space:]]*#/ { next }
        { gsub(/\t/, "    ") }
        /^cli:/ { in_cli=1; next }
        in_cli && /^  agents:/ { in_agents=1; next }
        in_agents && $0 ~ "^    " agent ":" { in_target=1; next }
        in_target && /^      type:/ {
            val=$0; sub(/^.*type:[[:space:]]*/, "", val)
            gsub(/["'"'"']/, "", val)
            sub(/[[:space:]]*#.*$/, "", val)
            print val; exit
        }
        in_target && /^    [a-z]/ { exit }
        /^[a-z]/ { in_cli=0; in_agents=0; in_target=0 }
    ' "$yaml_config")

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
        local default_type=$(awk '
            /^[[:space:]]*#/ { next }
            { gsub(/\t/, "    ") }
            /^cli:/ { in_cli=1; next }
            in_cli && /^  default:/ {
                val=$0; sub(/^.*default:[[:space:]]*/, "", val)
                gsub(/["'"'"']/, "", val)
                sub(/[[:space:]]*#.*$/, "", val)
                print val; exit
            }
            in_cli && /^[a-z]/ { exit }
        ' "$yaml_config")

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

# Copilot用のオプションを settings.yaml から取得
# 引数:
#   $1: settings.yamlのパス
# 出力: オプション文字列（なければ空文字）
_get_copilot_options() {
    local yaml_config="$1"

    if [ ! -f "$yaml_config" ]; then
        return 0
    fi

    awk '
        /^[[:space:]]*#/ { next }
        { gsub(/\t/, "    ") }
        /^cli:/ { in_cli=1; next }
        in_cli && /copilot_options:/ {
            val=$0; sub(/^.*copilot_options:[[:space:]]*/, "", val)
            gsub(/["'"'"']/, "", val)
            sub(/[[:space:]]*#.*$/, "", val)
            print val; exit
        }
        in_cli && /^[a-z]/ { exit }
    ' "$yaml_config"
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
                options="--model $model"
            fi

            # デフォルトオプション追加
            options="$options --dangerously-skip-permissions"
            ;;

        copilot)
            base_cmd="gh copilot"

            # エージェント固有の環境変数
            env_vars=$(get_agent_env "$agent_name" "$yaml_config")

            # エージェント専用の指示書を標準ファイル名にコピー
            # Copilot CLI は .github/copilot-instructions.md しか読まないため
            local instructions_copy=""
            if [ -f ".github/copilot-instructions-${agent_name}.md" ]; then
                instructions_copy="cp .github/copilot-instructions-${agent_name}.md .github/copilot-instructions.md 2>/dev/null || true && "
            fi

            # パーミッション設定（settings.yaml から取得、なければデフォルト）
            local copilot_opts=$(_get_copilot_options "$yaml_config")
            if [ -z "$copilot_opts" ]; then
                copilot_opts="--allow-all --allow-all-tools --allow-all-paths"
            fi
            options="$copilot_opts"

            # コピーコマンド + copilot コマンドを結合
            base_cmd="${instructions_copy}${base_cmd}"
            ;;

        *)
            echo "Error: Unknown CLI type: $cli_type" >&2
            return 1
            ;;
    esac

    # 環境変数 + コマンド + オプション
    if [ -n "$env_vars" ]; then
        echo "export ${env_vars} && ${base_cmd} ${options}"
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
        /^[[:space:]]*#/ { next }
        { gsub(/\t/, "    ") }
        /^cli:/ { in_cli=1; next }
        in_cli && /^  agents:/ { in_agents=1; next }
        in_agents && $0 ~ "^    " agent ":" { in_target=1; next }
        in_target && /^      model:/ {
            val=$0; sub(/^.*model:[[:space:]]*/, "", val)
            gsub(/["'"'"']/, "", val)
            sub(/[[:space:]]*#.*$/, "", val)
            print val; exit
        }
        in_target && /^    [a-z]/ { exit }
        in_cli && /^[a-z]/ { exit }
    ' "$yaml_config"
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

    # awkで env セクションの key=value ペアを抽出
    local raw_pairs=$(awk -v agent="$agent_name" '
        /^[[:space:]]*#/ { next }
        { gsub(/\t/, "    ") }
        /^cli:/ { in_cli=1; next }
        in_cli && /^  agents:/ { in_agents=1; next }
        in_agents && $0 ~ "^    " agent ":" { in_target=1; next }
        in_target && /^      env:/ { in_env=1; next }
        in_target && in_env && /^        [A-Z_]/ {
            key=$0; sub(/^[[:space:]]*/, "", key)
            sub(/:.*$/, "", key)
            val=$0; sub(/^[^:]*:[[:space:]]*/, "", val)
            gsub(/["'"'"']/, "", val)
            sub(/[[:space:]]*#.*$/, "", val)
            print key "=" val
        }
        in_target && in_env && /^      [a-z]/ { exit }
        in_target && /^    [a-z]/ { exit }
        in_cli && /^[a-z]/ { exit }
    ' "$yaml_config")

    local env_str=""
    while IFS= read -r pair; do
        [ -z "$pair" ] && continue

        local key="${pair%%=*}"
        local value="${pair#*=}"

        # 環境変数の置換（${VAR_NAME} 形式）— 許可リスト方式
        if echo "$value" | grep -q '^\${.*}$'; then
            local var_name=$(echo "$value" | sed 's/\${//g' | sed 's/}//g')

            # 許可リストチェック
            local allowed=false
            for allowed_var in $_ALLOWED_VAR_EXPANSIONS; do
                if [ "$var_name" = "$allowed_var" ]; then
                    allowed=true
                    break
                fi
            done

            if [ "$allowed" = true ]; then
                value="${!var_name}"
            else
                echo "Warning: unauthorized variable expansion: \${$var_name}" >&2
                value=""
            fi
        fi

        if [ -n "$env_str" ]; then
            env_str="$env_str "
        fi
        env_str="${env_str}${key}=${value}"
    done <<< "$raw_pairs"

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
            # GitHub Copilot CLI は gh の拡張機能として提供される
            if ! command -v gh &>/dev/null; then
                echo "Error: GitHub CLI (gh) が見つかりません" >&2
                echo "インストール: brew install gh (Mac) または sudo apt install gh (Ubuntu/Debian)" >&2
                return 1
            fi

            # gh copilot コマンドが利用可能か確認
            if ! gh copilot --version &>/dev/null 2>&1; then
                echo "Error: GitHub Copilot CLI 拡張が見つかりません" >&2
                echo "インストール: gh extension install github/gh-copilot" >&2
                echo "認証: gh auth login" >&2
                return 1
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

    # 足軽1-8の場合は ashigaru.md を使用
    local base_name="$agent_name"
    if [[ "$agent_name" =~ ^ashigaru[1-8]$ ]]; then
        base_name="ashigaru"
    fi

    local instruction_file="${instructions_dir}/${base_name}.md"

    if [ ! -f "$instruction_file" ]; then
        echo "Warning: Instruction file not found: $instruction_file" >&2
        return 1
    fi

    # .github ディレクトリを作成
    mkdir -p "$(dirname "$output_file")"

    # Lock file for race condition prevention
    local lock_file="${output_file}.lock"
    local max_wait=5
    local wait_count=0

    # Wait for lock (max 5 seconds)
    while [ -f "$lock_file" ] && [ $wait_count -lt $max_wait ]; do
        sleep 1
        wait_count=$((wait_count + 1))
    done

    # Create lock
    touch "$lock_file"

    # 指示書をコピー
    cat "$instruction_file" > "$output_file"

    # グローバルコンテキストを追加（存在する場合）
    if [ -f "memory/global_context.md" ]; then
        echo "" >> "$output_file"
        echo "---" >> "$output_file"
        echo "" >> "$output_file"
        cat "memory/global_context.md" >> "$output_file"
    fi

    # Remove lock
    rm -f "$lock_file"

    return 0
}
