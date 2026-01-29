#!/usr/bin/env bash
# ============================================================
# lib/generate_config.sh - Configuration file generator
# ============================================================
# Generates configuration files from templates by substituting
# environment variables.
#
# Usage:
#   source "$(dirname "$0")/lib/generate_config.sh"
#   generate_settings_yaml
# ============================================================

# Source detect_os.sh if not already loaded
_GENERATE_CONFIG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -z "${SHOGUN_OS_DETECTED:-}" ]]; then
    source "${_GENERATE_CONFIG_DIR}/detect_os.sh"
fi

# Substitute environment variables in a template file
# Usage: envsubst_file <template_file> <output_file>
envsubst_file() {
    local template_file="$1"
    local output_file="$2"

    if [[ ! -f "${template_file}" ]]; then
        echo "Error: Template file not found: ${template_file}" >&2
        return 1
    fi

    # Create output directory if needed
    mkdir -p "$(dirname "${output_file}")"

    # Use envsubst if available, otherwise use sed-based fallback
    if command -v envsubst >/dev/null 2>&1; then
        envsubst < "${template_file}" > "${output_file}"
    else
        # Fallback: simple variable substitution using sed
        local content
        content="$(cat "${template_file}")"

        # Replace ${VAR:-default} patterns
        content="$(echo "${content}" | sed -E \
            -e "s|\\\$\{SHOGUN_LANG:-[^}]*\}|${SHOGUN_LANG:-ja}|g" \
            -e "s|\\\$\{SHOGUN_HOME\}|${SHOGUN_HOME}|g" \
            -e "s|\\\$\{SHOGUN_HOME:-[^}]*\}|${SHOGUN_HOME}|g" \
            -e "s|\\\$\{SHOGUN_SCREENSHOT_DIR\}|${SHOGUN_SCREENSHOT_DIR}|g" \
            -e "s|\\\$\{SHOGUN_SCREENSHOT_DIR:-[^}]*\}|${SHOGUN_SCREENSHOT_DIR}|g" \
            -e "s|\\\$\{SHOGUN_QUEUE\}|${SHOGUN_QUEUE}|g" \
            -e "s|\\\$\{SHOGUN_QUEUE:-[^}]*\}|${SHOGUN_QUEUE}|g" \
            -e "s|\\\$\{SHOGUN_STATUS\}|${SHOGUN_STATUS}|g" \
            -e "s|\\\$\{SHOGUN_STATUS:-[^}]*\}|${SHOGUN_STATUS}|g" \
            -e "s|\\\$\{SHOGUN_LOGS\}|${SHOGUN_LOGS}|g" \
            -e "s|\\\$\{SHOGUN_LOGS:-[^}]*\}|${SHOGUN_LOGS}|g" \
            -e "s|\\\$\{SHOGUN_OS\}|${SHOGUN_OS}|g" \
        )"

        echo "${content}" > "${output_file}"
    fi

    return 0
}

# Generate settings.yaml from template
generate_settings_yaml() {
    local template_file="${SHOGUN_CONFIG}/settings.yaml.template"
    local output_file="${SHOGUN_CONFIG}/settings.yaml"
    local backup_file

    # If template doesn't exist, create it from existing settings.yaml
    if [[ ! -f "${template_file}" ]]; then
        if [[ -f "${output_file}" ]]; then
            echo "Note: Creating template from existing settings.yaml" >&2
            cp "${output_file}" "${template_file}"
        else
            echo "Warning: No template or settings file found" >&2
            return 1
        fi
    fi

    # Backup existing settings if different from template
    if [[ -f "${output_file}" ]]; then
        backup_file="${output_file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "${output_file}" "${backup_file}"
    fi

    envsubst_file "${template_file}" "${output_file}"

    return $?
}

# Generate all config files
generate_all_configs() {
    local errors=0

    # Ensure config directory exists
    mkdir -p "${SHOGUN_CONFIG}"

    # Generate settings.yaml if template exists
    if [[ -f "${SHOGUN_CONFIG}/settings.yaml.template" ]]; then
        if ! generate_settings_yaml; then
            ((errors++))
        fi
    fi

    return ${errors}
}

# Read a value from settings.yaml
# Usage: read_setting <key> [default_value]
read_setting() {
    local key="$1"
    local default_value="${2:-}"
    local settings_file="${SHOGUN_CONFIG}/settings.yaml"

    if [[ ! -f "${settings_file}" ]]; then
        echo "${default_value}"
        return
    fi

    # Simple YAML value extraction (top-level keys only)
    local value
    value="$(grep "^${key}:" "${settings_file}" 2>/dev/null | head -1 | sed 's/^[^:]*:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')"

    if [[ -n "${value}" ]]; then
        echo "${value}"
    else
        echo "${default_value}"
    fi
}

# Update a value in settings.yaml
# Usage: update_setting <key> <value>
update_setting() {
    local key="$1"
    local value="$2"
    local settings_file="${SHOGUN_CONFIG}/settings.yaml"

    if [[ ! -f "${settings_file}" ]]; then
        echo "Error: Settings file not found: ${settings_file}" >&2
        return 1
    fi

    # Use sed to update the value
    if grep -q "^${key}:" "${settings_file}"; then
        sed -i.bak "s|^${key}:.*|${key}: ${value}|" "${settings_file}"
    else
        echo "${key}: ${value}" >> "${settings_file}"
    fi

    return 0
}
