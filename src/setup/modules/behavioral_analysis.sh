#!/bin/bash

# Behavioral Analysis Module
# Part of HARDN-XDR Security Framework
# Purpose: System behavior baselining and anomaly detection

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
    exit 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    behavioral_analysis_setup
fi

return 0 2>/dev/null || hardn_module_exit 0
set -e
