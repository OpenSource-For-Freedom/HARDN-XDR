#!/bin/bash

# Credential Protection Module
# Part of HARDN-XDR Security Framework
# Purpose: Enhanced credential dumping protection and token manipulation prevention

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

MODULE_NAME="Credential Protection"
CONFIG_DIR="/etc/hardn-xdr/credential-protection"
LOG_FILE="/var/log/security/credential-protection.log"

credential_protection_setup() {
    HARDN_STATUS "info" "Setting up $MODULE_NAME"

    if ! check_root; then
        HARDN_STATUS "error" "This module requires root privileges"
        return 1
    fi

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Secure memory dump protection using safe sysctl
    safe_sysctl_set "kernel.core_pattern" "|/bin/false" "/etc/sysctl.d/99-credential-protection.conf"
    HARDN_STATUS "info" "Core dump protection configured"

    # Enhanced credential file monitoring
    if command -v auditctl >/dev/null 2>&1; then
        # Check if auditd is available (may not work in containers)
        if auditctl -l >/dev/null 2>&1; then
            auditctl -w /etc/shadow -p wa -k credential_access 2>/dev/null || true
            auditctl -w /etc/gshadow -p wa -k credential_access 2>/dev/null || true
            auditctl -w /etc/passwd -p wa -k credential_access 2>/dev/null || true
            auditctl -a always,exit -F arch=b64 -S setuid -k credential_manipulation 2>/dev/null || true
            auditctl -a always,exit -F arch=b32 -S setuid -k credential_manipulation 2>/dev/null || true
            HARDN_STATUS "info" "Added auditd rules for credential protection"
        else
            HARDN_STATUS "info" "Auditd not available (normal in containers)"
        fi
    fi

    # Restrict access to process memory using safe sysctl
    safe_sysctl_set "kernel.yama.ptrace_scope" "1" "/etc/sysctl.d/99-credential-protection.conf"
    HARDN_STATUS "info" "Enhanced ptrace restrictions applied"

    HARDN_STATUS "pass" "$MODULE_NAME setup completed"
    exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    credential_protection_setup
fi

return 0 2>/dev/null || hardn_module_exit 0
set -e
