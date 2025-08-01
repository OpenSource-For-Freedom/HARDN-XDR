#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
# Remove set -e to handle errors gracefully in CI environment


# Whiptail confirmation and warning
if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
    whiptail --title "USB Storage Blocking" --msgbox "WARNING: This will block USB storage devices.\n\n- If your system is running from USB, this may cause lockout.\n- If you have a USB keyboard, ensure it is detected.\n\nProceed only if you understand the risks!" 14 70
    if ! whiptail --title "Confirm USB Block" --yesno "Do you want to proceed with blocking USB storage?" 10 70; then
        HARDN_STATUS "info" "User cancelled USB block operation."
        exit 0  # Changed from return 0 for consistency
    fi
else
    HARDN_STATUS "info" "Running in non-interactive mode, proceeding with USB storage blocking"
fi

ROOT_USB=$(lsblk -o NAME,TRAN,MOUNTPOINT | grep -E 'usb.*\/$' || true)

if [[ -n "$ROOT_USB" ]]; then
  HARDN_STATUS "warning" "System is running from USB storage. Skipping USB block to avoid system lockout."
  exit 0  # Changed from return 0 for consistency
fi

# Optional: Check if keyboard is present before blocking
KEYBOARD_OK=$(udevadm info -q property --export -n /dev/input/event* | grep ID_INPUT_KEYBOARD || true)
if [[ -z "$KEYBOARD_OK" ]]; then
  HARDN_STATUS "error" "No valid USB keyboard detected. Blocking USB now may cause login failure."
  return 1
fi

# Proceed with blocking
cat > /etc/modprobe.d/99-usb-storage.conf << 'EOF'
blacklist usb-storage
blacklist uas
EOF

HARDN_STATUS "info" "USB storage modules blacklisted."

cat > /etc/udev/rules.d/99-usb-storage.rules << 'EOF'
# Add valid udev rules here if needed
EOF

HARDN_STATUS "info" "Udev rules written."

udevadm control --reload-rules && udevadm trigger && HARDN_STATUS "pass" "Udev rules reloaded."

# Try unloading storage
if lsmod | grep -q usb_storage; then
  rmmod usb_storage && HARDN_STATUS "pass" "usb-storage module unloaded." || HARDN_STATUS "warning" "Failed to unload usb-storage."
else
  HARDN_STATUS "info" "usb-storage module not currently loaded."
fi

# Ensure HID is enabled
if ! lsmod | grep -q usbhid; then
  modprobe usbhid && HARDN_STATUS "pass" "usbhid module loaded." || HARDN_STATUS "warning" "Could not load usbhid (may be normal in CI environment)!"
else
  HARDN_STATUS "pass" "usbhid module already active."
fi

HARDN_STATUS "pass" "USB policy: storage blocked, HID enabled."
# Safe return
exit 0