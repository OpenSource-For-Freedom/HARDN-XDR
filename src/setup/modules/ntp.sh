#!/bin/bash

# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh
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
		return 1
	fi
}

# NTP server whiptail
if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
	HARDN_STATUS "info" "CI mode: Using default Debian NTP pool servers."
	ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
else
	provider=$(whiptail --title "NTP Provider Selection" --menu "Choose your preferred NTP provider:\n\nThis controls the server your system will synchronize time with." 20 78 10 \
	"debian"   "Debian NTP Pool (default)" \
	"ntp.org"  "NTP.org global pool servers" \
	"google"   "Google Public NTP (high availability)" \
	"cloudflare" "Cloudflare NTP (privacy focused)" \
	"custom"   "Manually enter your own NTP servers" 3>&1 1>&2 2>&3)

	exitstatus=$?
	if [ $exitstatus -ne 0 ]; then
		HARDN_STATUS "warning" "User cancelled NTP selection. Using default Debian pool."
		provider="debian"
	fi

	case "$provider" in
		"debian")
			ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
			desc="Debian pool is geo-distributed and curated for Debian-based systems."
			;;
		"ntp.org")
			ntp_servers="0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org"
			desc="NTP.org pool is widely used across all Linux systems."
			;;
		"google")
			ntp_servers="time.google.com"
			desc="Google NTP offers leap-smear time sync with high uptime."
			;;
		"cloudflare")
			ntp_servers="time.cloudflare.com"
			desc="Cloudflare NTP is focused on low latency and privacy (no logging)."
			;;
		"custom")
			ntp_servers=$(whiptail --inputbox "Enter your custom NTP server(s) separated by space:" 10 78 3>&1 1>&2 2>&3)
			desc="Custom servers provided by user."
			;;
		*)
			ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
			desc="Default fallback to Debian pool."
			;;
	esac

	whiptail --title "NTP Info" --msgbox "Using the following NTP server(s):\n\n$ntp_servers\n\n$desc" 12 78
fi

HARDN_STATUS "info" "Setting up NTP using: $ntp_servers"
configured=false

# Try systemd-timesyncd first
if systemctl is-active --quiet systemd-timesyncd; then
	HARDN_STATUS "info" "systemd-timesyncd is active. Configuring..."
	timesyncd_conf="/etc/systemd/timesyncd.conf"
	temp_timesyncd_conf=$(mktemp)

	if [[ ! -f "$timesyncd_conf" ]]; then
		HARDN_STATUS "info" "Creating $timesyncd_conf as it does not exist."
		echo "[Time]" > "$timesyncd_conf"
		chmod 644 "$timesyncd_conf"
	fi

	cp "$timesyncd_conf" "$temp_timesyncd_conf"

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

	if timedatectl show-timesync --property=ServerAddress,NTP,Synchronized 2>/dev/null | grep -q "Synchronized=yes"; then
		ntpstat_output=$(timeout 3 ntpq -c rv 2>/dev/null || echo "")
		stratum=$(echo "$ntpstat_output" | grep -o 'stratum=[0-9]*' | cut -d= -f2)
		if [[ -n "$stratum" && "$stratum" -gt 2 ]]; then
			HARDN_STATUS "warning" "NTP is synchronized but using a high stratum peer (stratum $stratum). Consider using a lower stratum (closer to 1) for better accuracy."
		fi
	fi

else
	HARDN_STATUS "info" "systemd-timesyncd is not active. Checking/Configuring ntpd..."

	ntp_package_installed=false
	if is_installed ntp; then
		HARDN_STATUS "pass" "ntp package is already installed."
		ntp_package_installed=true
	else
		HARDN_STATUS "info" "ntp package not found. Attempting to install..."
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
			configured=false
			(return 1 2>/dev/null) || exit 1
		fi
	fi

	if [[ "$ntp_package_installed" = true ]]; then
		ntp_conf="/etc/ntp.conf"
		if [[ -f "$ntp_conf" && -w "$ntp_conf" ]]; then
			HARDN_STATUS "info" "Configuring $ntp_conf..."
			cp "$ntp_conf" "${ntp_conf}.bak.$(date +%F-%T)" 2>/dev/null || true

			temp_ntp_conf=$(mktemp)
			grep -vE "^\s*(pool|server)\s+" "$ntp_conf" > "$temp_ntp_conf"
			{
				echo "# HARDN-XDR configured NTP servers"
				for server in $ntp_servers; do
					echo "pool $server iburst"
				done
			} >> "$temp_ntp_conf"

			if ! cmp -s "$temp_ntp_conf" "$ntp_conf"; then
				mv "$temp_ntp_conf" "$ntp_conf"
				HARDN_STATUS "pass" "Updated $ntp_conf with recommended pool servers."

				if systemctl enable --now ntp; then
					HARDN_STATUS "pass" "ntp service enabled and started successfully."
					configured=true
				else
					HARDN_STATUS "error" "Failed to enable/start ntp service. Manual check required."
					configured=false
				fi
			else
				HARDN_STATUS "info" "No effective changes to $ntp_conf were needed."
				configured=true
			fi
			rm -f "$temp_ntp_conf"

			if ntpq -p 2>/dev/null | grep -q '^\*'; then
				stratum=$(timeout 3 ntpq -c rv 2>/dev/null | grep -o 'stratum=[0-9]*' | cut -d= -f2)
				if [[ -n "$stratum" && "$stratum" -gt 2 ]]; then
					HARDN_STATUS "warning" "NTP is synchronized but using a high stratum peer (stratum $stratum). Consider using a lower stratum (closer to 1) for better accuracy."
				fi
			fi

		else
			HARDN_STATUS "error" "NTP configuration file $ntp_conf not found or not writable. Skipping NTP configuration."
			configured=false
		fi
	fi
fi

if [[ "$configured" = true ]]; then
	HARDN_STATUS "pass" "NTP configuration attempt completed."
else
	HARDN_STATUS "error" "NTP configuration failed or skipped due to errors."
fi

(return 0 2>/dev/null) || exit 0