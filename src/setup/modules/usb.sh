#!/bin/bash
# HARDN-XDR - USB Security Module
# Designed to be sourced by hardn-main.sh

# Configure USB storage blocking via modprobe
hardn_usb_configure_modprobe() {
    cat > /etc/modprobe.d/99-usb-storage.conf << 'EOF'
blacklist usb-storage
blacklist uas          # Block USB Attached SCSI (another storage protocol)
EOF
    HARDN_STATUS "info" "USB security policy configured to block storage devices"
}

# Configure USB device control via udev rules
hardn_usb_configure_udev() {
    cat > /etc/udev/rules.d/99-usb-storage.rules << 'EOF'
# Block USB storage devices while allowing keyboards and mice
ACTION=="add", SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}=="08", RUN+="/bin/sh -c 'echo 0 > /sys$DEVPATH/authorized'"
# Interface class 08 is for mass storage
# Interface class 03 is for HID devices (keyboards, mice) - these remain allowed
EOF
    HARDN_STATUS "info" "Additional udev rules created for USB device control"

    # Reload rules
    if udevadm control --reload-rules && udevadm trigger; then
        HARDN_STATUS "pass" "Udev rules reloaded successfully"
    else
        HARDN_STATUS "error" "Failed to reload udev rules"
    fi
}

hardn_usb_manage_storage_module() {
        local module_status

        # Check if module is loaded
        if lsmod | grep -q "usb_storage"; then
            : "loaded"
        else
            : "not_loaded"
        fi
        module_status=$_

        case "$module_status" in
            loaded)
                HARDN_STATUS "info" "usb-storage module is loaded, attempting to unload..."
                if rmmod usb_storage >/dev/null 2>&1; then
                    HARDN_STATUS "pass" "Successfully unloaded usb-storage module"
                else
                    HARDN_STATUS "error" "Failed to unload usb-storage module (may be in use)"
                fi
                ;;
            not_loaded)
                HARDN_STATUS "pass" "usb-storage module is not loaded"
                ;;
        esac
}

hardn_usb_ensure_hid() {
        local hid_status
        local module_found=0

        # Use read to process lsmod output line by line without subshell
        while read -r module _ _; do
            # Skip header line
            [[ $module == "Module" ]] && continue

            # Check if this is the module we're looking for
            if [[ $module == "usbhid" ]]; then
                module_found=1
                break
            fi
        done < <(lsmod)

        # Set status based on whether module was found
        if ((module_found)); then
            : "loaded"
        else
            : "not_loaded"
        fi
        hid_status=$_

        case "$hid_status" in
            loaded)
                HARDN_STATUS "pass" "USB HID module is loaded - keyboards and mice will work"
                ;;
            not_loaded)
                HARDN_STATUS "warning" "USB HID module not loaded - attempting to load it..."
                if modprobe usbhid; then
                    HARDN_STATUS "pass" "Successfully loaded USB HID module"
                else
                    HARDN_STATUS "error" "Failed to load USB HID module"
                fi
                ;;
        esac
}

hardn_usb_secure() {
        local status=0

        # Run configuration steps
        hardn_usb_configure_modprobe || status=1
        hardn_usb_configure_udev || status=1
        hardn_usb_manage_storage_module || status=1
        hardn_usb_ensure_hid || status=1

        HARDN_STATUS "pass" "USB configuration complete: keyboards and mice allowed, storage blocked"
        return $status
}

# Log module load if debug is enabled
[ -n "${HARDN_DEBUG:-}" ] && HARDN_STATUS "debug" "USB security module loaded successfully"
