#!/bin/bash

# shellcheck disable=SC1091
# Source common functions - try both installed path and relative path
if [[ -f "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" ]]; then
    source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
elif [[ -f "../hardn-common.sh" ]]; then
    source ../hardn-common.sh
elif [[ -f "src/setup/hardn-common.sh" ]]; then
    source src/setup/hardn-common.sh
else
    echo "Error: Cannot find hardn-common.sh"
    exit 1
fi
set -e

# Install UFW if missing
if ! command -v ufw &> /dev/null; then
    apt-get update
    apt-get install -y ufw
fi

# Whiptail mode select
mode="basic"
if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
    if ! mode=$(whiptail --title "UFW Setup Mode" --radiolist "Choose firewall setup mode:" 12 90 2 \
        "basic" "Default deny incoming, allow outgoing, enable UFW" ON \
        "advanced" "Custom rules for server/container" OFF 3>&1 1>&2 2>&3); then
        HARDN_STATUS "info" "User cancelled UFW setup."
        return 1
    fi
else
    HARDN_STATUS "info" "Running in non-interactive mode, using basic UFW setup"
fi

# Reset UFW for a clean state
ufw --force reset

if [[ "$mode" == "basic" ]]; then
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    HARDN_STATUS "pass" "UFW basic firewall enabled: deny incoming, allow outgoing."
    ufw status verbose
    return 0
fi

# Advanced mode
if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
    if ! profile=$(whiptail --title "UFW Profile" --radiolist "Choose profile:" 10 70 3 \
        "desktop" "Allow common desktop ports (SSH, Web, Email)" ON \
        "server" "Allow server ports (SSH, HTTP, HTTPS)" OFF \
        "minimal" "Only SSH" OFF 3>&1 1>&2 2>&3); then
        HARDN_STATUS "info" "User cancelled profile selection."
        return 1
    fi
else
    profile="server"
    HARDN_STATUS "info" "Running in non-interactive mode, using server profile"
fi

ufw default deny incoming
ufw default allow outgoing

rules=""
if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
    if [[ "$profile" == "server" ]]; then
        if ! rules=$(whiptail --title "Server Firewall Rules" --checklist "Select services to allow:" 14 90 6 \
            "ssh" "SSH (port 22)" ON \
            "http" "HTTP (port 80)" OFF \
            "https" "HTTPS (port 443)" OFF \
            "custom" "Custom port(s)" OFF 3>&1 1>&2 2>&3); then
            HARDN_STATUS "info" "User cancelled rule selection."
            return 1
        fi
    elif [[ "$profile" == "container" ]]; then
        if ! rules=$(whiptail --title "Container Firewall Rules" --checklist "Select services to allow:" 12 90 4 \
            "ssh" "SSH (port 22)" OFF \
            "custom" "Custom port(s)" ON 3>&1 1>&2 2>&3); then
            HARDN_STATUS "info" "User cancelled rule selection."
            return 1
        fi
    fi
else
    # Default rules for non-interactive mode
    if [[ "$profile" == "server" ]]; then
        rules="ssh"
        HARDN_STATUS "info" "Running in non-interactive mode, allowing SSH for server profile"
    else
        rules=""
        HARDN_STATUS "info" "Running in non-interactive mode, no services allowed for container profile"
    fi
fi

rules=$(echo "$rules" | tr -d '"')

# Apply rules
[[ "$rules" == *"ssh"* ]] && ufw allow ssh
[[ "$rules" == *"http"* ]] && ufw allow http
[[ "$rules" == *"https"* ]] && ufw allow https

if [[ "$rules" == *"custom"* ]]; then
    if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
        custom_ports=$(whiptail --title "Custom Ports" --inputbox "Enter custom port(s) to allow (comma-separated, e.g. 8080,8443):" 10 90 3>&1 1>&2 2>&3)
        if [[ -n "$custom_ports" ]]; then
            IFS=',' read -ra ports <<< "$custom_ports"
            for port in "${ports[@]}"; do
                ufw allow "${port// /}"
            done
        fi
    else
        HARDN_STATUS "info" "Running in non-interactive mode, skipping custom ports"
    fi
fi

# Enable and show status
ufw --force enable
ufw status verbose
HARDN_STATUS "pass" "UFW advanced firewall enabled with selected rules."

HARDN_STATUS "pass" "UFW module completed successfully"
exit 0
