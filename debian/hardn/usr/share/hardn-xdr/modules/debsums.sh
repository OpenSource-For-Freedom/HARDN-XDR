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

HARDN_STATUS "info" "Configuring debsums..."

if ! is_installed debsums; then
    HARDN_STATUS "info" "Installing debsums..."
    if command -v apt >/dev/null 2>&1; then
        apt-get update -qq
        apt-get install -y debsums
    else
        HARDN_STATUS "warning" "debsums is a Debian-specific package, cannot install on this system."
        exit 0
    fi
fi

if ! command -v debsums >/dev/null 2>&1; then
	HARDN_STATUS "error" "debsums command not found, skipping configuration"
	exit 1
fi

# Create daily cron job for debsums
CRON_DAILY="/etc/cron.daily/debsums"
if [ ! -f "$CRON_DAILY" ]; then
	cat <<EOF > "$CRON_DAILY"
#!/bin/sh
debsums -s
EOF
	chmod +x "$CRON_DAILY"
	HARDN_STATUS "pass" "debsums daily cron job created"
else
	HARDN_STATUS "warning" "debsums daily cron job already exists"
fi

# Add debsums check to /etc/crontab if not present
CRONTAB_LINE="0 4 * * * root /usr/bin/debsums -s 2>&1 | logger -t debsums"
if ! grep -qF "/usr/bin/debsums -s" /etc/crontab; then
	echo "$CRONTAB_LINE" >> /etc/crontab
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
