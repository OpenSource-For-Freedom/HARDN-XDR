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
