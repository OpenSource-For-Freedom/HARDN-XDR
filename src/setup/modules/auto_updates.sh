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

HARDN_STATUS "info" "Configuring automatic security updates for Debian-based systems..."

if ! is_installed unattended-upgrades; then
    HARDN_STATUS "warning" "unattended-upgrades package not found, attempting to install..."
    apt-get update || true
    apt-get install -y unattended-upgrades || {
        HARDN_STATUS "warning" "Failed to install unattended-upgrades, skipping configuration."
        return 0
    }
fi

# Ensure we have the OS
if [[ -z "$ID" ]]; then
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
    else
        ID="debian"  # Safe default for CI
        CURRENT_DEBIAN_CODENAME="stable"  # Safe default for CI
    fi
fi

# Set a default codename if not available
if [[ -z "$CURRENT_DEBIAN_CODENAME" ]]; then
    CURRENT_DEBIAN_CODENAME="${VERSION_CODENAME:-stable}"
fi

# Validate variables before using them
if [[ -z "$ID" || -z "$CURRENT_DEBIAN_CODENAME" ]]; then
    HARDN_STATUS "warning" "Could not determine OS ID or codename, using defaults"
    ID="${ID:-debian}"
    CURRENT_DEBIAN_CODENAME="${CURRENT_DEBIAN_CODENAME:-stable}"
fi

case "${ID}" in # Use ${ID} from /etc/os-release
	"debian")
		cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${CURRENT_DEBIAN_CODENAME}-security";
    "${ID}:${CURRENT_DEBIAN_CODENAME}-updates";
};
Unattended-Upgrade::Package-Blacklist {
    // Add any packages you want to exclude from automatic updates
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "false";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
            ;;
	"ubuntu")
		cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${CURRENT_DEBIAN_CODENAME}-security";
    "${ID}ESMApps:${CURRENT_DEBIAN_CODENAME}-apps-security";
    "${ID}ESM:${CURRENT_DEBIAN_CODENAME}-infra-security";
};
EOF
		;;
	*)
		cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${CURRENT_DEBIAN_CODENAME}-security";
};
EOF
		;;
esac


return 0 2>/dev/null || hardn_module_exit 0
set -e
