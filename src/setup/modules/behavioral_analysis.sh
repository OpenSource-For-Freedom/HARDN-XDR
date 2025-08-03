#!/bin/bash

# Behavioral Analysis Module
# Part of HARDN-XDR Security Framework
# Purpose: System behavior baselining and anomaly detection

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
}

MODULE_NAME="Behavioral Analysis"
CONFIG_DIR="/etc/hardn-xdr/behavioral-analysis"
LOG_FILE="/var/log/security/behavioral-analysis.log"
# BASELINE_FILE="$CONFIG_DIR/system-baseline.json"  # Reserved for future use

behavioral_analysis_setup() {
    log_message "INFO: Setting up $MODULE_NAME"

    if ! check_root; then
        log_message "ERROR: This module requires root privileges"
        return 1
    fi

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Create behavioral monitoring configuration
    cat > "$CONFIG_DIR/behavioral-config.conf" << 'EOF'
# Behavioral Analysis Configuration
MONITOR_PROCESS_ANOMALIES=true
MONITOR_NETWORK_BEHAVIOR=true
MONITOR_FILE_ACCESS=true
MONITOR_USER_BEHAVIOR=true
ALERT_THRESHOLD=5
BASELINE_PERIOD=7
EOF

    # Create baseline monitoring script
    cat > "$CONFIG_DIR/create-baseline.sh" << 'EOF'
#!/bin/bash
# System baseline creation script

BASELINE_FILE="/etc/hardn-xdr/behavioral-analysis/system-baseline.json"

{
    echo "{"
    echo "  \"timestamp\": \"$(date -Iseconds)\","
    echo "  \"processes\": ["
    ps -eo comm --no-headers | sort -u | sed 's/^/    "/' | sed 's/$/",/' | sed '$ s/,$//'
    echo "  ],"
    echo "  \"network_connections\": $(netstat -tuln | wc -l),"
    echo "  \"file_descriptors\": $(lsof | wc -l),"
    echo "  \"users_logged_in\": $(who | wc -l)"
    echo "}"
} > "$BASELINE_FILE"
EOF

    chmod +x "$CONFIG_DIR/create-baseline.sh"

    # Create initial baseline
    "$CONFIG_DIR/create-baseline.sh"

    log_message "INFO: $MODULE_NAME setup completed"
    return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    behavioral_analysis_setup
fi

return 0 2>/dev/null || hardn_module_exit 0
