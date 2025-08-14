#!/bin/bash
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
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
}
#!/bin/bash
set -e

HARDN_STATUS "info" "Checking for deleted files in use..."
if command -v lsof >/dev/null 2>&1; then
    deleted_files=$(lsof +L1 | awk '{print $9}' | grep -v '^$')
    if [[ -n "$deleted_files" ]]; then
        HARDN_STATUS "warning" "Found deleted files in use:"
        echo "$deleted_files"
        HARDN_STATUS "warning" "Please consider rebooting the system to release these files."
    else
        HARDN_STATUS "pass" "No deleted files in use found."
    fi
else
    HARDN_STATUS "error" "lsof command not found. Cannot check for deleted files in use."
fi

return 0 2>/dev/null || hardn_module_exit 0

