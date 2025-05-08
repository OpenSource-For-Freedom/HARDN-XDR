#!/bin/bash

# Debian Compliance Script (Without FIPS Tools)
# Authors: Tim Burns, Kiumarz Hashemi
# Date: 2025-05-03
# Version: 2.0
# Description:
# This script enables compliance using enhanced security measures on Debian 12.

set -euo pipefail


LOG_FILE="/var/log/compliance-setup.log"
<<<<<<< HEAD
GUI_LOG_FILE="/var/log/hardn-gui-output.log"
=======
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
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

<<<<<<< HEAD
# Source centralized logging utility
source "$SCRIPT_DIR_TOOLS/centralized_logging.sh"

# Replace existing log calls with centralized logging
log_to_gui() {
    info "$1"
}

import_dependencies() {
    info "Importing dependencies..."
    if ! command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
        error "grub-mkpasswd-pbkdf2 command not found. Please install GRUB tools."
=======

import_dependencies() {
    echo "[INFO] Importing dependencies..."
    if ! command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
        echo "[ERROR] grub-mkpasswd-pbkdf2 command not found. Please install GRUB tools."
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
        exit 1
    fi

    if ! command -v openssl &> /dev/null; then
<<<<<<< HEAD
        info "Installing OpenSSL..."
=======
        echo "[INFO] Installing OpenSSL..."
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
        sudo apt-get install -y openssl
    fi

    if ! dpkg -l | grep -q libssl-dev; then
<<<<<<< HEAD
        info "Installing OpenSSL development libraries..."
        sudo apt-get install -y libssl-dev
    fi

    info "Dependencies imported successfully."
}

update_grub() {
    info "Updating GRUB configuration with enhanced security measures..."
    local grub_cfg="/etc/default/grub"
    local p1 p2 raw grub_password_hash

    if [[ ! -f "$grub_cfg" ]]; then
        error "GRUB configuration not found at $grub_cfg."
        return 1
    fi
    if [[ ! -w "$grub_cfg" ]]; then
        error "$grub_cfg is not writable. Check permissions."
        return 1
    fi

    sudo mkdir -p "$BACKUP_DIR"
    sudo cp "$grub_cfg" "$BACKUP_DIR/grub.bak.$(date +%s)"

=======
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

  
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
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

<<<<<<< HEAD
=======
   
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
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
<<<<<<< HEAD
            error "Password must be at least 12 characters long. Please try again."
            continue
        fi
        if grep -q -i -w "$p1" /usr/share/dict/words; then
            error "Password must not be a dictionary word. Please try again."
=======
            echo "[ERROR] Password must be at least 12 characters long. Please try again."
            continue
        fi
        if grep -q -i -w "$p1" /usr/share/dict/words; then
            echo "[ERROR] Password must not be a dictionary word. Please try again."
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
            continue
        fi
        read -r -sp "Confirm GRUB password: " p2; echo
        if [[ "$p1" != "$p2" ]]; then
<<<<<<< HEAD
            error "Passwords do not match. Please try again."
=======
            echo "[ERROR] Passwords do not match. Please try again."
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
            continue
        fi
        break
    done

<<<<<<< HEAD
    if ! command -v grub-mkpasswd-pbkdf2 &>/dev/null; then
        error "grub-mkpasswd-pbkdf2 not found; install grub2-common."
        return 1
    fi

    raw=$(printf "%s\n%s\n" "$p1" "$p1" | grub-mkpasswd-pbkdf2 2>/dev/null)
    grub_password_hash=$(awk '{print $NF}' <<<"$raw")
    if [[ -z "$grub_password_hash" ]]; then
        error "Failed to generate GRUB password hash."
=======
    
    if ! command -v grub-mkpasswd-pbkdf2 &>/dev/null; then
        echo "[ERROR] grub-mkpasswd-pbkdf2 not found; install grub2-common."
        return 1
    fi

   
    raw=$(printf "%s\n%s\n" "$p1" "$p1" | grub-mkpasswd-pbkdf2 2>/dev/null)
    grub_password_hash=$(awk '{print $NF}' <<<"$raw")
    if [[ -z "$grub_password_hash" ]]; then
        echo "[ERROR] Failed to generate GRUB password hash."
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
        return 1
    fi
    unset p1 p2 raw

<<<<<<< HEAD
=======
  
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
    set +x
    sudo tee -a /etc/grub.d/40_custom >/dev/null <<EOF
set superusers="admin"
password_pbkdf2 admin $grub_password_hash
EOF
    set -x

<<<<<<< HEAD
    info "GRUB password protection configured."
    sudo grub-mkconfig -o /boot/grub/grub.cfg >/dev/null 2>&1
    info "GRUB configuration rebuilt with enhanced security."
}

configure_memory() {
    info "Configuring secure kernel, monitored updates, and protecting RAM and CPU from attacks..."

    if ! grep -q "CONFIG_MODULE_SIG=y" "/boot/config-$(uname -r)"; then
        error "Kernel does not have module signing enabled."
        return 1
    fi
    info "Kernel supports module signing."

    info "Configuring secure RAM and CPU settings..."
    if ! grep -q "CONFIG_HARDENED_USERCOPY=y" "/boot/config-$(uname -r)"; then
        error "Kernel does not have hardened usercopy enabled."
        return 1
    fi
    info "Hardened usercopy is enabled."

    if ! grep -q "CONFIG_PAGE_TABLE_ISOLATION=y" "/boot/config-$(uname -r)"; then
        error "Kernel does not have page table isolation enabled."
        return 1
    fi
    info "Page table isolation is enabled."

    info "Configuring monitored updates and panic settings..."
=======
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
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
    sudo sysctl -w kernel.panic_on_oops=1
    sudo sysctl -w kernel.panic=10
    echo "kernel.panic_on_oops=1" | sudo tee -a /etc/sysctl.conf
    echo "kernel.panic=10" | sudo tee -a /etc/sysctl.conf
<<<<<<< HEAD
    info "Monitored updates and panic settings configured."
=======
    echo "[OK] Monitored updates and panic settings configured."
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742

    local grub_cfg="/etc/default/grub"
    if [ -f "$grub_cfg" ]; then
        sudo cp "$grub_cfg" "$BACKUP_DIR/grub.bak.$(date +%s)"
        if ! grep -q "GRUB_CMDLINE_LINUX" "$grub_cfg"; then
            echo "GRUB_CMDLINE_LINUX=\"module.sig_enforce=1 pti=on panic=10 lockdown=integrity\"" | sudo tee -a "$grub_cfg"
        else
            sudo sed -i 's/GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="module.sig_enforce=1 pti=on panic=10 lockdown=integrity /' "$grub_cfg"
        fi
        sudo grub-mkconfig -o /boot/grub/grub.cfg
<<<<<<< HEAD
        info "GRUB configuration updated for secure kernel settings."
    else
        error "GRUB configuration file not found at $grub_cfg."
        return 1
    fi

    local cron_file="/etc/cron.d/grub-update"
    if [ ! -f "$cron_file" ]; then
        info "Setting up cron job for GRUB updates..."
        echo "0 0 * * * root /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg" | sudo tee "$cron_file" > /dev/null
        info "Cron job for GRUB updates set."
    else
        info "Cron job for GRUB updates already exists."
    fi

    info "Secure kernel configuration completed."
}

setup_complete() {
    info "============================================================"
    info "[COMPLETED] Compliance setup completed successfully."
    info "============================================================"
}

=======
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






>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
main() {
    RED_BOLD="\033[1;31m"
    GREEN_BOLD="\033[1;32m"
    RESET="\033[0m"

    print_ascii_banner
    sleep 3
<<<<<<< HEAD
    info "============================================================"
    info "[STEP 1] Starting compliance setup..."
    info "============================================================"

    if [ "$(id -u)" -ne 0 ]; then
        info "------------------------------------------------------------"
        if ! mkdir -p "$BACKUP_DIR"; then
            error "Failed to create backup directory at $BACKUP_DIR. Please check permissions."
            exit 1
        fi
        info "------------------------------------------------------------"
        exit 1
    fi
    sleep 2
    info "------------------------------------------------------------"
    info "[STEP 2] Importing dependencies..."
    info "------------------------------------------------------------"
    import_dependencies
    sleep 2
    info "------------------------------------------------------------"
    info "[STEP 2] Creating backup directory at $BACKUP_DIR..."
    info "------------------------------------------------------------"
    mkdir -p "$BACKUP_DIR"
    info "Backup directory created."

    info "------------------------------------------------------------"
    info "[STEP 3] Configuring secure memory and kernel settings..."
    info "------------------------------------------------------------"
    configure_memory
    sleep 2
    info "Secure memory and kernel settings configured."

    info "------------------------------------------------------------"
    info "[STEP 4] Updating GRUB configuration for compliance..."
    info "------------------------------------------------------------"
    update_grub
    sleep 2
    info "GRUB configuration updated."
=======
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
>>>>>>> 8476171ece892a945fa8f35384c0e87d9c361742
    setup_complete 
}

main "$@"