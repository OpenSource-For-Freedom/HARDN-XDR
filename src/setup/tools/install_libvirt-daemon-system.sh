#!/bin/bash
set -e

if dpkg -s libvirt-daemon-system >/dev/null 2>&1; then
    echo "[libvirt-daemon-system] Already installed."
else
    echo "[libvirt-daemon-system] Installing..."
    apt-get update && apt-get install -y libvirt-daemon-system
fi
