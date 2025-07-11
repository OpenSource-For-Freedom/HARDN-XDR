#!/bin/bash

hardn_autoupdate_is_installed() {
    local pkg="$1"
    local pm

    pm=$(command -v apt dnf yum rpm 2>/dev/null | head -1)
    case "$pm" in
        */apt)  dpkg -s "$pkg" >/dev/null 2>&1 ;;
        */dnf)  dnf list installed "$pkg" >/dev/null 2>&1 ;;
        */yum)  yum list installed "$pkg" >/dev/null 2>&1 ;;
        */rpm)  rpm -q "$pkg" >/dev/null 2>&1 ;;
        *)      return 1 ;;
    esac
}

hardn_autoupdate_configure() {
    # Source /etc/os-release to get ID and CURRENT_DEBIAN_CODENAME
    [[ -f /etc/os-release ]] && . /etc/os-release

    HARDN_STATUS "info" "Configuring automatic security updates for Debian-based systems..."

    if ! hardn_autoupdate_is_installed "unattended-upgrades"; then
        HARDN_STATUS "warning" "unattended-upgrades package not found, skipping configuration."
        return 0
    fi

    local config_file="/etc/apt/apt.conf.d/50unattended-upgrades"
    local codename="${VERSION_CODENAME:-stable}"

    case "${ID:-unknown}" in
        "debian")
            cat > "$config_file" << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${codename}-security";
    "${ID}:${codename}-updates";
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
            cat > "$config_file" << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${codename}-security";
    "${ID}ESMApps:${codename}-apps-security";
    "${ID}ESM:${codename}-infra-security";
};
EOF
            ;;
        *)
            cat > "$config_file" << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID:-debian}:${codename}-security";
};
EOF
            ;;
    esac

    # Configure APT periodic updates
    cat > "/etc/apt/apt.conf.d/20auto-upgrades" << EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    HARDN_STATUS "success" "Automatic security updates configured successfully."
    return 0
}
