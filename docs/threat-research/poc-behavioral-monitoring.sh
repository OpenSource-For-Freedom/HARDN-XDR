#!/bin/bash

# Behavioral Monitoring Module - Proof of Concept
# Part of HARDN-XDR Security Framework
# Purpose: Detect behavioral patterns associated with advanced threats

set -euo pipefail

# Source common functions
source "/usr/share/hardn-xdr/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
}

MODULE_NAME="Behavioral Monitoring"
LOG_FILE="/var/log/security/behavioral-monitoring.log"
CONFIG_DIR="/etc/hardn-xdr/behavioral-monitoring"
BASELINE_FILE="$CONFIG_DIR/system-baseline.json"

# Behavioral monitoring configuration
MONITORING_ENABLED=true
ALERT_THRESHOLD=5
BASELINE_PERIOD=7  # days

behavioral_monitoring_setup() {
    log_message "INFO: Setting up $MODULE_NAME"
    
    # Check if running as root
    if ! check_root; then
        log_message "ERROR: This module requires root privileges"
        return 1
    fi
    
    # Create configuration directory
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Create behavioral monitoring configuration
    cat > "$CONFIG_DIR/behavioral-config.conf" << 'EOF'
# UNC2891 Behavioral Monitoring Configuration
# This is a proof-of-concept configuration

# Monitoring toggles
MONITOR_PROCESS_ANOMALIES=true
MONITOR_NETWORK_BEHAVIOR=true  
MONITOR_FILE_ACCESS=true
MONITOR_USER_BEHAVIOR=true

# Detection thresholds
PROCESS_ANOMALY_THRESHOLD=3
NETWORK_ANOMALY_THRESHOLD=5
FILE_ACCESS_THRESHOLD=10
USER_BEHAVIOR_THRESHOLD=2

# Suspicious process patterns (UNC2891-related indicators)
SUSPICIOUS_PROCESSES=(
    "powershell\.exe"
    "cmd\.exe.*\/c.*"
    "rundll32\.exe.*"
    "regsvr32\.exe.*"
    "mshta\.exe.*"
    "wscript\.exe.*"
    "cscript\.exe.*"
    "python.*-c.*"
    "perl.*-e.*"
    "sh.*-c.*"
)

# Suspicious network patterns
SUSPICIOUS_NETWORK_PATTERNS=(
    ".*\.onion.*"
    ".*base64.*"
    ".*powershell.*download.*"
    ".*wget.*\|.*curl.*http.*"
    ".*nc.*-e.*"
    ".*netcat.*-e.*"
)

# Suspicious file operations
SUSPICIOUS_FILE_PATTERNS=(
    "/tmp/.*\.sh"
    "/var/tmp/.*"  
    "/dev/shm/.*"
    ".*\.vbs"
    ".*\.ps1"
    "/etc/passwd"
    "/etc/shadow"
    "/etc/sudoers"
)
EOF

    # Create systemd service for continuous monitoring
    cat > "/etc/systemd/system/unc2891-behavioral-monitor.service" << 'EOF'
[Unit]
Description=UNC2891 Behavioral Monitoring Service
After=network.target auditd.service

[Service]
Type=simple
ExecStart=/usr/share/hardn-xdr/modules/unc2891_behavioral_monitoring.sh --daemon
Restart=always
RestartSec=10
User=root
Group=root

[Install]
WantedBy=multi-user.target
EOF

    # Create monitoring script
    cat > "/usr/share/hardn-xdr/modules/unc2891_behavioral_monitoring.sh" << 'EOF'
#!/bin/bash

# UNC2891 Behavioral Monitoring Daemon
# Continuously monitors system for behavioral indicators

CONFIG_FILE="/etc/hardn-xdr/behavioral-monitoring/behavioral-config.conf"
LOG_FILE="/var/log/security/behavioral-monitoring.log"

# Source configuration
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

log_alert() {
    local severity="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$severity] $message" >> "$LOG_FILE"
    
    # Send to syslog for centralized logging
    logger -p security.warning -t "UNC2891-Monitor" "$message"
}

monitor_process_behavior() {
    if [[ "$MONITOR_PROCESS_ANOMALIES" != "true" ]]; then
        return 0
    fi
    
    # Monitor for suspicious process executions
    local suspicious_count=0
    
    # Check recently started processes
    ps aux --sort=-etime | head -20 | while read -r line; do
        for pattern in "${SUSPICIOUS_PROCESSES[@]}"; do
            if echo "$line" | grep -qE "$pattern"; then
                log_alert "HIGH" "Suspicious process detected: $line"
                ((suspicious_count++))
            fi
        done
    done
    
    # Check for process injection indicators
    if command -v pgrep >/dev/null 2>&1; then
        # Look for processes with unusual memory mappings
        for pid in $(pgrep -f ".*"); do
            if [[ -r "/proc/$pid/maps" ]]; then
                if grep -q "rwx" "/proc/$pid/maps" 2>/dev/null; then
                    local cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
                    log_alert "MEDIUM" "Process $pid ($cmd) has RWX memory regions - possible injection"
                fi
            fi
        done
    fi
}

monitor_network_behavior() {
    if [[ "$MONITOR_NETWORK_BEHAVIOR" != "true" ]]; then
        return 0
    fi
    
    # Monitor network connections for suspicious patterns
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | while read -r line; do
            for pattern in "${SUSPICIOUS_NETWORK_PATTERNS[@]}"; do
                if echo "$line" | grep -qE "$pattern"; then
                    log_alert "HIGH" "Suspicious network activity: $line"
                fi
            done
        done
    fi
    
    # Check for unusual outbound connections
    if command -v netstat >/dev/null 2>&1; then
        netstat -an | grep ESTABLISHED | while read -r line; do
            # Look for connections to non-standard ports
            if echo "$line" | grep -qE ":4444|:5555|:8080|:9999"; then
                log_alert "MEDIUM" "Connection to suspicious port detected: $line"
            fi
        done
    fi
}

monitor_file_behavior() {
    if [[ "$MONITOR_FILE_ACCESS" != "true" ]]; then
        return 0
    fi
    
    # Monitor for suspicious file operations
    for pattern in "${SUSPICIOUS_FILE_PATTERNS[@]}"; do
        if find / -path "$pattern" -type f -mtime -1 2>/dev/null | head -5 | grep -q .; then
            log_alert "MEDIUM" "Suspicious file activity in: $pattern"
        fi
    done
    
    # Check for recently modified system files
    if find /etc -name "passwd" -o -name "shadow" -o -name "sudoers" -mtime -1 2>/dev/null | grep -q .; then
        log_alert "HIGH" "Critical system files modified recently"
    fi
}

monitor_user_behavior() {
    if [[ "$MONITOR_USER_BEHAVIOR" != "true" ]]; then
        return 0
    fi
    
    # Check for unusual login patterns
    if command -v last >/dev/null 2>&1; then
        # Check for logins from unusual locations or times
        last | head -10 | while read -r line; do
            if echo "$line" | grep -qE "pts/[0-9]+ *[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"; then
                log_alert "LOW" "Remote login detected: $line"
            fi
        done
    fi
    
    # Check for privilege escalation attempts
    if [[ -f "/var/log/auth.log" ]]; then
        if tail -50 /var/log/auth.log | grep -q "sudo.*FAILED\|su.*FAILED"; then
            log_alert "MEDIUM" "Failed privilege escalation attempts detected"
        fi
    fi
}

main_monitoring_loop() {
    log_alert "INFO" "UNC2891 Behavioral Monitoring started"
    
    while true; do
        monitor_process_behavior
        monitor_network_behavior
        monitor_file_behavior
        monitor_user_behavior
        
        # Sleep for monitoring interval
        sleep 30
    done
}

# Handle daemon mode
if [[ "${1:-}" == "--daemon" ]]; then
    main_monitoring_loop
else
    # Run once for testing
    monitor_process_behavior
    monitor_network_behavior
    monitor_file_behavior
    monitor_user_behavior
    echo "Monitoring check completed. Check $LOG_FILE for results."
fi
EOF

    # Make monitoring script executable
    chmod +x "/usr/share/hardn-xdr/modules/unc2891_behavioral_monitoring.sh"
    
    log_message "INFO: $MODULE_NAME setup completed"
    log_message "INFO: Configuration stored in: $CONFIG_DIR"
    log_message "INFO: Logs will be written to: $LOG_FILE"
    log_message "INFO: To enable continuous monitoring: systemctl enable --now unc2891-behavioral-monitor"
    
    return 0
}

behavioral_monitoring_status() {
    log_message "INFO: Checking $MODULE_NAME status"
    
    if [[ -f "$CONFIG_DIR/behavioral-config.conf" ]]; then
        log_message "SUCCESS: Behavioral monitoring configuration found"
    else
        log_message "WARNING: Behavioral monitoring not configured"
        return 1
    fi
    
    if systemctl is-enabled unc2891-behavioral-monitor >/dev/null 2>&1; then
        log_message "SUCCESS: Behavioral monitoring service enabled"
    else
        log_message "INFO: Behavioral monitoring service not enabled"
    fi
    
    if systemctl is-active unc2891-behavioral-monitor >/dev/null 2>&1; then
        log_message "SUCCESS: Behavioral monitoring service running"
    else
        log_message "INFO: Behavioral monitoring service not running"
    fi
    
    # Show recent alerts if log exists
    if [[ -f "$LOG_FILE" ]]; then
        local alert_count=$(wc -l < "$LOG_FILE" 2>/dev/null || echo "0")
        log_message "INFO: Total behavioral alerts logged: $alert_count"
        
        if [[ $alert_count -gt 0 ]]; then
            log_message "INFO: Recent alerts:"
            tail -5 "$LOG_FILE" 2>/dev/null || true
        fi
    fi
    
    return 0
}

behavioral_monitoring_test() {
    log_message "INFO: Testing $MODULE_NAME"
    
    # Create test directory
    local test_dir="/tmp/unc2891-test-$$"
    mkdir -p "$test_dir"
    
    # Run monitoring check once
    if /usr/share/hardn-xdr/modules/unc2891_behavioral_monitoring.sh; then
        log_message "SUCCESS: Behavioral monitoring test completed"
    else
        log_message "ERROR: Behavioral monitoring test failed"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    return 0
}

# Main execution
case "${1:-setup}" in
    "setup")
        behavioral_monitoring_setup
        ;;
    "status")
        behavioral_monitoring_status
        ;;
    "test")
        behavioral_monitoring_test
        ;;
    *)
        echo "Usage: $0 {setup|status|test}"
        echo "  setup  - Configure UNC2891 behavioral monitoring"
        echo "  status - Check monitoring status"
        echo "  test   - Test monitoring functionality"
        exit 1
        ;;
esac