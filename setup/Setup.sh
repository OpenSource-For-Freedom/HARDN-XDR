#!/bin/bash

# HARDN - Setup 
# Installs + Pre-config 
# Must have python loaded already 
# Author: Tim "TANK" Burns


set -e  # if fails run

echo "-------------------------------------------------------"
echo "  HARDN - Security Setup for Debian, and for us all.   "
echo "-------------------------------------------------------"

# ROOT - nust run as 
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use: sudo ./setup.sh"
   exit 1
fi

# MOVE - assuming you alreasy cloned repo
cd "$(dirname "$0")"

echo "[+] Updating system packages..."
apt update && apt upgrade -y

echo "[+] Installing required system dependencies..."
apt install -y python3 python3-pip ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums 

echo "[+] Installing Python dependencies..."
pip install -r requirements.txt

echo "[+] Installing HARDN as a system-wide command..."
pip install -e .

# BUILD and CHMOD

# Make Python scripts executable
chmod +x src/hardn.py
chmod +x src/hardn_dark.py
chmod +x src/packages.py

# Make Docker-related files executable
chmod +x docker/docker_image
chmod +x docker/docker-compose.yml

# Install Docker if not already installed
if ! command -v docker &> /dev/null
then
    echo "Docker not found, installing..."
    sudo apt-get update
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose not found, installing..."
    sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

# Build Docker image
cd docker
docker-compose build

echo "Setup complete. You can now run the HARDN scripts."

# SECURITY

# UFW
echo "[+] Setting up UFW (Firewall)..."
ufw default deny incoming
ufw default allow outgoing
ufw allow out 80,443/tcp
ufw enable

echo "[+] Setting up Fail2Ban..."
systemctl enable --now fail2ban

echo "[+] Setting up AppArmor..."
systemctl enable --now apparmor

# ESET-NOD32
echo "[+] Installing ESET NOD32 (ES32) Antivirus..."
wget -q https://download.eset.com/com/eset/apps/home/av/linux/latest/eset_nod32av_64bit.deb -O /tmp/eset.deb
dpkg -i /tmp/eset.deb || apt --fix-broken install -y
rm -f /tmp/eset.deb

# CRON
echo "[+] Setting up automatic updates..."
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/eset/esets/sbin/esets_update") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * apt update && apt upgrade -y") | crontab -
(crontab -l 2>/dev/null; echo "0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1") | crontab -

# USB disable 
echo "[+] Disabling USB storage (optional)..."
echo 'blacklist usb-storage' >> /etc/modprobe.d/usb-storage.conf
modprobe -r usb-storage || echo "USB storage module in use, cannot unload."

echo "-------------------------------------"
echo "[+] Setup complete!"
echo "    Start HARDN using:"
echo "    hardn"
echo "-------------------------------------"
