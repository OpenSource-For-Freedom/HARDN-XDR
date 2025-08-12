#!/bin/bash
# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# --------- OS Detection ----------
get_os_id() {
    awk -F= '/^ID=/{gsub("\"", "", $2); print $2}' /etc/os-release
}

OS_ID=$(get_os_id)

# Only allow execution on RHEL-based systems
if [[ ! "$OS_ID" =~ ^(rhel|centos|fedora|rocky|almalinux)$ ]]; then
    HARDN_STATUS "info" "This SELinux module is only supported on RHEL-based systems. Skipping..."
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- Container Detection ----------
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - SELinux is typically managed by the container runtime"
    HARDN_STATUS "info" "SELinux policies in containers are inherited from the host system"
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- Interactive Menu ---------
# Remove unused DEFAULT_MODE variable
# DEFAULT_MODE="permissive"
SHOW_MENU=false

if [ -t 0 ] && command -v whiptail &>/dev/null; then
    SHOW_MENU=true
fi

if $SHOW_MENU; then
    CHOICE=$(whiptail --title "SELinux Mode" --radiolist "Choose SELinux setup level:" 15 70 3 \
        "basic" "Install & set to permissive (safe)" ON \
        "advanced" "Install & set to enforcing (hardened)" OFF \
        "skip" "Skip SELinux setup on this system" OFF 3>&1 1>&2 2>&3)

    EXIT_STATUS=$?
    if [[ $EXIT_STATUS -ne 0 || "$CHOICE" == "skip" ]]; then
        HARDN_STATUS "info" "User cancelled or skipped SELinux setup."
        return 0 2>/dev/null || hardn_module_exit 0
    fi
else
    CHOICE="basic"
    HARDN_STATUS "info" "No terminal or whiptail. Defaulting to basic (permissive)."
fi

# --------- Package Installation ---------
HARDN_STATUS "info" "Installing SELinux for $OS_ID..."
PKG_MGR=$(command -v dnf || command -v yum)
$PKG_MGR install -y selinux-policy selinux-policy-targeted policycoreutils policycoreutils-python-utils audit || {
    HARDN_STATUS "warning" "Failed to install SELinux packages."
    return 0 2>/dev/null || hardn_module_exit 0
}

# --------- Config File Setup ---------
CONFIG_FILE=""
[ -f /etc/selinux/config ] && CONFIG_FILE="/etc/selinux/config"
[ -f /etc/selinux/selinux.conf ] && CONFIG_FILE="/etc/selinux/selinux.conf"

if [[ -n "$CONFIG_FILE" ]]; then
    sed -i 's/^SELINUX=.*/SELINUX='"$([[ "$CHOICE" == "advanced" ]] && echo "enforcing" || echo "permissive")"'/' "$CONFIG_FILE"
    sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' "$CONFIG_FILE"
    HARDN_STATUS "info" "SELinux mode set to ${CHOICE^^}, policy set to targeted."
else
    HARDN_STATUS "warning" "SELinux config file not found."
fi

# --------- Auto Relabel If Enforcing + RHEL-based ---------
if [[ "$CHOICE" == "advanced" ]]; then
    if command -v fixfiles >/dev/null 2>&1; then
        HARDN_STATUS "info" "Scheduling full filesystem relabel on next boot..."
        touch /.autorelabel
        fixfiles onboot || HARDN_STATUS "warning" "fixfiles onboot failed or not supported."
        HARDN_STATUS "info" "A reboot is required to complete SELinux enforcement."
    fi
fi

# --------- Final Stat Check ---------
if [ -d /sys/fs/selinux ]; then
    MODE=$(getenforce 2>/dev/null || echo "Unknown")
    HARDN_STATUS "pass" "SELinux present: Mode = $MODE"
else
    HARDN_STATUS "warning" "SELinux is not currently active."
fi

return 0 2>/dev/null || hardn_module_exit 0
