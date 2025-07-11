#!/bin/bash

# FireWire security module for HARDN-XDR
# This script disables and blacklists FireWire modules for security

# Unload a single FireWire module if loaded
hardn_firewire_unload_module() {
        local module_name="$1"

        if ! grep -q "^${module_name}" /proc/modules; then
            HARDN_STATUS "info" "FireWire module ${module_name} is not currently loaded."
            return 0  # No change (0=false)
        fi

        HARDN_STATUS "info" "FireWire module ${module_name} is loaded. Attempting to unload..."

        if rmmod "$module_name" 2>/dev/null; then
            HARDN_STATUS "pass" "FireWire module ${module_name} unloaded successfully."
            return 1  # Changed (1=true)
        fi

        HARDN_STATUS "error" "Failed to unload FireWire module ${module_name}. It might be in use or built-in."
        return 0  # No change (0=false)
}

# Blacklist a single FireWire module
hardn_firewire_blacklist_module() {
        local module_name="$1"
        local blacklist_file="$2"

        [[ -f "$blacklist_file" ]] || {
            touch "$blacklist_file" &&
            HARDN_STATUS "pass" "Created FireWire blacklist file: ${blacklist_file}"
        }

        # Add module to blacklist if not already present
        if ! grep -q "^blacklist ${module_name}$" "$blacklist_file"; then
            printf "blacklist %s\n" "$module_name" >> "$blacklist_file"
            HARDN_STATUS "pass" "Blacklisted FireWire module ${module_name} in ${blacklist_file}"
            return 1  # Changed (1=true)
        else
            HARDN_STATUS "info" "FireWire module ${module_name} already blacklisted in ${blacklist_file}."
        fi

        return 0  # No change (0=false)
}

hardn_firewire_process_modules() {
        local action="$1"
        local modules="$2"
        local blacklist_file="$3"
        local changed=0
        local pids=()

        # Process each module in parallel
        for module in $modules; do
            case "$action" in
                unload)
                    hardn_firewire_unload_module "$module" &
                    pids+=($!)
                    ;;
                blacklist)
                    hardn_firewire_blacklist_module "$module" "$blacklist_file" &
                    pids+=($!)
                    ;;
            esac
        done

        # Wait for all processes and collect results
        for pid in "${pids[@]}"; do
            wait "$pid"
            [[ $? -eq 1 ]] && changed=1
        done

        return $changed
}

hardn_firewire_disable() {
        HARDN_STATUS "info" "Checking/Disabling FireWire (IEEE 1394) drivers..."
        local firewire_modules="firewire_core firewire_ohci firewire_sbp2"
        local blacklist_file="/etc/modprobe.d/blacklist-firewire.conf"
        local changed=0
        local result=0

        # Process modules in parallel for both unloading and blacklisting
        hardn_firewire_process_modules "unload" "$firewire_modules" ""
        result=$?
        [[ $result -eq 1 ]] && changed=1

        hardn_firewire_process_modules "blacklist" "$firewire_modules" "$blacklist_file"
        result=$?
        [[ $result -eq 1 ]] && changed=1

        # Show result using whiptail
        if [[ $changed -eq 1 ]]; then
            whiptail --infobox "FireWire drivers checked. Unloaded and/or blacklisted where applicable." 7 70
        else
            whiptail --infobox "FireWire drivers checked. No changes made (likely already disabled/not present)." 8 70
        fi

        return 0
}

# Prevent direct execution
[[ "${BASH_SOURCE[0]}" == "$0" ]] && {
    printf "Error: This script should be sourced by hardn-main.sh, not executed directly.\n" >&2
    exit 1
}

