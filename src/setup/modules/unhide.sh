#!/bin/bash

# shellcheck disable=SC1091
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "[*] Updating package index..."
sudo apt update

HARDN_STATUS "[*] Installing unhide..."
sudo apt install -y unhide

HARDN_STATUS "[*] Verifying installation..."
if command -v unhide >/dev/null 2>&1; then
    HARDN_STATUS "[+] Unhide installed successfully: $(unhide -v 2>&1 | head -n1)"
else
    HARDN_STATUS "[!] Failed to install unhide." >&2
    return 1
fi

HARDN_STATUS "[*] Usage example:"
HARDN_STATUS "    sudo unhide proc"
HARDN_STATUS "    sudo unhide sys"

# shellcheck disable=SC2317
return 0 2>/dev/null || hardn_module_exit 0
