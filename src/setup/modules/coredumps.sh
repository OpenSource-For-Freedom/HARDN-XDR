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

HARDN_STATUS "info" "Disabling core dumps..."
if ! grep -q "hard core" /etc/security/limits.conf; then
	echo "* hard core 0" >> /etc/security/limits.conf
fi
if ! grep -q "fs.suid_dumpable" /etc/sysctl.conf; then
	echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
fi
if ! grep -q "kernel.core_pattern" /etc/sysctl.conf; then
	echo "kernel.core_pattern = /dev/null" >> /etc/sysctl.conf
fi
sysctl -p >/dev/null 2>&1
HARDN_STATUS "pass" "Core dumps disabled: Limits set to 0, suid_dumpable set to 0, core_pattern set to /dev/null."
HARDN_STATUS "info" "Kernel security settings applied successfully."
HARDN_STATUS "info" "Starting kernel security hardening..."
