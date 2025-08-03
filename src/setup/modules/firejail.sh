#!/bin/bash

# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Setting up Firejail..."

if ! command -v firejail >/dev/null 2>&1; then
    HARDN_STATUS "info" "Firejail not found. Installing..."
    if apt-get update && apt-get install -y firejail >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Firejail installed successfully."
    else
        HARDN_STATUS "warning" "Failed to install Firejail. Skipping profile setup."
        return 0 2>/dev/null || hardn_module_exit 0
    fi
fi

HARDN_STATUS "info" "Setting up Firejail profiles for browsers..."

# Ensure the firejail directory exists
mkdir -p /etc/firejail

browsers="firefox chromium chromium-browser google-chrome brave-browser opera vivaldi midori epiphany"

# Find installed browsers
for browser in $browsers; do
    if command -v "$browser" >/dev/null 2>&1; then
        app="$browser"
        # Remove possible path and extension for profile name
        profile_name=$(basename "$app" | cut -d. -f1)
        if [ ! -f "/etc/firejail/${profile_name}.profile" ]; then
            HARDN_STATUS "info" "Creating Firejail profile for $profile_name..."
            {
                echo "# Firejail profile for $profile_name"
                echo "include /etc/firejail/firejail.config"
                echo "private"
                echo "net none"
                echo "caps.drop all"
                echo "seccomp"
                echo "private-etc"
                echo "private-dev"
                echo "nosound"
                echo "nodbus"
                echo "noexec"
                echo "nohome"
                echo "nonewprivs"
                echo "noroot"
                echo "nooverlay"
                echo "nodns"
                echo "no3d"
            } > "/etc/firejail/${profile_name}.profile"
        fi
    fi
done

return 0 2>/dev/null || hardn_module_exit 0
