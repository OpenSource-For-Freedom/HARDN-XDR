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

# Check for container environment
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - UFW firewall may not be functional"
    HARDN_STATUS "info" "In containers, network policies are typically managed by the container runtime"
    HARDN_STATUS "pass" "UFW configuration skipped (container environment)"
    return 0 2>/dev/null || hardn_module_exit 0
fi

# Install UFW if missing
if ! command -v ufw &> /dev/null; then
    apt-get update
    apt-get install -y ufw
fi

# Use basic mode by default for automated deployment
mode="basic"
HARDN_STATUS "info" "UFW configured for basic firewall setup (automated mode)"

# Reset UFW for a clean state
ufw --force reset

if [[ "$mode" == "basic" ]]; then
    ufw default deny incoming
    ufw default allow outgoing
    ufw --force enable
    HARDN_STATUS "pass" "UFW basic firewall enabled: deny incoming, allow outgoing."
    ufw status verbose
    exit 0
fi

# Advanced mode
# Use server profile by default for automated deployment
profile="server"
HARDN_STATUS "info" "UFW configured for server profile (automated mode)"

ufw default deny incoming
ufw default allow outgoing

# Default rules for automated deployment: SSH only for security
rules="ssh"
HARDN_STATUS "info" "UFW configured to allow SSH only (secure default for automated deployment)"

rules=$(echo "$rules" | tr -d '"')

# Apply rules
[[ "$rules" == *"ssh"* ]] && ufw allow ssh
[[ "$rules" == *"http"* ]] && ufw allow http
[[ "$rules" == *"https"* ]] && ufw allow https

# Skip custom ports for automated deployment (can be added manually later if needed)
HARDN_STATUS "info" "Custom ports skipped for automated deployment (can be configured manually later)"

# Enable and show status
ufw --force enable
ufw status verbose
HARDN_STATUS "pass" "UFW firewall enabled with SSH access (secure default)."

HARDN_STATUS "pass" "UFW module completed successfully"
return 0 2>/dev/null || exit 0
