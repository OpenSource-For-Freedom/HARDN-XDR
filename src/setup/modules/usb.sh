#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

ROOT_USB=$(lsblk -o NAME,TRAN,MOUNTPOINT | grep -E 'usb.*\/$' || true)

if [[ -n "$ROOT_USB" ]]; then
  HARDN_STATUS "warning" "System is running from USB storage. Skipping USB block to avoid system lockout."
  exit 0
fi

# Optional: Check if keyboard is present before blocking
KEYBOARD_OK=$(udevadm info -q property --export -n /dev/input/event* | grep ID_INPUT_KEYBOARD || true)
if [[ -z "$KEYBOARD_OK" ]]; then
  HARDN_STATUS "error" "No valid USB keyboard detected. Blocking USB now may cause login failure."
  exit 1
fi

# Proceed with blocking
cat > /etc/modprobe.d/99-usb-storage.conf << 'EOF'
blacklist usb-storage
blacklist uas
EOF

HARDN_STATUS "info" "USB storage modules blacklisted."

cat > /etc/udev/rules.d/99-usb-storage.rules << 'EOF'
ACTION=="add", SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}=="08", RUN+="/bin/sh -c 'echo 0 > /sys$DEVPATH/authorized'"
EOF

HARDN_STATUS "info" "Udev rules written."

udevadm control --reload-rules && udevadm trigger && HARDN_STATUS "pass" "Udev rules reloaded."

# Try unloading storage
if lsmod | grep -q "usb_storage"; then
  rmmod usb_storage && HARDN_STATUS "pass" "usb-storage module unloaded." || HARDN_STATUS "warning" "Failed to unload usb-storage."
else
  HARDN_STATUS "info" "usb-storage module not currently loaded."
fi

# Ensure HID is enabled
if ! lsmod | grep -q "usbhid"; then
  modprobe usbhid && HARDN_STATUS "pass" "usbhid module loaded." || HARDN_STATUS "error" "Could not load usbhid!"
else
  HARDN_STATUS "pass" "usbhid module already active."
fi

HARDN_STATUS "pass" "USB policy: storage blocked, HID enabled."