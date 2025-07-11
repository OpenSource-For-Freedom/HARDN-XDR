#!/bin/bash

# Fallback for CI 
HARDN_STATUS() {
  echo "[$1] $2"
}
set -x  # debugging

is_installed() {
    if command -v apt >/dev/null 2>&1; then
        dpkg -s "$1" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$1" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$1" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1 # if it cnt detetmine manager 
    fi
}

# Create AIDE alerting and SIEM integration system
create_aide_alerting_system() {
    HARDN_STATUS "info" "Creating AIDE alerting system with SIEM integration..."
    
    # Create enhanced AIDE check script with alerting
    cat > /usr/local/bin/aide-check-with-alerts.sh << 'EOF'
#!/bin/bash
# AIDE Check with Alerting and SIEM Integration
# STIG Compliance: File Integrity Monitoring with automated response

AIDE_LOG="/var/log/aide/aide.log"
AIDE_ALERT_LOG="/var/log/aide/aide-alerts.log"
SIEM_LOG="/var/log/aide/aide-siem.log"
AIDE_SUMMARY="/var/log/aide/aide-summary.log"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$AIDE_ALERT_LOG"
}

# SIEM logging function (structured format)
siem_log() {
    local event_type="$1"
    local severity="$2"
    local details="$3"
    
    cat >> "$SIEM_LOG" << EOL
{
    "timestamp": "$(date -Iseconds)",
    "event_type": "$event_type",
    "severity": "$severity",
    "source": "aide",
    "hostname": "$(hostname)",
    "details": "$details"
}
EOL
}

# Email alert function (if mail is available)
send_alert() {
    local subject="$1"
    local body="$2"
    
    if command -v mail >/dev/null 2>&1; then
        echo "$body" | mail -s "$subject" root 2>/dev/null || true
    fi
    
    # Log to syslog for remote forwarding
    logger -p security.crit "AIDE ALERT: $subject"
}

# Main AIDE check function
run_aide_check() {
    log_message "INFO" "Starting AIDE integrity check"
    
    # Ensure directories exist
    mkdir -p /var/log/aide
    
    # Run AIDE check
    if /usr/bin/aide --check > "$AIDE_LOG" 2>&1; then
        log_message "INFO" "AIDE check completed successfully - no integrity violations detected"
        siem_log "aide_check" "info" "Integrity check passed"
        
        # Update summary
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] AIDE Check: PASSED" >> "$AIDE_SUMMARY"
        
        return 0
    else
        # AIDE detected changes
        local exit_code=$?
        log_message "CRITICAL" "AIDE detected integrity violations (exit code: $exit_code)"
        
        # Count changes
        local added=$(grep -c "^added:" "$AIDE_LOG" 2>/dev/null || echo "0")
        local removed=$(grep -c "^removed:" "$AIDE_LOG" 2>/dev/null || echo "0") 
        local changed=$(grep -c "^changed:" "$AIDE_LOG" 2>/dev/null || echo "0")
        
        local alert_details="Added: $added, Removed: $removed, Changed: $changed"
        
        siem_log "aide_violation" "critical" "$alert_details"
        log_message "CRITICAL" "Integrity violations detected: $alert_details"
        
        # Send alert
        local alert_subject="CRITICAL: AIDE Integrity Violation on $(hostname)"
        local alert_body="AIDE has detected file system integrity violations:

Added files: $added
Removed files: $removed  
Changed files: $changed

Please review the full report at: $AIDE_LOG

This alert was generated automatically by HARDN-XDR AIDE monitoring."
        
        send_alert "$alert_subject" "$alert_body"
        
        # Update summary
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] AIDE Check: FAILED - $alert_details" >> "$AIDE_SUMMARY"
        
        return 1
    fi
}

# Periodic review function
aide_periodic_review() {
    log_message "INFO" "Performing periodic AIDE configuration review"
    
    # Check database age
    local db_file="/var/lib/aide/aide.db"
    if [[ -f "$db_file" ]]; then
        local db_age_days=$(( ($(date +%s) - $(stat -c %Y "$db_file")) / 86400 ))
        if [[ $db_age_days -gt 30 ]]; then
            log_message "WARNING" "AIDE database is $db_age_days days old - consider updating baseline"
            siem_log "aide_maintenance" "warning" "Database age: $db_age_days days"
        fi
    fi
    
    # Check configuration file
    if [[ -f "/etc/aide/aide.conf" ]]; then
        local config_check=$(aide --config-check 2>&1)
        if [[ $? -eq 0 ]]; then
            log_message "INFO" "AIDE configuration validation passed"
        else
            log_message "ERROR" "AIDE configuration validation failed: $config_check"
            siem_log "aide_config_error" "error" "Configuration validation failed"
        fi
    fi
}

# Main execution
main() {
    # Rotate logs if they get too large
    for log_file in "$AIDE_LOG" "$AIDE_ALERT_LOG" "$SIEM_LOG"; do
        if [[ -f "$log_file" ]] && [[ $(stat -f%s "$log_file" 2>/dev/null || stat -c%s "$log_file") -gt 10485760 ]]; then
            mv "$log_file" "${log_file}.old"
            touch "$log_file"
            chmod 640 "$log_file"
        fi
    done
    
    # Run the check
    run_aide_check
    
    # Periodic review (run weekly)
    if [[ $(date +%u) -eq 1 ]]; then
        aide_periodic_review
    fi
    
    log_message "INFO" "AIDE check process completed"
}

# Execute main function
main "$@"
EOF

    chmod 755 /usr/local/bin/aide-check-with-alerts.sh
    chown root:root /usr/local/bin/aide-check-with-alerts.sh
    
    # Create AIDE status script for manual checks
    cat > /usr/local/bin/aide-status.sh << 'EOF'
#!/bin/bash
# AIDE Status and Management Script

AIDE_SUMMARY="/var/log/aide/aide-summary.log"
AIDE_ALERT_LOG="/var/log/aide/aide-alerts.log"

echo "=== AIDE Status Report ==="
echo "Generated: $(date)"
echo

# Check if AIDE is installed and configured
if command -v aide >/dev/null 2>&1; then
    echo "✓ AIDE is installed"
    aide_version=$(aide --version 2>&1 | head -1)
    echo "  Version: $aide_version"
else
    echo "✗ AIDE is not installed"
    exit 1
fi

# Check database status
echo
echo "Database Status:"
if [[ -f /var/lib/aide/aide.db ]]; then
    echo "✓ AIDE database exists"
    db_date=$(stat -c %y /var/lib/aide/aide.db | cut -d' ' -f1)
    echo "  Last updated: $db_date"
else
    echo "✗ AIDE database missing"
fi

# Check recent alerts
echo
echo "Recent Activity:"
if [[ -f "$AIDE_SUMMARY" ]]; then
    echo "Last 5 check results:"
    tail -5 "$AIDE_SUMMARY" 2>/dev/null || echo "  No recent activity"
else
    echo "  No activity log found"
fi

# Check for critical alerts
echo
if [[ -f "$AIDE_ALERT_LOG" ]]; then
    critical_alerts=$(grep -c "CRITICAL" "$AIDE_ALERT_LOG" 2>/dev/null || echo "0")
    echo "Critical alerts in log: $critical_alerts"
    if [[ $critical_alerts -gt 0 ]]; then
        echo "Recent critical alerts:"
        grep "CRITICAL" "$AIDE_ALERT_LOG" | tail -3
    fi
else
    echo "No alert log found"
fi

echo
echo "=== End of AIDE Status Report ==="
EOF

    chmod 755 /usr/local/bin/aide-status.sh
    chown root:root /usr/local/bin/aide-status.sh
    
    HARDN_STATUS "pass" "AIDE alerting system created with SIEM integration"
    HARDN_STATUS "info" "Use '/usr/local/bin/aide-status.sh' to check AIDE status"
}

if ! is_installed aide; then
    HARDN_STATUS "info" "Installing and configuring AIDE with SIEM integration and alerting..."
    if command -v apt >/dev/null 2>&1; then
        apt install -y aide aide-common
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y aide
    elif command -v yum >/dev/null 2>&1; then
        yum install -y aide
    fi

    if [[ -f "/etc/aide/aide.conf" ]]; then
        # Backup original config
        cp /etc/aide/aide.conf /etc/aide/aide.conf.bak
        
        # Create comprehensive AIDE configuration for STIG compliance
        cat > /etc/aide/aide.conf <<EOF
# HARDN-XDR STIG Compliant AIDE Configuration
# Enhanced for SIEM integration and comprehensive monitoring

database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
gzip_dbout=yes
verbose=5
report_url=file:/var/log/aide/aide.log

# Define macros for file attributes
FIPSR = p+i+n+u+g+s+m+c+md5+sha1+sha256+sha512+rmd160
NORMAL = FIPSR+acl+selinux+xattrs
DIR = p+i+n+u+g+acl+selinux+xattrs
PERMS = p+i+n+u+g+acl+selinux
LOG = p+u+g+i+n+acl+selinux+xattrs
LSPP = FIPSR+acl+selinux+xattrs
DATAONLY = p+n+u+g+s+acl+selinux+xattrs

# Critical system directories (high priority monitoring)
/boot NORMAL
/bin NORMAL
/sbin NORMAL
/lib NORMAL
/lib64 NORMAL
/usr/bin NORMAL
/usr/sbin NORMAL
/usr/lib NORMAL
/usr/lib64 NORMAL

# Configuration directories
/etc NORMAL
!/etc/mtab
!/etc/.pwd.lock
!/etc/adjtime
!/etc/lvm/cache
!/etc/lvm/backup
!/etc/lvm/archive

# System directories
/root NORMAL
!/root/.bash_history
!/root/.viminfo

# Important system files
/etc/passwd NORMAL
/etc/shadow NORMAL
/etc/group NORMAL
/etc/gshadow NORMAL
/etc/sudoers NORMAL
/etc/sudoers.d NORMAL

# SSH configuration
/etc/ssh NORMAL

# Kernel and modules
/lib/modules NORMAL

# Log directories (permissions only)
/var/log LOG
!/var/log/.*

# Exclude volatile files and directories
!/var/.*
!/tmp/.*
!/proc/.*
!/sys/.*
!/dev/.*
!/run/.*
!/home/.*/.*cache.*
!/home/.*/.mozilla/.*
!/home/.*/.config/.*
EOF

        # Create aide log directory
        mkdir -p /var/log/aide
        chown root:root /var/log/aide
        chmod 750 /var/log/aide
        
        # Initialize AIDE database
        HARDN_STATUS "info" "Initializing AIDE database (this may take several minutes)..."
        aideinit || true
        if [[ -f /var/lib/aide/aide.db.new ]]; then
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db || true
            HARDN_STATUS "pass" "AIDE database initialized successfully"
        else
            HARDN_STATUS "warning" "AIDE database initialization may have failed"
        fi
        
        # Create AIDE alerting script for SIEM integration
        create_aide_alerting_system
        
        # Create enhanced cron job with alerting
        cat > /etc/cron.d/aide-check << 'EOF'
# AIDE integrity check with SIEM alerting - runs daily at 5 AM
0 5 * * * root /usr/local/bin/aide-check-with-alerts.sh
EOF
        chmod 644 /etc/cron.d/aide-check
        
        HARDN_STATUS "pass" "AIDE installed and configured with comprehensive monitoring and SIEM integration."
        HARDN_STATUS "info" "AIDE will run daily at 5 AM with automated alerting for integrity violations."
    else
        HARDN_STATUS "error" "AIDE install failed, /etc/aide/aide.conf not found"
    fi
else
    HARDN_STATUS "warning" "AIDE already installed, enhancing with SIEM integration..."
    create_aide_alerting_system
fi