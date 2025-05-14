#!/bin/bash
# Calls the GRUB configuration script
if [ -f "$1" ]; then
    chmod +x "$1"
    "$1"
else
    echo "GRUB script not found at: $1"
    exit 1
fi