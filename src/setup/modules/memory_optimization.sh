#!/bin/bash
# Module: memory_optimization.sh
# Purpose: Optimize system and memory management for less powerful desktops
# Compliance: CIS-005.1, STIG-V-38539
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

# Check system resources
check_system_resources() {
    local total_ram_mb=$(free -m | awk 'NR==2{print $2}')
    local cpu_cores=$(nproc)
    local is_low_resource=false
    
    HARDN_STATUS "info" "System Resources: ${total_ram_mb}MB RAM, ${cpu_cores} CPU cores"
    
    # Define low-resource system thresholds
    if [[ $total_ram_mb -lt 2048 ]] || [[ $cpu_cores -lt 2 ]]; then
        is_low_resource=true
        HARDN_STATUS "info" "Low-resource system detected - applying optimizations"
    else
        HARDN_STATUS "info" "Standard resource system - applying minimal optimizations"
    fi
    
    echo "$is_low_resource"
}

# Optimize swap usage for low-memory systems
optimize_swap_usage() {
    HARDN_STATUS "info" "Optimizing swap usage..."
    
    local is_low_resource="$1"
    local swappiness_value=10
    
    if [[ "$is_low_resource" == "true" ]]; then
        # More aggressive swapping for low-memory systems
        swappiness_value=30
        HARDN_STATUS "info" "Low-memory system - setting swappiness to $swappiness_value"
    else
        # Conservative swapping for normal systems
        swappiness_value=10
        HARDN_STATUS "info" "Standard system - setting swappiness to $swappiness_value"
    fi
    
    # Configure vm.swappiness
    if [[ -w /proc/sys/vm/swappiness ]]; then
        echo "$swappiness_value" > /proc/sys/vm/swappiness
        
        # Make permanent
        if ! grep -q "vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
            echo "vm.swappiness = $swappiness_value" >> /etc/sysctl.conf
        else
            sed -i "s/vm.swappiness.*/vm.swappiness = $swappiness_value/" /etc/sysctl.conf
        fi
        
        HARDN_STATUS "pass" "Swap usage optimized (swappiness=$swappiness_value)"
    else
        HARDN_STATUS "warning" "Cannot modify swap settings in container environment"
    fi
}

# Optimize memory caching
optimize_memory_caching() {
    HARDN_STATUS "info" "Optimizing memory caching..."
    
    local is_low_resource="$1"
    
    if [[ ! -w /proc/sys/vm ]]; then
        HARDN_STATUS "warning" "Cannot modify memory settings in container environment"
        return 0
    fi
    
    # Configure dirty page ratios for better memory management
    if [[ "$is_low_resource" == "true" ]]; then
        # More aggressive memory management for low-resource systems
        echo "5" > /proc/sys/vm/dirty_ratio
        echo "2" > /proc/sys/vm/dirty_background_ratio
        
        # Reduce cache pressure
        echo "150" > /proc/sys/vm/vfs_cache_pressure
        
        # Make permanent
        cat >> /etc/sysctl.conf << 'EOF'
# HARDN-XDR: Low-resource memory optimization
vm.dirty_ratio = 5
vm.dirty_background_ratio = 2
vm.vfs_cache_pressure = 150
EOF
        
        HARDN_STATUS "pass" "Aggressive memory caching configured for low-resource system"
    else
        # Standard memory management
        echo "10" > /proc/sys/vm/dirty_ratio
        echo "5" > /proc/sys/vm/dirty_background_ratio
        echo "100" > /proc/sys/vm/vfs_cache_pressure
        
        # Make permanent
        cat >> /etc/sysctl.conf << 'EOF'
# HARDN-XDR: Standard memory optimization
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 100
EOF
        
        HARDN_STATUS "pass" "Standard memory caching configured"
    fi
}

# Optimize security modules for resource usage
optimize_security_modules() {
    HARDN_STATUS "info" "Optimizing security modules for resource usage..."
    
    local is_low_resource="$1"
    local config_file="/etc/hardn-xdr/resource-optimization.conf"
    
    mkdir -p "$(dirname "$config_file")"
    
    cat > "$config_file" << EOF
# HARDN-XDR Resource Optimization Configuration
# Generated: $(date)

[system]
low_resource_mode = $is_low_resource
total_ram_mb = $(free -m | awk 'NR==2{print $2}')
cpu_cores = $(nproc)

[module_optimization]
EOF
    
    if [[ "$is_low_resource" == "true" ]]; then
        cat >> "$config_file" << 'EOF'
# Skip resource-intensive modules on low-resource systems
skip_yara_signatures = true
skip_heavy_scanning = true
reduce_audit_logging = true
disable_realtime_monitoring = true
limit_concurrent_scans = 2

[performance_tuning]
# Reduce scan frequencies
malware_scan_interval = 86400  # Daily instead of hourly
integrity_check_interval = 604800  # Weekly instead of daily
log_rotation_size = 10M  # Smaller log files
EOF
        HARDN_STATUS "info" "Low-resource optimizations configured"
    else
        cat >> "$config_file" << 'EOF'
# Standard resource configuration
skip_yara_signatures = false
skip_heavy_scanning = false
reduce_audit_logging = false
disable_realtime_monitoring = false
limit_concurrent_scans = 4

[performance_tuning]
# Standard scan frequencies
malware_scan_interval = 3600  # Hourly
integrity_check_interval = 86400  # Daily
log_rotation_size = 50M  # Standard log files
EOF
        HARDN_STATUS "info" "Standard resource configuration applied"
    fi
    
    HARDN_STATUS "pass" "Security module optimization completed"
}

# Configure systemd service limits for resource management
configure_service_limits() {
    HARDN_STATUS "info" "Configuring service resource limits..."
    
    local is_low_resource="$1"
    local limits_dir="/etc/systemd/system.conf.d"
    
    if ! is_systemd_available; then
        HARDN_STATUS "warning" "systemd not available - skipping service limits"
        return 0
    fi
    
    mkdir -p "$limits_dir"
    
    if [[ "$is_low_resource" == "true" ]]; then
        cat > "$limits_dir/hardn-resource-limits.conf" << 'EOF'
[Manager]
# HARDN-XDR: Low-resource system limits
DefaultMemoryMax=256M
DefaultTasksMax=512
DefaultTimeoutStartSec=30s
DefaultTimeoutStopSec=15s
EOF
        HARDN_STATUS "pass" "Restrictive service limits configured"
    else
        cat > "$limits_dir/hardn-resource-limits.conf" << 'EOF'
[Manager]
# HARDN-XDR: Standard system limits
DefaultMemoryMax=512M
DefaultTasksMax=1024
DefaultTimeoutStartSec=60s
DefaultTimeoutStopSec=30s
EOF
        HARDN_STATUS "pass" "Standard service limits configured"
    fi
    
    # Reload systemd if not in container
    if ! is_container_environment; then
        systemctl daemon-reload 2>/dev/null || true
    fi
}

# Optimize desktop environment for low-resource systems
optimize_desktop_environment() {
    local is_low_resource="$1"
    
    if [[ "$is_low_resource" != "true" ]]; then
        HARDN_STATUS "info" "Standard resource system - skipping desktop optimizations"
        return 0
    fi
    
    HARDN_STATUS "info" "Optimizing desktop environment for low-resource system..."
    
    # Create desktop optimization script
    local desktop_script="/usr/local/bin/hardn-desktop-optimize"
    
    cat > "$desktop_script" << 'EOF'
#!/bin/bash
# HARDN-XDR Desktop Optimization Script

# Disable unnecessary desktop effects
if command -v gsettings >/dev/null 2>&1; then
    # GNOME optimizations
    gsettings set org.gnome.desktop.interface enable-animations false
    gsettings set org.gnome.desktop.interface enable-hot-corners false
    gsettings set org.gnome.shell.overrides workspaces-only-on-primary true
fi

# Reduce compositor effects in various desktop environments
if command -v xfconf-query >/dev/null 2>&1; then
    # XFCE optimizations
    xfconf-query -c xfwm4 -p /general/use_compositing -s false
    xfconf-query -c xfwm4 -p /general/frame_opacity -s 100
fi

# Disable thumbnail generation for large files
if [[ -f ~/.config/user-dirs.conf ]]; then
    echo 'enabled=False' >> ~/.config/user-dirs.conf
fi

echo "Desktop optimizations applied for low-resource system"
EOF
    
    chmod +x "$desktop_script"
    
    HARDN_STATUS "pass" "Desktop optimization script created: $desktop_script"
    HARDN_STATUS "info" "Run '$desktop_script' in user session to apply desktop optimizations"
}

# Create resource monitoring script
create_resource_monitor() {
    HARDN_STATUS "info" "Creating resource monitoring script..."
    
    local monitor_script="/usr/local/bin/hardn-resource-monitor"
    
    cat > "$monitor_script" << 'EOF'
#!/bin/bash
# HARDN-XDR Resource Monitoring Script

LOG_FILE="/var/log/hardn-xdr/resource-usage.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Get system metrics
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
memory_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
cpu_load=$(uptime | awk -F'load average:' '{print $2}' | cut -d, -f1 | xargs)
disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')

# Log metrics
echo "$timestamp,Memory:${memory_usage}%,CPU:${cpu_load},Disk:${disk_usage}%" >> "$LOG_FILE"

# Check for resource warnings
if (( $(echo "$memory_usage > 90" | bc -l) )); then
    logger -t hardn-xdr "WARNING: High memory usage: ${memory_usage}%"
fi

if (( $(echo "$cpu_load > 2.0" | bc -l) )); then
    logger -t hardn-xdr "WARNING: High CPU load: $cpu_load"
fi

if [[ $disk_usage -gt 90 ]]; then
    logger -t hardn-xdr "WARNING: High disk usage: ${disk_usage}%"
fi
EOF
    
    chmod +x "$monitor_script"
    
    # Set up cron job for monitoring
    if create_scheduled_task; then
        local cron_entry="*/5 * * * * root $monitor_script"
        if ! grep -q "hardn-resource-monitor" /etc/crontab 2>/dev/null; then
            echo "$cron_entry" >> /etc/crontab
            HARDN_STATUS "pass" "Resource monitoring scheduled every 5 minutes"
        fi
    fi
    
    HARDN_STATUS "pass" "Resource monitoring script created: $monitor_script"
}

# Generate resource optimization report
generate_optimization_report() {
    local is_low_resource="$1"
    local report_file="/var/log/hardn-xdr/resource-optimization-report.txt"
    
    mkdir -p "$(dirname "$report_file")"
    
    cat > "$report_file" << EOF
# HARDN-XDR Resource Optimization Report
Generated: $(date)

## System Information
Total RAM: $(free -m | awk 'NR==2{print $2}')MB
CPU Cores: $(nproc)
Low Resource Mode: $is_low_resource

## Applied Optimizations
EOF
    
    if [[ "$is_low_resource" == "true" ]]; then
        cat >> "$report_file" << 'EOF'
✓ Aggressive swap management (swappiness=30)
✓ Reduced memory caching (dirty_ratio=5)
✓ Resource-intensive modules disabled
✓ Service memory limits applied (256MB default)
✓ Desktop environment optimizations available
✓ Reduced scan frequencies for performance

## Recommendations for Low-Resource Systems
- Consider disabling visual effects in desktop environment
- Run desktop optimization script for GUI systems
- Monitor resource usage with hardn-resource-monitor
- Review running services and disable unnecessary ones
- Consider upgrading to SSD for better performance
EOF
    else
        cat >> "$report_file" << 'EOF'
- Conservative swap management (swappiness=10)
- Standard memory caching (dirty_ratio=10)
- All security modules enabled
- Standard service memory limits (512MB default)
- Resource monitoring enabled

## Recommendations for Standard Systems
- Resource optimization is minimal for this system
- All security features are enabled
- Monitor resource usage trends
- Consider increasing security module frequency if desired
EOF
    fi
    
    HARDN_STATUS "pass" "Optimization report generated: $report_file"
}

# Main execution function
memory_optimization_main() {
    HARDN_STATUS "info" "Starting memory and resource optimization..."
    
    # Check root privileges
    if ! check_root; then
        HARDN_STATUS "error" "Root privileges required for memory optimization"
        hardn_module_exit 1
    fi
    
    # Skip in container environments for most optimizations
    if is_container_environment; then
        HARDN_STATUS "info" "Container environment detected - applying limited optimizations"
        optimize_security_modules "false"
        HARDN_STATUS "pass" "Container-appropriate optimizations completed"
        return 0
    fi
    
    # Check system resources
    local is_low_resource
    is_low_resource=$(check_system_resources)
    
    # Apply optimizations based on system resources
    optimize_swap_usage "$is_low_resource"
    optimize_memory_caching "$is_low_resource"
    optimize_security_modules "$is_low_resource"
    configure_service_limits "$is_low_resource"
    optimize_desktop_environment "$is_low_resource"
    create_resource_monitor
    
    # Generate report
    generate_optimization_report "$is_low_resource"
    
    # Summary message
    if [[ "$is_low_resource" == "true" ]]; then
        hardn_msgbox "Low-resource optimizations applied. Review /var/log/hardn-xdr/resource-optimization-report.txt for details."
    else
        hardn_msgbox "Standard resource optimizations applied. System has adequate resources for full security suite."
    fi
    
    HARDN_STATUS "pass" "Memory and resource optimization completed successfully"
    
    return 0
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    memory_optimization_main "$@"
fi
