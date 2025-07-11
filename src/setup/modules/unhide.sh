#!/bin/bash

set -e

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

HARDN_STATUS "[*] Updating package index..."
sudo apt update

HARDN_STATUS "[*] Installing unhide..."
sudo apt install -y unhide

HARDN_STATUS "[*] Verifying installation..."
if command -v unhide >/dev/null 2>&1; then
    HARDN_STATUS "[+] Unhide installed successfully: $(unhide -v 2>&1 | head -n1)"
else
    HARDN_STATUS "[!] Failed to install unhide." >&2
    exit 1
fi

HARDN_STATUS "[*] Usage example:"
HARDN_STATUS "    sudo unhide proc"
HARDN_STATUS "    sudo unhide sys"
