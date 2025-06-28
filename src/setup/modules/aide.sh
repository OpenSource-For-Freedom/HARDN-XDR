############################## AIDE (Advanced Intrusion Detection Environment)
if ! dpkg -s aide >/dev/null 2>&1; then
	HARDN_STATUS "info" "Installing and configuring AIDE..."
	apt install -y aide >/dev/null 2>&1
	if [[ -f "/etc/aide/aide.conf" ]]; then
		aideinit >/dev/null 2>&1 || true
		mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db >/dev/null 2>&1 || true
		echo "0 5 * * * root /usr/bin/aide --check" >> /etc/crontab
		HARDN_STATUS "pass" "AIDE installed and configured successfully"
	else
		HARDN_STATUS "error" "AIDE install failed, /etc/aide/aide.conf not found"
	fi
else
	HARDN_STATUS "warning" "AIDE already installed, skipping configuration..."
fi
