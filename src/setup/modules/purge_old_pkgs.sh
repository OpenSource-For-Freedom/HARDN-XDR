#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Purging configuration files of old/removed packages..."

if ! command -v dpkg >/dev/null 2>&1; then
    HARDN_STATUS "warning" "This script is intended for Debian-based systems. Skipping."
    return 0 2>/dev/null || hardn_module_exit 0
fi

if ! command -v whiptail >/dev/null 2>&1; then
    apt-get install -y whiptail >/dev/null 2>&1
fi

packages_to_purge=$(dpkg -l | grep '^rc' | awk '{print $2}')

if [[ "$packages_to_purge" ]]; then
    HARDN_STATUS "info" "Found the following packages with leftover configuration files to purge:"
    echo "$packages_to_purge"

    if command -v whiptail >/dev/null; then
        hardn_msgbox "The following packages have leftover configuration files that will be purged:\n\n$packages_to_purge" 15 70
    fi

    for pkg in $packages_to_purge; do
        HARDN_STATUS "info" "Purging $pkg..."
        if apt-get purge -y "$pkg" >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Successfully purged $pkg."
        else
            HARDN_STATUS "error" "Failed to purge $pkg. Trying dpkg --purge..."
            if dpkg --purge "$pkg" >/dev/null 2>&1; then
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

HARDN_STATUS "info" "Running apt-get autoremove and clean to free up space..."
apt-get autoremove -y >/dev/null 2>&1
apt-get clean >/dev/null 2>&1
hardn_infobox "Apt cache cleaned." 7 70

return 0 2>/dev/null || hardn_module_exit 0
