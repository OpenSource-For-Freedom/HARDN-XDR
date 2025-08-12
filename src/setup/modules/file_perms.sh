#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# Check for container environment
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - file permission modifications may be restricted"
    HARDN_STATUS "info" "Some filesystems in containers may be read-only or have permission restrictions"
fi

HARDN_STATUS "info" "Setting secure file permissions..."

# Function to safely change permissions
safe_chmod() {
    local perm="$1"
    local file="$2"
    local description="$3"
    
    if [[ -e "$file" ]]; then
        if chmod "$perm" "$file" 2>/dev/null; then
            HARDN_STATUS "pass" "Set permissions $perm on $file ($description)"
        else
            HARDN_STATUS "warning" "Failed to set permissions on $file ($description) - may be read-only"
        fi
    else
        HARDN_STATUS "warning" "File $file not found, skipping permission change"
    fi
}

safe_chmod 700 /root "root home directory"
safe_chmod 644 /etc/passwd "user database"
safe_chmod 600 /etc/shadow "password hashes"
safe_chmod 644 /etc/group "group database"
safe_chmod 600 /etc/gshadow "group passwords"

# Set permissions for sshd_config only if it exists
if [ -f /etc/ssh/sshd_config ]; then
    safe_chmod 644 /etc/ssh/sshd_config "SSH daemon config"
else
    HARDN_STATUS "warning" "SSH configuration file not found, skipping"
fi

HARDN_STATUS "pass" "File permissions hardening completed."

return 0 2>/dev/null || hardn_module_exit 0
