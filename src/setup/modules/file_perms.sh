#!/bin/bash

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

HARDN_STATUS "info" "Setting secure file permissions..."
chmod 700 /root                    # root home directory - root
chmod 644 /etc/passwd              # user database - readable (required)
chmod 600 /etc/shadow              # password hashes - root only
chmod 644 /etc/group               # group database - readable
chmod 600 /etc/gshadow             # group passwords - root

# Set permissions for sshd_config only if it exists
if [ -f /etc/ssh/sshd_config ]; then
    chmod 644 /etc/ssh/sshd_config     # SSH daemon config - readable
    HARDN_STATUS "pass" "SSH configuration file permissions updated"
else
    HARDN_STATUS "warning" "SSH configuration file not found, skipping"
fi

HARDN_STATUS "pass" "File permissions hardening completed successfully."
