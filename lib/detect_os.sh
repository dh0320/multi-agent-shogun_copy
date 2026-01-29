#!/usr/bin/env bash
# ============================================================
# lib/detect_os.sh - OS detection and environment configuration
# ============================================================
# This module detects the operating system and sets environment
# variables for cross-platform compatibility.
#
# Usage:
#   source "$(dirname "$0")/lib/detect_os.sh"
#   # Now SHOGUN_OS and other variables are available
# ============================================================

# Prevent multiple sourcing
if [[ -n "${SHOGUN_OS_DETECTED:-}" ]]; then
    return 0
fi

# Get the directory where this script is located
_DETECT_OS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHOGUN_ROOT="$(cd "${_DETECT_OS_DIR}/.." && pwd)"

detect_os() {
    local os_type
    os_type="$(uname -s)"

    case "${os_type}" in
        Darwin)
            export SHOGUN_OS="macos"
            export SHOGUN_HOME="${SHOGUN_HOME:-${HOME}/multi-agent-shogun}"
            export SHOGUN_SCREENSHOT_DIR="${SHOGUN_SCREENSHOT_DIR:-${HOME}/Pictures/Screenshots}"
            export SHOGUN_OPEN_CMD="open"
            export SHOGUN_TERMINAL_CMD="osascript"
            export SHOGUN_PKG_MANAGER="brew"
            ;;
        Linux)
            if grep -qEi "(microsoft|wsl)" /proc/version 2>/dev/null; then
                export SHOGUN_OS="wsl"
                # WSL: Use project directory directly, or allow override
                export SHOGUN_HOME="${SHOGUN_HOME:-${SHOGUN_ROOT}}"
                # WSL: Default to Windows user's Screenshots folder
                local win_user
                win_user="$(cmd.exe /c "echo %USERNAME%" 2>/dev/null | tr -d '\r' || echo "${USER}")"
                export SHOGUN_SCREENSHOT_DIR="${SHOGUN_SCREENSHOT_DIR:-/mnt/c/Users/${win_user}/Pictures/Screenshots}"
                export SHOGUN_OPEN_CMD="wslview"  # wslu package
                export SHOGUN_TERMINAL_CMD="wt.exe"
                export SHOGUN_PKG_MANAGER="apt"
            else
                export SHOGUN_OS="linux"
                export SHOGUN_HOME="${SHOGUN_HOME:-${HOME}/multi-agent-shogun}"
                export SHOGUN_SCREENSHOT_DIR="${SHOGUN_SCREENSHOT_DIR:-${HOME}/Pictures/Screenshots}"
                export SHOGUN_OPEN_CMD="xdg-open"
                export SHOGUN_TERMINAL_CMD=""  # varies by distro
                # Detect package manager
                if command -v apt-get >/dev/null 2>&1; then
                    export SHOGUN_PKG_MANAGER="apt"
                elif command -v dnf >/dev/null 2>&1; then
                    export SHOGUN_PKG_MANAGER="dnf"
                elif command -v pacman >/dev/null 2>&1; then
                    export SHOGUN_PKG_MANAGER="pacman"
                elif command -v zypper >/dev/null 2>&1; then
                    export SHOGUN_PKG_MANAGER="zypper"
                else
                    export SHOGUN_PKG_MANAGER="unknown"
                fi
            fi
            ;;
        MINGW*|MSYS*|CYGWIN*)
            export SHOGUN_OS="windows"
            export SHOGUN_HOME="${SHOGUN_HOME:-${USERPROFILE}/multi-agent-shogun}"
            export SHOGUN_SCREENSHOT_DIR="${SHOGUN_SCREENSHOT_DIR:-${USERPROFILE}/Pictures/Screenshots}"
            export SHOGUN_OPEN_CMD="start"
            export SHOGUN_TERMINAL_CMD="wt.exe"
            export SHOGUN_PKG_MANAGER="choco"
            ;;
        *)
            echo "Error: Unsupported OS: ${os_type}" >&2
            export SHOGUN_OS="unknown"
            export SHOGUN_HOME="${SHOGUN_HOME:-${HOME}/multi-agent-shogun}"
            export SHOGUN_SCREENSHOT_DIR="${SHOGUN_SCREENSHOT_DIR:-${HOME}/Pictures}"
            export SHOGUN_OPEN_CMD="echo"
            export SHOGUN_TERMINAL_CMD=""
            export SHOGUN_PKG_MANAGER="unknown"
            return 1
            ;;
    esac

    # Common paths (can be overridden by environment)
    export SHOGUN_CONFIG="${SHOGUN_CONFIG:-${SHOGUN_HOME}/config}"
    export SHOGUN_QUEUE="${SHOGUN_QUEUE:-${SHOGUN_HOME}/queue}"
    export SHOGUN_STATUS="${SHOGUN_STATUS:-${SHOGUN_HOME}/status}"
    export SHOGUN_LOGS="${SHOGUN_LOGS:-${SHOGUN_HOME}/logs}"
    export SHOGUN_INSTRUCTIONS="${SHOGUN_INSTRUCTIONS:-${SHOGUN_HOME}/instructions}"

    # Mark as detected
    export SHOGUN_OS_DETECTED=1

    return 0
}

# Get shell config file for the current user
get_shell_config() {
    local shell_name
    shell_name="$(basename "${SHELL:-/bin/bash}")"

    case "${shell_name}" in
        zsh)
            echo "${HOME}/.zshrc"
            ;;
        bash)
            if [[ "${SHOGUN_OS}" == "macos" ]]; then
                # macOS uses .bash_profile by default for login shells
                if [[ -f "${HOME}/.bash_profile" ]]; then
                    echo "${HOME}/.bash_profile"
                else
                    echo "${HOME}/.bashrc"
                fi
            else
                echo "${HOME}/.bashrc"
            fi
            ;;
        fish)
            echo "${HOME}/.config/fish/config.fish"
            ;;
        *)
            echo "${HOME}/.profile"
            ;;
    esac
}

# Check if running in interactive terminal
is_interactive() {
    [[ -t 0 && -t 1 ]]
}

# Print OS detection summary (for debugging)
print_os_info() {
    echo "SHOGUN_OS:            ${SHOGUN_OS}"
    echo "SHOGUN_HOME:          ${SHOGUN_HOME}"
    echo "SHOGUN_CONFIG:        ${SHOGUN_CONFIG}"
    echo "SHOGUN_QUEUE:         ${SHOGUN_QUEUE}"
    echo "SHOGUN_STATUS:        ${SHOGUN_STATUS}"
    echo "SHOGUN_LOGS:          ${SHOGUN_LOGS}"
    echo "SHOGUN_SCREENSHOT_DIR: ${SHOGUN_SCREENSHOT_DIR}"
    echo "SHOGUN_OPEN_CMD:      ${SHOGUN_OPEN_CMD}"
    echo "SHOGUN_TERMINAL_CMD:  ${SHOGUN_TERMINAL_CMD}"
    echo "SHOGUN_PKG_MANAGER:   ${SHOGUN_PKG_MANAGER}"
}

# Run detection immediately when sourced
detect_os
