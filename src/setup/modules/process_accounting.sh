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

HARDN_STATUS "info" "Enabling process accounting (acct) and system statistics (sysstat)..."
changed_acct=false
changed_sysstat=false

HARDN_STATUS "info" "Checking and installing acct (process accounting)..."
if ! command -v acct >/dev/null 2>&1 && ! command -v psacct >/dev/null 2>&1; then
	HARDN_STATUS "info" "Installing acct (process accounting)..."
	if apt-get install -y acct; then
		HARDN_STATUS "pass" "acct installed successfully."
		changed_acct=true
	else
		HARDN_STATUS "error" "Failed to install acct. Please check manually."
	fi
else
	HARDN_STATUS "info" "acct/psacct is already installed."
fi

if command -v acct >/dev/null 2>&1 || command -v psacct >/dev/null 2>&1; then
	if ! systemctl is-active --quiet acct && ! systemctl is-active --quiet psacct; then
		HARDN_STATUS "info" "Attempting to enable and start acct/psacct service..."
		systemctl enable --now acct 2>/dev/null || systemctl enable --now psacct 2>/dev/null
		HARDN_STATUS "pass" "acct/psacct service enabled and started."
		changed_acct=true
	else
		HARDN_STATUS "pass" "acct/psacct service is already active."
	fi
fi

# Enable Sysstat
HARDN_STATUS "info" "Checking and installing sysstat..."
if ! command -v sar >/dev/null 2>&1; then
	HARDN_STATUS "info" "Installing sysstat..."
	if apt-get install -y sysstat; then
		HARDN_STATUS "pass" "sysstat installed successfully."
		changed_sysstat=true
	else
		HARDN_STATUS "error" "Failed to install sysstat. Please check manually."
	fi
else
	HARDN_STATUS "info" "sysstat is already installed."
fi

if command -v sar >/dev/null 2>&1; then
	sysstat_conf="/etc/default/sysstat"
	if [[ -f "$sysstat_conf" ]]; then
		if ! grep -qE '^\s*ENABLED="true"' "$sysstat_conf"; then
			HARDN_STATUS "info" "Enabling sysstat data collection in $sysstat_conf..."
			sed -i 's/^\s*ENABLED="false"/ENABLED="true"/' "$sysstat_conf"
			if ! grep -qE '^\s*ENABLED=' "$sysstat_conf"; then
				echo 'ENABLED="true"' >> "$sysstat_conf"
			fi
			changed_sysstat=true
			HARDN_STATUS "pass" "sysstat data collection enabled."
		else
			HARDN_STATUS "pass" "sysstat data collection is already enabled in $sysstat_conf."
		fi
	else
		HARDN_STATUS "warning" "sysstat configuration file $sysstat_conf not found. Manual check might be needed."
	fi

	if ! systemctl is-active --quiet sysstat; then
		HARDN_STATUS "info" "Attempting to enable and start sysstat service..."
		if systemctl enable --now sysstat; then
			HARDN_STATUS "pass" "sysstat service enabled and started."
			changed_sysstat=true
		else
			HARDN_STATUS "error" "Failed to enable/start sysstat service."
		fi
	else
		HARDN_STATUS "pass" "sysstat service is already active."
	fi
fi

if [[ "$changed_acct" = true || "$changed_sysstat" = true ]]; then
	HARDN_STATUS "pass" "Process accounting (acct) and sysstat configured successfully."
else
	HARDN_STATUS "pass" "Process accounting (acct) and sysstat already configured or no changes needed."
fi

return 0 2>/dev/null || hardn_module_exit 0
set -e
