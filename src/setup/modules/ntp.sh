#!/bin/bash
# Source common functions with fallback for development/CI environments
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}
#!/bin/bash


# Check for container environment
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - time synchronization typically managed by host"
    HARDN_STATUS "info" "Container clocks are usually synchronized with the container host"
    HARDN_STATUS "pass" "NTP module completed (container environment)"
    return 0 2>/dev/null || hardn_module_exit 0
fi

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

return 0 2>/dev/null || hardn_module_exit 0
set -e
