#!/bin/bash

# #!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
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
