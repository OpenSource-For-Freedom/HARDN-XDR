#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# Universal package installer
is_installed() {
    command -v "$1" &>/dev/null
}

HARDN_STATUS "info" "Installing OpenSSH server..."
hardn_msgbox "Installing OpenSSH server...\n\nThis may take a few minutes."
hardn_infobox "Please have your ssh key stored and login backup...\n\nThis process disables certain processes."

# Install OpenSSH server
if is_installed apt-get; then
    sudo apt-get update
    sudo apt-get install -y openssh-server
elif is_installed yum; then
    sudo yum install -y openssh-server
elif is_installed dnf; then
    sudo dnf install -y openssh-server
else
    HARDN_STATUS "error" "Unsupported package manager. Please install OpenSSH server manually."
    return 1
fi

# Define the service name
# On Debian/Ubuntu, the service is ssh.service, and sshd.service is a symlink.
# On RHEL/CentOS, the service is sshd.service.
# use canonical name to avoid issues with aliases.
if systemctl list-unit-files | grep -q -w "ssh.service"; then
    SERVICE_NAME="ssh.service"
elif systemctl list-unit-files | grep -q -w "sshd.service"; then
    SERVICE_NAME="sshd.service"
else
    HARDN_STATUS "error" "Could not find sshd or ssh service."
    return 1
fi

HARDN_STATUS "info" "Enabling and starting SSH service: $SERVICE_NAME"
hardn_msgbox "Enabling and starting SSH service: $SERVICE_NAME\n\nThis may take a few seconds."
hardn_infobox "Please have your ssh key stored and login backup...\n\nThis process disables login certain processes."
hardn_msgbox "Press OK to continue."

# Enable and start sshd service
sudo systemctl enable "$SERVICE_NAME"
sudo systemctl start "$SERVICE_NAME"

# COMMENTED OUT: Basic configuration
# WARNING: These SSH hardening settings are DISABLED for testing
SSHD_CONFIG="/etc/ssh/sshd_config"
if [ -f "$SSHD_CONFIG" ]; then
    # DISABLED: sudo sed -i 's/^#?PermitRootLogin.*/PermitRootLogin no/' "$SSHD_CONFIG"
    # DISABLED: sudo sed -i 's/^#?PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
    HARDN_STATUS "warning" "SSH hardening is DISABLED - PermitRootLogin and PasswordAuthentication changes are commented out"
    HARDN_STATUS "info" "This allows password login for testing. Re-enable after confirming SSH key access works."
else
    HARDN_STATUS "warning" "$SSHD_CONFIG not found. Skipping configuration."
fi

# Restart sshd to apply changes (minimal changes now)
sudo systemctl restart "$SERVICE_NAME"

HARDN_STATUS "pass" "OpenSSH server installed with MINIMAL hardening for testing."

#Safe return or exit
return 0 2>/dev/null || exit 0
