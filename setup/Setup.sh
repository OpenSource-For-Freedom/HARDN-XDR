#!/bin/bash

# HARDN - Setup 
# Installs + Pre-config 
# Must have python loaded already 
# Author: Tim "TANK" Burns

set -e  # Exit immediately if a command exits with a non-zero status

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
# PYTHON 3 EVE BUILD
echo "[+] Installing required system dependencies..."
apt install -y python3 python3-venv python3-pip ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums

echo "[+] Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "[+] Installing Python dependencies..."
pip install --upgrade pip
pip install -r requirements.txt

echo "[+] Installing HARDN as a system-wide command..."
pip install -e .

# BUILD and CHMOD (ALL)
chmod +x src/hardn.py
chmod +x src/hardn_dark.py
chmod +x src/packages.py
chmod +x src/kernelpy.py

echo "All necessary files have been made executable."

echo "-------------------------------------------------------"
echo "                  BUILDING DOCKER IMAGE                "
echo "-------------------------------------------------------"

# Make Docker-related files executable
if ! groups $USER | grep -q "\bdocker\b"; then
    echo "User added to docker group. Please log out and log back in for changes to take effect."
else
    echo "User is already in the docker group."
fi

# Install Docker if not already installed
if ! command -v docker &> /dev/null
then
    echo "Docker not found, installing..."
    sudo apt update
    sudo apt install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# APT DEB PACKAGES

# LYNIS
echo "[+] Setting up Lynis..."
sudo apt install -y lynis
lynis update info   
lynis audit system --pentest >> /var/log/lynis.log 2>&1
lynis audit system --pentest
# FIREJAIL
echo "[+] Setting up Firejail..."
sudo apt install firejail -y
# postfix
echo "[+] Setting up Postfix..."
sudo apt install postfix -y
# Aide
echo "[+] Setting up Aide..."
sudo apt install aide -y
# TCPD
echo "[+] Setting up TCPD..."
sudo apt install tcpd -y
# TCPWRAPPERS
echo "[+] Setting up TCPWRAPPERS..."
sudo apt install tcpd -y
# fail2ban
echo "[+] Setting up fail2ban..."
sudo apt install fail2ban -y

# DEBSUMS
echo "[+] Setting up Debsums..." 
sudo apt install debsums -y
# APPARMOR
echo "[+] Setting up AppArmor..."
sudo apt install apparmor apparmor-profiles apparmor-utils -y
sudo systemctl enable apparmor
sudo systemctl start apparmor
# selinux
echo "[+] Setting up SELinux..."
sudo apt install selinux-basics selinux-policy-default auditd -y
# maldetect LMD
echo "[+] Setting up maldetect..."
sudo apt install maldetect -y
# clamav
echo "[+] Setting up ClamAV..."
sudo apt install clamav -y
# clamav-daemon
echo "[+] Setting up ClamAV Daemon..."
sudo apt install clamav-daemon -y
# clamav-freshclam
echo "[+] Setting up ClamAV Freshclam..."
sudo apt install clamav-freshclam -y
# clamav-unofficial-sigs
echo "[+] Setting up ClamAV Unofficial Sigs..." 
sudo apt install clamav-unofficial-sigs -y
# clamtk
echo "[+] Setting up ClamTK..."
sudo apt install clamtk -y
# libpam-pwquality 
echo "[+] Setting up libpam-pwquality..."
sudo apt install libpam-pwquality -y
# libpam-cracklib
echo "[+] Setting up libpam-cracklib..."
sudo apt install libpam-cracklib -y
# libpam-tmpdir
echo "[+] Setting up libpam-tmpdir..."
sudo apt install libpam-tmpdir -y
# libpam-ccreds
echo "[+] Setting up libpam-ccreds..."
sudo apt install libpam-ccreds -y
# libpam-ldap
echo "[+] Setting up libpam-ldap..."
sudo apt install libpam-ldap -y
# libpam-krb5
echo "[+] Setting up libpam-krb5..."
sudo apt install libpam-krb5 -y
# libpam-mount
echo "[+] Setting up libpam-mount..."
sudo apt install libpam-mount -y
# libpam-ssh
echo "[+] Setting up libpam-ssh..."
sudo apt install libpam-ssh -y
# chkrootkit
echo "[+] Setting up chkrootkit..."
sudo apt install chkrootkit -y
# rkhunter
echo "[+] Setting up rkhunter..."
sudo apt install rkhunter -y



# Update and clean system packages
sudo apt update -y
sudo apt install -y curl
sudo apt upgrade -y
sudo apt dist-upgrade -y
# Ensure autoremove is safe before executing
if sudo apt autoremove --dry-run | grep -q "The following packages will be REMOVED"; then
    echo "Autoremove will remove packages. Proceeding with caution..."
    sudo apt autoremove -y
else
    echo "No packages to autoremove."
fi
sudo apt autoclean -y
sudo apt clean -y
# Removed redundant installation of python3-tk as python3 and dependencies are already installed.
python3 -c "try: import tkinter; print('tkinter is installed') except ImportError: print('tkinter is not installed')"
sudo apt install python3-pip -y
sudo apt install python3-venv -y
sudo apt install python3-dev -y
sudo apt install python3-setuptools -y
sudo apt install python3-wheel -y
sudo apt install python3-virtualenv -y


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

# Build Docker image using configuration from HARDN file
pushd docker
docker-compose -f ../HARDN/docker_compose.yml build
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
# ufw allow 22/tcp
# Allow HTTP and HTTPS
ufw allow outgoing 80/tcp 
ufw allow 443/tcp

# Allow Docker locally
ufw allow from 127.0.0.1 to any port 2375
ufw --force reload
ufw enable

# DEBSUMS
# Install Debsums if not already installed
echo "[+] Setting up Debsums..."
sudo apt install -y debsums

# Run Debsums with various options
debsums --all
debsums --all --changed
debsums --all --changed --quiet
debsums --all --changed --quiet --verbose
debsums --all --changed --quiet --verbose --force
debsums --all --changed --quiet --verbose --force --no-pager
debsums --all --changed --quiet --verbose --force --no-pager --no-color
debsums --all --changed --quiet --verbose --force --no-pager --no-color --no-progress
debsums --all --changed --quiet --verbose --force --no-pager --no-color --no-progress --no-headers
debsums --all --changed --quiet --verbose --force --no-pager --no-color --no-progress --no-headers --no-truncate
debsums --all --changed --quiet --verbose --force --no-pager --no-color --no-progress --no-headers --no-truncate --no-syslog



# CRON
echo "[+] Setting up automatic updates..."

# Define cron jobs
declare -a cron_jobs=(
    "0 3 * * * apt update && apt upgrade -y"
    "0 2 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1"
    "0 1 * * * debsums --all --changed --quiet --verbose --force --no-pager --no-color --no-progress --no-headers --no-truncate --no-syslog"
    "0 4 * * * ufw status"
    "0 5 * * * fail2ban-client status"
    "0 6 * * * apparmor_parser -r /etc/apparmor.d/usr.sbin.rsyslogd"
    "0 7 * * * lynis update info"
    "0 8 * * * debsums --all"
    "0 9 * * * lynis audit system --quick --tests-from-group malware"
    "0 10 * * * debsums"
    "0 11 * * * ufw status"
    "0 12 * * * fail2ban-client status"
    "0 13 * * * apparmor_parser -r /etc/apparmor.d/usr.sbin.rsyslogd"
    "0 14 * * * lynis update info"
    "0 15 * * * debsums"
    "0 16 * * * ufw status"
    "0 17 * * * fail2ban-client status"
    "0 18 * * * apparmor_parser -r /etc/apparmor.d/usr.sbin.rsyslogd"
)

# Add cron jobs
for job in "${cron_jobs[@]}"; do
    (crontab -l 2>/dev/null; echo "$job") | crontab -
done

echo " ------------------------------------"
echo "[+] Setup complete!"
echo "    Start HARDN using:"
echo "    hardn"
echo "-------------------------------------"