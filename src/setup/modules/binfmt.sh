#!/bin/bash
# HARDN-XDR - Binary Format Module
# Designed to be sourced by hardn-main.sh

hardn_binfmt_check_mount() {
        local mount_status

        if mount | grep -q 'binfmt_misc'; then
            : "mounted"
        else
            : "not_mounted"
        fi
        mount_status=$_

        case "$mount_status" in
            mounted)
                HARDN_STATUS "info" "binfmt_misc is mounted. Attempting to unmount..."
                if umount /proc/sys/fs/binfmt_misc; then
                    HARDN_STATUS "pass" "binfmt_misc unmounted successfully"
                else
                    HARDN_STATUS "error" "Failed to unmount binfmt_misc (might be busy or not a separate mount)"
                fi
                ;;
            not_mounted)
                # No action needed if not mounted
                ;;
        esac
}

hardn_binfmt_check_module() {
        local module_status

        if lsmod | grep -q "^binfmt_misc"; then
            : "loaded"
        else
            : "not_loaded"
        fi
        module_status=$_

        case "$module_status" in
            loaded)
                HARDN_STATUS "info" "binfmt_misc module is loaded. Attempting to unload..."
                if rmmod binfmt_misc; then
                    HARDN_STATUS "pass" "binfmt_misc module unloaded successfully"
                else
                    HARDN_STATUS "error" "Failed to unload binfmt_misc module (might be in use or built-in)"
                fi
                ;;
            not_loaded)
                HARDN_STATUS "pass" "binfmt_misc module is not currently loaded"
                ;;
        esac
}

hardn_binfmt_configure_modprobe() {
        local modprobe_conf="/etc/modprobe.d/disable-binfmt_misc.conf"
        local rule="install binfmt_misc /bin/true"
        local file_status

        if [[ ! -f "$modprobe_conf" ]]; then
            : "missing"
        elif ! grep -q "$rule" "$modprobe_conf"; then
            : "incomplete"
        else
            : "configured"
        fi
        file_status=$_

        case "$file_status" in
            missing)
                printf "%s\n" "$rule" > "$modprobe_conf"
                HARDN_STATUS "pass" "Added modprobe rule to prevent binfmt_misc from loading on boot"
                ;;
            incomplete)
                printf "%s\n" "$rule" >> "$modprobe_conf"
                HARDN_STATUS "pass" "Appended modprobe rule to prevent binfmt_misc from loading"
                ;;
            configured)
                HARDN_STATUS "info" "Modprobe rule to disable binfmt_misc already exists"
                ;;
        esac
}

hardn_disable_binfmt_misc() {
        HARDN_STATUS "info" "Checking/Disabling non-native binary format support (binfmt_misc)..."

        # run in sequence
        hardn_binfmt_check_mount
        hardn_binfmt_check_module
        hardn_binfmt_configure_modprobe

        command -v whiptail >/dev/null 2>&1 &&
            whiptail --infobox "Non-native binary format support (binfmt_misc) checked/disabled." 7 70

        return 0
}

[ -n "${HARDN_DEBUG:-}" ] && HARDN_STATUS "debug" "Binary format module loaded successfully"

