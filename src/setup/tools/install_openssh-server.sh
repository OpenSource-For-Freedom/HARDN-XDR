#!/bin/bash
set -e

if dpkg -s openssh-server >/dev/null 2>&1; then
    echo "[openssh-server] Already installed."
else
    echo "[openssh-server] Installing..."
    apt-get update && apt-get install -y openssh-server
fi
