#################################### rkhunter
HARDN_STATUS "info" "Configuring rkhunter..."
if ! dpkg -s rkhunter >/dev/null 2>&1; then
	HARDN_STATUS "info" "rkhunter package not found. Attempting to install via apt..."
	if apt-get install -y rkhunter >/dev/null 2>&1; then
		HARDN_STATUS "pass" "rkhunter installed successfully via apt."
	else
		HARDN_STATUS "warning" "Warning: Failed to install rkhunter via apt. Attempting to download and install from GitHub as a fallback..."
		# Ensure git is installed for GitHub clone
		if ! command -v git >/dev/null 2>&1; then
			HARDN_STATUS "info" "Installing git..."
			apt-get install -y git >/dev/null 2>&1 || {
				HARDN_STATUS "error" "Error: Failed to install git. Cannot proceed with GitHub install."
				# Skip GitHub install if git fails
				return
			}
		fi

		cd /tmp || { HARDN_STATUS "error" "Error: Cannot change directory to /tmp."; return 1; }
		HARDN_STATUS "info" "Cloning rkhunter from GitHub..."
		if git clone https://github.com/Rootkit-Hunter/rkhunter.git rkhunter_github_clone >/dev/null 2>&1; then
			cd rkhunter_github_clone || { HARDN_STATUS "error" "Error: Cannot change directory to rkhunter_github_clone."; return 1; }
			HARDN_STATUS "info" "Running rkhunter installer..."
			if ./installer.sh --install >/dev/null 2>&1; then
				HARDN_STATUS "pass" "rkhunter installed successfully from GitHub."
			else
				HARDN_STATUS "error" "Error: rkhunter installer failed."
			fi
			cd .. && rm -rf rkhunter_github_clone
		else
			HARDN_STATUS "error" "Error: Failed to clone rkhunter from GitHub."
		fi
	fi
else
	HARDN_STATUS "pass" "rkhunter package is already installed."
fi

if command -v rkhunter >/dev/null 2>&1; then
	# fixes: issue with git install where /etc/default/rkhunter is not created during the installation process
	test -e /etc/default/rkhunter || touch /etc/default/rkhunter

	sed -i 's/#CRON_DAILY_RUN=""/CRON_DAILY_RUN="true"/' /etc/default/rkhunter 2>/dev/null || true


	rkhunter --configcheck >/dev/null 2>&1 || true
	rkhunter --update --nocolors >/dev/null 2>&1 || {
		HARDN_STATUS "warning" "Warning: Failed to update rkhunter database."
	}
	rkhunter --propupd --nocolors >/dev/null 2>&1 || {
		HARDN_STATUS "warning" "Warning: Failed to update rkhunter properties."
	}
else
	HARDN_STATUS "warning" "Warning: rkhunter not found, skipping configuration."
fi
