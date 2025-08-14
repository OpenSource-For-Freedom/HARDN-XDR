#!/bin/bash
# Source common functions with fallback for development/CI environments
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}
#!/bin/bash

# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh

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
set -e
