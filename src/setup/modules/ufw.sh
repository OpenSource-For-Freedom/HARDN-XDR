#!/bin/bash
# ufw.sh - Configure UFW firewall

HARDN_STATUS "info" "Setting up UFW firewall..."

# Universal package installer
is_installed() {
    command -v "$1" &>/dev/null
}

# Install UFW if not present
if ! is_installed ufw; then
    HARDN_STATUS "info" "UFW not found. Installing..."
    if is_installed apt-get; then
        sudo apt-get update >/dev/null 2>&1
        sudo apt-get install -y ufw >/dev/null 2>&1
    elif is_installed dnf; then
        sudo dnf install -y ufw >/dev/null 2>&1
    elif is_installed yum; then
        sudo yum install -y ufw >/dev/null 2>&1
    else
        HARDN_STATUS "error" "Unsupported package manager. Cannot install UFW."
        return 1
    fi
fi

HARDN_STATUS "info" "Configuring UFW rules..."
sudo ufw --force reset >/dev/null
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow out 53/tcp
sudo ufw allow out ssh
sudo ufw allow out http
sudo ufw allow out https/tcp
sudo ufw logging medium
HARDN_STATUS "info" "Enabling UFW firewall..."
echo "y" | sudo ufw enable
sudo ufw status verbose
HARDN_STATUS "pass" "UFW firewall is configured and enabled."
