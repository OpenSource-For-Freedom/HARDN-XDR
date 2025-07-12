#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Setting secure file permissions..."
chmod 700 /root                    # root home directory - root
chmod 644 /etc/passwd              # user database - readable (required)
chmod 600 /etc/shadow              # password hashes - root only
chmod 644 /etc/group               # group database - readable
chmod 600 /etc/gshadow             # group passwords - root

# Set permissions for sshd_config only if it exists
if [ -f /etc/ssh/sshd_config ]; then
    chmod 644 /etc/ssh/sshd_config     # SSH daemon config - readable
    HARDN_STATUS "pass" "SSH configuration file permissions updated"
else
    HARDN_STATUS "warning" "SSH configuration file not found, skipping"
fi

HARDN_STATUS "pass" "File permissions hardening completed successfully."
