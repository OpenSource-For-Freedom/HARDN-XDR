#!/bin/bash
########################################
#            HARDN - Setup             #
#  Please have repo cloned before hand #
#       Installs + Pre-config          #
#    Must have python-3 loaded already #
#       Author: Tim "TANK" Burns       #
########################################

# Function to display scrolling text
scroll_text() {
    local text="$1"
    local delay="${2:-0.1}"
    for ((i=0; i<${#text}; i++)); do
        echo -n "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

# Display the banner with scrolling text
clear
scroll_text "=======================================================" 0.02
scroll_text "=======================================================" 0.02
scroll_text "          HARDN - Security Setup for Debian            " 0.02
scroll_text "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 0.02
scroll_text "    WARNING: This script will make changes to your     " 0.02
scroll_text "    system. Please ensure you have a backup before     " 0.02
scroll_text "              running this script.                     " 0.02
scroll_text "=======================================================" 0.02
scroll_text "=======================================================" 0.02
scroll_text "                 HARDN - STARTING                      " 0.02
scroll_text "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~" 0.02
scroll_text "  This script will install all required system packs   " 0.02
scroll_text "  and security tools for a hardened Debian system.     " 0.02
scroll_text "  Please ensure you have cloned the repo before hand.  " 0.02
scroll_text "=======================================================" 0.02
# ENSURE - the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use: sudo ./Setup.sh"
   exit 1
fi

# INSTALL 
cd "$(dirname "$0")"

echo "[+] Updating system packages..."
apt update && apt install -y python3 python3-tk

echo "[+] Installing required system dependencies..."
apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums rkhunter libpam-pwquality libvirt-daemon-system libvirt-clients qemu-kvm docker.io docker-compose

# Install pexpect using apt
echo "[+] Installing pexpect using apt"
apt install -y python3-pexpect

scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "  HARDN - Installing System Packs and Security Tools   " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02

# SYSTEM PACKS
echo "[+] Installing all needed system dependencies..."
apt install -y \
    ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail \
    tcpd lynis debsums rkhunter libpam-pwquality \
    libvirt-daemon-system libvirt-clients qemu-kvm \
    docker.io docker-compose \
    openssh-server

# SECURITY 

# UFW (update) 
ufw allow out 53,80,443/tcp
ufw allow out 53,123/udp
ufw allow out 67,68/udp  # because static Ip's are 1993
ufw allow out 67,68/udp       


# UFW - reload 
ufw reload || { echo "[-] UFW failed to reload."; exit 1; }

scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "               [+] Setting up Fail2Ban...              " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02
systemctl enable --now fail2ban

scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "               [+] Setting up AppArmor...              " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02
systemctl enable --now apparmor

# remove eset32
# eset32 didnt work
sudo rm /etc/apt/sources.list.d/ubuntu-eset-ppa.list
sudo apt-get update

scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "               [+] Installing chkrootkit...            " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02
# ADD CHROOTKIT
sudo apt-get install -y chkrootkit

scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "               [+] Installing LMD...                   " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02
# ADD lmd
sudo apt-get install -y linuxmalwaredetect


scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "               [+] Installing rkhunter...              " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02
# Installing rkhunter
apt install -y rkhunter
rkhunter --update
rkhunter --propupd

scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "               [+] Reloading AppArmor...               " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02
# Reloading AppArmor 
apparmor_parser -r /etc/apparmor.d/*

scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "               [+] Configuring cron...                 " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02

# Configuring cron 
touch /var/log/lynis_cron.log
chmod 600 /var/log/lynis_cron.log
crontab -l 2>/dev/null | grep -v "lynis audit system --cronjob" | grep -v "apt update && apt upgrade -y" | grep -v "/opt/eset/esets/sbin/esets_update" | grep -v "chkrootkit" | grep -v "maldet --update" | grep -v "maldet --scan-all" | crontab -
crontab -l 2>/dev/null > mycron
cat <<EOF >> mycron
0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1
0 2 * * * apt update && apt upgrade -y
0 3 * * * /opt/eset/esets/sbin/esets_update
0 4 * * * chkrootkit
0 5 * * * maldet --update
0 6 * * * maldet --scan-all / >> /var/log/maldet_scan.log 2>&1
EOF
crontab mycron
rm mycron

scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "               [+] Disabling USB...                    " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02

# Disabling USB 
lsmod | grep usb_storage && echo "[-] Warning: USB storage is still active!" || echo "[+] USB storage successfully disabled."
echo 'blacklist usb-storage' >> /etc/modprobe.d/usb-storage.conf
modprobe -r usb-storage || echo "USB storage module in use, cannot unload."


scroll_text "=======================================================" 0.02
scroll_text "                                                       " 0.02
scroll_text "  HARDN - UPDATING SYSTEM PACKS and ADDING GRS         " 0.02
scroll_text "                                                       " 0.02
scroll_text "=======================================================" 0.02

# Update system
apt update && apt upgrade -y || { echo "[-] System update failed."; exit 1; }

# Install grs (commented out because the package is not available)
# echo "[+] Installing grs..."
# apt install -y grs

scroll_text "=======================================================" 0.02
scroll_text "             [+] HARDN - Setup Complete                " 0.02
scroll_text "  Please ensure to configure UFW, Fail2Ban, AppArmor   " 0.02
scroll_text "        and other security tools as needed.            " 0.02
scroll_text "-------------------------------------------------------" 0.02
scroll_text "  [+] Please reboot your system to apply changes       " 0.02
scroll_text "=======================================================" 0.02
