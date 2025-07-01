#!/bin/bash
HARDN_STATUS "error" "Checking/Disabling FireWire (IEEE 1394) drivers..."
local firewire_modules changed blacklist_file
firewire_modules="firewire_core firewire_ohci firewire_sbp2"
changed=0

for module_name in $firewire_modules; do
	if lsmod | grep -q "^${module_name}"; then
		HARDN_STATUS "info" "FireWire module $module_name is loaded. Attempting to unload..."
		if rmmod "$module_name"; then
			HARDN_STATUS "pass" "FireWire module $module_name unloaded successfully."
			changed=1
		else
			HARDN_STATUS "error" "Failed to unload FireWire module $module_name. It might be in use or built-in."
		fi
	else
		HARDN_STATUS "info" "FireWire module $module_name is not currently loaded."
	fi
done

blacklist_file="/etc/modprobe.d/blacklist-firewire.conf"
if [[ ! -f "$blacklist_file" ]]; then
	touch "$blacklist_file"
	HARDN_STATUS "pass" "Created FireWire blacklist file: $blacklist_file"
fi

for module_name in $firewire_modules; do
	if ! grep -q "blacklist $module_name" "$blacklist_file"; then
		echo "blacklist $module_name" >> "$blacklist_file"
		HARDN_STATUS "pass" "Blacklisted FireWire module $module_name in $blacklist_file"
		changed=1
	else
		HARDN_STATUS "info" "FireWire module $module_name already blacklisted in $blacklist_file."
	fi
done

if [[ "$changed" -eq 1 ]]; then
	whiptail --infobox "FireWire drivers checked. Unloaded and/or blacklisted where applicable." 7 70
else
	whiptail --infobox "FireWire drivers checked. No changes made (likely already disabled/not present)." 8 70
fi

