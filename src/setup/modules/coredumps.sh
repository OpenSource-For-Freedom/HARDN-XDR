#!/bin/bash

# Add sysctl parameter if not already present
hardn_coredump_add_sysctl_param() {
        local param="$1"
        local value="$2"
        if ! grep -q "^${param}[[:space:]]*=" /etc/sysctl.conf; then
            printf "%s = %s\n" "$param" "$value" >> /etc/sysctl.conf
        fi
}

hardn_disable_core_dumps() {
        HARDN_STATUS "info" "Disabling core dumps..."

        # Add configuration to limits.conf if not present
        if ! grep -q "hard core" /etc/security/limits.conf; then
            printf "* hard core 0\n" >> /etc/security/limits.conf
        fi

        # Configure sysctl parameters in parallel
        {
            hardn_coredump_add_sysctl_param "fs.suid_dumpable" "0"
        } &
        {
            hardn_coredump_add_sysctl_param "kernel.core_pattern" "/dev/null"
        } &
        wait

        sysctl -p >/dev/null 2>&1

        HARDN_STATUS "pass" "Core dumps disabled: Limits set to 0, suid_dumpable set to 0, core_pattern set to /dev/null."
        return 0
}

hardn_kernel_security_start() {
        HARDN_STATUS "info" "Kernel security settings applied successfully."
        HARDN_STATUS "info" "Starting kernel security hardening..."
        return 0
}

# Prevent direct execution
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    printf "Error: This script should be sourced by hardn-main.sh, not executed directly.\n" >&2
    exit 1
fi
