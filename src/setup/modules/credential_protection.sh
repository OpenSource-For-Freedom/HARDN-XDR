#!/bin/bash

# Credential Protection Module
# Part of HARDN-XDR Security Framework
# Purpose: Enhanced credential dumping protection and token manipulation prevention

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    check_root() { [[ $EUID -eq 0 ]]; }
}
set -e

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

    # Secure memory dump protection (if not already configured)
    if ! grep -q "kernel.core_pattern" /etc/sysctl.d/99-credential-protection.conf 2>/dev/null; then
        echo 'kernel.core_pattern=|/bin/false' >> /etc/sysctl.d/99-credential-protection.conf
        HARDN_STATUS "info" "Core dump protection configured"
    fi

    # Enhanced credential file monitoring
    if command -v auditctl >/dev/null 2>&1; then
        auditctl -w /etc/shadow -p wa -k credential_access
        auditctl -w /etc/gshadow -p wa -k credential_access
        auditctl -w /etc/passwd -p wa -k credential_access
        auditctl -a always,exit -F arch=b64 -S setuid -k credential_manipulation
        auditctl -a always,exit -F arch=b32 -S setuid -k credential_manipulation
        HARDN_STATUS "info" "Added auditd rules for credential protection"
    fi

    # Restrict access to process memory
    if [[ -d /proc/sys/kernel ]]; then
        echo 1 > /proc/sys/kernel/yama/ptrace_scope
        if ! grep -q "kernel.yama.ptrace_scope" /etc/sysctl.d/99-credential-protection.conf 2>/dev/null; then
            echo 'kernel.yama.ptrace_scope = 1' >> /etc/sysctl.d/99-credential-protection.conf
        fi
        HARDN_STATUS "info" "Enhanced ptrace restrictions applied"
    fi

    HARDN_STATUS "pass" "$MODULE_NAME setup completed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    credential_protection_setup
fi

return 0 2>/dev/null || hardn_module_exit 0
