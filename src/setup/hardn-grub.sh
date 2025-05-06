#!/bin/bash

# Debian Compliance Script (Without FIPS Tools)
# Authors: Tim Burns, Kiumarz Hashemi
# Date: 2025-05-03
# Version: 2.0
# Description:
# This script enables compliance using enhanced security measures on Debian 12.

set -euo pipefail


LOG_FILE="/var/log/compliance-setup.log"
BACKUP_DIR="/var/backups/compliance"


exec > >(tee -a "$LOG_FILE") 2>&1

print_ascii_banner() {
    CYAN_BOLD="\033[1;36m"
    RESET="\033[0m"

    printf "%s" "${CYAN_BOLD}"
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
                                    
                                            C O M P L I A N C E

                                                   v 2.0
EOF
    printf "%s" "${RESET}"
}


import_dependencies() {
    echo "[INFO] Importing dependencies..."
    if ! command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
        echo "[ERROR] grub-mkpasswd-pbkdf2 command not found. Please install GRUB tools."
        exit 1
    fi

    if ! command -v openssl &> /dev/null; then
        echo "[INFO] Installing OpenSSL..."
        sudo apt-get install -y openssl
    fi

    if ! dpkg -l | grep -q libssl-dev; then
        echo "[INFO] Installing OpenSSL development libraries..."
        sudo apt-get install -y libssl-dev
    fi

    echo "[OK] Dependencies imported successfully."
}






update_grub() {
    echo "[INFO] Updating GRUB configuration with enhanced security measures..."
    local grub_cfg="/etc/default/grub"
    local p1 p2 raw grub_password_hash

   
    if [[ ! -f "$grub_cfg" ]]; then
        echo "[ERROR] GRUB configuration not found at $grub_cfg."
        return 1
    fi
    if [[ ! -w "$grub_cfg" ]]; then
        echo "[ERROR] $grub_cfg is not writable. Check permissions."
        return 1
    fi

  
    sudo mkdir -p "$BACKUP_DIR"
    sudo cp "$grub_cfg" "$BACKUP_DIR/grub.bak.$(date +%s)"

  
    if ! grep -q 'module.sig_enforce=1' "$grub_cfg"; then
        if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT' "$grub_cfg"; then
            sudo sed -i \
              's@^GRUB_CMDLINE_LINUX_DEFAULT="\([^"]*\)"@GRUB_CMDLINE_LINUX_DEFAULT="\1 module.sig_enforce=1 lockdown=integrity"@' \
              "$grub_cfg"
        else
            echo 'GRUB_CMDLINE_LINUX_DEFAULT="quiet module.sig_enforce=1 lockdown=integrity"' \
                | sudo tee -a "$grub_cfg" >/dev/null
        fi
    fi

   
    YELLOW_BOLD="\033[1;33m"
    RESET="\033[0m"

    echo -e "${YELLOW_BOLD}"
    echo "============================================================"
    echo "                   GRUB PASSWORD SETUP                      "
    echo "============================================================"
    echo "        Please enter a password to secure your GRUB         "
    echo "                  configuration.                            "
    echo "  Password must be at least 12 characters long and not a    "
    echo "                  dictionary word.                          "
    echo "============================================================"
    echo -e "${RESET}"

    while true; do
        read -r -sp "Enter GRUB password: " p1; echo
        if [[ ${#p1} -lt 12 ]]; then
            echo "[ERROR] Password must be at least 12 characters long. Please try again."
            continue
        fi
        if grep -q -i -w "$p1" /usr/share/dict/words; then
            echo "[ERROR] Password must not be a dictionary word. Please try again."
            continue
        fi
        read -r -sp "Confirm GRUB password: " p2; echo
        if [[ "$p1" != "$p2" ]]; then
            echo "[ERROR] Passwords do not match. Please try again."
            continue
        fi
        break
    done

    
    if ! command -v grub-mkpasswd-pbkdf2 &>/dev/null; then
        echo "[ERROR] grub-mkpasswd-pbkdf2 not found; install grub2-common."
        return 1
    fi

   
    raw=$(printf "%s\n%s\n" "$p1" "$p1" | grub-mkpasswd-pbkdf2 2>/dev/null)
    grub_password_hash=$(awk '{print $NF}' <<<"$raw")
    if [[ -z "$grub_password_hash" ]]; then
        echo "[ERROR] Failed to generate GRUB password hash."
        return 1
    fi
    unset p1 p2 raw

  
    set +x
    sudo tee -a /etc/grub.d/40_custom >/dev/null <<EOF
set superusers="admin"
password_pbkdf2 admin $grub_password_hash
EOF
    set -x

    echo "[OK] GRUB password protection configured."
    sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    echo "[OK] GRUB configuration rebuilt with enhanced security."
}







configure_memory() {
    echo "[INFO] Configuring secure kernel, monitored updates, and protecting RAM and CPU from attacks..."

    if ! grep -q "CONFIG_MODULE_SIG=y" "/boot/config-$(uname -r)"; then
        echo "[ERROR] Kernel does not have module signing enabled."
        return 1
    fi
    echo "[OK] Kernel supports module signing."

    echo "[INFO] Configuring secure RAM and CPU settings..."
    if ! grep -q "CONFIG_HARDENED_USERCOPY=y" "/boot/config-$(uname -r)"; then
        echo "[ERROR] Kernel does not have hardened usercopy enabled."
        return 1
    fi
    echo "[OK] Hardened usercopy is enabled."

    if ! grep -q "CONFIG_PAGE_TABLE_ISOLATION=y" "/boot/config-$(uname -r)"; then
        echo "[ERROR] Kernel does not have page table isolation enabled."
        return 1
    fi
    echo "[OK] Page table isolation is enabled."

    echo "[INFO] Configuring monitored updates and panic settings..."
    sudo sysctl -w kernel.panic_on_oops=1
    sudo sysctl -w kernel.panic=10
    echo "kernel.panic_on_oops=1" | sudo tee -a /etc/sysctl.conf
    echo "kernel.panic=10" | sudo tee -a /etc/sysctl.conf
    echo "[OK] Monitored updates and panic settings configured."

    local grub_cfg="/etc/default/grub"
    if [ -f "$grub_cfg" ]; then
        sudo cp "$grub_cfg" "$BACKUP_DIR/grub.bak.$(date +%s)"
        if ! grep -q "GRUB_CMDLINE_LINUX" "$grub_cfg"; then
            echo "GRUB_CMDLINE_LINUX=\"module.sig_enforce=1 pti=on panic=10 lockdown=integrity\"" | sudo tee -a "$grub_cfg"
        else
            sudo sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="module.sig_enforce=1 pti=on panic=10 lockdown=integrity /' "$grub_cfg"
        fi
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        echo "[INFO] GRUB configuration updated for secure kernel settings."
    else
        echo "[ERROR] GRUB configuration file not found at $grub_cfg."
        return 1
    fi

   
    local cron_file="/etc/cron.d/grub-update"
    if [ ! -f "$cron_file" ]; then
        echo "[INFO] Setting up cron job for GRUB updates..."
        echo "0 0 * * * root /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg" | sudo tee "$cron_file" > /dev/null
        echo "[OK] Cron job for GRUB updates set."
    else
        echo "[INFO] Cron job for GRUB updates already exists."
    fi

    echo "[OK] Secure kernel configuration completed."
}






setup_complete() {
    echo "============================================================"
    echo -e "${GREEN_BOLD}[COMPLETED] Compliance setup completed successfully.${RESET}"
    echo "============================================================"
}






main() {
    RED_BOLD="\033[1;31m"
    GREEN_BOLD="\033[1;32m"
    RESET="\033[0m"

    print_ascii_banner
    sleep 3
    echo "============================================================"
    echo -e "${RED_BOLD}[STEP 1] Starting compliance setup...${RESET}"
    echo "============================================================"

    if [ "$(id -u)" -ne 0 ]; then
        echo "------------------------------------------------------------"
    if ! mkdir -p "$BACKUP_DIR"; then
        echo "[ERROR] Failed to create backup directory at $BACKUP_DIR. Please check permissions."
        exit 1
    fi
        echo "------------------------------------------------------------"
        exit 1
    fi
    sleep 2
    echo "------------------------------------------------------------"
    echo -e "${RED_BOLD}[STEP 2] Importing dependencies...${RESET}"
    echo "------------------------------------------------------------"
    echo -e "${GREEN_BOLD}[OK] Dependencies imported successfully.${RESET}"
    import_dependencies
    sleep 2
    echo "------------------------------------------------------------"
    echo -e "${RED_BOLD}[STEP 2] Creating backup directory at $BACKUP_DIR...${RESET}"
    echo "------------------------------------------------------------"
    mkdir -p "$BACKUP_DIR"
    echo -e "${GREEN_BOLD}[OK] Backup directory created.${RESET}"

    echo "------------------------------------------------------------"
    echo -e "${RED_BOLD}[STEP 3] Configuring secure memory and kernel settings...${RESET}"
    echo "------------------------------------------------------------"
    configure_memory
    sleep 2
    echo -e "${GREEN_BOLD}[OK] Secure memory and kernel settings configured.${RESET}"

    echo "------------------------------------------------------------"
    echo -e "${RED_BOLD}[STEP 4] Updating GRUB configuration for compliance...${RESET}"
    echo "------------------------------------------------------------"
    update_grub
    sleep 2
    echo -e "${GREEN_BOLD}[OK] GRUB configuration updated.${RESET}"
    setup_complete 
}

main "$@"