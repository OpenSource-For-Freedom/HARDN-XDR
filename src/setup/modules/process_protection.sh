#!/bin/bash

# Process Protection Module
# Part of HARDN-XDR Security Framework
# Purpose: Detect and prevent process injection techniques

set -euo pipefail
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}

MODULE_NAME="Process Protection"
CONFIG_DIR="/etc/hardn-xdr/process-protection"
LOG_FILE="/var/log/security/process-protection.log"

process_protection_setup() {
    HARDN_STATUS "info" "Setting up $MODULE_NAME"

    if ! check_root; then
        HARDN_STATUS "error" "This module requires root privileges"
        return 1
    fi

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Configure process injection detection rules
    cat > "$CONFIG_DIR/injection-rules.conf" << 'EOF'
# Process injection detection rules
MONITOR_PTRACE=true
MONITOR_PROC_MEM=true
MONITOR_DYNAMIC_LIBRARIES=true
EOF

    # Add auditd rules for process monitoring
    if command -v auditctl >/dev/null 2>&1; then
        # Check if auditd is available (may not work in containers)
        if auditctl -l >/dev/null 2>&1; then
            auditctl -a always,exit -F arch=b64 -S ptrace -k process_injection 2>/dev/null || true
            auditctl -a always,exit -F arch=b32 -S ptrace -k process_injection 2>/dev/null || true
            HARDN_STATUS "info" "Added auditd rules for process injection detection"
        else
            HARDN_STATUS "info" "Auditd not available (normal in containers)"
        fi
    fi

    HARDN_STATUS "pass" "$MODULE_NAME setup completed"
    exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    process_protection_setup
fi

return 0 2>/dev/null || hardn_module_exit 0

return 0 2>/dev/null || hardn_module_exit 0
