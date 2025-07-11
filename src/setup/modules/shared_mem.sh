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

HARDN_STATUS "info" "Securing shared memory..."
if ! grep -q "tmpfs /run/shm" /etc/fstab; then
	echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
	HARDN_STATUS "pass" "Shared memory security configured in /etc/fstab"
else
	HARDN_STATUS "info" "Shared memory security already configured"
fi

HARDN_STATUS "pass" "Shared memory hardening completed"
