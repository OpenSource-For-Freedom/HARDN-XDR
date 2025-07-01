#!/bin/bash

# Debsums Optimization Improvements:
# 1. Process Prioritization: Using nice/ionice to reduce system impact during checks
# 2. Parallel Processing: Leveraging GNU parallel for multi-core efficiency
# 3. Randomized Scheduling: Staggered execution times to prevent system load spikes
# 4. Enhanced Logging: Structured logs with timestamps and failure-focused reporting
# 5. Adaptive Execution: Script adjusts based on available system tools
# 6. Automatic Dependencies: Installs required tools for optimal performance

# Function to detect package manager
get_pkg_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v rpm >/dev/null 2>&1; then
        echo "rpm"
    else
        echo "unknown"
    fi
}

# Function to check if a package is installed
is_installed() {
    local package="$1"
    local pkg_manager

    pkg_manager=$(get_pkg_manager)

    case "$pkg_manager" in
        apt)
            dpkg -s "$package" >/dev/null 2>&1
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

HARDN_STATUS "info" "Configuring debsums..."

# Get package manager once to avoid redundant checks
PKG_MANAGER=$(get_pkg_manager)

if ! is_installed debsums; then
    HARDN_STATUS "info" "Installing debsums..."
    if [ "$PKG_MANAGER" = "apt" ]; then
        apt-get update -qq
        apt-get install -y debsums || {
            HARDN_STATUS "error" "Failed to install debsums"
            exit 1
        }
    else
        HARDN_STATUS "warning" "debsums is a Debian-specific package, cannot install on this system."
        exit 0
    fi
fi

if ! command -v debsums >/dev/null 2>&1; then
    HARDN_STATUS "error" "debsums command not found, skipping configuration"
    exit 1
fi

# Create optimized daily cron job for debsums
CRON_DAILY="/etc/cron.daily/debsums"
if [ ! -f "$CRON_DAILY" ]; then
    cat <<EOF > "$CRON_DAILY"
#!/bin/bash
# Run debsums with optimizations
# Use nice to lower CPU priority
# Use ionice to lower I/O priority
# Use parallel processing for faster checks

# Log file for results
LOG_FILE="/var/log/debsums-check.log"

echo "Starting debsums check at \$(date)" > "\$LOG_FILE"

# Check if parallel is installed
if command -v parallel >/dev/null 2>&1; then
    # Get list of installed packages and process them in parallel
    dpkg-query -f '\${Package}\n' -W | nice -n 19 ionice -c3 parallel -j\$(nproc) "debsums -s {} 2>&1 || echo 'Failed: {}'" >> "\$LOG_FILE"
else
    # Fall back to standard method with nice and ionice
    nice -n 19 ionice -c3 debsums -s 2>&1 >> "\$LOG_FILE"
fi

echo "Completed debsums check at \$(date)" >> "\$LOG_FILE"

# Report only failures
if grep -q "Failed:" "\$LOG_FILE"; then
    echo "Some packages failed verification. See \$LOG_FILE for details."
    grep "Failed:" "\$LOG_FILE" | logger -t debsums
fi
EOF
    chmod +x "$CRON_DAILY"
    HARDN_STATUS "pass" "Optimized debsums daily cron job created"
else
    HARDN_STATUS "warning" "debsums daily cron job already exists"
fi

# Add debsums check to /etc/crontab if not present
# Schedule during off-hours with randomized start time to avoid system load spikes
# Use hostname to generate a more distributed random value
HOSTNAME_HASH=$(hostname | cksum | cut -d' ' -f1)
RANDOM_MINUTE=$((HOSTNAME_HASH % 60))
CRONTAB_LINE="$RANDOM_MINUTE 3 * * * root nice -n 19 ionice -c3 /usr/bin/debsums -s 2>&1 | logger -t debsums"
if ! grep -qF "/usr/bin/debsums -s" /etc/crontab; then
    echo "$CRONTAB_LINE" >> /etc/crontab
    HARDN_STATUS "pass" "Optimized debsums daily check added to crontab"
else
    HARDN_STATUS "warning" "debsums already in crontab"
fi

# Install parallel for faster processing if available
if [ "$PKG_MANAGER" = "apt" ]; then
    if ! is_installed parallel; then
        HARDN_STATUS "info" "Installing GNU parallel for faster debsums processing..."
        apt-get install -y parallel || {
            HARDN_STATUS "warning" "Failed to install GNU parallel, will use standard method"
        }
    fi
fi

# Run initial check with optimizations
HARDN_STATUS "info" "Running initial debsums check (this may take some time)..."
if command -v parallel >/dev/null 2>&1; then
    # Use parallel processing for faster initial check
    if dpkg-query -f '${Package}\n' -W | nice -n 19 ionice -c3 parallel -j"$(nproc)" "debsums -s {} >/dev/null 2>&1" 2>/dev/null; then
        HARDN_STATUS "pass" "Initial debsums check completed successfully"
    else
        HARDN_STATUS "warning" "Warning: Some packages failed debsums verification"
    fi
else
    # Fall back to standard method
    if nice -n 19 ionice -c3 debsums -s >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Initial debsums check completed successfully"
    else
        HARDN_STATUS "warning" "Warning: Some packages failed debsums verification"
    fi
fi
