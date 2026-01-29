#!/usr/bin/env bash
# ============================================================
# lib/utils.sh - Common utility functions
# ============================================================
# Shared utility functions for cross-platform compatibility.
#
# Usage:
#   source "$(dirname "$0")/lib/utils.sh"
# ============================================================

# Prevent multiple sourcing
if [[ -n "${SHOGUN_UTILS_LOADED:-}" ]]; then
    return 0
fi

# Source detect_os.sh if not already loaded
_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${SHOGUN_OS_DETECTED:-}" ]]; then
    source "${_UTILS_DIR}/detect_os.sh"
fi

# ============================================================
# Color definitions
# ============================================================
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[1;35m'
export NC='\033[0m'  # No Color
export BOLD='\033[1m'

# ============================================================
# Logging functions (with Sengoku-style messages)
# ============================================================
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_step() {
    echo -e "\n${CYAN}${BOLD}--- $1 ---${NC}\n"
}

log_war() {
    echo -e "\033[1;31m[WAR]${NC} $1"
}

# ============================================================
# Prerequisite checking
# ============================================================

# Check if a command exists
has_command() {
    command -v "$1" >/dev/null 2>&1
}

# Check all prerequisites and return missing ones
# Usage: check_prerequisites
# Returns: 0 if all present, 1 if missing
check_prerequisites() {
    local missing=()

    if ! has_command tmux; then
        missing+=("tmux")
    fi

    if ! has_command claude; then
        missing+=("claude-code")
    fi

    if ! has_command node; then
        missing+=("node")
    fi

    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "${missing[*]}"
        return 1
    fi

    return 0
}

# Print installation instructions for missing prerequisites
print_install_instructions() {
    local missing="$1"

    echo "Missing dependencies: ${missing}" >&2
    echo "" >&2
    echo "Install with:" >&2

    case "${SHOGUN_OS}" in
        macos)
            echo "  brew install tmux" >&2
            echo "  npm install -g @anthropic-ai/claude-code" >&2
            ;;
        linux|wsl)
            case "${SHOGUN_PKG_MANAGER}" in
                apt)
                    echo "  sudo apt-get update && sudo apt-get install -y tmux" >&2
                    ;;
                dnf)
                    echo "  sudo dnf install -y tmux" >&2
                    ;;
                pacman)
                    echo "  sudo pacman -S --noconfirm tmux" >&2
                    ;;
                zypper)
                    echo "  sudo zypper install -y tmux" >&2
                    ;;
                *)
                    echo "  [Install tmux using your package manager]" >&2
                    ;;
            esac
            echo "  npm install -g @anthropic-ai/claude-code" >&2
            ;;
        windows)
            echo "  choco install tmux" >&2
            echo "  npm install -g @anthropic-ai/claude-code" >&2
            ;;
    esac
}

# ============================================================
# tmux session management
# ============================================================

# Check if a tmux session exists
tmux_session_exists() {
    local session_name="$1"
    tmux has-session -t "${session_name}" 2>/dev/null
}

# Kill a tmux session if it exists
tmux_kill_session() {
    local session_name="$1"
    if tmux_session_exists "${session_name}"; then
        tmux kill-session -t "${session_name}" 2>/dev/null
        return 0
    fi
    return 1
}

# ============================================================
# Terminal attachment (OS-specific)
# ============================================================

# Open a new terminal and attach to a tmux session
attach_terminal() {
    local session_name="${1:-shogun}"

    case "${SHOGUN_OS}" in
        macos)
            if has_command osascript; then
                osascript -e "tell app \"Terminal\" to do script \"tmux attach-session -t ${session_name}\""
            else
                echo "Run: tmux attach-session -t ${session_name}"
            fi
            ;;
        linux)
            if has_command gnome-terminal; then
                gnome-terminal -- tmux attach-session -t "${session_name}" &
            elif has_command konsole; then
                konsole -e tmux attach-session -t "${session_name}" &
            elif has_command xterm; then
                xterm -e "tmux attach-session -t ${session_name}" &
            else
                echo "Run: tmux attach-session -t ${session_name}"
            fi
            ;;
        wsl)
            if has_command wt.exe; then
                wt.exe -w 0 new-tab wsl.exe -e bash -c "tmux attach-session -t ${session_name}" 2>/dev/null || \
                echo "Run: tmux attach-session -t ${session_name}"
            else
                echo "Run: tmux attach-session -t ${session_name}"
            fi
            ;;
        windows)
            if has_command wt.exe; then
                wt.exe new-tab bash -c "tmux attach-session -t ${session_name}"
            else
                echo "Run: tmux attach-session -t ${session_name}"
            fi
            ;;
        *)
            echo "Run: tmux attach-session -t ${session_name}"
            ;;
    esac
}

# Open terminals for both shogun and multiagent sessions
attach_all_terminals() {
    case "${SHOGUN_OS}" in
        macos)
            if has_command osascript; then
                osascript -e 'tell app "Terminal" to do script "tmux attach-session -t shogun"'
                osascript -e 'tell app "Terminal" to do script "tmux attach-session -t multiagent"'
            else
                echo "Run in separate terminals:"
                echo "  tmux attach-session -t shogun"
                echo "  tmux attach-session -t multiagent"
            fi
            ;;
        linux)
            if has_command gnome-terminal; then
                gnome-terminal -- tmux attach-session -t shogun &
                gnome-terminal -- tmux attach-session -t multiagent &
            else
                echo "Run in separate terminals:"
                echo "  tmux attach-session -t shogun"
                echo "  tmux attach-session -t multiagent"
            fi
            ;;
        wsl)
            if has_command wt.exe; then
                wt.exe -w 0 new-tab wsl.exe -e bash -c "tmux attach-session -t shogun" \; \
                       new-tab wsl.exe -e bash -c "tmux attach-session -t multiagent" 2>/dev/null || {
                    echo "Run in separate terminals:"
                    echo "  tmux attach-session -t shogun"
                    echo "  tmux attach-session -t multiagent"
                }
            else
                echo "Run in separate terminals:"
                echo "  tmux attach-session -t shogun"
                echo "  tmux attach-session -t multiagent"
            fi
            ;;
        *)
            echo "Run in separate terminals:"
            echo "  tmux attach-session -t shogun"
            echo "  tmux attach-session -t multiagent"
            ;;
    esac
}

# ============================================================
# File operations
# ============================================================

# Ensure directory exists with proper permissions
ensure_dir() {
    local dir="$1"
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}"
    fi
}

# Create or reset a YAML file with initial content
init_yaml_file() {
    local file="$1"
    local content="$2"

    ensure_dir "$(dirname "${file}")"
    echo "${content}" > "${file}"
}

# ============================================================
# Version comparison
# ============================================================

# Compare version strings (returns 0 if v1 >= v2)
version_gte() {
    local v1="$1"
    local v2="$2"

    # Remove 'v' prefix if present
    v1="${v1#v}"
    v2="${v2#v}"

    printf '%s\n%s' "${v2}" "${v1}" | sort -V -C
}

# Get major version number
get_major_version() {
    local version="$1"
    version="${version#v}"
    echo "${version%%.*}"
}

# Mark as loaded
export SHOGUN_UTILS_LOADED=1
