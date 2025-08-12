#!/bin/bash

# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# -------- Check for container environment --------
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected, skipping Fail2ban setup."
    HARDN_STATUS "info" "Fail2ban is not suitable for container environments"
    return 0 2>/dev/null || hardn_module_exit 0
fi

# Install Fail2ban automatically for security hardening
HARDN_STATUS "info" "Installing Fail2ban for brute force protection (automated mode)"

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
    safe_systemctl "enable" "fail2ban"
    safe_systemctl "start" "fail2ban"
    safe_systemctl "status" "fail2ban" "--no-pager" || true
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
    safe_systemctl "daemon-reexec"
    HARDN_STATUS "pass" "Fail2ban service hardened with override.conf"
}

# -------- UFW Integration --------
configure_ufw_for_fail2ban() {
    if ! command -v ufw >/dev/null 2>&1; then
        HARDN_STATUS "info" "UFW not found. Skipping UFW integration."
        return 0
    fi

    if ! safe_systemctl "status" "ufw" "--quiet"; then
        HARDN_STATUS "warning" "UFW is not active. Skipping UFW integration."
        return 0
    fi

    # Enable UFW integration automatically for enhanced security
    HARDN_STATUS "info" "Configuring Fail2ban with UFW integration (automated mode)"

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
}

summary_message() {
    HARDN_STATUS "pass" "Fail2ban installation and hardening completed successfully"
    HARDN_STATUS "info" "Check active jails: fail2ban-client status"
    HARDN_STATUS "info" "Logs: /var/log/fail2ban.log"
    HARDN_STATUS "info" "Configuration: /etc/fail2ban/jail.local"
}

main() {
    install_fail2ban || return 0
    harden_fail2ban_service
    enable_and_start_fail2ban
    configure_ufw_for_fail2ban
    summary_message
    HARDN_STATUS "pass" "Fail2ban installation and setup complete."
    return 0 2>/dev/null || hardn_module_exit 0
}

main

return 0 2>/dev/null || hardn_module_exit 0
