#!/bin/bash

source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# -------- Check for interactive and container --------
if grep -qa container /proc/1/environ || systemd-detect-virt --quiet --container || ! [ -t 0 ]; then
    HARDN_STATUS "info" "Skipping Fail2ban setup (container or non-interactive)."
    return 0 2>/dev/null || exit 0
fi

# -------- Ensure whiptail exists --------
if ! command -v whiptail &>/dev/null; then
    HARDN_STATUS "warning" "whiptail not found. Skipping Fail2ban wizard."
    return 0 2>/dev/null || exit 0
fi

# -------- Prompt user to continue --------
if ! whiptail --title "Fail2ban Setup" --yesno \
"Fail2ban protects your server from brute force attacks by banning IPs.\n\n\
Setup will:\n• Install Fail2ban\n• Harden its systemd service\n• Enable and start the service\n• Optionally integrate with UFW\n\nDo you want to continue?" 18 70; then
    HARDN_STATUS "info" "User cancelled Fail2ban setup."
    return 0 2>/dev/null || exit 0
fi

# -------- Installation --------
install_fail2ban() {
    HARDN_STATUS "info" "Installing Fail2ban..."

    if command -v yum &>/dev/null; then
        yum install -y epel-release
        yum install -y fail2ban
    elif command -v dnf &>/dev/null; then
        dnf install -y epel-release
        dnf install -y fail2ban
    elif command -v apt &>/dev/null; then
        apt update -y
        apt install -y fail2ban
    elif command -v rpm &>/dev/null; then
        HARDN_STATUS "error" "Please use yum or dnf to install Fail2ban on RPM-based systems."
        return 1
    else
        HARDN_STATUS "error" "No supported package manager found."
        return 1
    fi

    HARDN_STATUS "pass" "Fail2ban installed successfully."
}

# -------- Enable + Start Service --------
enable_and_start_fail2ban() {
    HARDN_STATUS "info" "Enabling and starting Fail2ban service..."
    systemctl enable fail2ban
    systemctl start fail2ban
    systemctl status fail2ban --no-pager || true
    HARDN_STATUS "pass" "Fail2ban service enabled and running."
}

# -------- Systemd Hardening --------
harden_fail2ban_service() {
    HARDN_STATUS "info" "Applying systemd hardening to Fail2ban..."
    mkdir -p /etc/systemd/system/fail2ban.service.d
    cat > /etc/systemd/system/fail2ban.service.d/override.conf <<EOF
[Service]
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
PrivateDevices=true
EOF
    systemctl daemon-reexec
    HARDN_STATUS "pass" "Fail2ban service hardened with override.conf"
}

# -------- UFW Integration --------
configure_ufw_for_fail2ban() {
    if ! command -v ufw >/dev/null 2>&1; then
        HARDN_STATUS "info" "UFW not found. Skipping UFW integration."
        return 0
    fi

    if ! systemctl is-active --quiet ufw; then
        HARDN_STATUS "warning" "UFW is not active. Skipping UFW integration."
        return 0
    fi

    if whiptail --title "Enable UFW Integration" --yesno \
"UFW (Uncomplicated Firewall) is active on your system.\n\n\
Would you like Fail2ban to use UFW to block brute force attacks?" 14 70; then

        mkdir -p /etc/fail2ban
        JAIL_LOCAL="/etc/fail2ban/jail.local"
        touch "$JAIL_LOCAL"

        if ! grep -q '\[DEFAULT\]' "$JAIL_LOCAL"; then
            cat >> "$JAIL_LOCAL" <<EOF
[DEFAULT]
banaction = ufw
EOF
            HARDN_STATUS "info" "UFW banaction set in jail.local."
        elif ! grep -q 'banaction = ufw' "$JAIL_LOCAL"; then
            sed -i 's/^banaction\s*=.*/banaction = ufw/' "$JAIL_LOCAL"
            HARDN_STATUS "info" "banaction updated to use UFW."
        fi

        systemctl restart fail2ban
        HARDN_STATUS "pass" "Fail2ban reloaded with UFW support."
    else
        HARDN_STATUS "info" "User skipped UFW integration."
    fi
}

summary_message() {
    whiptail --title "Setup Complete" --msgbox \
"Fail2ban was installed and hardened.\n\n\
To check active jails:\n  fail2ban-client status\n\n\
Logs:\n  /var/log/fail2ban.log\n\n\
To configure bans:\n  /etc/fail2ban/jail.local\n\nSetup complete." 16 70
}

main() {
    install_fail2ban || return 0
    harden_fail2ban_service
    enable_and_start_fail2ban
    configure_ufw_for_fail2ban
    summary_message
    HARDN_STATUS "pass" "Fail2ban installation and setup complete."
    return 0 2>/dev/null || exit 0
}

main