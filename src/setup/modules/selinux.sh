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

# --------- OS Detection ----------
get_os_id() {
    awk -F= '/^ID=/{gsub("\"", "", $2); print $2}' /etc/os-release
}

OS_ID=$(get_os_id)

# Only allow execution on RHEL-based systems
if [[ ! "$OS_ID" =~ ^(rhel|centos|fedora|rocky|almalinux)$ ]]; then
    HARDN_STATUS "info" "This SELinux module is only supported on RHEL-based systems. Skipping..."
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- Container Detection ----------
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - SELinux is typically managed by the container runtime"
    HARDN_STATUS "info" "SELinux policies in containers are inherited from the host system"
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --------- Interactive Menu ---------
# Remove unused DEFAULT_MODE variable
# DEFAULT_MODE="permissive"
SHOW_MENU=false

if [ -t 0 ] && command -v whiptail &>/dev/null; then
    SHOW_MENU=true
fi

if $SHOW_MENU; then
    CHOICE=$(whiptail --title "SELinux Mode" --radiolist "Choose SELinux setup level:" 15 70 3 \
        "basic" "Install & set to permissive (safe)" ON \
        "advanced" "Install & set to enforcing (hardened)" OFF \
        "skip" "Skip SELinux setup on this system" OFF 3>&1 1>&2 2>&3)

    EXIT_STATUS=$?
    if [[ $EXIT_STATUS -ne 0 || "$CHOICE" == "skip" ]]; then
        HARDN_STATUS "info" "User cancelled or skipped SELinux setup."
        return 0 2>/dev/null || hardn_module_exit 0
    fi
else
    CHOICE="basic"
    HARDN_STATUS "info" "No terminal or whiptail. Defaulting to basic (permissive)."
fi

# --------- Package Installation ---------
HARDN_STATUS "info" "Installing SELinux for $OS_ID..."
PKG_MGR=$(command -v dnf || command -v yum)
$PKG_MGR install -y selinux-policy selinux-policy-targeted policycoreutils policycoreutils-python-utils audit || {
    HARDN_STATUS "warning" "Failed to install SELinux packages."
    return 0 2>/dev/null || hardn_module_exit 0
}

# --------- Config File Setup ---------
CONFIG_FILE=""
[ -f /etc/selinux/config ] && CONFIG_FILE="/etc/selinux/config"
[ -f /etc/selinux/selinux.conf ] && CONFIG_FILE="/etc/selinux/selinux.conf"

if [[ -n "$CONFIG_FILE" ]]; then
    sed -i 's/^SELINUX=.*/SELINUX='"$([[ "$CHOICE" == "advanced" ]] && echo "enforcing" || echo "permissive")"'/' "$CONFIG_FILE"
    sed -i 's/^SELINUXTYPE=.*/SELINUXTYPE=targeted/' "$CONFIG_FILE"
    HARDN_STATUS "info" "SELinux mode set to ${CHOICE^^}, policy set to targeted."
else
    HARDN_STATUS "warning" "SELinux config file not found."
fi

# --------- Auto Relabel If Enforcing + RHEL-based ---------
if [[ "$CHOICE" == "advanced" ]]; then
    if command -v fixfiles >/dev/null 2>&1; then
        HARDN_STATUS "info" "Scheduling full filesystem relabel on next boot..."
        touch /.autorelabel
        fixfiles onboot || HARDN_STATUS "warning" "fixfiles onboot failed or not supported."
        HARDN_STATUS "info" "A reboot is required to complete SELinux enforcement."
    fi
fi

# --------- Final Stat Check ---------
if [ -d /sys/fs/selinux ]; then
    MODE=$(getenforce 2>/dev/null || echo "Unknown")
    HARDN_STATUS "pass" "SELinux present: Mode = $MODE"
else
    HARDN_STATUS "warning" "SELinux is not currently active."
fi

return 0 2>/dev/null || hardn_module_exit 0
set -e
