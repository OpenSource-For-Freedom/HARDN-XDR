#!/bin/bash

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
# for arch status first , arm64 wont support this package 
ARCH=$(uname -m)
HARDN_STATUS "info" "Detected architecture: $ARCH"

if [[ "$ARCH" == "aarch64" || "$ARCH" == "arm64" ]]; then
    HARDN_STATUS "warning" "rkhunter may not be fully supported or available on $ARCH. Attempting fallback install..."
fi

HARDN_STATUS "info" "Installing rkhunter prerequisites..."
apt-get update
apt-get install -y curl file gnupg2 net-tools sudo bash binutils whiptail lsof findutils || {
    HARDN_STATUS "error" "Failed to install prerequisites"
    exit 1
}

HARDN_STATUS "info" "Configuring rkhunter..."

if ! is_installed rkhunter; then
    HARDN_STATUS "info" "rkhunter not found in system. Trying apt install..."
    apt-get install -y rkhunter || HARDN_STATUS "warning" "rkhunter not found in apt, trying GitHub fallback."
fi

if ! is_installed rkhunter; then
    if ! is_installed git; then
        HARDN_STATUS "info" "Installing git for GitHub fallback..."
        apt-get install -y git || {
            HARDN_STATUS "error" "Git install failed. Cannot proceed."
            exit 1
        }
    fi

    cd /tmp || exit 1
    git clone https://github.com/Rootkit-Hunter/rkhunter.git rkhunter_github_clone || {
        HARDN_STATUS "error" "Failed to clone rkhunter repo"
        exit 1
    }

    cd rkhunter_github_clone
    ./installer.sh --layout DEB >/dev/null 2>&1 && ./installer.sh --install >/dev/null 2>&1 || {
        HARDN_STATUS "error" "GitHub rkhunter installer failed"
        cd .. && rm -rf rkhunter_github_clone
        exit 1
    }

    cd .. && rm -rf rkhunter_github_clone
    HARDN_STATUS "pass" "rkhunter installed from GitHub."
else
    HARDN_STATUS "pass" "rkhunter installed via package manager."
fi


if ! command -v rkhunter >/dev/null 2>&1; then
    HARDN_STATUS "error" "rkhunter not found in path after install."
    exit 1
fi

test -e /etc/default/rkhunter || touch /etc/default/rkhunter
sed -i 's/#CRON_DAILY_RUN=""/CRON_DAILY_RUN="true"/' /etc/default/rkhunter 2>/dev/null || true

rkhunter --propupd >/dev/null 2>&1 || HARDN_STATUS "warning" "Failed: rkhunter --propupd"
rkhunter --version || {
    HARDN_STATUS "error" "rkhunter command failed post-install"
    exit 1
}

HARDN_STATUS "pass" "rkhunter installed and configured successfully on $ARCH."