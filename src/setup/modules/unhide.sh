#!/usr/bin/env bash

set -e

echo "[*] Updating package index..."
sudo apt update

echo "[*] Installing unhide..."
sudo apt install -y unhide

echo "[*] Verifying installation..."
if command -v unhide >/dev/null 2>&1; then
    echo "[+] Unhide installed successfully: $(unhide -v 2>&1 | head -n1)"
else
    echo "[!] Failed to install unhide." >&2
    exit 1
fi

echo "[*] Usage example:"
echo "    sudo unhide proc"
echo "    sudo unhide sys"
