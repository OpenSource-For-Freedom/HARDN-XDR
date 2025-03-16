#!/bin/bash

# HARDN - Setup 
# Installs + Pre-config 
# Must have python loaded already 
# Author: Tim "TANK" Burns


set -e  # if fails run

echo "-------------------------------------------------------"
echo "                  HARDN - DEVOPS - Branch              "
echo "-------------------------------------------------------"

# ROOT - must run as 
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use: sudo ./setup.sh"
   exit 1
fi

# MOVE - assuming you already cloned repo
cd "$(dirname "$0")"

echo "[+] Updating system packages..."
apt update && apt upgrade -y

echo "[+] Installing required system dependencies..."
apt install -y python3 python3-pip ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums 

echo "[+] Installing Python dependencies..."
pip install -r requirements.txt

echo "[+] Installing HARDN as a system-wide command..."
pip install -e .

# BUILD and CHMOD (ALL)
chmod +x src/hardn.py
chmod +x src/hardn_dark.py
chmod +x src/packages.py
chmod +x src/kernelpy.py
# chmod +x docker/docker_image
# chmod +x docker/docker-compose.yml (not needed for YAML configuration file)

echo "All necessary files have been made executable."

echo "-------------------------------------------------------"
echo "                  BUIDLING DOCKER IMAGE                "
echo "-------------------------------------------------------"

# Make Docker-related files executable
if ! groups $USER | grep -q "\bdocker\b"; then
    echo "User added to docker group. Please log out and log back in for changes to take effect."
else
    echo "User is already in the docker group."
fi
chmod +x docker/docker_image
chmod +x docker/docker-compose.yml

# Install Docker if not already installed
if ! command -v docker &> /dev/null
then
    echo "Docker not found, installing..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Install Docker Compose if not already installed
if ! command -v docker-compose &> /dev/null
then
    echo "Docker Compose not found, installing..."
    LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi
# Pull Docker image from docker/docker_image
docker pull ubuntu:latest

# Build Docker image
pushd docker
docker-compose build
popd
echo "Setup complete. You can now run the HARDN scripts."

# RUN DOCKER
sudo systemctl start docker
sudo systemctl enable docker


echo "-------------------------------------------------------"
echo "                     SECURITY                          "
echo "-------------------------------------------------------"


# SECURITY

# UFW
ufw default deny incoming
ufw default allow outgoing

# Allow SSH
ufw allow 22/tcp
# Allow HTTP and HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Allow Docker locally
ufw allow from 127.0.0.1 to any port 2375

ufw --force reload # apply changes

ufw enable
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
(crontab -l 2>/dev/null; echo "0 3 * * * /opt/eset/esets/sbin/esets_update"; echo "0 2 * * * apt update && apt upgrade -y"; echo "0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1") | crontab -
echo " ------------------------------------"
echo "[+] Setup complete!"
echo "    Start HARDN using:"
echo "    hardn"
echo "-------------------------------------"
