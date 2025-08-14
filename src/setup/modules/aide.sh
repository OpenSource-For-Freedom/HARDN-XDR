#!/bin/bash
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
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
}
#!/bin/bash

# AIDE Module for HARDN-XDR
# Installs and configures a basic AIDE setup

set -e

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
    return 1
    fi
}

if ! is_installed aide; then
    HARDN_STATUS "info" "Installing and configuring AIDE (quick scan)..."

    if command -v apt >/dev/null 2>&1; then
        apt update -y || HARDN_STATUS "warning" "apt update failed, continuing anyway"
        apt install -y aide || {
            HARDN_STATUS "error" "Failed to install AIDE via apt"
            return 1
        }
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y aide || {
            HARDN_STATUS "error" "Failed to install AIDE via dnf"
            return 1
        }
    elif command -v yum >/dev/null 2>&1; then
        yum install -y aide || {
            HARDN_STATUS "error" "Failed to install AIDE via yum"
            return 1
        }
    fi
fi

if [[ -f "/etc/aide/aide.conf" ]]; then
    cp /etc/aide/aide.conf /etc/aide/aide.conf.bak

    cat > /etc/aide/aide.conf <<EOF
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
gzip_dbout=no

/etc       NORMAL
/bin       NORMAL
/usr/bin   NORMAL
EOF

    aideinit || true
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db || true

    if ! grep -q '/usr/bin/aide --check' /etc/crontab; then
        echo "0 5 * * * root /usr/bin/aide --check" >> /etc/crontab
    fi

    HARDN_STATUS "pass" "AIDE installed and configured for a quick scan (only /etc, /bin, /usr/bin)."
    HARDN_STATUS "info" "For a deeper scan, edit /etc/aide/aide.conf and add more directories."
else
    HARDN_STATUS "warning" "Skipping: /etc/aide/aide.conf not found after install"
fi


return 0 2>/dev/null || hardn_module_exit 0
