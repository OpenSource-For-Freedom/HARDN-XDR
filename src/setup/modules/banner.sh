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


# Check for container environment
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - banner configuration may be limited"
    HARDN_STATUS "info" "Some container environments may override login banners"
fi

HARDN_STATUS "info" "Setting up the HARDN XDR Banner..."

configure_stig_banner() {
    local banner_file="$1"
    local banner_description="$2"

    HARDN_STATUS "info" "Configuring STIG compliant banner for ${banner_description}..."

    if [ -f "$banner_file" ]; then
        cp "$banner_file" "${banner_file}.bak.$(date +%F-%T)" 2>/dev/null || true
    else
        touch "$banner_file"
    fi

    {
        echo "*************************************************************"
        echo "*     ############# H A R D N - X D R ##############        *"
        echo "*  This system is for the use of authorized SIG users.      *"
        echo "*  Individuals using this computer system without authority *"
        echo "*  or in excess of their authority are subject to having    *"
        echo "*  all of their activities on this system monitored and     *"
        echo "*  recorded by system personnel.                            *"
        echo "*                                                           *"
        echo "************************************************************"
    } > "$banner_file"

    chmod 644 "$banner_file"
    HARDN_STATUS "pass" "STIG compliant banner configured in $banner_file."
}

# Configure banner for local logins
configure_stig_banner "/etc/issue" "local logins (/etc/issue)"

# Configure banner for remote logins
configure_stig_banner "/etc/issue.net" "remote logins (/etc/issue.net)"

# Configure banner for message of the day
configure_stig_banner "/etc/motd" "message of the day (/etc/motd)"

HARDN_STATUS "pass" "All HARDN-XDR banners configured successfully."

return 0 2>/dev/null || hardn_module_exit 0
set -e
