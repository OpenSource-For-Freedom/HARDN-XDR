#!/bin/bash

# Process Protection Module
# Part of HARDN-XDR Security Framework
# Purpose: Detect and prevent process injection techniques

set -euo pipefail

source "/usr/share/hardn-xdr/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
}

MODULE_NAME="Process Protection"
CONFIG_DIR="/etc/hardn-xdr/process-protection"
LOG_FILE="/var/log/security/process-protection.log"

process_protection_setup() {
    log_message "INFO: Setting up $MODULE_NAME"
    
    if ! check_root; then
        log_message "ERROR: This module requires root privileges"
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
        auditctl -a always,exit -F arch=b64 -S ptrace -k process_injection
        auditctl -a always,exit -F arch=b32 -S ptrace -k process_injection
        log_message "INFO: Added auditd rules for process injection detection"
    fi
    
    log_message "INFO: $MODULE_NAME setup completed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    process_protection_setup
fi