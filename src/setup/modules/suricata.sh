####################################### Suricata
HARDN_STATUS "error" "Checking and configuring Suricata..."

if dpkg -s suricata >/dev/null 2>&1; then
	HARDN_STATUS "pass" "Suricata package is already installed."
else
	HARDN_STATUS "info" "Suricata package not found. Attempting to install from source..."

	local suricata_version="7.0.0" 
	local download_url="https://www.suricata-ids.org/download/releases/suricata-${suricata_version}.tar.gz"
	local download_dir="/tmp/suricata_install"
	local tar_file="$download_dir/suricata-${suricata_version}.tar.gz"
	local extracted_dir="suricata-${suricata_version}"

  
	HARDN_STATUS "info" "Installing Suricata build dependencies..."
	if ! apt-get update >/dev/null 2>&1 || ! apt-get install -y \
		build-essential libpcap-dev libnet1-dev libyaml-0-2 libyaml-dev zlib1g zlib1g-dev \
		libcap-ng-dev libmagic-dev libjansson-dev libnss3-dev liblz4-dev libtool \
		libnfnetlink-dev libevent-dev pkg-config libhiredis-dev libczmq-dev \
		python3 python3-yaml python3-setuptools python3-pip python3-dev \
		rustc cargo >/dev/null 2>&1; then
		HARDN_STATUS "error" "Error: Failed to install Suricata build dependencies. Skipping Suricata configuration."
		return 1
	fi
	HARDN_STATUS "pass" "Suricata build dependencies installed."

	mkdir -p "$download_dir"
	cd "$download_dir" || { HARDN_STATUS "error" "Error: Cannot change directory to $download_dir."; return 1; }

	HARDN_STATUS "info" "Downloading %s...\\n" "$download_url"
	if wget -q "$download_url" -O "$tar_file"; then
		HARDN_STATUS "pass" "Download successful."
		HARDN_STATUS "info" "Extracting..."
		if tar -xzf "$tar_file" -C "$download_dir"; then
			HARDN_STATUS "pass" "Extraction successful."

			if [[ -d "$download_dir/$extracted_dir" ]]; then
				cd "$download_dir/$extracted_dir" || { HARDN_STATUS "error" "Error: Cannot change directory to extracted folder."; return 1; }

				HARDN_STATUS "info" "Running ./configure..."
				
				if ./configure \
					--prefix=/usr \
					--sysconfdir=/etc \
					--localstatedir=/var \
					--disable-gccmarch-native \
					--enable-lua \
					--enable-geoip \
					> /dev/null 2>&1; then 
					HARDN_STATUS "pass" "Configure successful."

					HARDN_STATUS "info" "Running make..."
					if make > /dev/null 2>&1; then 
						HARDN_STATUS "pass" "Make successful."

						HARDN_STATUS "info" "Running make install..."
						if make install > /dev/null 2>&1; then 
							HARDN_STATUS "pass" "Suricata installed successfully from source."
						 
							ldconfig >/dev/null 2>&1 || true
						else
							HARDN_STATUS "error" "Error: make install failed."
							cd /tmp || true 
							rm -rf "$download_dir"
							return 1
						fi
					else
						HARDN_STATUS "error" "Error: make failed."
						cd /tmp || true 
						rm -rf "$download_dir"
						return 1
					fi
				else
					HARDN_STATUS "error" "Error: ./configure failed."
					cd /tmp || true 
					rm -rf "$download_dir"
					return 1
				fi
			else
				HARDN_STATUS "error" "Error: Extracted directory not found."
				cd /tmp || true 
				rm -rf "$download_dir"
				return 1
			fi
		else
			HARDN_STATUS "error" "Error: Failed to extract $tar_file."
			cd /tmp || true
			rm -rf "$download_dir"
			return 1
		fi
	else
		HARDN_STATUS "error" "Error: Failed to download $download_url."
		cd /tmp || true # Move out before cleanup
		rm -rf "$download_dir"
		return 1
	fi

	# Clean up temporary files
	cd /tmp || true # Move out of the download directory before removing
	rm -rf "$download_dir"
fi

# If Suricata is installed 
if command -v suricata >/dev/null 2>&1; then
	HARDN_STATUS "info" "Configuring Suricata..."

	# Ensure the default configuration 
	if [ ! -d /etc/suricata ]; then
		HARDN_STATUS "info" "Creating /etc/suricata and copying default config..."
		mkdir -p /etc/suricata

		if [ ! -f /etc/suricata/suricata.yaml ]; then
			 HARDN_STATUS "error" "Error: Suricata default configuration file /etc/suricata/suricata.yaml not found after installation. Skipping configuration."
			 return 1
		fi
	fi

	# Enable the service 
	if systemctl enable suricata >/dev/null 2>&1; then
		HARDN_STATUS "pass" "Suricata service enabled successfully."
	else
		HARDN_STATUS "error" "Failed to enable Suricata service. Check if the service file exists (e.g., /lib/systemd/system/suricata.service)."
	fi

	# Update rules
	HARDN_STATUS "info" "Running suricata-update..."
	# suricata-update might need python dependencies.....
	if ! command -v suricata-update >/dev/null 2>&1; then
		 HARDN_STATUS "info" "suricata-update command not found. Attempting to install..."
		 if pip3 install --upgrade pip >/dev/null 2>&1 && pip3 install --upgrade suricata-update >/dev/null 2>&1; then
			 HARDN_STATUS "pass" "suricata-update installed successfully via pip3."
		 else
			 HARDN_STATUS "error" "Error: Failed to install suricata-update via pip3. Skipping rule update."
		 fi
	fi

	if command -v suricata-update >/dev/null 2>&1; then
		if suricata-update >/dev/null 2>&1; then
			HARDN_STATUS "pass" "Suricata rules updated successfully."
		else
			HARDN_STATUS "warning" "Warning: Suricata rules update failed. Check output manually."
		fi
	else
		 HARDN_STATUS "error" "suricata-update command not available, skipping rule update."
	fi

	# Start the service
	if systemctl start suricata >/dev/null 2>&1; then
		HARDN_STATUS "pass" "Suricata service started successfully."
	else
		HARDN_STATUS "error" "Failed to start Suricata service. Check logs for details."
	fi
else
	HARDN_STATUS "error" "Suricata command not found after installation attempt, skipping configuration."
fi

