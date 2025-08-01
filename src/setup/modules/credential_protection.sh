#!/bin/bash

# Credential Protection Module
# Part of HARDN-XDR Security Framework
# Purpose: Enhanced credential dumping protection and token manipulation prevention

set -euo pipefail

source "/usr/share/hardn-xdr/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
}

MODULE_NAME="Credential Protection"
CONFIG_DIR="/etc/hardn-xdr/credential-protection"
LOG_FILE="/var/log/security/credential-protection.log"

credential_protection_setup() {
    log_message "INFO: Setting up $MODULE_NAME"
    
    if ! check_root; then
        log_message "ERROR: This module requires root privileges"
        return 1
    fi
    
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Secure memory dump protection
    echo 'kernel.core_pattern=|/bin/false' >> /etc/sysctl.d/99-credential-protection.conf
    
    # Enhanced credential file monitoring
    if command -v auditctl >/dev/null 2>&1; then
        auditctl -w /etc/shadow -p wa -k credential_access
        auditctl -w /etc/gshadow -p wa -k credential_access
        auditctl -w /etc/passwd -p wa -k credential_access
        auditctl -a always,exit -F arch=b64 -S setuid -k credential_manipulation
        auditctl -a always,exit -F arch=b32 -S setuid -k credential_manipulation
        log_message "INFO: Added auditd rules for credential protection"
    fi
    
    # Restrict access to process memory
    if [[ -d /proc/sys/kernel ]]; then
        echo 1 > /proc/sys/kernel/yama/ptrace_scope
        echo 'kernel.yama.ptrace_scope = 1' >> /etc/sysctl.d/99-credential-protection.conf
        log_message "INFO: Enhanced ptrace restrictions applied"
    fi
    
    log_message "INFO: $MODULE_NAME setup completed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    credential_protection_setup
fi