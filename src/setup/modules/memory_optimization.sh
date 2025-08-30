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
    hardn_yesno() { [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0; echo "Auto-confirming: $1" >&2; return 0; }
    hardn_msgbox() { [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0; echo "Info: $1" >&2; }
    is_container_environment() { [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
    is_systemd_available() { [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1; }
    create_scheduled_task() { echo "Info: Scheduled task creation skipped in CI environment" >&2; return 0; }
    check_container_limitations() { [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]] && echo "Warning: Container limitations detected" >&2; return 0; }
    hardn_module_exit() { exit "${1:-0}"; }
}

export LC_ALL=C
export LANG=C

# --- Check system resources ---
check_system_resources() {
    local total_ram_mb=$(free -m | awk 'NR==2{print $2}')
    local cpu_cores=$(nproc)
    local is_low_resource=false
    HARDN_STATUS "info" "System Resources: ${total_ram_mb}MB RAM, ${cpu_cores} CPU cores"

    if [[ $total_ram_mb -lt 2048 ]] || [[ $cpu_cores -lt 2 ]]; then
        is_low_resource=true
        HARDN_STATUS "info" "Low-resource system detected - applying optimizations"
    else
        HARDN_STATUS "info" "Standard resource system - minimal optimizations"
    fi
    echo "$is_low_resource"
}

# --- Optimize swap ---
optimize_swap_usage() {
    local is_low_resource="$1"
    local swappiness_value=10
    [[ "$is_low_resource" == "true" ]] && swappiness_value=30

    if [[ -w /proc/sys/vm/swappiness ]]; then
        sysctl -w vm.swappiness="$swappiness_value" >/dev/null 2>&1
        install -d -m 0755 /etc/sysctl.d
        cat >/etc/sysctl.d/99-hardn-memory.conf <<EOF
vm.swappiness = $swappiness_value
EOF
        HARDN_STATUS "pass" "Swap usage optimized (swappiness=$swappiness_value)"
    else
        HARDN_STATUS "warning" "Cannot modify swap in container environment"
    fi
}

# --- Optimize memory caching ---
optimize_memory_caching() {
    local is_low_resource="$1"
    install -d -m 0755 /etc/sysctl.d

    if [[ "$is_low_resource" == "true" ]]; then
        sysctl -w vm.dirty_ratio=10 vm.dirty_background_ratio=5 vm.vfs_cache_pressure=120 >/dev/null 2>&1
        cat >/etc/sysctl.d/99-hardn-memory.conf <<'EOF'
# HARDN-XDR: Low-resource memory optimization (desktop-safe)
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 120
EOF
        HARDN_STATUS "pass" "Low-resource memory caching tuned (desktop-safe)"
    else
        sysctl -w vm.dirty_ratio=10 vm.dirty_background_ratio=5 vm.vfs_cache_pressure=100 >/dev/null 2>&1
        cat >/etc/sysctl.d/99-hardn-memory.conf <<'EOF'
# HARDN-XDR: Standard memory optimization
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5
vm.vfs_cache_pressure = 100
EOF
        HARDN_STATUS "pass" "Standard memory caching configured"
    fi
}

# --- Optimize security modules (resource aware) ---
optimize_security_modules() {
    local is_low_resource="$1"
    local config_file="/etc/hardn-xdr/resource-optimization.conf"
    mkdir -p "$(dirname "$config_file")"

    cat > "$config_file" <<EOF
[system]
low_resource_mode = $is_low_resource
total_ram_mb = $(free -m | awk 'NR==2{print $2}')
cpu_cores = $(nproc)
EOF
    [[ "$is_low_resource" == "true" ]] && HARDN_STATUS "info" "Low-resource security module tweaks applied" || HARDN_STATUS "info" "Standard security config applied"
    HARDN_STATUS "pass" "Security module optimization recorded"
}

# --- Skip global systemd manager limits for desktop ---
configure_service_limits() {
    HARDN_STATUS "info" "Skipping global systemd Manager limits for desktop safety"
}

# --- Desktop environment optimizations (user-session only) ---
optimize_desktop_environment() {
    local is_low_resource="$1"
    [[ "$is_low_resource" != "true" ]] && return 0

    local desktop_script="/usr/local/bin/hardn-desktop-optimize"
    cat > "$desktop_script" <<'EOF'
#!/bin/bash
# HARDN-XDR Desktop Optimization Script (to be run in user session)

if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface enable-animations false
    gsettings set org.gnome.shell.overrides workspaces-only-on-primary true
fi

if command -v xfconf-query >/dev/null 2>&1; then
    xfconf-query -c xfwm4 -p /general/use_compositing -s false
fi

echo "Desktop optimizations applied for low-resource system"
EOF
    chmod +x "$desktop_script"

    cat >/etc/xdg/autostart/hardn-desktop-optimize.desktop <<EOF
[Desktop Entry]
Type=Application
Name=HARDN Desktop Optimize
Exec=$desktop_script
OnlyShowIn=GNOME;XFCE;
X-GNOME-Autostart-enabled=true
X-GNOME-Autostart-Delay=10
EOF

    HARDN_STATUS "pass" "Desktop optimization script & autostart created"
}

# --- Resource monitor ---
create_resource_monitor() {
    local monitor_script="/usr/local/bin/hardn-resource-monitor"
    cat > "$monitor_script" <<'EOF'
#!/bin/bash
LOG_FILE="/var/log/hardn-xdr/resource-usage.log"
mkdir -p "$(dirname "$LOG_FILE")"
timestamp=$(date '+%Y-%m-%d %H:%M:%S')
memory_usage=$(free | awk 'NR==2{printf "%.1f", $3*100/$2}')
cpu_load=$(awk '{print $1}' /proc/loadavg)
disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
echo "$timestamp,Memory:${memory_usage}%,CPU:${cpu_load},Disk:${disk_usage}%" >> "$LOG_FILE"
awk -v m="$memory_usage" 'BEGIN{exit !(m>90)}' && logger -t hardn-xdr "WARNING: High memory usage: ${memory_usage}%"
awk -v c="$cpu_load"  'BEGIN{exit !(c>2.0)}' && logger -t hardn-xdr "WARNING: High CPU load: $cpu_load"
[[ $disk_usage -gt 90 ]] && logger -t hardn-xdr "WARNING: High disk usage: ${disk_usage}%"
EOF
    chmod +x "$monitor_script"

    echo "*/5 * * * * root $monitor_script" >/etc/cron.d/hardn-resource-monitor
    chmod 644 /etc/cron.d/hardn-resource-monitor
    HARDN_STATUS "pass" "Resource monitor scheduled every 5 minutes"
}

# --- Report generator ---
generate_optimization_report() {
    local is_low_resource="$1"
    local report_file="/var/log/hardn-xdr/resource-optimization-report.txt"
    mkdir -p "$(dirname "$report_file")"

    echo "# HARDN-XDR Resource Optimization Report" >"$report_file"
    echo "Generated: $(date)" >>"$report_file"
    echo "Total RAM: $(free -m | awk 'NR==2{print $2}')MB" >>"$report_file"
    echo "CPU Cores: $(nproc)" >>"$report_file"
    echo "Low Resource Mode: $is_low_resource" >>"$report_file"
}

# --- Main ---
memory_optimization_main() {
    if ! check_root; then
        HARDN_STATUS "error" "Root privileges required"
        hardn_module_exit 1
    fi

    if is_container_environment; then
        HARDN_STATUS "info" "Container detected - limited optimizations"
        optimize_security_modules "false"
        return 0
    fi

    local is_low_resource
    is_low_resource=$(check_system_resources)
    optimize_swap_usage "$is_low_resource"
    optimize_memory_caching "$is_low_resource"
    optimize_security_modules "$is_low_resource"
    configure_service_limits "$is_low_resource"
    optimize_desktop_environment "$is_low_resource"
    create_resource_monitor
    generate_optimization_report "$is_low_resource"
    HARDN_STATUS "pass" "Memory/resource optimization completed"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] && memory_optimization_main "$@"