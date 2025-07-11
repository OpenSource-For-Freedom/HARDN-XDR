#!/bin/bash
# HARDN-XDR - UFW Configuration Module
# Designed to be sourced by hardn-main.sh

# Check if package is installed
hardn_ufw_is_installed() {
        local package="$1"
        command -v "$package" >/dev/null 2>&1 && return 0

        case "$(command -v dpkg apt dnf yum rpm 2>/dev/null | head -1)" in
            */dpkg) dpkg -s "$package" >/dev/null 2>&1 ;;
            */apt)  apt list --installed "$package" 2>/dev/null | grep -q "^$package/" ;;
            */dnf)  dnf list installed "$package" >/dev/null 2>&1 ;;
            */yum)  yum list installed "$package" >/dev/null 2>&1 ;;
            */rpm)  rpm -q "$package" >/dev/null 2>&1 ;;
            *)      return 1 ;;
        esac
}

# Install UFW package
hardn_ufw_install() {
        hardn_ufw_is_installed ufw && return 0

        HARDN_STATUS "info" "Installing UFW package..."

        case "$(command -v apt-get dnf yum 2>/dev/null | head -1)" in
            */apt-get) apt-get update -qq && apt-get install -y ufw >/dev/null 2>&1 ;;
            */dnf)     dnf install -y ufw >/dev/null 2>&1 ;;
            */yum)     yum install -y ufw >/dev/null 2>&1 ;;
            *)         HARDN_STATUS "error" "Unsupported package manager"; return 1 ;;
        esac

        hardn_ufw_is_installed ufw || { HARDN_STATUS "error" "Failed to install UFW"; return 1; }
        HARDN_STATUS "pass" "UFW installed successfully"
        return 0
}

# Configure UFW with secure defaults
hardn_ufw_configure() {
        local status=0
        local default_rules="${1:-ssh}"

        # Reset UFW to default state
        ufw --force reset >/dev/null 2>&1 || status=1

        # Set default policies
        ufw default deny incoming >/dev/null 2>&1 || status=1
        ufw default allow outgoing >/dev/null 2>&1 || status=1

        # Allow specified services
        for rule in $default_rules; do
            case "$rule" in
                ssh|SSH)
                    ufw allow ssh comment "Allow SSH" >/dev/null 2>&1 || status=1
                    ;;
                http|HTTP)
                    ufw allow http comment "Allow HTTP" >/dev/null 2>&1 || status=1
                    ;;
                https|HTTPS)
                    ufw allow https comment "Allow HTTPS" >/dev/null 2>&1 || status=1
                    ;;
                *)
                    if [[ "$rule" =~ ^[0-9]+$ ]]; then
                        ufw allow "$rule/tcp" comment "Allow port $rule/tcp" >/dev/null 2>&1 || status=1
                    fi
                    ;;
            esac
        done

        # Enable UFW
        ufw --force enable >/dev/null 2>&1 || status=1

        # Verify UFW is active
        if ufw status | grep -q "Status: active"; then
            HARDN_STATUS "pass" "UFW enabled with secure defaults"
        else
            HARDN_STATUS "error" "Failed to enable UFW"
            status=1
        fi

        return $status
}

# Main UFW hardening function
hardn_ufw_setup() {
        local allowed_services="${1:-ssh}"
        local status=0

        HARDN_STATUS "info" "Setting up UFW firewall..."

        # Install UFW if needed
        hardn_ufw_install || return 1

        # Configure UFW
        hardn_ufw_configure "$allowed_services" || status=1

        # Report status
        if [ $status -eq 0 ]; then
            HARDN_STATUS "pass" "UFW firewall configured successfully"
        else
            HARDN_STATUS "error" "UFW firewall configuration had errors"
        fi

        return $status
}

# Log module load if debug is enabled
[ -n "${HARDN_DEBUG:-}" ] && HARDN_STATUS "debug" "UFW module loaded successfully"
