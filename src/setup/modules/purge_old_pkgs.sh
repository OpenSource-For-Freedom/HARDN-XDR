HARDN_STATUS "error" "Purging configuration files of old/removed packages..."
local packages_to_purge
packages_to_purge=$(dpkg -l | grep '^rc' | awk '{print $2}')

if [[ "$packages_to_purge" ]]; then
	HARDN_STATUS "info" "Found the following packages with leftover configuration files to purge:"
	echo "$packages_to_purge"
   
	if command -v whiptail >/dev/null; then
		whiptail --title "Packages to Purge" --msgbox "The following packages have leftover configuration files that will be purged:\n\n$packages_to_purge" 15 70
	fi

	for pkg in $packages_to_purge; do
		HARDN_STATUS "error" "Purging $pkg..."
		if apt-get purge -y "$pkg"; then
			HARDN_STATUS "pass" "Successfully purged $pkg."
		else
			HARDN_STATUS "error" "Failed to purge $pkg. Trying dpkg --purge..."
			if dpkg --purge "$pkg"; then
				HARDN_STATUS "pass" "Successfully purged $pkg with dpkg."
			else
				HARDN_STATUS "error" "Failed to purge $pkg with dpkg as well."
			fi
		fi
	done
	whiptail --infobox "Purged configuration files for removed packages." 7 70
else
	HARDN_STATUS "pass" "No old/removed packages with leftover configuration files found to purge."
	whiptail --infobox "No leftover package configurations to purge." 7 70
fi

HARDN_STATUS "error" "Running apt-get autoremove and clean to free up space..."
apt-get autoremove -y
apt-get clean
whiptail --infobox "Apt cache cleaned." 7 70
