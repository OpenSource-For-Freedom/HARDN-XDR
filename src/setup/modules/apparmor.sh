#!/bin/bash

source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# --------- Detect if in container or no TTY ----------
if grep -qa container /proc/1/environ || systemd-detect-virt --quiet --container || ! [ -t 0 ]; then
    HARDN_STATUS "info" "Skipping AppArmor setup (container or non-interactive)."
    return 0 2>/dev/null || exit 0
fi

# --------- Check whiptail ----------
if ! command -v whiptail &>/dev/null; then
    HARDN_STATUS "warning" "whiptail not found. Skipping AppArmor wizard."

    return 0 2>/dev/null || exit 0
fi

# --------- User Prompt for Mode ----------
MODE=$(whiptail --title "AppArmor Setup" --radiolist \
"AppArmor is a Mandatory Access Control system. Select a configuration mode:\n\n\
• Enforce: Strictly enforce profile rules\n\
• Complain: Log violations but allow all\n\
• Disabled: Turn off AppArmor (not recommended)\n\n\
Choose the desired mode:" 20 78 3 \
"enforce" "Secure, default mode" ON \
"complain" "Debug/logging only" OFF \
"disabled" "Disable AppArmor completely" OFF 3>&1 1>&2 2>&3)

if [[ $? -ne 0 || "$MODE" == "disabled" ]]; then
    HARDN_STATUS "info" "User cancelled or selected to skip AppArmor setup."
    return 0 2>/dev/null || exit 0
fi

# --------- Begin Installation ----------
HARDN_STATUS "info" "Initializing AppArmor security module..."

if ! is_installed apparmor || ! is_installed apparmor-utils; then
    HARDN_STATUS "info" "AppArmor packages not found. Installing..."
    if command -v apt >/dev/null 2>&1; then
        if ! (apt update -y && apt install -y apparmor apparmor-utils); then
            HARDN_STATUS "warning" "Failed to install AppArmor with apt."
            return 0
        fi
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y apparmor apparmor-utils || {
            HARDN_STATUS "warning" "Failed to install AppArmor with dnf."
            return 0
        }
    elif command -v yum >/dev/null 2>&1; then
        yum install -y apparmor apparmor-utils || {
            HARDN_STATUS "warning" "Failed to install AppArmor with yum."
            return 0
        }
    fi
fi

# --------- Ensure Kernel Boot Flag ----------
if ! grep -q "apparmor=1" /proc/cmdline; then
    if grep -q '^GRUB_CMDLINE_LINUX="' /etc/default/grub; then
        sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="apparmor=1 security=apparmor /' /etc/default/grub
        if grep -q "ID=debian" /etc/os-release || grep -q "ID=ubuntu" /etc/os-release; then
            update-grub
        elif grep -q "ID=fedora" /etc/os-release || grep -q "ID=centos" /etc/os-release; then
            grub2-mkconfig -o /boot/grub2/grub.cfg
        else
            HARDN_STATUS "error" "Unsupported distribution. GRUB update failed."
            return 1
        fi
        HARDN_STATUS "info" "GRUB updated to enable AppArmor. Reboot required."
    else
        HARDN_STATUS "warning" "Could not modify GRUB. Please enable AppArmor manually."
    fi
fi

# --------- Load Kernel Module ----------
if ! lsmod | grep -q apparmor; then
    if modprobe apparmor; then
        HARDN_STATUS "info" "AppArmor kernel module loaded."
    else
        HARDN_STATUS "error" "Failed to load AppArmor kernel module. Please check your system configuration."
        return 1
    fi
fi

# --------- Apply Selected Mode ----------
if [[ "$MODE" == "enforce" ]]; then
    HARDN_STATUS "info" "Enforcing all AppArmor profiles..."
    aa-enforce /etc/apparmor.d/* 2>/dev/null || {
        HARDN_STATUS "warning" "Some profiles could not be enforced."
    }
elif [[ "$MODE" == "complain" ]]; then
    HARDN_STATUS "info" "Setting all AppArmor profiles to complain mode..."
    aa-complain /etc/apparmor.d/* 2>/dev/null || {
        HARDN_STATUS "warning" "Some profiles could not be put in complain mode."
    }
fi

# --------- Service Handling ----------
systemctl restart apparmor.service
systemctl enable apparmor.service

# --------- Status Output ----------
if command -v aa-status &>/dev/null; then
    HARDN_STATUS "info" "Current AppArmor profile status:"
    aa-status
fi

HARDN_STATUS "pass" "AppArmor module completed in $MODE mode."


return 0 2>/dev/null || hardn_module_exit 0
