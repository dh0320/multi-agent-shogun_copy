#!/usr/bin/env bash
# ============================================================
# install.sh - Unified installer for multi-agent-shogun
# ============================================================
# Cross-platform installation script supporting:
# - macOS (Darwin)
# - Linux (Ubuntu, Fedora, Arch, etc.)
# - WSL2 (Windows Subsystem for Linux)
# - Windows (Git Bash/MSYS2)
#
# Usage:
#   ./install.sh              # Full installation
#   ./install.sh --deps-only  # Install dependencies only
#   ./install.sh --config-only # Generate config only
#   ./install.sh --check      # Check prerequisites only
#   ./install.sh -h           # Show help
# ============================================================

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Source the OS detection and utilities
source "${SCRIPT_DIR}/lib/detect_os.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/generate_config.sh"

# Track results
declare -a RESULTS=()
HAS_ERROR=false

# Parse arguments
DEPS_ONLY=false
CONFIG_ONLY=false
CHECK_ONLY=false
SHOW_HELP=false
SKIP_DEPS=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --deps-only)
            DEPS_ONLY=true
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --check)
            CHECK_ONLY=true
            shift
            ;;
        --skip-deps)
            SKIP_DEPS=true
            shift
            ;;
        -h|--help)
            SHOW_HELP=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            SHOW_HELP=true
            shift
            ;;
    esac
done

# Show help
if [[ "${SHOW_HELP}" == true ]]; then
    echo ""
    echo "multi-agent-shogun - Cross-platform installer"
    echo ""
    echo "Usage: ./install.sh [options]"
    echo ""
    echo "Options:"
    echo "  --deps-only    Install dependencies only"
    echo "  --config-only  Generate configuration only"
    echo "  --check        Check prerequisites only"
    echo "  --skip-deps    Skip dependency installation"
    echo "  -h, --help     Show this help"
    echo ""
    echo "Detected OS: ${SHOGUN_OS}"
    echo "Package manager: ${SHOGUN_PKG_MANAGER}"
    echo ""
    exit 0
fi

# ============================================================
# Banner
# ============================================================
show_banner() {
    echo ""
    echo "  +============================================================+"
    echo "  |  multi-agent-shogun Installer                              |"
    echo "  |  Cross-platform Installation Script                        |"
    echo "  +============================================================+"
    echo ""
    echo "  Detected OS: ${SHOGUN_OS}"
    echo "  Package manager: ${SHOGUN_PKG_MANAGER}"
    echo "  Home directory: ${SHOGUN_HOME}"
    echo ""
}

# ============================================================
# Dependency Installation
# ============================================================
install_tmux() {
    if has_command tmux; then
        local version
        version=$(tmux -V | awk '{print $2}')
        log_success "tmux already installed (v${version})"
        RESULTS+=("tmux: OK (v${version})")
        return 0
    fi

    log_info "Installing tmux..."

    case "${SHOGUN_OS}" in
        macos)
            if has_command brew; then
                brew install tmux
            else
                log_error "Homebrew not found. Install it first:"
                echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
                return 1
            fi
            ;;
        linux|wsl)
            case "${SHOGUN_PKG_MANAGER}" in
                apt)
                    sudo apt-get update -qq
                    sudo apt-get install -y tmux
                    ;;
                dnf)
                    sudo dnf install -y tmux
                    ;;
                pacman)
                    sudo pacman -S --noconfirm tmux
                    ;;
                zypper)
                    sudo zypper install -y tmux
                    ;;
                *)
                    log_error "Unknown package manager. Install tmux manually."
                    return 1
                    ;;
            esac
            ;;
        windows)
            if has_command choco; then
                choco install tmux -y
            elif has_command pacman; then
                # MSYS2
                pacman -S --noconfirm tmux
            else
                log_error "Install tmux manually via Chocolatey or MSYS2"
                return 1
            fi
            ;;
        *)
            log_error "Unsupported OS for automatic tmux installation"
            return 1
            ;;
    esac

    if has_command tmux; then
        local version
        version=$(tmux -V | awk '{print $2}')
        log_success "tmux installed (v${version})"
        RESULTS+=("tmux: Installed (v${version})")
        return 0
    else
        log_error "tmux installation failed"
        RESULTS+=("tmux: Installation failed")
        return 1
    fi
}

install_nodejs() {
    if has_command node; then
        local version
        version=$(node -v)
        local major
        major=$(get_major_version "${version}")

        if [[ "${major}" -lt 18 ]]; then
            log_warn "Node.js ${version} found, but v18+ is recommended"
            RESULTS+=("Node.js: OK (${version} - upgrade recommended)")
        else
            log_success "Node.js already installed (${version})"
            RESULTS+=("Node.js: OK (${version})")
        fi
        return 0
    fi

    log_info "Node.js not found"
    echo ""
    echo "  Recommended installation methods:"
    echo ""
    echo "  1. Using fnm (Fast Node Manager):"
    echo '     curl -fsSL https://fnm.vercel.app/install | bash'
    echo '     fnm install 20'
    echo '     fnm use 20'
    echo ""
    echo "  2. Using nvm (Node Version Manager):"
    echo '     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.0/install.sh | bash'
    echo '     nvm install 20'
    echo ""

    case "${SHOGUN_OS}" in
        macos)
            echo "  3. Using Homebrew:"
            echo '     brew install node@20'
            ;;
        linux|wsl)
            echo "  3. Using package manager (Ubuntu/Debian):"
            echo '     curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -'
            echo '     sudo apt-get install -y nodejs'
            ;;
    esac
    echo ""

    RESULTS+=("Node.js: Not installed (manual installation required)")
    return 1
}

install_claude_code() {
    if has_command claude; then
        local version
        version=$(claude --version 2>/dev/null || echo "unknown")
        log_success "Claude Code CLI already installed"
        RESULTS+=("Claude Code CLI: OK")
        return 0
    fi

    if ! has_command npm; then
        log_error "npm not found. Install Node.js first."
        RESULTS+=("Claude Code CLI: Not installed (npm required)")
        return 1
    fi

    log_info "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code

    if has_command claude; then
        log_success "Claude Code CLI installed"
        RESULTS+=("Claude Code CLI: Installed")
        return 0
    else
        log_error "Claude Code CLI installation failed"
        RESULTS+=("Claude Code CLI: Installation failed")
        return 1
    fi
}

install_dependencies() {
    log_step "Installing Dependencies"

    local errors=0

    install_tmux || ((errors++)) || true
    install_nodejs || ((errors++)) || true

    # Only try to install Claude Code if we have npm
    if has_command npm; then
        install_claude_code || ((errors++)) || true
    fi

    return ${errors}
}

# ============================================================
# Directory Structure Setup
# ============================================================
setup_directories() {
    log_step "Setting up Directory Structure"

    local directories=(
        "${SHOGUN_QUEUE}/tasks"
        "${SHOGUN_QUEUE}/reports"
        "${SHOGUN_CONFIG}"
        "${SHOGUN_STATUS}"
        "${SHOGUN_LOGS}"
        "${SHOGUN_INSTRUCTIONS}"
        "${SHOGUN_HOME}/skills"
        "${SHOGUN_HOME}/demo_output"
    )

    local created=0
    local existed=0

    for dir in "${directories[@]}"; do
        if [[ ! -d "${dir}" ]]; then
            mkdir -p "${dir}"
            log_info "Created: ${dir#${SHOGUN_HOME}/}"
            ((created++))
        else
            ((existed++))
        fi
    done

    log_success "Directories: ${created} created, ${existed} existing"
    RESULTS+=("Directory structure: OK (created:${created}, existing:${existed})")
}

# ============================================================
# Configuration Setup
# ============================================================
setup_config() {
    log_step "Setting up Configuration"

    # Generate settings.yaml from template
    if [[ -f "${SHOGUN_CONFIG}/settings.yaml.template" ]]; then
        log_info "Generating settings.yaml from template..."
        generate_settings_yaml
        log_success "settings.yaml generated"
    elif [[ ! -f "${SHOGUN_CONFIG}/settings.yaml" ]]; then
        # Create default settings.yaml
        log_info "Creating default settings.yaml..."
        cat > "${SHOGUN_CONFIG}/settings.yaml" << EOF
# multi-agent-shogun settings
language: ja
os: ${SHOGUN_OS}

paths:
  home: ${SHOGUN_HOME}
  screenshot: ${SHOGUN_SCREENSHOT_DIR}
  queue: ${SHOGUN_QUEUE}
  status: ${SHOGUN_STATUS}
  logs: ${SHOGUN_LOGS}

tmux:
  shogun_session: shogun
  multiagent_session: multiagent
  pane_count: 9

claude:
  command: claude
  flags: "--dangerously-skip-permissions"

skill:
  save_path: "~/.claude/skills/shogun-generated/"
  local_path: "${SHOGUN_HOME}/skills/"

logging:
  level: info
  path: ${SHOGUN_LOGS}
EOF
        log_success "settings.yaml created"
    else
        log_info "settings.yaml already exists"
    fi

    # Create projects.yaml if it doesn't exist
    if [[ ! -f "${SHOGUN_CONFIG}/projects.yaml" ]]; then
        if [[ -f "${SHOGUN_CONFIG}/projects.yaml.sample" ]]; then
            cp "${SHOGUN_CONFIG}/projects.yaml.sample" "${SHOGUN_CONFIG}/projects.yaml"
        else
            cat > "${SHOGUN_CONFIG}/projects.yaml" << EOF
projects:
  - id: sample_project
    name: "Sample Project"
    path: "/path/to/your/project"
    priority: high
    status: active

current_project: sample_project
EOF
        fi
        log_info "projects.yaml created (please customize)"
    fi

    RESULTS+=("Configuration: OK")
}

# ============================================================
# Queue Files Setup
# ============================================================
setup_queue_files() {
    log_step "Setting up Queue Files"

    # Ashigaru task files
    for i in {1..8}; do
        local task_file="${SHOGUN_QUEUE}/tasks/ashigaru${i}.yaml"
        if [[ ! -f "${task_file}" ]]; then
            cat > "${task_file}" << EOF
# Ashigaru ${i} task file
task:
  task_id: null
  parent_cmd: null
  description: null
  target_path: null
  status: idle
  timestamp: ""
EOF
        fi
    done
    log_info "Ashigaru task files (1-8) ready"

    # Ashigaru report files
    for i in {1..8}; do
        local report_file="${SHOGUN_QUEUE}/reports/ashigaru${i}_report.yaml"
        if [[ ! -f "${report_file}" ]]; then
            cat > "${report_file}" << EOF
worker_id: ashigaru${i}
task_id: null
timestamp: ""
status: idle
result: null
EOF
        fi
    done
    log_info "Ashigaru report files (1-8) ready"

    RESULTS+=("Queue files: OK")
}

# ============================================================
# Shell Aliases Setup
# ============================================================
setup_aliases() {
    log_step "Setting up Shell Aliases"

    local shell_config
    shell_config=$(get_shell_config)

    if [[ ! -f "${shell_config}" ]]; then
        log_warn "Shell config not found: ${shell_config}"
        RESULTS+=("Aliases: Skipped (no shell config)")
        return 0
    fi

    local alias_added=false
    local alias_marker="# multi-agent-shogun aliases"

    # Check if aliases already exist
    if grep -q "${alias_marker}" "${shell_config}" 2>/dev/null; then
        log_info "Aliases already configured in ${shell_config}"
        RESULTS+=("Aliases: OK (already configured)")
        return 0
    fi

    # Add aliases
    {
        echo ""
        echo "${alias_marker} (added by install.sh)"
        echo "alias css='cd \"${SHOGUN_HOME}\" && ./start.sh'"
        echo "alias csm='cd \"${SHOGUN_HOME}\"'"
        echo "alias css-attach='tmux attach-session -t shogun'"
        echo "alias csm-attach='tmux attach-session -t multiagent'"
    } >> "${shell_config}"

    log_success "Aliases added to ${shell_config}"
    log_info "Run 'source ${shell_config}' or restart your shell to use them"
    RESULTS+=("Aliases: Added to ${shell_config}")
}

# ============================================================
# Script Permissions
# ============================================================
setup_permissions() {
    log_step "Setting up Permissions"

    local scripts=(
        "start.sh"
        "install.sh"
        "setup.sh"
        "shutsujin_departure.sh"
        "first_setup.sh"
        "lib/detect_os.sh"
        "lib/generate_config.sh"
        "lib/utils.sh"
    )

    for script in "${scripts[@]}"; do
        local script_path="${SHOGUN_HOME}/${script}"
        if [[ -f "${script_path}" ]]; then
            chmod +x "${script_path}"
            log_info "Made executable: ${script}"
        fi
    done

    RESULTS+=("Permissions: OK")
}

# ============================================================
# Check Prerequisites Only
# ============================================================
check_only() {
    log_step "Checking Prerequisites"

    local all_ok=true

    if has_command tmux; then
        local version
        version=$(tmux -V | awk '{print $2}')
        log_success "tmux: v${version}"
    else
        log_error "tmux: NOT FOUND"
        all_ok=false
    fi

    if has_command node; then
        local version
        version=$(node -v)
        log_success "Node.js: ${version}"
    else
        log_error "Node.js: NOT FOUND"
        all_ok=false
    fi

    if has_command npm; then
        local version
        version=$(npm -v)
        log_success "npm: v${version}"
    else
        log_error "npm: NOT FOUND"
        all_ok=false
    fi

    if has_command claude; then
        log_success "Claude Code CLI: installed"
    else
        log_error "Claude Code CLI: NOT FOUND"
        all_ok=false
    fi

    echo ""
    if [[ "${all_ok}" == true ]]; then
        log_success "All prerequisites are installed!"
        return 0
    else
        log_error "Some prerequisites are missing"
        return 1
    fi
}

# ============================================================
# Summary
# ============================================================
show_summary() {
    echo ""
    echo "  +============================================================+"
    echo "  |  Installation Summary                                      |"
    echo "  +============================================================+"
    echo ""

    for result in "${RESULTS[@]}"; do
        if [[ "${result}" == *"failed"* ]] || [[ "${result}" == *"NOT"* ]]; then
            echo -e "  ${RED}x${NC} ${result}"
        elif [[ "${result}" == *"recommended"* ]] || [[ "${result}" == *"Skipped"* ]]; then
            echo -e "  ${YELLOW}!${NC} ${result}"
        else
            echo -e "  ${GREEN}+${NC} ${result}"
        fi
    done

    echo ""

    if [[ "${HAS_ERROR}" == true ]]; then
        echo "  +============================================================+"
        echo "  |  Some dependencies are missing                             |"
        echo "  +============================================================+"
        echo ""
        echo "  Please install the missing dependencies and run again."
    else
        echo "  +============================================================+"
        echo "  |  Installation Complete!                                    |"
        echo "  +============================================================+"
        echo ""
        echo "  Next steps:"
        echo "    1. Run: ./start.sh"
        echo "    2. Or use alias: css"
        echo ""
    fi
}

# ============================================================
# Main
# ============================================================
main() {
    show_banner

    if [[ "${CHECK_ONLY}" == true ]]; then
        check_only
        exit $?
    fi

    if [[ "${DEPS_ONLY}" == true ]]; then
        install_dependencies || HAS_ERROR=true
        show_summary
        exit 0
    fi

    if [[ "${CONFIG_ONLY}" == true ]]; then
        setup_directories
        setup_config
        setup_queue_files
        show_summary
        exit 0
    fi

    # Full installation
    if [[ "${SKIP_DEPS}" != true ]]; then
        install_dependencies || HAS_ERROR=true
    fi

    setup_directories
    setup_config
    setup_queue_files
    setup_aliases
    setup_permissions

    show_summary
}

main "$@"
