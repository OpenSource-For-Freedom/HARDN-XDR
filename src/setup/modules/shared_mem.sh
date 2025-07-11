#!/bin/bash
# Shared memory security module for HARDN-XDR
# This script is designed to be sourced by hardn-main.sh

hardn_secure_shared_memory() {
    local fstab_entry="tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0"
    local status=0
    local action=""

    HARDN_STATUS "info" "Securing shared memory..."

    # Determine the action needed using built-ins instead of grep
    action="needs_securing"
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" == *"tmpfs /run/shm"* ]]; then
            action="already_secured"
            break
        fi
    done < /etc/fstab

    # Take appropriate action based on state
    case "$action" in
        needs_securing)
            # Try to update fstab
            if echo "$fstab_entry" >> /etc/fstab; then
                HARDN_STATUS "pass" "Added shared memory restrictions to fstab"

                # Try to apply mount options immediately
                : "$(mount -o remount,noexec,nosuid,nodev /run/shm 2>/dev/null)"
                case "$?" in
                    0) HARDN_STATUS "pass" "Applied mount options to current session" ;;
                    *) HARDN_STATUS "info" "Mount options will apply after reboot" ;;
                esac
            else
                HARDN_STATUS "warning" "Failed to update fstab for shared memory"
                status=1
            fi
            ;;
        already_secured)
            HARDN_STATUS "info" "Shared memory already secured in fstab"
            ;;
    esac

    return $status
}
