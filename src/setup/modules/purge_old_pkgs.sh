#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

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
        return 1
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

packages_to_purge=$(dpkg -l | grep '^rc' | awk '{print $2}')

if [[ "$packages_to_purge" ]]; then
    HARDN_STATUS "info" "Found the following packages with leftover configuration files to purge:"
    echo "$packages_to_purge"

    if command -v whiptail >/dev/null; then
        hardn_msgbox "The following packages have leftover configuration files that will be purged:\n\n$packages_to_purge" 15 70
    fi

    for pkg in $packages_to_purge; do
        HARDN_STATUS "error" "Purging $pkg..."
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

HARDN_STATUS "error" "Running apt-get autoremove and clean to free up space..."
apt-get autoremove -y >/dev/null 2>&1
apt-get clean >/dev/null 2>&1
hardn_infobox "Apt cache cleaned." 7 70