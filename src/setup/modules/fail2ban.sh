#!/bin/bash

set -e

install_fail2ban() {
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
        echo "Please use yum or dnf to install fail2ban on RPM-based systems."
        exit 1
    else
        echo "No supported package manager found."
        exit 1
    fi
}

enable_and_start_fail2ban() {
    sudo systemctl enable fail2ban
    sudo systemctl start fail2ban
    sudo systemctl status fail2ban --no-pager
}

harden_fail2ban_service() {
    echo "Hardening fail2ban service..."
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
    echo "Fail2ban service hardened."
}

main() {
    install_fail2ban
    harden_fail2ban_service
    enable_and_start_fail2ban
    echo "Fail2ban installation and setup complete."
}

main