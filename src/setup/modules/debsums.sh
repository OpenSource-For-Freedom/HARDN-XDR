#!/bin/bash

# Debsums Optimization Improvements for performance.
# 1. Process Prioritization: Using nice/ionice to reduce system impact during checks
# 2. Parallel Processing: Leveraging GNU parallel with optimal core usage
# 3. Randomized Scheduling: Staggered execution times to prevent system load spikes
# 4. Enhanced Logging: Structured logs with timestamps, rotation and failure-focused reporting
# 5. Adaptive Execution: Script adjusts based on available system tools
# 6. Automatic Dependencies: Installs required tools for optimal performance
# 7. Reduced nested if statements: Simplified logic and improved readability
# 8. Used Case statements for performance and efficiency
# 9. Command availability caching: Reduced redundant checks
# 10. Resource limits: Memory and CPU constraints for better system stability
# 11. Efficient string handling: Optimized text processing

# Speed up script by not using unicode
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
        # Rotate logs - more efficient than logrotate for simple cases
        for i in $(seq $max_logs -1 1); do
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
        return 1
    fi

    # Install if not present
    if ! is_installed debsums; then
        HARDN_STATUS "info" "Installing debsums..."
        apt-get update -qq
        apt-get install -y debsums || {
            HARDN_STATUS "error" "Failed to install debsums"
            return 1
        }
    fi

    # Verify installation
    if [ "$DEBSUMS_AVAILABLE" != "yes" ]; then
        # Re-check in case it was just installed
        DEBSUMS_AVAILABLE=$(command -v debsums >/dev/null 2>&1 && echo "yes" || echo "no")
        if [ "$DEBSUMS_AVAILABLE" != "yes" ]; then
            HARDN_STATUS "error" "debsums command not found, skipping configuration"
            return 1
        fi
    fi

    return 0
}

# Call setup function and exit if it fails
setup_debsums || exit $?

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
    apt-get install -y parallel || {
        HARDN_STATUS "warning" "Failed to install GNU parallel, will use standard method"
        return 1
    }

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

# Run initial check with optimizations
HARDN_STATUS "info" "Running initial debsums check (this may take some time)..."
start_time=$(date +%s)

# Choose method based on parallel availability and run the check
if command -v parallel >/dev/null 2>&1; then
    run_parallel_check
    result=$?
    report_check_result $result
else
    run_standard_check
    result=$?
    report_check_result $result
fi

# Report execution time
measure_execution_time "$start_time"
