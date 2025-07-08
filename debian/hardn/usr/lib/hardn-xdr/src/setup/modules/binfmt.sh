#!/bin/bash
disable_binfmt_misc() {
    HARDN_STATUS "error" "Checking/Disabling non-native binary format support (binfmt_misc)..."
    if mount | grep -q 'binfmt_misc'; then
        HARDN_STATUS "info" "binfmt_misc is mounted. Attempting to unmount..."
        if umount /proc/sys/fs/binfmt_misc; then
            HARDN_STATUS "pass" "binfmt_misc unmounted successfully."
        else
            HARDN_STATUS "error" "Failed to unmount binfmt_misc. It might be busy or not a separate mount."
        fi
    fi

    if lsmod | grep -q "^binfmt_misc"; then
        HARDN_STATUS "info" "binfmt_misc module is loaded. Attempting to unload..."
        if rmmod binfmt_misc; then
            HARDN_STATUS "pass" "binfmt_misc module unloaded successfully."
        else
            HARDN_STATUS "error" "Failed to unload binfmt_misc module. It might be in use or built-in."
        fi
    else
        HARDN_STATUS "pass" "binfmt_misc module is not currently loaded."
    fi

    # Prevent module from loading on boot
    local modprobe_conf="/etc/modprobe.d/disable-binfmt_misc.conf"

    if [[ ! -f "$modprobe_conf" ]]; then
        echo "install binfmt_misc /bin/true" > "$modprobe_conf"
        HARDN_STATUS "pass" "Added modprobe rule to prevent binfmt_misc from loading on boot: $modprobe_conf"

    else
        if ! grep -q "install binfmt_misc /bin/true" "$modprobe_conf"; then
            echo "install binfmt_misc /bin/true" >> "$modprobe_conf"
            HARDN_STATUS "pass" "Appended modprobe rule to prevent binfmt_misc from loading to $modprobe_conf"
        else
            HARDN_STATUS "info" "Modprobe rule to disable binfmt_misc already exists in $modprobe_conf."
        fi
    fi
    whiptail --infobox "Non-native binary format support (binfmt_misc) checked/disabled." 7 70
}
