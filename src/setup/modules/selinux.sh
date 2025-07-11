#!/bin/bash

# Module for installing and configuring SELinux
# This script is designed to be sourced by hardn-main.sh

# Check if a package is installed
hardn_selinux_is_installed() {
        local pkg="$1"
        local cmd=""
       # local ret=1

        # Determine package manager without subshell
        command -v apt >/dev/null 2>&1 && cmd="apt"
        [ -z "$cmd" ] && command -v dnf >/dev/null 2>&1 && cmd="dnf"
        [ -z "$cmd" ] && command -v yum >/dev/null 2>&1 && cmd="yum"
        [ -z "$cmd" ] && command -v rpm >/dev/null 2>&1 && cmd="rpm"

        case "$cmd" in
            apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
            dnf) dnf list installed "$pkg" >/dev/null 2>&1 ;;
            yum) yum list installed "$pkg" >/dev/null 2>&1 ;;
            rpm) rpm -q "$pkg" >/dev/null 2>&1 ;;
            *) return 1 ;;
        esac

        return $?
}

# Install SELinux packages based on package manager
hardn_selinux_install_packages() {
        local cmd=""
        local status=0

        # Determine package manager without subshell
        command -v dnf >/dev/null 2>&1 && cmd="dnf"
        [ -z "$cmd" ] && command -v yum >/dev/null 2>&1 && cmd="yum"
        [ -z "$cmd" ] && command -v apt-get >/dev/null 2>&1 && cmd="apt"

        case "$cmd" in
            dnf)
                if ! hardn_selinux_is_installed selinux-policy; then
                    HARDN_STATUS "info" "Installing SELinux packages with dnf..."
                    dnf install -y selinux-policy selinux-policy-targeted policycoreutils policycoreutils-python-utils || {
                        HARDN_STATUS "error" "Failed to install SELinux packages with dnf."
                        status=1
                    }
                else
                    HARDN_STATUS "info" "SELinux packages already installed (dnf)."
                fi
                ;;
            yum)
                if ! hardn_selinux_is_installed selinux-policy; then
                    HARDN_STATUS "info" "Installing SELinux packages with yum..."
                    yum install -y selinux-policy selinux-policy-targeted policycoreutils policycoreutils-python || {
                        HARDN_STATUS "error" "Failed to install SELinux packages with yum."
                        status=1
                    }
                else
                    HARDN_STATUS "info" "SELinux packages already installed (yum)."
                fi
                ;;
            apt)
                if ! hardn_selinux_is_installed selinux-basics; then
                    HARDN_STATUS "info" "Updating apt and installing SELinux packages..."
                    if apt-get update && apt-get install -y selinux-basics selinux-policy-default auditd; then
                        HARDN_STATUS "pass" "Successfully installed SELinux packages with apt-get."
                    else
                        HARDN_STATUS "error" "Failed to install SELinux packages with apt-get."
                        status=1
                    fi
                else
                    HARDN_STATUS "info" "SELinux packages already installed (apt-get)."
                fi
                ;;
            *)
                HARDN_STATUS "error" "Unsupported package manager. Please install SELinux manually."
                status=1
                ;;
        esac

        return $status
}

# Configure SELinux to enforcing mode
hardn_selinux_configure() {
        local status=0
        local config_file=""

        # Find the correct config file
        if [ -f /etc/selinux/config ]; then
            config_file="/etc/selinux/config"
        elif [ -f /etc/selinux/selinux.conf ]; then
            config_file="/etc/selinux/selinux.conf"
        else
            HARDN_STATUS "warning" "SELinux configuration file not found."
            return 1
        fi

        # Set SELinux to enforcing mode
        HARDN_STATUS "info" "Setting SELINUX=enforcing in ${config_file}"
        sed -i 's/^SELINUX=.*/SELINUX=enforcing/' "$config_file" || {
            HARDN_STATUS "error" "Failed to set SELINUX=enforcing in ${config_file}"
            status=1
        }

        # For Debian/Ubuntu, initialize SELinux
        if command -v selinux-activate >/dev/null 2>&1; then
            HARDN_STATUS "info" "Running selinux-activate..."
            selinux-activate || {
                HARDN_STATUS "error" "Failed to run selinux-activate."
                status=1
            }
        fi

        return $status
}

# Main function to install and configure SELinux
hardn_selinux_setup() {
        local status=0

        # Install SELinux packages
        hardn_selinux_install_packages || status=1

        # Configure SELinux
        hardn_selinux_configure || status=1

        if [ $status -eq 0 ]; then
            HARDN_STATUS "pass" "SELinux installation and basic setup complete."
        else
            HARDN_STATUS "warning" "SELinux setup completed with warnings."
        fi

        HARDN_STATUS "info" "A reboot may be required for changes to take effect."
        return $status
}

# Main entry point when called from hardn-main.sh
hardn_selinux_main() {
        hardn_selinux_setup
        return $?
}
