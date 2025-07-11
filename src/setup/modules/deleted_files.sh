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

HARDN_STATUS "info" "Checking for deleted files in use..."
if command -v lsof >/dev/null 2>&1; then
deleted_files=$(lsof +L1 | awk '{print $9}' | grep -v '^$')
if [[ -n "$deleted_files" ]]; then
    HARDN_STATUS "warning" "Found deleted files in use:"
    echo "$deleted_files"
    HARDN_STATUS "warning" "Please consider rebooting the system to release these files."
else
    HARDN_STATUS "pass" "No deleted files in use found."
fi
else
HARDN_STATUS "error" "lsof command not found. Cannot check for deleted files in use."
fi

