#!/usr/bin/env bash
# ============================================================
# start.sh - Unified entry point for multi-agent-shogun
# ============================================================
# Cross-platform startup script that handles OS detection
# and delegates to the main deployment script.
#
# Usage:
#   ./start.sh              # Full startup (all agents)
#   ./start.sh -s           # Setup only (no Claude launch)
#   ./start.sh -t           # Open terminal tabs (WSL/macOS)
#   ./start.sh --detach     # Setup without terminal attach
#   ./start.sh --no-launch  # Create sessions, no Claude
#   ./start.sh -h           # Show help
# ============================================================

set -euo pipefail

# Get script directory (works with symlinks)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Source the OS detection and utilities
source "${SCRIPT_DIR}/lib/detect_os.sh"
source "${SCRIPT_DIR}/lib/utils.sh"
source "${SCRIPT_DIR}/lib/generate_config.sh"

# Parse arguments
SETUP_ONLY=false
OPEN_TERMINAL=false
DETACH=false
NO_LAUNCH=false
SHOW_HELP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--setup-only)
            SETUP_ONLY=true
            shift
            ;;
        -t|--terminal)
            OPEN_TERMINAL=true
            shift
            ;;
        --detach)
            DETACH=true
            shift
            ;;
        --no-launch)
            NO_LAUNCH=true
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
    echo "multi-agent-shogun - Cross-platform startup script"
    echo ""
    echo "Usage: ./start.sh [options]"
    echo ""
    echo "Options:"
    echo "  -s, --setup-only  Setup tmux sessions only (no Claude)"
    echo "  -t, --terminal    Open terminal tabs (WSL/macOS)"
    echo "  --detach          Don't attach to terminal"
    echo "  --no-launch       Create sessions without launching Claude"
    echo "  -h, --help        Show this help"
    echo ""
    echo "Detected OS: ${SHOGUN_OS}"
    echo "Home: ${SHOGUN_HOME}"
    echo ""
    exit 0
fi

# Check prerequisites
log_step "Checking prerequisites"
if ! missing=$(check_prerequisites); then
    print_install_instructions "${missing}"
    exit 1
fi
log_success "All prerequisites found"

# Generate config if template exists but config doesn't
if [[ -f "${SHOGUN_CONFIG}/settings.yaml.template" ]] && [[ ! -f "${SHOGUN_CONFIG}/settings.yaml" ]]; then
    log_info "Generating settings.yaml from template..."
    generate_settings_yaml
fi

# Build arguments for shutsujin_departure.sh
args=()
if [[ "${SETUP_ONLY}" == true ]]; then
    args+=("-s")
fi
if [[ "${OPEN_TERMINAL}" == true ]]; then
    args+=("-t")
fi

# Run the main deployment script
log_step "Starting deployment on ${SHOGUN_OS}"
exec "${SCRIPT_DIR}/shutsujin_departure.sh" "${args[@]}"
