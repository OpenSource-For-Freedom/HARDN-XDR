#!/bin/bash
########################################
#            HARDN - Setup             #
#  Please have repo cloned before hand #
#       Installs + Pre-config          #
#    Must have python-3 loaded already #
#       Author: Tim "TANK" Burns       #
########################################
# ADDED PYTHON EVE FOR PIP INSTALL 
# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use: sudo ./Setup.sh"
   exit 1
fi

# Function to display scrolling text with color
scroll_text() {
    local text="$1"
    local delay="${2:-0.1}"
    local color="${3:-\e[0m}"  # Default to no color
    echo -ne "${color}"  # Set the color
    for ((i=0; i<${#text}; i++)); do
        echo -ne "${text:$i:1}"
        sleep "$delay"
    done
    echo -e "\e[0m"  # Reset the color
}

# BANNER - scrolling text
clear
scroll_text "=======================================================" 0.02 $'\e[33m'
scroll_text "=======================================================" 0.02 $'\e[33m'
scroll_text "          HARDN - Security Setup for Debian            " 0.02 $'\e[92m'
scroll_text "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 0.02 $'\e[33m'
scroll_text "    WARNING: This script will make changes to your     " 0.02 $'\e[92m'
scroll_text "    system. Please ensure you have a backup before     " 0.02 $'\e[92m'
scroll_text "              running this script.                     " 0.02 $'\e[92m'
scroll_text "=======================================================" 0.02 $'\e[33m'
scroll_text "=======================================================" 0.02 $'\e[33m'
scroll_text "                 HARDN - STARTING                      " 0.02 $'\e[92m'
scroll_text "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 0.02 $'\e[33m'
scroll_text "  This script will install all required system packs   " 0.02 $'\e[92m'
scroll_text "  and security tools for a hardened Debian system.     " 0.02 $'\e[92m'
scroll_text "  Please ensure you have cloned the repo before hand.  " 0.02 $'\e[92m'
scroll_text "=======================================================" 0.02 $'\e[33m'

# Change to the script's directory
cd "$(dirname "$0")"

# Update system packages and install Python 3 and pip
update_system_packages() {
    echo "[+] Updating system packages..."
    apt update && apt upgrade -y
    echo "[+] Installing Python 3, pip, and python3-tk..."
    apt install -y python3 python3-pip python3-tk
}
update_system_packages

# Create Python virtual environment and install dependencies
setup_python_env() {
    echo "[+] Setting up Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    if [[ -f requirements.txt ]]; then
        pip install -r requirements.txt
    else
        echo "requirements.txt not found. Skipping Python dependencies installation."
    fi
}
setup_python_env

# Install system security tools
install_security_tools() {
    echo "[+] Installing required system security tools..."
    apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums rkhunter libpam-pwquality libvirt-daemon-system libvirt-clients qemu-kvm docker.io docker-compose openssh-server
}
install_security_tools

# UFW configuration
configure_ufw() {
    echo "[+] Configuring UFW..."
    ufw allow out 53,80,443/tcp
    ufw allow out 53,123/udp
    ufw allow out 67,68/udp
    ufw reload
}
configure_ufw

# Enable and start Fail2Ban and AppArmor services
enable_services() {
    echo "[+] Enabling and starting Fail2Ban and AppArmor services..."
    systemctl enable --now fail2ban
    systemctl enable --now apparmor
}
enable_services

# Install chkrootkit, LMD, and rkhunter
install_additional_tools() {
    echo "[+] Installing chkrootkit, LMD, and rkhunter..."
    apt install -y chkrootkit
    wget http://www.rfxn.com/downloads/maldetect-current.tar.gz
    tar -xzf maldetect-current.tar.gz
    cd maldetect-*
    sudo ./install.sh
    cd ..
    rm -rf maldetect-*
    rm maldetect-current.tar.gz
    apt install -y rkhunter
    rkhunter --update
    rkhunter --propupd
}
install_additional_tools

# Reload AppArmor profiles
reload_apparmor() {
    echo "[+] Reloading AppArmor profiles..."
    apparmor_parser -r /etc/apparmor.d/*
}
reload_apparmor

# Configure cron jobs
configure_cron() {
    echo "[+] Configuring cron jobs..."
    remove_existing_cron_jobs() {
        crontab -l 2>/dev/null | grep -v "lynis audit system --cronjob" \
        | grep -v "apt update && apt upgrade -y" \
        | grep -v "/opt/eset/esets/sbin/esets_update" \
        | grep -v "chkrootkit" \
        | grep -v "maldet --update" \
        | grep -v "maldet --scan-all" \
        | crontab -
    }
    remove_existing_cron_jobs
    crontab -l 2>/dev/null > mycron
    cat <<EOF >> mycron
0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1
0 3 * * * /opt/eset/esets/sbin/esets_update
0 4 * * * chkrootkit
0 5 * * * maldet --update
0 6 * * * maldet --scan-all / >> /var/log/maldet_scan.log 2>&1
EOF
    crontab mycron
    rm mycron
}
configure_cron

# Disable USB storage
disable_usb_storage() {
    echo "[+] Disabling USB storage..."
    echo 'blacklist usb-storage' > /etc/modprobe.d/usb-storage.conf
    modprobe -r usb-storage && echo "[+] USB storage successfully disabled." || echo "[-] Warning: USB storage module in use, cannot unload."
}
disable_usb_storage

# Update system packages again
update_system_packages || { echo "[-] System update failed."; exit 1; }

scroll_text "=======================================================" 0.02
scroll_text "             [+] HARDN - Setup Complete                " 0.02
scroll_text "  Please ensure to configure UFW, Fail2Ban, AppArmor   " 0.02
scroll_text "        and other security tools as needed.            " 0.02
scroll_text "-------------------------------------------------------" 0.02
scroll_text "  [+] Please reboot your system to apply changes       " 0.02
scroll_text "=======================================================" 0.02