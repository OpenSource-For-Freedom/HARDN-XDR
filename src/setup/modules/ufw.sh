#!/bin/bash

# HARDN-XDR - NTP Configuration Module
#
# This script configures NTP time synchronization using either systemd-timesyncd
# or traditional ntpd, depending on what's available on the system.
#
# This script is designed to be sourced by hardn-main.sh and not executed directly.
# It provides the configure_ntp() function which should be called from the main script.
#
# Dependencies: systemd, ntp (optional)
#
# Author: HARDN-XDR Team
# Version: 1.0

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../hardn-common.sh" 2>/dev/null || {
    # Fallback if common file not found
    HARDN_STATUS() {
        local status="$1"
        local message="$2"
        case "$status" in
            "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
            "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
            "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
            "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
            *)         echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
        esac
    }
}

# Exit if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script is part of HARDN-XDR and should be sourced by hardn-main.sh"
    echo "Usage: source $(basename "${BASH_SOURCE[0]}") from hardn-main.sh"
    exit 1
fi

# Function to check if a package is installed
is_installed() {
    local package="$1"

    case "$(get_package_manager)" in
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

# Function to determine package manager
get_package_manager() {
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

# Function to install NTP package
install_ntp_package() {
    if is_installed ntp; then
        HARDN_STATUS "pass" "ntp package is already installed."
        return 0
    fi

    HARDN_STATUS "info" "ntp package not found. Attempting to install..."

    # Attempt installation based on package manager
    case "$(get_package_manager)" in
        apt)
            apt-get update >/dev/null 2>&1 && apt-get install -y ntp >/dev/null 2>&1
            ;;
        dnf)
            dnf install -y ntp >/dev/null 2>&1
            ;;
        yum)
            yum install -y ntp >/dev/null 2>&1
            ;;
        *)
            HARDN_STATUS "error" "Unsupported package manager. Cannot install ntp."
            return 1
            ;;
    esac

    if is_installed ntp; then
        HARDN_STATUS "pass" "ntp package installed successfully."
        return 0
    else
        HARDN_STATUS "error" "Failed to install ntp package."
        return 1
    fi
}

# Function to check NTP stratum
check_ntp_stratum() {
    local stratum_source="$1"
    local stratum

    case "$stratum_source" in
        timesyncd)
            if ! timedatectl show-timesync --property=ServerAddress,NTP,Synchronized 2>/dev/null | grep -q "Synchronized=yes"; then
                return
            fi
            stratum=$(ntpq -c rv 2>/dev/null | grep -o 'stratum=[0-9]*' | cut -d= -f2)
            ;;
        ntpd)
            if ! ntpq -p 2>/dev/null | grep -q '^\*'; then
                return
            fi
            stratum=$(ntpq -c rv 2>/dev/null | grep -o 'stratum=[0-9]*' | cut -d= -f2)
            ;;
        *)
            return
            ;;
    esac

    if [[ -n "$stratum" && "$stratum" -gt 2 ]]; then
        HARDN_STATUS "warning" "NTP is synchronized but using a high stratum peer (stratum $stratum). Consider using a lower stratum (closer to 1) for better accuracy."
    fi
}

# Function to configure systemd-timesyncd
configure_systemd_timesyncd() {
    local ntp_servers="$1"
    local timesyncd_conf="/etc/systemd/timesyncd.conf"
    local temp_timesyncd_conf

    HARDN_STATUS "info" "systemd-timesyncd is active. Configuring..."

    # Create config file if it doesn't exist
    if [[ ! -f "$timesyncd_conf" ]]; then
        HARDN_STATUS "info" "Creating $timesyncd_conf as it does not exist."
        echo "[Time]" > "$timesyncd_conf"
        chmod 644 "$timesyncd_conf"
    fi

    # Create temporary config file
    temp_timesyncd_conf=$(mktemp)
    cp "$timesyncd_conf" "$temp_timesyncd_conf"

    # Update NTP servers in config
    update_timesyncd_conf "$temp_timesyncd_conf" "$ntp_servers"

    # Apply changes if needed
    if ! cmp -s "$temp_timesyncd_conf" "$timesyncd_conf"; then
        cp "$temp_timesyncd_conf" "$timesyncd_conf"
        HARDN_STATUS "pass" "Updated $timesyncd_conf. Restarting systemd-timesyncd..."

        if systemctl restart systemd-timesyncd; then
            HARDN_STATUS "pass" "systemd-timesyncd restarted successfully."
            rm -f "$temp_timesyncd_conf"
            check_ntp_stratum "timesyncd"
            return 0
        else
            HARDN_STATUS "error" "Failed to restart systemd-timesyncd. Manual check required."
            rm -f "$temp_timesyncd_conf"
            return 1
        fi
    else
        HARDN_STATUS "info" "No effective changes to $timesyncd_conf were needed."
        rm -f "$temp_timesyncd_conf"
        check_ntp_stratum "timesyncd"
        return 0
    fi
}

# Function to update timesyncd.conf
update_timesyncd_conf() {
    local config_file="$1"
    local ntp_servers="$2"

    if grep -qE "^\s*NTP=" "$config_file"; then
        sed -i -E "s/^\s*NTP=.*/NTP=$ntp_servers/" "$config_file"
    elif grep -q "\[Time\]" "$config_file"; then
        sed -i "/\[Time\]/a NTP=$ntp_servers" "$config_file"
    else
        echo -e "\n[Time]\nNTP=$ntp_servers" >> "$config_file"
    fi
}

# Function to configure ntpd
configure_ntpd() {
    local ntp_servers="$1"
    local ntp_conf="/etc/ntp.conf"
    local temp_ntp_conf

    HARDN_STATUS "info" "systemd-timesyncd is not active. Checking/Configuring ntpd..."

    # Install NTP if needed
    if ! install_ntp_package; then
        return 1
    fi

    # Check if the configuration file exists and is writable
    if [[ ! -f "$ntp_conf" || ! -w "$ntp_conf" ]]; then
        HARDN_STATUS "error" "NTP configuration file $ntp_conf not found or not writable. Skipping NTP configuration."
        return 1
    fi

    HARDN_STATUS "info" "Configuring $ntp_conf..."

    # Backup existing config
    cp "$ntp_conf" "${ntp_conf}.bak.$(date +%F-%T)" 2>/dev/null || true

    # Create temporary config file
    temp_ntp_conf=$(mktemp)

    # Update NTP configuration
    update_ntp_conf "$ntp_conf" "$temp_ntp_conf" "$ntp_servers"

    # Apply changes if needed
    if ! cmp -s "$temp_ntp_conf" "$ntp_conf"; then
        mv "$temp_ntp_conf" "$ntp_conf"
        HARDN_STATUS "pass" "Updated $ntp_conf with recommended pool servers."

        if systemctl enable --now ntp; then
            HARDN_STATUS "pass" "ntp service enabled and started successfully."
            check_ntp_stratum "ntpd"
            return 0
        else
            HARDN_STATUS "error" "Failed to enable/start ntp service. Manual check required."
            return 1
        fi
    else
        HARDN_STATUS "info" "No effective changes to $ntp_conf were needed."
        rm -f "$temp_ntp_conf"
        check_ntp_stratum "ntpd"
        return 0
    fi
}

# Function to update ntp.conf
update_ntp_conf() {
    local source_conf="$1"
    local target_conf="$2"
    local ntp_servers="$3"

    # Remove existing pool/server lines and keep other configuration
    grep -vE "^\s*(pool|server)\s+" "$source_conf" > "$target_conf"

    # Add new server configuration
    {
        echo "# HARDN-XDR configured NTP servers"
        for server in $ntp_servers; do
            echo "pool $server iburst"
        done
    } >> "$target_conf"
}

# Main function to configure NTP - this is the function that should be called from hardn-main.sh
configure_ntp() {
    # Default NTP servers - can be overridden by passing parameters
    local ntp_servers="${1:-0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org}"
    local configured=false

    HARDN_STATUS "info" "Setting up NTP daemon..."

    # Determine which NTP implementation to use
    if systemctl is-active --quiet systemd-timesyncd; then
        if configure_systemd_timesyncd "$ntp_servers"; then
            configured=true
        fi
    else
        if configure_ntpd "$ntp_servers"; then
            configured=true
        fi
    fi

    # Final status report
    if [[ "$configured" = true ]]; then
        HARDN_STATUS "pass" "NTP configuration completed successfully."
    else
        HARDN_STATUS "error" "NTP configuration failed or skipped due to errors."
    fi

    # Return success/failure status to the calling script
    [[ "$configured" = true ]]
    return $?
}

# Export the main function so it can be called after sourcing
export -f configure_ntp

# Log that the module was loaded successfully
if [[ -n "$HARDN_DEBUG" ]]; then
    HARDN_STATUS "debug" "NTP module loaded successfully"
fi


