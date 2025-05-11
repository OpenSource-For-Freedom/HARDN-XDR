#!/bin/bash
set -e

if dpkg -s libvirt-clients >/dev/null 2>&1; then
    echo "[libvirt-clients] Already installed."
else
    echo "[libvirt-clients] Installing..."
    apt-get update && apt-get install -y libvirt-clients
fi
