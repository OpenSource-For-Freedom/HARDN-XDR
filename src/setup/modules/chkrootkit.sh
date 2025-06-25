####################################### chkrootkit
HARDN_STATUS "info" "Configuring chkrootkit..."
if ! command -v chkrootkit >/dev/null 2>&1; then
	HARDN_STATUS "info" "chkrootkit package not found. Attempting to download and install from chkrootkit.org..."
	download_url="https://www.chkrootkit.org/dl/chkrootkit.tar.gz"
	download_dir="/tmp/chkrootkit_install"
	tar_file="$download_dir/chkrootkit.tar.gz"

	mkdir -p "$download_dir"
	cd "$download_dir" || { HARDN_STATUS "error" "Error: Cannot change directory to $download_dir."; return 1; }

	HARDN_STATUS "info" "Downloading $download_url..."
	if wget -q "$download_url" -O "$tar_file"; then
		HARDN_STATUS "pass" "Download successful."
		HARDN_STATUS "info" "Extracting..."
		if tar -xzf "$tar_file" -C "$download_dir"; then
			HARDN_STATUS "pass" "Extraction successful."
			extracted_dir=$(tar -tf "$tar_file" | head -1 | cut -f1 -d/)
			if [[ -d "$download_dir/$extracted_dir" ]]; then
				cd "$download_dir/$extracted_dir" || { HARDN_STATUS "error" "Error: Cannot change directory to extracted folder."; return 1; }
				HARDN_STATUS "info" "Running chkrootkit installer..."
				if [[ -f "chkrootkit" ]]; then
					cp chkrootkit /usr/local/sbin/
					chmod +x /usr/local/sbin/chkrootkit
					if [[ -f "chkrootkit.8" ]]; then
						cp chkrootkit.8 /usr/local/share/man/man8/
						mandb >/dev/null 2>&1 || true
					fi
					HARDN_STATUS "pass" "chkrootkit installed to /usr/local/sbin."
				else
					HARDN_STATUS "error" "Error: chkrootkit script not found in extracted directory."
				fi
			else
				HARDN_STATUS "error" "Error: Extracted directory not found."
			fi
		else
			HARDN_STATUS "error" "Error: Failed to extract $tar_file."
		fi
	else
		HARDN_STATUS "error" "Error: Failed to download $download_url."
	fi
	cd /tmp || true
	rm -rf "$download_dir"
else
	HARDN_STATUS "pass" "chkrootkit package is already installed."
fi

if command -v chkrootkit >/dev/null 2>&1; then
	if ! grep -q "/usr/local/sbin/chkrootkit" /etc/crontab; then
		echo "0 3 * * * root /usr/local/sbin/chkrootkit 2>&1 | logger -t chkrootkit" >> /etc/crontab
		HARDN_STATUS "pass" "chkrootkit daily check added to crontab."
	else
		HARDN_STATUS "info" "chkrootkit already in crontab."
	fi
else
	HARDN_STATUS "error" "chkrootkit command not found after installation attempt, skipping cron configuration."
fi

