########################### debsums 
HARDN_STATUS "info" "Configuring debsums..."
if command -v debsums >/dev/null 2>&1; then
	if debsums_init >/dev/null 2>&1; then
		HARDN_STATUS "pass" "debsums initialized successfully"
	else
		HARDN_STATUS "error" "Failed to initialize debsums"
	fi
	
	# Add debsums check to daily cron
	if ! grep -q "debsums" /etc/crontab; then
		echo "0 4 * * * root /usr/bin/debsums -s 2>&1 | logger -t debsums" >> /etc/crontab
		HARDN_STATUS "pass" "debsums daily check added to crontab"
	else
		HARDN_STATUS "warning" "debsums already in crontab"
	fi
	
	# Run initial check
	HARDN_STATUS "info" "Running initial debsums check..."
	if debsums -s >/dev/null 2>&1; then
		HARDN_STATUS "pass" "Initial debsums check completed successfully"
	else
		HARDN_STATUS "warning" "Warning: Some packages failed debsums verification"
	fi
else
	HARDN_STATUS "error" "debsums command not found, skipping configuration"
fi

