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


# Check if systemd is available and running
is_systemd_available() {
    # Check if systemd is the init system (PID 1)
    if [[ -d /run/systemd/system ]] && [[ "$(readlink -f /sbin/init)" == *"systemd"* ]] || [[ -f /lib/systemd/systemd ]]; then
        # Additional check: can we actually communicate with systemd?
        if systemctl --version &>/dev/null && systemctl status --no-pager &>/dev/null; then
            return 0
        fi
    fi
    exit 1
}

HARDN_STATUS "info" "Installing OpenSSH server..."
HARDN_STATUS "info" "Installing OpenSSH server for secure remote access"
HARDN_STATUS "warning" "SSH configuration will be hardened - ensure you have backup access"

# Check if in CI/container environment and skip installation if needed
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - SSH server installation may be limited"
    if ! command -v sshd >/dev/null 2>&1; then
        HARDN_STATUS "warning" "SSH daemon not found in container - simulating configuration"
        # In containers, we can still test configuration logic without actual installation
    fi
else
    # Install OpenSSH server only in non-container environments
    if command -v apt-get &>/dev/null; then
        apt-get install -y openssh-server
    elif command -v yum &>/dev/null; then
        yum install -y openssh-server
    elif command -v dnf &>/dev/null; then
        dnf install -y openssh-server
    elif command -v pacman &>/dev/null; then
        pacman -S --noconfirm openssh
    elif command -v zypper &>/dev/null; then
        zypper install -y openssh
    else
        HARDN_STATUS "error" "Unsupported package manager. Please install OpenSSH server manually."
        return 1
    fi
fi

# Define the service name
# On Debian/Ubuntu, the service is ssh.service, and sshd.service is a symlink.
# On RHEL/CentOS, the service is sshd.service.
# use canonical name to avoid issues with aliases.
SERVICE_NAME=""
if is_systemd_available; then
    if systemctl list-unit-files | grep -q -w "ssh.service"; then
        SERVICE_NAME="ssh.service"
    elif systemctl list-unit-files | grep -q -w "sshd.service"; then
        SERVICE_NAME="sshd.service"
    else
        HARDN_STATUS "error" "Could not find sshd or ssh service."
        return 1
    fi
else
    HARDN_STATUS "warning" "systemd not available - skipping service detection"
    # Try to determine service name by checking common locations
    if [[ -f /etc/init.d/ssh ]]; then
        SERVICE_NAME="ssh"
    elif [[ -f /etc/init.d/sshd ]]; then
        SERVICE_NAME="sshd"
    else
        HARDN_STATUS "warning" "Could not detect SSH service name - using 'ssh' as fallback"
        SERVICE_NAME="ssh"
    fi
fi

HARDN_STATUS "info" "Enabling and starting SSH service: $SERVICE_NAME"
HARDN_STATUS "info" "Configuring SSH service for secure remote access"
HARDN_STATUS "warning" "Ensure you have SSH key access or backup login method"
HARDN_STATUS "info" "Proceeding with SSH hardening configuration"

# Enable and start sshd service using safe wrapper
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - SSH service management will be skipped"
    HARDN_STATUS "info" "In containers, SSH service should be managed by the container orchestrator"
else
    safe_systemctl "enable" "$SERVICE_NAME"
    safe_systemctl "start" "$SERVICE_NAME"
    
    # Check if SSH is running
    if pgrep -x "sshd" >/dev/null; then
        HARDN_STATUS "pass" "SSH daemon is running"
    elif safe_systemctl "status" "$SERVICE_NAME"; then
        HARDN_STATUS "pass" "SSH service is active according to systemctl"
    else
        HARDN_STATUS "warning" "SSH daemon not detected running - manual start may be required"
    fi
fi

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
if ! is_container_environment; then
    safe_systemctl "restart" "$SERVICE_NAME"
else
    HARDN_STATUS "info" "Container environment - skipping SSH service restart"
fi

HARDN_STATUS "pass" "OpenSSH server installed."

return 0 2>/dev/null || hardn_module_exit 0
set -e
