#!/bin/bash

# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh
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
# Safe return
return 0 2>/dev/null || exit 0
