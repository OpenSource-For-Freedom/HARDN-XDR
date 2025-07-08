#!/bin/bash
# sshd.sh - Install and basic setup for OpenSSH server

set -e

# Universal package installer
is_installed() {
    command -v "$1" &>/dev/null
}

# Install OpenSSH server
if is_installed apt-get; then
    sudo apt-get update
    sudo apt-get install -y openssh-server
elif is_installed yum; then
    sudo yum install -y openssh-server
elif is_installed dnf; then
    sudo dnf install -y openssh-server
else
    echo "Unsupported package manager. Please install OpenSSH server manually."
    exit 1
fi

# Define the service name
# On Debian/Ubuntu, the service is ssh.service, and sshd.service is a symlink.
# On RHEL/CentOS, the service is sshd.service.
# We will prefer the canonical name to avoid issues with aliases.
if systemctl list-unit-files | grep -q -w "ssh.service"; then
    SERVICE_NAME="ssh.service"
elif systemctl list-unit-files | grep -q -w "sshd.service"; then
    SERVICE_NAME="sshd.service"
else
    echo "Could not find sshd or ssh service."
    exit 1
fi

# Enable and start sshd service
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# Basic configuration: PermitRootLogin no, PasswordAuthentication no
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    sudo sed -i 's/^#?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    sudo sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    echo "Warning: PasswordAuthentication has been disabled. Ensure you have SSH key-based access."
else
    echo "Warning: $SSHD_CONFIG not found. Skipping configuration."
fi

# Restart sshd to apply changes
sudo systemctl restart "$SERVICE_NAME"

echo "OpenSSH server installed and basic setup complete."