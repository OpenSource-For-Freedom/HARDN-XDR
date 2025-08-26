#!/bin/bash
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

# Check for container environment
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - package integrity checks may be limited"
    HARDN_STATUS "info" "Container images typically have minimal package sets with different integrity expectations"
fi

export LC_ALL=C
export LANG=C

# Initialize temporary files array (patched)
TMP_FILES=()

# Set up cleanup trap for any temporary files
cleanup() {
    if [[ ${#TMP_FILES[@]} -gt 0 ]]; then
        rm -f "${TMP_FILES[@]}"
    fi
}
trap cleanup EXIT INT TERM

# Cache command availability at script start
PARALLEL_AVAILABLE=$(command -v parallel >/dev/null 2>&1 && echo "yes" || echo "no")
DEBSUMS_AVAILABLE=$(command -v debsums >/dev/null 2>&1 && echo "yes" || echo "no")
SYSTEMD_AVAILABLE=$(command -v systemctl >/dev/null 2>&1 && echo "yes" || echo "no")

# Set resource limits to prevent excessive memory usage
ulimit -v 1000000 2>/dev/null || true

# Function to detect package manager
get_pkg_manager() {
    local cmd
    for cmd in apt dnf yum rpm; do
        which $cmd >/dev/null 2>&1 && { echo "$cmd"; return 0; }
    done
    echo "unknown"
}

# Function to check if a package is installed
is_installed() {
    local package="$1"
    case "$PKG_MANAGER" in
        apt)
            dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"
            ;;
        dnf) dnf list installed "$package" >/dev/null 2>&1 ;;
        yum) yum list installed "$package" >/dev/null 2>&1 ;;
        rpm) rpm -q "$package" >/dev/null 2>&1 ;;
        *) return 1 ;;
    esac
}

# Logging setup
setup_logging() {
    local log_dir="/var/log/debsums"
    local log_file="$log_dir/debsums-check.log"
    local max_logs=5
    [ -d "$log_dir" ] || mkdir -p "$log_dir"
    if [ -f "$log_file" ]; then
        for((i=max_logs;i>=1;i--)); do
            [ -f "${log_file}.$i" ] && mv "${log_file}.$i" "${log_file}.$((i+1))"
        done
        mv "$log_file" "${log_file}.1"
    fi
    echo "$log_file"
}

HARDN_STATUS "info" "Configuring debsums..."

# Get package manager once
PKG_MANAGER=$(get_pkg_manager)

# Consolidated setup
setup_debsums() {
    if [ "$PKG_MANAGER" != "apt" ]; then
        HARDN_STATUS "warning" "debsums is a Debian-specific package, cannot install on this system."
        return 0
    fi

    if ! is_installed debsums; then
        HARDN_STATUS "info" "Installing debsums..."
        if ! safe_package_install debsums; then
            HARDN_STATUS "error" "Failed to install debsums"
            return 0
        fi
    fi

    if [ "$DEBSUMS_AVAILABLE" != "yes" ]; then
        DEBSUMS_AVAILABLE=$(command -v debsums >/dev/null 2>&1 && echo "yes" || echo "no")
        if [ "$DEBSUMS_AVAILABLE" != "yes" ]; then
            HARDN_STATUS "error" "debsums command not found, skipping configuration"
            return 0
        fi
    fi
    exit 0
}

if ! setup_debsums; then
  HARDN_STATUS "warning" "Skipping debsums module due to setup failure."
  exit 0
fi

# Create scheduled task
create_scheduled_task() {
    local cpu_count=$(nproc)
    local optimal_cores=$((cpu_count > 1 ? cpu_count - 1 : 1))
    local hostname_hash=$(hostname | cksum | cut -d' ' -f1)
    local random_minute=$((hostname_hash % 60))
    local random_hour=$((3 + (hostname_hash % 4)))

    if [ "$SYSTEMD_AVAILABLE" = "yes" ] && ! is_container_environment; then
        local service_file="/etc/systemd/system/debsums-check.service"
        local timer_file="/etc/systemd/system/debsums-check.timer"
        if [ ! -f "$service_file" ]; then
            cat <<EOF > "$service_file"
[Unit]
Description=Check package integrity with debsums
After=network.target

[Service]
Type=oneshot
Nice=19
IOSchedulingClass=idle
CPUQuota=75%
MemoryLimit=512M
ExecStart=/bin/bash -c 'LOG_FILE=\$(mktemp); echo "Starting debsums check at \$(date)" > \$LOG_FILE; if command -v parallel >/dev/null 2>&1; then dpkg-query -f \${Package}\\\\n -W | parallel -j$optimal_cores "debsums -s {} 2>&1 || echo Failed: {}" >> \$LOG_FILE; else debsums -s 2>&1 >> \$LOG_FILE; fi; echo "Completed at \$(date)" >> \$LOG_FILE; grep -q "Failed:" \$LOG_FILE && grep "Failed:" \$LOG_FILE | logger -t debsums; cat \$LOG_FILE >> /var/log/debsums/debsums-check.log; rm \$LOG_FILE'

[Install]
WantedBy=multi-user.target
EOF

            cat <<EOF > "$timer_file"
[Unit]
Description=Run debsums check daily

[Timer]
OnCalendar=*-*-* $random_hour:$random_minute:00
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

            if systemctl daemon-reload >/dev/null 2>&1 && \
               systemctl enable debsums-check.timer >/dev/null 2>&1 && \
               systemctl start debsums-check.timer >/dev/null 2>&1; then
                HARDN_STATUS "pass" "Systemd timer for debsums check created and enabled"
            else
                HARDN_STATUS "warning" "Failed to enable systemd timer, falling back to cron"
                rm -f "$service_file" "$timer_file"
                SYSTEMD_AVAILABLE="no"
            fi
        else
            HARDN_STATUS "warning" "Systemd service for debsums already exists"
        fi
    fi

    if [ "$SYSTEMD_AVAILABLE" != "yes" ] || is_container_environment; then
        local cron_file="/etc/cron.d/debsums"
        if [ ! -f "$cron_file" ]; then
            cat <<EOF > "$cron_file"
# Debsums integrity check - runs at $random_hour:$random_minute daily
$random_minute $random_hour * * * root cd / && ulimit -v 1000000 && nice -n 19 ionice -c3 bash -c 'LOG_FILE=\$(mktemp); echo "Starting debsums check at \$(date)" > \$LOG_FILE; if command -v parallel >/dev/null 2>&1; then dpkg-query -f \${Package}\\\\n -W | parallel -j$optimal_cores "debsums -s {} 2>&1 || echo Failed: {}" >> \$LOG_FILE; else debsums -s 2>&1 >> \$LOG_FILE; fi; echo "Completed at \$(date)" >> \$LOG_FILE; grep -q "Failed:" \$LOG_FILE && grep "Failed:" \$LOG_FILE | logger -t debsums; cat \$LOG_FILE >> /var/log/debsums/debsums-check.log; rm \$LOG_FILE'
EOF
            chmod 644 "$cron_file"
            HARDN_STATUS "pass" "Optimized debsums cron job created"
        else
            HARDN_STATUS "warning" "Debsums cron job already exists"
        fi

        if [ -f "/etc/cron.daily/debsums" ]; then
            rm -f "/etc/cron.daily/debsums"
        fi

        if grep -qF "/usr/bin/debsums" /etc/crontab; then
            TMP_CRONTAB=$(mktemp)
            TMP_FILES+=("$TMP_CRONTAB")
            sed '/\/usr\/bin\/debsums/d' /etc/crontab > "$TMP_CRONTAB"
            cat "$TMP_CRONTAB" > /etc/crontab
        fi
    fi

    setup_logging >/dev/null
}

# Install parallel for faster processing if available
install_parallel() {
    [ "$PKG_MANAGER" != "apt" ] && return 0
    [ "$PARALLEL_AVAILABLE" = "yes" ] && return 0
    HARDN_STATUS "info" "Installing GNU parallel for faster debsums processing..."
    if ! safe_package_install parallel; then
        HARDN_STATUS "warning" "Failed to install GNU parallel, will use standard method"
        return 0
    fi
    PARALLEL_AVAILABLE="yes"
    exit 0
}

# Parallel check
run_parallel_check() {
    local cpu_count=$(nproc)
    local optimal_cores=$((cpu_count > 1 ? cpu_count - 1 : 1))
    dpkg-query -f '${Package}\n' -W |
        nice -n 19 ionice -c3 parallel --will-cite -j"$optimal_cores" \
        "debsums -s {} >/dev/null 2>&1" 2>/dev/null
}

# Standard check
run_standard_check() {
    nice -n 19 ionice -c3 debsums -s >/dev/null 2>&1
}

report_check_result() {
    local success=$1
    if [ "$success" -eq 0 ]; then
        printf "PASS: Initial debsums check completed successfully\n"
        HARDN_STATUS "pass" "Initial debsums check completed successfully"
    else
        printf "WARNING: Some packages failed debsums verification\n"
        HARDN_STATUS "warning" "Some packages failed debsums verification"
    fi
}

measure_execution_time() {
    local start_time=$1
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))
    local time_str=""
    [ $hours -gt 0 ] && time_str="${hours}h "
    [ $minutes -gt 0 ] && time_str="${time_str}${minutes}m "
    time_str="${time_str}${seconds}s"
    HARDN_STATUS "info" "Debsums check completed in: $time_str"
}

# Install parallel
install_parallel

# Create scheduled task
create_scheduled_task

# Run initial check
HARDN_STATUS "info" "Running initial debsums check (this may take some time)..."
start_time=$(date +%s)

if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]; then
    HARDN_STATUS "info" "CI environment detected, skipping intensive debsums verification"
    HARDN_STATUS "pass" "Debsums configuration completed (verification skipped in CI)"
else
    if command -v parallel >/dev/null 2>&1; then
        run_parallel_check || HARDN_STATUS "warning" "Some packages failed debsums verification."
        result=$?
        report_check_result $result
    else
        run_standard_check || HARDN_STATUS "warning" "Some packages failed debsums verification."
        result=$?
        report_check_result $result
    fi
    measure_execution_time "$start_time"
fi

return 0 2>/dev/null || hardn_module_exit 0
set -e
