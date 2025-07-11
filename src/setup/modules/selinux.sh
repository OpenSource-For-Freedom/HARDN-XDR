#!/bin/bash
set +e  # Don't exit on error

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

is_installed() {
    if command -v apt >/dev/null 2>&1; then
        dpkg -s "$1" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$1" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$1" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1 # Cannot determine package manager
    fi
}

# SELinux installation and setup script

# Install SELinux packages
if command -v dnf >/dev/null 2>&1; then
    if ! is_installed selinux-policy; then
        HARDN_STATUS info "Installing SELinux packages with dnf..."
        if ! sudo dnf install -y selinux-policy selinux-policy-targeted policycoreutils policycoreutils-python-utils; then
            HARDN_STATUS error "Failed to install SELinux packages with dnf."
        fi
    else
        HARDN_STATUS info "SELinux packages already installed (dnf)."
    fi
elif command -v yum >/dev/null 2>&1; then
    if ! is_installed selinux-policy; then
        HARDN_STATUS info "Installing SELinux packages with yum..."
        if ! sudo yum install -y selinux-policy selinux-policy-targeted policycoreutils policycoreutils-python; then
            HARDN_STATUS error "Failed to install SELinux packages with yum."
        fi
    else
        HARDN_STATUS info "SELinux packages already installed (yum)."
    fi
elif command -v apt-get >/dev/null 2>&1; then
    if ! is_installed selinux-basics; then
        HARDN_STATUS info "Updating apt-get and installing SELinux packages..."
        if ! sudo apt-get update; then
            HARDN_STATUS error "Failed to update apt-get."
        fi
        if ! sudo apt-get install -y selinux-basics selinux-policy-default auditd; then
            HARDN_STATUS error "Failed to install SELinux packages with apt-get."
        fi
    else
        HARDN_STATUS info "SELinux packages already installed (apt-get)."
    fi
else
    HARDN_STATUS error "Unsupported package manager. Please install SELinux manually."
    # Don't exit, just warn
fi

# Enable SELinux (for Debian/Ubuntu)
if [ -f /etc/selinux/config ]; then
    HARDN_STATUS info "Setting SELINUX=enforcing in /etc/selinux/config"
    if ! sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config; then
        HARDN_STATUS error "Failed to set SELINUX=enforcing in /etc/selinux/config"
    fi
elif [ -f /etc/selinux/selinux.conf ]; then
    HARDN_STATUS info "Setting SELINUX=enforcing in /etc/selinux/selinux.conf"
    if ! sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/selinux.conf; then
        HARDN_STATUS error "Failed to set SELINUX=enforcing in /etc/selinux/selinux.conf"
    fi
fi

# For Debian/Ubuntu, initialize SELinux
if command -v selinux-activate >/dev/null 2>&1; then
    HARDN_STATUS info "Running selinux-activate..."
    if ! sudo selinux-activate; then
        HARDN_STATUS error "Failed to run selinux-activate."
    fi
fi

HARDN_STATUS info "SELinux installation and basic setup complete."
HARDN_STATUS info "A reboot may be required for changes to take effect."
