#!/bin/bash

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

HARDN_STATUS "error" "Enabling process accounting (acct) and system statistics (sysstat)..."
local changed_acct changed_sysstat
changed_acct=false
changed_sysstat=false

# Universal package installation check function
is_installed() {
    local pkg="$1"
    if command -v dpkg >/dev/null 2>&1; then
        dpkg -s "$pkg" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$pkg" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$pkg" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$pkg" >/dev/null 2>&1
    else
        return 1
    fi
}

HARDN_STATUS "info" "Checking and installing acct (process accounting)..."
if ! is_installed acct && ! is_installed psacct; then
	hardn_infobox "Installing acct (process accounting)..." 7 60
	if apt-get install -y acct; then
		HARDN_STATUS "pass" "acct installed successfully."
		changed_acct=true
	else
		HARDN_STATUS "error" "Failed to install acct. Please check manually."
	fi
else
	HARDN_STATUS "info" "acct/psacct is already installed."
fi

if is_installed acct || is_installed psacct; then
	if ! systemctl is-active --quiet acct && ! systemctl is-active --quiet psacct; then
		HARDN_STATUS "info" "Attempting to enable and start acct/psacct service..."
		systemctl enable --now acct 2>/dev/null || systemctl enable --now psacct 2>/dev/null
		HARDN_STATUS "pass" "acct/psacct service enabled and started."
		changed_acct=true
	else
		HARDN_STATUS "pass" "acct/psacct service is already active."
	fi
fi

# Enable Sysstat
HARDN_STATUS "info" "Checking and installing sysstat..."
if ! is_installed sysstat; then
	hardn_infobox "Installing sysstat..." 7 60
	if apt-get install -y sysstat; then
		HARDN_STATUS "pass" "sysstat installed successfully."
		changed_sysstat=true
	else
		HARDN_STATUS "error" "Failed to install sysstat. Please check manually."
	fi
else
	HARDN_STATUS "info" "sysstat is already installed."
fi

if is_installed sysstat; then
	local sysstat_conf
	sysstat_conf="/etc/default/sysstat"
	if [[ -f "$sysstat_conf" ]]; then
		if ! grep -qE '^\s*ENABLED="true"' "$sysstat_conf"; then
			HARDN_STATUS "info" "Enabling sysstat data collection in $sysstat_conf..."
			sed -i 's/^\s*ENABLED="false"/ENABLED="true"/' "$sysstat_conf"
			if ! grep -qE '^\s*ENABLED=' "$sysstat_conf"; then
				echo 'ENABLED="true"' >> "$sysstat_conf"
			fi
			changed_sysstat=true
			HARDN_STATUS "pass" "sysstat data collection enabled."
		else
			HARDN_STATUS "pass" "sysstat data collection is already enabled in $sysstat_conf."
		fi
	else
		HARDN_STATUS "warning" "sysstat configuration file $sysstat_conf not found. Manual check might be needed."
	fi

	if ! systemctl is-active --quiet sysstat; then
		HARDN_STATUS "info" "Attempting to enable and start sysstat service..."
		if systemctl enable --now sysstat; then
			HARDN_STATUS "pass" "sysstat service enabled and started."
			changed_sysstat=true
		else
			HARDN_STATUS "error" "Failed to enable/start sysstat service."
		fi
	else
		HARDN_STATUS "pass" "sysstat service is already active."
	fi
fi

if [[ "$changed_acct" = true || "$changed_sysstat" = true ]]; then
	HARDN_STATUS "pass" "Process accounting (acct) and sysstat configured successfully."
else
	HARDN_STATUS "pass" "Process accounting (acct) and sysstat already configured or no changes needed."
fi
