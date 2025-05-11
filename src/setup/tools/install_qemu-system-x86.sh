#!/bin/bash
set -e

if dpkg -s qemu-system-x86 >/dev/null 2>&1; then
    echo "[qemu-system-x86] Already installed."
else
    echo "[qemu-system-x86] Installing..."
    apt-get update && apt-get install -y qemu-system-x86
fi
