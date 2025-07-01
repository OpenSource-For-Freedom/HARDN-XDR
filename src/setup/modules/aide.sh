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

if ! is_installed aide; then
	HARDN_STATUS "info" "Installing and configuring AIDE (quick scan)..."
	if command -v apt >/dev/null 2>&1; then
		apt install -y aide >/dev/null 2>&1
	elif command -v dnf >/dev/null 2>&1; then
		dnf install -y aide >/dev/null 2>&1
	elif command -v yum >/dev/null 2>&1; then
		yum install -y aide >/dev/null 2>&1
	fi

	if [[ -f "/etc/aide/aide.conf" ]]; then
		# Backup original config
		cp /etc/aide/aide.conf /etc/aide/aide.conf.bak
		# Minimal config for fast scan
		cat > /etc/aide/aide.conf <<EOF
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new
gzip_dbout=no

# Only scan fast directories
/etc    NORMAL
/bin    NORMAL
/usr/bin NORMAL

# You can add more directories for a deeper scan
EOF
		aideinit >/dev/null 2>&1 || true
		mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db >/dev/null 2>&1 || true
		grep -q '/usr/bin/aide --check' /etc/crontab || echo "0 5 * * * root /usr/bin/aide --check" >> /etc/crontab
		HARDN_STATUS "pass" "AIDE installed and configured for a quick scan (only /etc, /bin, /usr/bin)."
		HARDN_STATUS "info" "For a deeper scan, edit /etc/aide/aide.conf and add more directories."
	else
		HARDN_STATUS "error" "AIDE install failed, /etc/aide/aide.conf not found"
	fi
else
	HARDN_STATUS "warning" "AIDE already installed, skipping configuration..."
fi
