#!/bin/bash

# Module for installing and configuring rkhunter
# This script is designed to be sourced by hardn-main.sh

hardn_rkhunter_is_installed() {
        local pkg="$1"
        local _=1
        local cmd=""

        # Check for package managers without subshell
        command -v apt >/dev/null 2>&1 && cmd="apt"
        [ -z "$cmd" ] && command -v dnf >/dev/null 2>&1 && cmd="dnf"
        [ -z "$cmd" ] && command -v yum >/dev/null 2>&1 && cmd="yum"
        [ -z "$cmd" ] && command -v rpm >/dev/null 2>&1 && cmd="rpm"

        case "$cmd" in
            apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
            dnf) dnf list installed "$pkg" >/dev/null 2>&1 ;;
            yum) yum list installed "$pkg" >/dev/null 2>&1 ;;
            rpm) rpm -q "$pkg" >/dev/null 2>&1 ;;
            *) : ;;
        esac

        _=$?
        return $_
}

hardn_rkhunter_install_prerequisites() {
        local prerequisites="curl file gnupg2 net-tools sudo bash binutils whiptail lsof findutils"
        local failed_pkgs=""
        local temp_file

        HARDN_STATUS "info" "Installing rkhunter prerequisites..."
        apt-get update

        # Install prerequisites in parallel if possible
        if command -v xargs >/dev/null 2>&1; then
            # Create temporary file for storing failed packages
            temp_file=$(mktemp)

            # USE SINGLE QUOTES FOR THE BASH COMMAND - $1 AND $2
            # THEY ARE INTERPRETED BY THE BASH PROCESS, NOT THE PARENT SHELL
            # SHELLCHECK DISABLE=SC2016
            printf "%s\n" $prerequisites | xargs -P "$(nproc)" -I{} bash -c '
                apt-get install -y "$1" >/dev/null 2>&1 || echo "$1" >> "$2"
            ' _ {} "$temp_file"

            # Read failed packages from temp file
            if [ -s "$temp_file" ]; then
                failed_pkgs=$(tr '\n' ' ' < "$temp_file")
            fi

            # Clean up temp file
            rm -f "$temp_file"
        else
            # Fallback to sequential installation
            for pkg in $prerequisites; do
                apt-get install -y "$pkg" >/dev/null 2>&1 || failed_pkgs+="$pkg "
            done
        fi

        # Check if any packages failed to install
        if [[ -n "$failed_pkgs" ]]; then
            HARDN_STATUS "error" "Failed to install prerequisites: $failed_pkgs"
            return 1
        fi

        return 0
}

hardn_rkhunter_install_from_apt() {
        HARDN_STATUS "info" "rkhunter not found in system. Trying apt install..."
        apt-get install -y rkhunter >/dev/null 2>&1
        return $?
}

hardn_rkhunter_install_from_github() {
        local temp_dir
        local ret=0

        if ! hardn_rkhunter_is_installed git; then
            HARDN_STATUS "info" "Installing git for GitHub fallback..."
            apt-get install -y git >/dev/null 2>&1 || return 1
        fi

        # Create temporary directory
        temp_dir=$(mktemp -d)

        if ! git clone https://github.com/Rootkit-Hunter/rkhunter.git "$temp_dir" >/dev/null 2>&1; then
            HARDN_STATUS "error" "Failed to clone rkhunter repo"
            rm -rf "$temp_dir"
            return 1
        fi

        # Install from source
        (
            cd "$temp_dir" || return 1
            ./installer.sh --layout DEB >/dev/null 2>&1 &&
            ./installer.sh --install >/dev/null 2>&1
        )
        ret=$?

        # Clean up
        rm -rf "$temp_dir"

        if [[ $ret -eq 0 ]]; then
            HARDN_STATUS "pass" "rkhunter installed from GitHub."
        else
            HARDN_STATUS "error" "GitHub rkhunter installer failed"
            return 1
        fi

        return 0
}

hardn_rkhunter_configure() {
        [ -e /etc/default/rkhunter ] || touch /etc/default/rkhunter

        sed -i 's/#CRON_DAILY_RUN=""/CRON_DAILY_RUN="true"/' /etc/default/rkhunter 2>/dev/null || true

        rkhunter --propupd >/dev/null 2>&1 || {
            HARDN_STATUS "warning" "Failed: rkhunter --propupd"
            return 1
        }

        if ! rkhunter --version >/dev/null 2>&1; then
            HARDN_STATUS "error" "rkhunter command failed post-install"
            return 1
        fi

        return 0
}

hardn_rkhunter_setup() {
        local arch
        arch=$(uname -m)

        HARDN_STATUS "info" "Detected architecture: $arch"

        # Check architecture compatibility
        if [[ "$arch" == "aarch64" || "$arch" == "arm64" ]]; then
            HARDN_STATUS "warning" "rkhunter may not be fully supported or available on $arch. Attempting fallback install..."
        fi

        # Install prerequisites
        hardn_rkhunter_install_prerequisites || return 1

        HARDN_STATUS "info" "Configuring rkhunter..."

        # Try to install rkhunter
        if ! hardn_rkhunter_is_installed rkhunter; then
            hardn_rkhunter_install_from_apt ||
            HARDN_STATUS "warning" "rkhunter not found in apt, trying GitHub fallback."
        fi

        # Try GitHub fallback if needed
        if ! hardn_rkhunter_is_installed rkhunter; then
            hardn_rkhunter_install_from_github || return 1
        else
            HARDN_STATUS "pass" "rkhunter installed via package manager."
        fi

        # Verify installation
        if ! command -v rkhunter >/dev/null 2>&1; then
            HARDN_STATUS "error" "rkhunter not found in path after install."
            return 1
        fi

        # Configure rkhunter
        hardn_rkhunter_configure || return 1

        HARDN_STATUS "pass" "rkhunter installed and configured successfully on $arch."
        return 0
}

hardn_rkhunter_main() {
        hardn_rkhunter_setup
        return $?
}
