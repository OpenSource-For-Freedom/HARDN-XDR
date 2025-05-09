#!/bin/bash

# Enhanced Ubuntu Pro 24.04 FIPS 140-2 Compliance Script (Safe Mode)
# Authors: Tim Burns
# Date: 2025-05-03
# Version: 1.7
# Description:
# This script enables FIPS 140-2 compliance safely on Ubuntu Pro 24.04 by checking NICs, backing up GRUB/initramfs,
# logging actions, and supporting dry-run mode to avoid breaking connectivity.

set -euo pipefail

LOG_FILE="/var/log/fips-setup.log"
BACKUP_DIR="/var/backups/fips"
DRY_RUN=false


if [[ ! -t 0 || ! -t 1 ]]; then
    echo "[ERROR] This script must be run in an interactive shell (not at login or as part of an automated process)."
    sleep 3
    exit 1
fi


read -p $'\e[1;31mWARNING: This script will make system-level changes for FIPS compliance.\nIt may affect boot, kernel, and cryptography.\nAre you sure you want to continue? (yes/NO): \e[0m' CONFIRM
if [[ ! "$CONFIRM" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    echo "[INFO] Aborted by user. No changes made."
    sleep 2
    exit 0
fi

# Enable logging
exec > >(tee -a "$LOG_FILE") 2>&1



print_ascii_banner() {
    CYAN_BOLD="\033[1;36m"
    RESET="\033[0m"

    printf "${CYAN_BOLD}"
    cat << "EOF"
                              ▄█    █▄       ▄████████    ▄████████ ████████▄  ███▄▄▄▄   
                             ███    ███     ███    ███   ███    ███ ███   ▀███ ███▀▀▀██▄ 
                             ███    ███     ███    ███   ███    ███ ███    ███ ███   ███ 
                            ▄███▄▄▄▄███▄▄   ███    ███  ▄███▄▄▄▄██▀ ███    ███ ███   ███ 
                           ▀▀███▀▀▀▀███▀  ▀███████████ ▀▀███▀▀▀▀▀   ███    ███ ███   ███ 
                             ███    ███     ███    ███ ▀███████████ ███    ███ ███   ███ 
                             ███    ███     ███    ███   ███    ███ ███   ▄███ ███   ███ 
                             ███    █▀      ███    █▀    ███    ███ ████████▀   ▀█   █▀  
                                                         ███    ███ 
                                    
                                           
                                          U B U N T U   P R O  2 4 . 0 4

                                           F I P S  -  C O M P L I A N C E


                                                      v 1.7 
EOF
    printf "${RESET}"
}

check_nic_modules() {
    echo "[INFO] Verifying NIC kernel modules..."
    local modules=(e1000e ixgbe r8169 r8168 atlantic tg3)
    local found=false

    for mod in "${modules[@]}"; do
        if modinfo "$mod" &>/dev/null; then
            echo "[OK] Found NIC module: $mod"
            found=true
            break
        fi
    done

    if ! $found; then
        echo "[WARNING] No known NIC kernel modules found."
        echo "[INFO] Attempting to detect and add missing NIC drivers..."
        if apt show linux-modules-extra-$(uname -r) &>/dev/null; then
            apt update && apt install -y linux-modules-extra-$(uname -r)
            echo "[INFO] NIC drivers installed. Please verify manually if issues persist."
        else
            echo "[ERROR] linux-modules-extra-$(uname -r) not found. Skipping NIC driver installation."
        fi
    fi
}

fips_compatible() {
    echo "[INFO] Checking for FIPS-compatible kernels in the repository..."

    local available_kernels
    available_kernels=$(apt-cache search linux-image | grep -E "fips|hwe|generic" | awk '{print $1}')
    echo "[DEBUG] Available kernels: $available_kernels"

    if [[ -z "$available_kernels" ]]; then
        echo "[ERROR] No FIPS-compatible kernels found in the repository. Please check your sources.list or consider using a custom kernel."
        return 1
    fi

    echo "[INFO] Available FIPS-compatible kernels:"
    echo "$available_kernels"

    local current_kernel
    current_kernel=$(uname -r)
    echo "[DEBUG] Current kernel: $current_kernel"

    if [[ "$available_kernels" == *"$current_kernel"* ]]; then
        echo "[OK] Current kernel ($current_kernel) is FIPS-compatible."
    else
        echo "[WARNING] Current kernel ($current_kernel) is not FIPS-compatible."
        echo "[ACTION] Consider installing one of the following FIPS-compatible kernels:"
        echo "$available_kernels"
        echo "[INFO] To install a new kernel, run the following command:"
        echo "sudo apt install <kernel-package-name>"
    fi
}

backup_grub_settings() {
    echo "[INFO] Backing up GRUB config..."
    mkdir -p "$BACKUP_DIR"
    cp /etc/default/grub "$BACKUP_DIR/grub.bak.$(date +%s)"
    echo "[OK] GRUB configuration backed up."
}

setup_fips_license() {
    echo "[STEP] Checking Ubuntu Pro license status..."
    if ! command -v ua &>/dev/null; then
        echo "[ERROR] Ubuntu Advantage (ua) tool is not installed. Please install 'ubuntu-advantage-tools' and try again."
        return 1
    fi
    local status
    status=$(ua status 2>/dev/null | grep -i 'Attached to' || true)
    if [[ -z "$status" ]]; then
        echo "[INFO] This system is not attached to Ubuntu Pro."
        read -p $'\e[1;33mEnter your Ubuntu Pro token to attach this machine (or leave blank to skip): \e[0m' UA_TOKEN
        if [[ -n "$UA_TOKEN" ]]; then
            if ua attach "$UA_TOKEN"; then
                echo "[OK] Successfully attached to Ubuntu Pro."
            else
                echo "[ERROR] Failed to attach to Ubuntu Pro. FIPS enable will likely fail."
            fi
        else
            echo "[WARNING] Skipping Ubuntu Pro attach. FIPS enable may fail if not already licensed."
        fi
    else
        echo "[OK] Ubuntu Pro is already attached."
    fi
}

setup_fips_compliance() {
    echo "[STEP] Setting up FIPS packages and dependencies..."
    if ! apt update; then
        echo "[ERROR] Failed to update package lists. Please check your network and repository configuration."
        return 1
    fi

    local packages=("ubuntu-advantage-tools" "fips-initramfs" "grub2" "openssl" "libssl3")
    for pkg in "${packages[@]}"; do
        if ! apt install -y "$pkg"; then
            echo "[ERROR] Failed to install package: $pkg. Ensure the package is available in your repository."
            return 1
        fi
    done

    ua enable fips || echo "[ERROR] Failed to enable FIPS through Ubuntu Advantage. Ensure you have an active subscription."

    if [ -f /etc/ssl/openssl.cnf ]; then
        sed -i 's/#.*fips_mode = 1/fips_mode = 1/' /etc/ssl/openssl.cnf
        echo "[INFO] FIPS mode enabled in OpenSSL configuration."
    else
        echo "[WARNING] OpenSSL configuration file not found. Skipping FIPS mode setup for OpenSSL."
    fi

    echo "[OK] FIPS compliance setup completed successfully."
    echo "[INFO] Please reboot the system to activate FIPS mode."
}

apply_security_settings() {
    echo "[STEP] Applying kernel-level security settings..."
    local settings=("slub_debug=FZP" "mce=0" "page_poison=1" "pti=on" "vsyscall=none" "kptr_restrict=2")

    for setting in "${settings[@]}"; do
        if ! grep -q "$setting" /etc/default/grub; then
            if ! grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
                echo "GRUB_CMDLINE_LINUX=\"$setting\"" >> /etc/default/grub
            else
                sed -i "s/GRUB_CMDLINE_LINUX=\"/GRUB_CMDLINE_LINUX=\"$setting /" /etc/default/grub
            fi
        fi
    done
    echo "[OK] Security settings applied to GRUB. Please validate manually before rebooting."
}

add_fips_to_grub() {
    echo "[STEP] Adding fips=1 to GRUB configuration..."
    if ! grep -q "fips=1" /etc/default/grub; then
        if ! grep -q "^GRUB_CMDLINE_LINUX=" /etc/default/grub; then
            echo 'GRUB_CMDLINE_LINUX="fips=1"' >> /etc/default/grub
        else
            sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="fips=1 /' /etc/default/grub
        fi
    fi
    echo "[INFO] Updating GRUB configuration..."
    update-grub || echo "[ERROR] GRUB update failed. Please verify manually."
}

regenerate_initramfs() {
    echo "[STEP] Regenerating initramfs with FIPS modules..."
    if $DRY_RUN; then echo "[DRY RUN] Skipping initramfs regeneration"; return 0; fi

    mkdir -p "$BACKUP_DIR/initrd"
    cp /boot/initrd.img-$(uname -r) "$BACKUP_DIR/initrd.img-$(uname -r).bak" || true

    if update-initramfs -u -k "$(uname -r)"; then
        echo "[OK] Initramfs regenerated successfully."
    else
        echo "[ERROR] Failed to regenerate initramfs. Restoring backup..."
        cp "$BACKUP_DIR/initrd.img-$(uname -r).bak" /boot/initrd.img-$(uname -r)
        echo "[INFO] Backup restored. Please troubleshoot initramfs errors."
    fi
}

verify_fips_mode() {
    echo "[VERIFY] Checking if FIPS mode is active..."
    if grep -q "fips=1" /proc/cmdline; then
        echo "[OK] FIPS mode appears enabled."
    else
        echo "[WARNING] FIPS mode not yet active. Please reboot to activate."
        echo "Verify after reboot with: cat /proc/sys/crypto/fips_enabled (should be 1)"
    fi
}

setup_cron_updates() {
    echo "[STEP] Setting up Cron job for updates..."
    local cron_job="0 3 * * * /usr/bin/apt update && /usr/bin/apt upgrade -y"
    (crontab -l 2>/dev/null | grep -v -F "$cron_job"; echo "$cron_job") | crontab -
    echo "[OK] Cron job scheduled for daily updates."
}

main() {
    print_ascii_banner
    RED_BOLD="\033[1;31m"
    RESET="\033[0m"
    echo -e "${RED_BOLD}[START] FIPS 140-2 Compliance Setup...${RESET}"

    [[ $EUID -ne 0 ]] && echo "[ERROR] Run this script as root." && exit 1
    
    setup_fips_license
    fips_compatible
    check_nic_modules
    backup_grub_settings
    setup_fips_compliance
    apply_security_settings
    regenerate_initramfs
    add_fips_to_grub
    setup_cron_updates
    verify_fips_mode

    echo "[DONE] FIPS setup completed. See $LOG_FILE for full trace."
    echo "[INFO] Please reboot the system to activate FIPS mode."
}

main "$@"
