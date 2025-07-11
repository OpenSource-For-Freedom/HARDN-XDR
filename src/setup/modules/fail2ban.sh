#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../hardn-common.sh" 2>/dev/null || {
    # Fallback if common file not found
    HARDN_STATUS() {
        local status="$1"
        local message="$2"
        case "$status" in
            "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
            "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
            "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
            "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
            *)         echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
        esac
    }
}

set -e

install_fail2ban() {
    HARDN_STATUS "info" "Installing Fail2ban..."
    hardn_msgbox "Installing Fail2ban...\n\nThis may take a few minutes."
    hardn_infobox "Please have your ssh key stored and login backup...\n\nThis process disables certain processes."
    hardn_msgbox "Press OK to continue."
    if command -v yum &>/dev/null; then
        sudo yum install -y epel-release
        sudo yum install -y fail2ban
    elif command -v dnf &>/dev/null; then
        sudo dnf install -y epel-release
        sudo dnf install -y fail2ban
    elif command -v apt &>/dev/null; then
        sudo apt update
        sudo apt install -y fail2ban
    elif command -v rpm &>/dev/null; then
        HARDN_STATUS "error" "Please use yum or dnf to install fail2ban on RPM-based systems."
        exit 1
    else
        HARDN_STATUS "error" "No supported package manager found."
        exit 1
    fi
    HARDN_STATUS "pass" "Fail2ban installed successfully"
}

enable_and_start_fail2ban() {
    HARDN_STATUS "info" "Enabling and starting Fail2ban service..."
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    sudo systemctl status fail2ban --no-pager
    HARDN_STATUS "pass" "Fail2ban service enabled and started"
}

harden_fail2ban_service() {
    HARDN_STATUS "info" "Hardening fail2ban service..."
    sudo mkdir -p /etc/systemd/system/fail2ban.service.d
    sudo bash -c 'cat > /etc/systemd/system/fail2ban.service.d/override.conf' <<EOF
[Service]
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
PrivateDevices=true
EOF
    sudo systemctl daemon-reload
    HARDN_STATUS "pass" "Fail2ban service hardened"
}

main() {
    install_fail2ban
    harden_fail2ban_service
    enable_and_start_fail2ban
    HARDN_STATUS "pass" "Fail2ban installation and setup complete"
}

main
