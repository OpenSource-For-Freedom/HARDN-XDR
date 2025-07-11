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

HARDN_STATUS "info" "Configuring automatic security updates for Debian-based systems..."

if ! is_installed unattended-upgrades; then
    HARDN_STATUS "warning" "unattended-upgrades package not found, skipping configuration."
    return 0
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
