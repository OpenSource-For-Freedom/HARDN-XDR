#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# --------- is_installed ----------
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
        return 1
    fi
}

# --------- OS Detection ----------
get_os_id() {
    awk -F= '/^ID=/{gsub("\"", "", $2); print $2}' /etc/os-release
}

OS_ID=$(get_os_id)

# --------- Container Detection ----------
if grep -qa container /proc/1/environ || systemd-detect-virt --quiet --container; then
    HARDN_STATUS "info" "Container environment detected. Skipping SELinux setup."
    return 0 2>/dev/null || exit 0
fi

# --------- Interactive Menu ---------
DEFAULT_MODE="permissive"
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
        return 0 2>/dev/null || exit 0
    fi
else
    CHOICE="basic"
    HARDN_STATUS "info" "No terminal or whiptail. Defaulting to basic (permissive)."
fi

# --------- Package Installation ---------
case "$OS_ID" in
    debian|ubuntu)
        HARDN_STATUS "info" "Installing SELinux for Debian/Ubuntu..."
        apt-get update -y
        DEBIAN_FRONTEND=noninteractive apt-get install -y selinux-basics selinux-policy-default auditd || {
            HARDN_STATUS "warning" "Failed to install SELinux packages."
            return 0 2>/dev/null || exit 0
        }

        if command -v selinux-activate &>/dev/null; then
            HARDN_STATUS "info" "Running selinux-activate..."
            selinux-activate || HARDN_STATUS "warning" "selinux-activate encountered an issue."
        fi
        ;;
    rhel|centos|fedora|rocky|almalinux)
        HARDN_STATUS "info" "Installing SELinux for $OS_ID..."
        PKG_MGR=$(command -v dnf || command -v yum)
        $PKG_MGR install -y selinux-policy selinux-policy-targeted policycoreutils policycoreutils-python-utils audit || {
            HARDN_STATUS "warning" "Failed to install SELinux packages."
            return 0 2>/dev/null || exit 0
        }
        ;;
    *)
        HARDN_STATUS "warning" "Unsupported OS ($OS_ID). Skipping SELinux setup."
        return 0 2>/dev/null || exit 0
        ;;
esac

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
if [[ "$CHOICE" == "advanced" && "$OS_ID" =~ ^(rhel|centos|fedora|rocky|almalinux)$ ]]; then
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

return 0 2>/dev/null || exit 0