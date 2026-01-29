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
    
    # エージェント固有の設定をチェック
    local agent_type=$(grep -A 2 "^    ${agent_name}:" "$yaml_config" 2>/dev/null | grep "^\s*type:" | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
    
    if [ -n "$agent_type" ]; then
        echo "$agent_type"
    else
        # デフォルトCLIタイプを取得
        local default_type=$(grep "^  default:" "$yaml_config" 2>/dev/null | head -1 | awk '{print $2}' | tr -d '"' | tr -d "'")
        echo "${default_type:-claude}"
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
                options="--model $model"
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
    
    grep -A 5 "^    ${agent_name}:" "$yaml_config" 2>/dev/null | \
        grep "model:" | \
        awk '{print $2}' | \
        tr -d '"' | \
        tr -d "'"
}

# エージェント固有の環境変数を取得
# 引数:
#   $1: エージェント名
#   $2: settings.yamlのパス
# 出力: 環境変数の設定文字列（例: "MAX_THINKING_TOKENS=0"）
get_agent_env() {
    local agent_name="$1"
    local yaml_config="$2"
    
    # エージェント設定ブロックを抽出
    local in_agent=false
    local in_env=false
    local env_str=""
    
    while IFS= read -r line; do
        # エージェントセクション開始
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
            ;;
        copilot)
            if ! command -v copilot &>/dev/null; then
                echo "Error: GitHub Copilot CLI が見つかりません" >&2
                echo "インストール: brew install gh (or apt/yum), then gh extension install github/gh-copilot" >&2
                return 1
            fi
            
            # GitHub認証チェック
            if ! gh auth status &>/dev/null 2>&1; then
                echo "Warning: GitHub にログインしていません" >&2
                echo "認証: gh auth login" >&2
                # 警告のみで続行
            fi
            ;;
        *)
            echo "Error: Unknown CLI type: $cli_type" >&2
            return 1
            ;;
    esac
    
    return 0
}

# Copilot用の指示書を生成
# 引数:
#   $1: エージェント名
#   $2: 指示書ディレクトリ (instructions/)
#   $3: 出力先 (.github/copilot-instructions.md)
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
