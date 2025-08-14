#!/bin/bash
# Source common functions with fallback for development/CI environments
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
#!/bin/bash

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

    HARDN_STATUS "info" "Purging leftover configuration files for removed packages: $packages_to_purge"

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
    HARDN_STATUS "pass" "Purged configuration files for removed packages"
else
    HARDN_STATUS "pass" "No old/removed packages with leftover configuration files found to purge."
    HARDN_STATUS "info" "No leftover package configurations to purge"
fi

HARDN_STATUS "info" "Running apt-get autoremove and clean to free up space..."
apt-get autoremove -y >/dev/null 2>&1
apt-get clean >/dev/null 2>&1
HARDN_STATUS "pass" "Apt cache cleaned"

return 0 2>/dev/null || hardn_module_exit 0
set -e
