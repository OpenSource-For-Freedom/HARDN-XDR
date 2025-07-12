#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

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

HARDN_STATUS "info" "Setting up NTP daemon..."

local ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
local configured=false

# Prefer systemd-timesyncd if active
if systemctl is-active --quiet systemd-timesyncd; then
HARDN_STATUS "info" "systemd-timesyncd is active. Configuring..."
local timesyncd_conf="/etc/systemd/timesyncd.conf"
local temp_timesyncd_conf
temp_timesyncd_conf=$(mktemp)

if [[ ! -f "$timesyncd_conf" ]]; then
    HARDN_STATUS "info" "Creating $timesyncd_conf as it does not exist."
    echo "[Time]" > "$timesyncd_conf"
    chmod 644 "$timesyncd_conf"
fi

cp "$timesyncd_conf" "$temp_timesyncd_conf"

# Set NTP= explicitly
if grep -qE "^\s*NTP=" "$temp_timesyncd_conf"; then
    sed -i -E "s/^\s*NTP=.*/NTP=$ntp_servers/" "$temp_timesyncd_conf"
else
    if grep -q "\[Time\]" "$temp_timesyncd_conf"; then
	sed -i "/\[Time\]/a NTP=$ntp_servers" "$temp_timesyncd_conf"
    else
	echo -e "\n[Time]\nNTP=$ntp_servers" >> "$temp_timesyncd_conf"
    fi
fi

if ! cmp -s "$temp_timesyncd_conf" "$timesyncd_conf"; then
    cp "$temp_timesyncd_conf" "$timesyncd_conf"
    HARDN_STATUS "pass" "Updated $timesyncd_conf. Restarting systemd-timesyncd..."
    if systemctl restart systemd-timesyncd; then
	HARDN_STATUS "pass" "systemd-timesyncd restarted successfully."
	configured=true
    else
	HARDN_STATUS "error" "Failed to restart systemd-timesyncd. Manual check required."
    fi
else
    HARDN_STATUS "info" "No effective changes to $timesyncd_conf were needed."
    configured=true
fi
rm -f "$temp_timesyncd_conf"

# Check NTP peer stratum and warn if not stratum 1 or 2
if timedatectl show-timesync --property=ServerAddress,NTP,Synchronized 2>/dev/null | grep -q "Synchronized=yes"; then
    ntpstat_output=$(ntpq -c rv 2>/dev/null)
    stratum=$(echo "$ntpstat_output" | grep -o 'stratum=[0-9]*' | cut -d= -f2)
    if [[ -n "$stratum" && "$stratum" -gt 2 ]]; then
	HARDN_STATUS "warning" "NTP is synchronized but using a high stratum peer (stratum $stratum). Consider using a lower stratum (closer to 1) for better accuracy."
    fi
fi

# Fallback to ntpd if systemd-timesyncd is not active
else
HARDN_STATUS "info" "systemd-timesyncd is not active. Checking/Configuring ntpd..."

local ntp_package_installed=false
# Ensure ntp package is installed
if is_installed ntp; then
     HARDN_STATUS "pass" "ntp package is already installed."
     ntp_package_installed=true
else
     HARDN_STATUS "info" "ntp package not found. Attempting to install..."
     # Attempt installation, check exit status
     if command -v apt >/dev/null 2>&1; then
        apt-get update >/dev/null 2>&1 && apt-get install -y ntp >/dev/null 2>&1
     elif command -v dnf >/dev/null 2>&1; then
        dnf install -y ntp >/dev/null 2>&1
     elif command -v yum >/dev/null 2>&1; then
        yum install -y ntp >/dev/null 2>&1
     fi

     if is_installed ntp; then
	 HARDN_STATUS "pass" "ntp package installed successfully."
	 ntp_package_installed=true
     else
	 HARDN_STATUS "error" "Failed to install ntp package. Skipping NTP configuration."
	 configured=false # Ensure configured is false on failure
	 # Do not return here, allow the rest of setup_security to run
     fi
fi

# Proceed with configuration ONLY if the package is installed
if [[ "$ntp_package_installed" = true ]]; then
    local ntp_conf="/etc/ntp.conf"
    # Check if the configuration file exists and is writable
    if [[ -f "$ntp_conf" ]] && [[ -w "$ntp_conf" ]]; then
	HARDN_STATUS "info" "Configuring $ntp_conf..."
	# Backup existing config
	cp "$ntp_conf" "${ntp_conf}.bak.$(date +%F-%T)" 2>/dev/null || true

	# Remove existing pool/server lines and add the desired ones
	local temp_ntp_conf
	temp_ntp_conf=$(mktemp)
	grep -vE "^\s*(pool|server)\s+" "$ntp_conf" > "$temp_ntp_conf"
	{
	    echo "# HARDN-XDR configured NTP servers"
	    for server in $ntp_servers; do
		echo "pool $server iburst"
	    done
	} >> "$temp_ntp_conf"

	# Check if changes were made before copying and restarting
	if ! cmp -s "$temp_ntp_conf" "$ntp_conf"; then
	    mv "$temp_ntp_conf" "$ntp_conf"
	    HARDN_STATUS "pass" "Updated $ntp_conf with recommended pool servers."

	    # Restart/Enable ntp service
	    if systemctl enable --now ntp; then
		HARDN_STATUS "pass" "ntp service enabled and started successfully."
		configured=true
	    else
		HARDN_STATUS "error" "Failed to enable/start ntp service. Manual check required."
		configured=false # Set to false on service failure
	    fi
	else
	    HARDN_STATUS "info" "No effective changes to $ntp_conf were needed."
	    configured=true # Already configured correctly or no changes needed
	fi
	rm -f "$temp_ntp_conf" # Clean up temp file

	# Check NTP peer stratum and warn if not stratum 1 or 2
	if ntpq -p 2>/dev/null | grep -q '^\*'; then
	    stratum=$(ntpq -c rv 2>/dev/null | grep -o 'stratum=[0-9]*' | cut -d= -f2)
	    if [[ -n "$stratum" && "$stratum" -gt 2 ]]; then
		HARDN_STATUS "warning" "NTP is synchronized but using a high stratum peer (stratum $stratum). Consider using a lower stratum (closer to 1) for better accuracy."
	    fi
	fi

    else
	# This is the error path the user saw
	HARDN_STATUS "error" "NTP configuration file $ntp_conf not found or not writable after ntp package check/installation. Skipping NTP configuration."
	configured=false # Set to false if config file is missing/unwritable
    fi
fi # End if ntp_package_installed
fi # End of systemd-timesyncd else block

if [[ "$configured" = true ]]; then
HARDN_STATUS "pass" "NTP configuration attempt completed."
else
HARDN_STATUS "error" "NTP configuration failed or skipped due to errors."
fi

