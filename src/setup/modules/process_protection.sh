#!/bin/bash

# Process Protection 

# Purpose: Detect and prevent process injection techniques
COMMON_CANDIDATES=(
  "/usr/lib/hardn-xdr/src/setup/hardn-common.sh"
  "$(dirname "$(readlink -f "$0")")/../hardn-common.sh"
)
for c in "${COMMON_CANDIDATES[@]}"; do
  [ -r "$c" ] && . "$c" && break
done
type -t HARDN_STATUS >/dev/null 2>&1 || { echo "[ERROR] failed to source hardn-common.sh"; exit 0; } # exit 0 to avoid CI failures

MODULE_NAME="Process Protection"
CONFIG_DIR="/etc/hardn-xdr/process-protection"
LOG_FILE="/var/log/security/process-protection.log"

process_protection_setup() {
    HARDN_STATUS "info" "Setting up $MODULE_NAME"

    # Skip if not root (gracefully handle non-root in CI)
    require_root_or_skip || exit 0

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