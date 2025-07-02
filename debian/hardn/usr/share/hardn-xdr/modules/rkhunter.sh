#!/bin/bash

is_installed() {
    if command -v apt >/dev/null 2>&1; then
        dpkg -s "$1" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$1" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$1" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1 # Cannot determine package manager
    fi
}

HARDN_STATUS "info" "Configuring rkhunter..."
if ! is_installed rkhunter; then
	HARDN_STATUS "info" "rkhunter package not found. Attempting to install..."
    if command -v apt-get >/dev/null 2>&1; then
        apt-get install -y rkhunter >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y rkhunter >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y rkhunter >/dev/null 2>&1
    fi

	if ! is_installed rkhunter; then
		HARDN_STATUS "warning" "Warning: Failed to install rkhunter via package manager. Attempting to download and install from GitHub as a fallback..."
		# Ensure git is installed for GitHub clone
		if ! is_installed git; then
			HARDN_STATUS "info" "Installing git..."
			if command -v apt-get >/dev/null 2>&1; then
                apt-get install -y git >/dev/null 2>&1
            elif command -v dnf >/dev/null 2>&1; then
                dnf install -y git >/dev/null 2>&1
            elif command -v yum >/dev/null 2>&1; then
                yum install -y git >/dev/null 2>&1
            fi

			if ! is_installed git; then
				HARDN_STATUS "error" "Error: Failed to install git. Cannot proceed with GitHub install."
				# Skip GitHub install if git fails
				return
			fi
		fi

		cd /tmp || { HARDN_STATUS "error" "Error: Cannot change directory to /tmp."; return 1; }
		HARDN_STATUS "info" "Cloning rkhunter from GitHub..."
		if git clone https://github.com/Rootkit-Hunter/rkhunter.git rkhunter_github_clone >/dev/null 2>&1; then
			cd rkhunter_github_clone || { HARDN_STATUS "error" "Error: Cannot change directory to rkhunter_github_clone."; return 1; }
			HARDN_STATUS "info" "Running rkhunter installer..."
			if ./installer.sh --layout DEB >/dev/null 2>&1; then
			    ./installer.sh --install >/dev/null 2>&1 || {
					HARDN_STATUS "error" "Error: rkhunter installer failed."
					cd .. && rm -rf rkhunter_github_clone
					return 1
				}
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


	rkhunter --overwrite >/dev/null 2>&1 || true
	rkhunter --version >/dev/null 2>&1 || {
		HARDN_STATUS "warning" "Warning: Failed to update rkhunter database."
	}
	rkhunter --show >/dev/null 2>&1 || {
		HARDN_STATUS "warning" "Warning: Failed to update rkhunter properties."
	}
else
	HARDN_STATUS "warning" "Warning: rkhunter not found, skipping configuration."
fi
