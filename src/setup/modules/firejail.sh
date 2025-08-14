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

# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh

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
set -e
