#!/bin/bash

echo "##############################################################"
echo "#       ██░ ██  ▄▄▄       ██▀███  ▓█████▄  ███▄    █         #"
echo "#      ▓██░ ██▒▒████▄    ▓██ ▒ ██▒▒██▀ ██▌ ██ ▀█   █         #"
echo "#      ▒██▀▀██░▒██  ▀█▄  ▓██ ░▄█ ▒░██   █▌▓██  ▀█ ██▒        #"
echo "#      ░▓█ ░██ ░██▄▄▄▄██ ▒██▀▀█▄  ░▓█▄   ▌▓██▒  ▐▌██▒        #"
echo "#      ░▓█▒░██▓ ▓█   ▓██▒░██▓ ▒██▒░▒████▓ ▒██░   ▓██░        #"
echo "#       ▒ ░░▒░▒ ▒▒   ▓▒█░░ ▒▓ ░▒▓░ ▒▒▓  ▒ ░ ▒░   ▒ ▒         #"
echo "#       ▒ ░▒░ ░  ▒   ▒▒ ░  ░▒ ░ ▒░ ░ ▒  ▒ ░ ░░   ░ ▒░        #"
echo "#       ░  ░░ ░  ░   ▒     ░░   ░  ░ ░  ░    ░   ░ ░         #"
echo "#       ░  ░  ░      ░  ░   ░        ░             ░         #"  
echo "#                           ░                                #"
echo "#               THE LINUX SECURITY PROJECT                   #"
echo "#                  DEVELOPER: TIM BURNS                      #"
echo "#                                                            #"      
echo "##############################################################"



set -e  # Exit immediately if a command exits with a non-zero status

print_separator() {
echo "-------------------------------------------------------"
echo "                   HARDN - SETUP                       "
echo "-------------------------------------------------------"
}
# Ensure the script is run as root
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use: sudo ./setup.sh"
   exit 1
fi


# DOCKER

echo "-------------------------------------------------------"
echo "                 START DOCKER INSTALL                  "
echo "-------------------------------------------------------"

# Install Docker Compose standalone binary
echo "[+] Installing Docker Compose standalone binary..."
LATEST_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep tag_name | cut -d '"' -f 4)
curl -L "https://github.com/docker/compose/releases/download/${LATEST_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Move to the script's directory
cd "$(dirname "$0")"

echo "[+] Updating system packages..."
apt update && apt upgrade -y

echo "[+] Installing required system dependencies..."
apt install -y python3 python3-venv python3-pip ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums build-essential python3-dev python3-setuptools python3-wheel docker.io

echo "[+] Setting up Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

echo "[+] Upgrading pip and installing Python dependencies..."
pip install --upgrade pip setuptools wheel
pip install docker-compose PyYAML
pip install -r requirements.txt

echo "[+] Installing HARDN as a system-wide command..."
pip install -e .

echo "-------------------------------------------------------"
echo "                 BUILD PYTHON EVE                      "
echo "-------------------------------------------------------"

# FIND - source file and file path 
if [ -f "src/hardn_dark.py" ]; then
    chmod +x src/hardn_dark.py
else
    echo "Warning: src/hardn_dark.py not found. Skipping chmod."
fi

if [ -f "src/packages.py" ]; then
    chmod +x src/packages.py
else
    echo "Warning: src/packages.py not found. Skipping chmod."
fi

if [ -f "src/kernelpy.py" ]; then
    chmod +x src/kernelpy.py
else
    echo "Warning: src/kernelpy.py not found. Skipping chmod."
fi

echo "-------------------------------------------------------"
echo "                  BUILDING DOCKER IMAGE                "
echo "-------------------------------------------------------"

# Check if the 'docker' directory exists
if [ -d "docker" ]; then
    pushd docker
    if [ -f "docker-compose.yml" ]; then
        docker-compose -f docker-compose.yml build
    else
        echo "Warning: 'docker-compose.yml' not found. Skipping Docker image build."
    fi
    popd
else
    echo "Warning: 'docker' directory not found. Skipping Docker image build."
fi

# Ensure Docker is installed and running
if ! command -v docker &> /dev/null; then
    echo "Docker not found, installing..."
    apt install -y docker.io
    systemctl start docker
    systemctl enable docker
fi

# Add the user to the Docker group
if ! groups $USER | grep -q "\bdocker\b"; then
    usermod -aG docker $USER
    echo "User added to the Docker group. Please log out and log back in for changes to take effect."
else
    echo "User is already in the Docker group."
fi
# Pull and build Docker image
if ! docker image inspect ubuntu:latest > /dev/null 2>&1; then
    echo "[+] Pulling ubuntu:latest image..."
    docker pull ubuntu:latest
else
    echo "[+] ubuntu:latest image already exists locally. Skipping pull."
fi

# Check if the 'docker' directory exists
if [ -d "docker" ]; then
    pushd docker
    if [ -f "docker-compose.yml" ]; then
        docker-compose -f docker-compose.yml build
    else
        echo "Warning: 'docker-compose.yml' not found. Skipping Docker image build."
    fi
    popd
else
    echo "Warning: 'docker' directory not found. Skipping Docker image build."
fi

echo "-------------------------------------------------------"
echo "                     SECURITY                          "
echo "-------------------------------------------------------"


# Configure UFW
ufw default deny incoming
ufw default allow outgoing
ufw allow out 80/tcp
ufw allow 443/tcp
ufw allow from 127.0.0.1 to any port 2375
ufw --force enable

# Install and configure additional security tools
apt install -y lynis fail2ban apparmor apparmor-profiles apparmor-utils debsums
systemctl enable apparmor
systemctl start apparmor

# APT DEB PACKAGES
echo "-------------------------------------------------------"
echo "                       PACKAGES                        "
echo "-------------------------------------------------------"

# Install additional packages
apt install -y postfix aide tcpd chkrootkit rkhunter clamav clamav-daemon clamav-freshclam clamav-unofficial-sigs clamtk \
    libpam-pwquality libpam-cracklib libpam-tmpdir libpam-ccreds libpam-ldap libpam-krb5 libpam-mount libpam-ssh \
    selinux-basics selinux-policy-default auditd maldetect

# Update ClamAV database
freshclam

echo "-------------------------------------------------------"
echo "                      THE PURGE                        "
echo "-------------------------------------------------------"

# AUTOREM is safe before exit
echo "[+] Checking for unnecessary packages to remove..."
if sudo apt autoremove --dry-run | grep -q "The following packages will be REMOVED"; then
    echo "[!] The following packages will be removed:"
    sudo apt autoremove --dry-run | grep "The following packages will be REMOVED" -A 10
    echo "[+] Proceeding with autoremove..."
    sudo apt autoremove -y
else
    echo "[+] No unnecessary packages to remove."
fi

echo "[+] Cleaning up package cache..."
sudo apt autoclean -y
sudo apt clean -y

# Run Debsums
echo "[+] Running Debsums..."
debsums --all --changed --quiet --verbose

echo "-------------------------------------------------------"
echo "                          CRON                         "
echo "-------------------------------------------------------"
# Set up automatic updates
echo "[+] Setting up automatic updates..."
(crontab -l 2>/dev/null; echo "0 3 * * * apt update && apt upgrade -y") | crontab -

echo "-------------------------------------------------------"
echo "[+]               HARDN SETUP COMPLETE"
echo "-------------------------------------------------------"