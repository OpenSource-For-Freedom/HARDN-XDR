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
        return 1 # Cannot determine package manager
    fi
}

HARDN_STATUS "error" "Purging configuration files of old/removed packages..."

if ! command -v dpkg >/dev/null 2>&1; then
    HARDN_STATUS "warning" "This script is intended for Debian-based systems. Skipping."
    exit 0
fi

if ! is_installed whiptail; then
    apt-get install -y whiptail >/dev/null 2>&1
fi

local packages_to_purge
packages_to_purge=$(dpkg -l | grep '^rc' | awk '{print $2}')

if [[ "$packages_to_purge" ]]; then
	HARDN_STATUS "info" "Found the following packages with leftover configuration files to purge:"
	echo "$packages_to_purge"

	if command -v whiptail >/dev/null; then
		hardn_msgbox "The following packages have leftover configuration files that will be purged:\n\n$packages_to_purge" 15 70
	fi

	for pkg in $packages_to_purge; do
		HARDN_STATUS "error" "Purging $pkg..."
		if apt-get purge -y "$pkg"; then
			HARDN_STATUS "pass" "Successfully purged $pkg."
		else
			HARDN_STATUS "error" "Failed to purge $pkg. Trying dpkg --purge..."
			if dpkg --purge "$pkg"; then
				HARDN_STATUS "pass" "Successfully purged $pkg with dpkg."
			else
				HARDN_STATUS "error" "Failed to purge $pkg with dpkg as well."
			fi
		fi
	done
	hardn_infobox "Purged configuration files for removed packages." 7 70
else
	HARDN_STATUS "pass" "No old/removed packages with leftover configuration files found to purge."
	hardn_infobox "No leftover package configurations to purge." 7 70
fi

HARDN_STATUS "error" "Running apt-get autoremove and clean to free up space..."
apt-get autoremove -y
apt-get clean
hardn_infobox "Apt cache cleaned." 7 70
