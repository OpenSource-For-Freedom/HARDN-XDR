#!/bin/bash
set -e

if dpkg -s openssh-client >/dev/null 2>&1; then
    echo "[openssh-client] Already installed."
else
    echo "[openssh-client] Installing..."
    apt-get update && apt-get install -y openssh-client
fi
