#!/bin/bash
cat > /etc/modprobe.d/99-usb-storage.conf << 'EOF'
blacklist usb-storage
blacklist uas          # Block USB Attached SCSI (another storage protocol)

EOF
    
HARDN_STATUS "info" "USB security policy configured to allow HID devices but block storage."
    
# Create udev rules to further control USB devices 
cat > /etc/udev/rules.d/99-usb-storage.rules << 'EOF'
# Block USB storage devices while allowing keyboards and mice
ACTION=="add", SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}=="08", RUN+="/bin/sh -c 'echo 0 > /sys$DEVPATH/authorized'"
# Interface class 08 is for mass storage
# Interface class 03 is for HID devices (keyboards, mice) - these remain allowed
EOF

HARDN_STATUS "info" "Additional udev rules created for USB device control."
    
    # Reload rules
if udevadm control --reload-rules && udevadm trigger; then
	HARDN_STATUS "pass" "Udev rules reloaded successfully."
else
	HARDN_STATUS "error" "Failed to reload udev rules."
fi
    
    # Unload the usb-storage module 
if lsmod | grep -q "usb_storage"; then
	HARDN_STATUS "info" "usb-storage module is currently loaded, attempting to unload..."
	if rmmod usb_storage >/dev/null 2>&1; then
		HARDN_STATUS "pass" "Successfully unloaded usb-storage module."
	else
		HARDN_STATUS "error" "Failed to unload usb-storage module. It may be in use."
	fi
else
	HARDN_STATUS "pass" "usb-storage module is not loaded, no need to unload."
fi

# HID is enabled
if lsmod | grep -q "usbhid"; then
	HARDN_STATUS "pass" "USB HID module is loaded - keyboards and mice will work."
else
	HARDN_STATUS "warning" "USB HID module is not loaded - attempting to load it..."
	if modprobe usbhid; then
		HARDN_STATUS "pass" "Successfully loaded USB HID module."
	else
		HARDN_STATUS "error" "Failed to load USB HID module."
	fi
fi

HARDN_STATUS "pass" "USB configuration complete: keyboards and mice allowed, storage blocked."
