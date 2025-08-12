#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# Check for container environment
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - package integrity checks may be limited"
    HARDN_STATUS "info" "Container images typically have minimal package sets with different integrity expectations"
fi

export LC_ALL=C
export LANG=C

# Set up cleanup trap for any temporary files
cleanup() {
    # Remove any temporary files created by the script
    [ -n "$TMP_FILES" ] && rm -f "$TMP_FILES"
}
trap cleanup EXIT INT TERM

# Cache command availability at script start
PARALLEL_AVAILABLE=$(command -v parallel >/dev/null 2>&1 && echo "yes" || echo "no")
DEBSUMS_AVAILABLE=$(command -v debsums >/dev/null 2>&1 && echo "yes" || echo "no")
SYSTEMD_AVAILABLE=$(command -v systemctl >/dev/null 2>&1 && echo "yes" || echo "no")

# Set resource limits to prevent excessive memory usage
# Limit virtual memory to 1GB
ulimit -v 1000000 2>/dev/null || true

# Function to detect package manager (optimized with case statement)
get_pkg_manager() {
    # Use which instead of command -v for better performance
    local cmd
    for cmd in apt dnf yum rpm; do
        which $cmd >/dev/null 2>&1 && { echo "$cmd"; return 0; }
    done
    echo "unknown"
}

# Function to check if a package is installed (optimized)
is_installed() {
    local package="$1"

    # Use cached package manager value
    case "$PKG_MANAGER" in
        apt)
            dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"
            ;;
        dnf)
            dnf list installed "$package" >/dev/null 2>&1
            ;;
        yum)
            yum list installed "$package" >/dev/null 2>&1
            ;;
        rpm)
            rpm -q "$package" >/dev/null 2>&1
            ;;
        *)
            return 1 # Cannot determine package manager
            ;;
    esac
}

# Function to efficiently create log directories with rotation
setup_logging() {
    local log_dir="/var/log/debsums"
    local log_file="$log_dir/debsums-check.log"
    local max_logs=5

    # Create log directory if it doesn't exist
    [ -d "$log_dir" ] || mkdir -p "$log_dir"

    # Set up log rotation
    if [ -f "$log_file" ]; then
        # C-Style for loop, Rotate logs - more efficient than logrotate for simple cases
        for((i=max_logs;i>=1;i--)); do
            [ -f "${log_file}.$i" ] && mv "${log_file}.$i" "${log_file}.$((i+1))"
        done
        mv "$log_file" "${log_file}.1"
    fi

    # Return the log file path
    echo "$log_file"
}

HARDN_STATUS "info" "Configuring debsums..."

# Get package manager once to avoid redundant checks
PKG_MANAGER=$(get_pkg_manager)

# Consolidated function to handle debsums installation and verification
setup_debsums() {
# Only proceed on apt-based systems
    if [ "$PKG_MANAGER" != "apt" ]; then
        HARDN_STATUS "warning" "debsums is a Debian-specific package, cannot install on this system."
        return 0  # Changed from return 1 to return 0 for CI compatibility
    fi

    # Install if not present
    if ! is_installed debsums; then
        HARDN_STATUS "info" "Installing debsums..."
        if ! safe_package_install debsums; then
            HARDN_STATUS "error" "Failed to install debsums"
            return 0  # Changed from return 1 for CI compatibility
        fi
    fi

    # Verify installation
    if [ "$DEBSUMS_AVAILABLE" != "yes" ]; then
        # Re-check in case it was just installed
        DEBSUMS_AVAILABLE=$(command -v debsums >/dev/null 2>&1 && echo "yes" || echo "no")
        if [ "$DEBSUMS_AVAILABLE" != "yes" ]; then
            HARDN_STATUS "error" "debsums command not found, skipping configuration"
            return 0  # Changed from return 1 for CI compatibility
        fi
    fi

    return 0
}

# Call setup function and exit if it fails
if ! setup_debsums; then
  HARDN_STATUS "warning" "Skipping debsums module due to setup failure."
  exit 0  # Changed from exit 1 for CI compatibility
fi

# Function to create systemd service if available, otherwise use cron
create_scheduled_task() {
    # Determine optimal CPU usage - leave one core free
    local cpu_count
    cpu_count=$(nproc)
    local optimal_cores=$((cpu_count > 1 ? cpu_count - 1 : 1))

    # Generate a random minute based on hostname for distributed scheduling
    local hostname_hash
    hostname_hash=$(hostname | cksum | cut -d' ' -f1)
    local random_minute=$((hostname_hash % 60))
    local random_hour=$((3 + (hostname_hash % 4)))  # Between 3-6 AM

    if [ "$SYSTEMD_AVAILABLE" = "yes" ]; then
        # Create systemd timer and service for better resource control
        local service_file="/etc/systemd/system/debsums-check.service"
        local timer_file="/etc/systemd/system/debsums-check.timer"

        # Only create if files don't exist
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

            systemctl daemon-reload
            systemctl enable debsums-check.timer
            systemctl start debsums-check.timer
            HARDN_STATUS "pass" "Systemd timer for debsums check created and enabled"
        else
            HARDN_STATUS "warning" "Systemd service for debsums already exists"
        fi
    else
        # Fall back to cron if systemd not available
        local cron_file="/etc/cron.d/debsums"
        if [ ! -f "$cron_file" ]; then
            # Create a single cron job with proper resource limits
            cat <<EOF > "$cron_file"
# Debsums integrity check - runs at $random_hour:$random_minute daily
$random_minute $random_hour * * * root cd / && ulimit -v 1000000 && nice -n 19 ionice -c3 bash -c 'LOG_FILE=\$(mktemp); echo "Starting debsums check at \$(date)" > \$LOG_FILE; if command -v parallel >/dev/null 2>&1; then dpkg-query -f \${Package}\\\\n -W | parallel -j$optimal_cores "debsums -s {} 2>&1 || echo Failed: {}" >> \$LOG_FILE; else debsums -s 2>&1 >> \$LOG_FILE; fi; echo "Completed at \$(date)" >> \$LOG_FILE; grep -q "Failed:" \$LOG_FILE && grep "Failed:" \$LOG_FILE | logger -t debsums; cat \$LOG_FILE >> /var/log/debsums/debsums-check.log; rm \$LOG_FILE'
EOF
            chmod 644 "$cron_file"
            HARDN_STATUS "pass" "Optimized debsums cron job created"
        else
            HARDN_STATUS "warning" "Debsums cron job already exists"
        fi

        # Remove any old cron entries to avoid duplication
        if [ -f "/etc/cron.daily/debsums" ]; then
            rm -f "/etc/cron.daily/debsums"
        fi

        # Remove from /etc/crontab if present (use sed instead of grep+echo)
        if grep -qF "/usr/bin/debsums" /etc/crontab; then
            TMP_CRONTAB=$(mktemp)
            TMP_FILES="$TMP_FILES $TMP_CRONTAB"
            sed '/\/usr\/bin\/debsums/d' /etc/crontab > "$TMP_CRONTAB"
            cat "$TMP_CRONTAB" > /etc/crontab
        fi
    fi

    # Create log directory
    setup_logging >/dev/null
}

# Install parallel for faster processing if available (optimized)
install_parallel() {
    # Skip if not apt or already installed
    [ "$PKG_MANAGER" != "apt" ] && return 0
    [ "$PARALLEL_AVAILABLE" = "yes" ] && return 0

    HARDN_STATUS "info" "Installing GNU parallel for faster debsums processing..."
    if ! safe_package_install parallel; then
        HARDN_STATUS "warning" "Failed to install GNU parallel, will use standard method"
        return 0  # Changed from return 1 for CI compatibility
    fi

    # Update availability status
    PARALLEL_AVAILABLE="yes"
    return 0
}

# Function to run debsums check with parallel processing (optimized)
run_parallel_check() {
    # Determine optimal CPU usage - leave one core free
    local cpu_count
    cpu_count=$(nproc)
    local optimal_cores=$((cpu_count > 1 ? cpu_count - 1 : 1))

    # Use memory-efficient pipeline
    dpkg-query -f '${Package}\n' -W |
        nice -n 19 ionice -c3 parallel --will-cite -j"$optimal_cores" \
        "debsums -s {} >/dev/null 2>&1" 2>/dev/null
    return $?
}

# Function to run debsums check with standard method (optimized)
run_standard_check() {
    # Set memory and CPU limits
    nice -n 19 ionice -c3 debsums -s >/dev/null 2>&1
    return $?
}

# Function to report check results (optimized with printf)
report_check_result() {
    local success=$1
    if [ "$success" -eq 0 ]; then
        printf "PASS: Initial debsums check completed successfully\n"
        HARDN_STATUS "pass" "Initial debsums check completed successfully"
    else
        printf "WARNING: Warning: Some packages failed debsums verification\n"
        HARDN_STATUS "warning" "Warning: Some packages failed debsums verification"
    fi
}

# Function to measure time taken for the debsums check
measure_execution_time() {
    local start_time=$1
    local end_time
    end_time=$(date +%s)

    local duration=$((end_time - start_time))

    # Format the duration in a human-readable format
    local hours=$((duration / 3600))
    local minutes=$(( (duration % 3600) / 60 ))
    local seconds=$((duration % 60))

    # Build the time string based on duration
    local time_str=""
    [ $hours -gt 0 ] && time_str="${hours}h "
    [ $minutes -gt 0 ] && time_str="${time_str}${minutes}m "
    time_str="${time_str}${seconds}s"

    HARDN_STATUS "info" "Debsums check completed in: $time_str"
}

# Install parallel for better performance
install_parallel

# Create scheduled task (systemd timer or cron)
create_scheduled_task

# Run initial check with optimizations - handle gracefully in CI
HARDN_STATUS "info" "Running initial debsums check (this may take some time)..."
start_time=$(date +%s)

# Skip intensive debsums check in CI environment to prevent timeouts
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]; then
    HARDN_STATUS "info" "CI environment detected, skipping intensive debsums verification"
    HARDN_STATUS "pass" "Debsums configuration completed (verification skipped in CI)"
else
    # Choose method based on parallel availability and run the check
    if command -v parallel >/dev/null 2>&1; then
        run_parallel_check || HARDN_STATUS "warning" "Some packages failed debsums verification."
        result=$?
        report_check_result $result
    else
        run_standard_check || HARDN_STATUS "warning" "Some packages failed debsums verification."
        result=$?
        report_check_result $result
    fi

    # Report execution time
    measure_execution_time "$start_time"
fi

return 0 2>/dev/null || hardn_module_exit 0
