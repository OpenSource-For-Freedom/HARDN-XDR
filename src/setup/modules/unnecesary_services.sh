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

# shellcheck disable=SC1091

HARDN_STATUS "info" "Disabling unnecessary services..."
disable_service_if_active() {
	local service_name
	service_name="$1"
	if systemctl is-active --quiet "$service_name"; then
		HARDN_STATUS "info" "Disabling active service: $service_name..."
		systemctl disable --now "$service_name" || HARDN_STATUS "warning" "Failed to disable service: $service_name (may not be installed or already disabled)."
	elif systemctl list-unit-files --type=service | grep -qw "^$service_name.service"; then
		HARDN_STATUS "info" "Service $service_name is not active, ensuring it is disabled..."
		systemctl disable "$service_name" || HARDN_STATUS "warning" "Failed to disable service: $service_name (may not be installed or already disabled)."
	else
		HARDN_STATUS "info" "Service $service_name not found or not installed. Skipping."
	fi
}

disable_service_if_active avahi-daemon
disable_service_if_active cups
disable_service_if_active rpcbind
disable_service_if_active nfs-server
disable_service_if_active smbd
disable_service_if_active snmpd
disable_service_if_active apache2
disable_service_if_active mysql
disable_service_if_active bind9


packages_to_remove="telnet vsftpd proftpd tftpd postfix exim4"
for pkg in $packages_to_remove; do
	if dpkg -s "$pkg" >/dev/null 2>&1; then
		HARDN_STATUS "error" "Removing package: $pkg..."
		apt remove -y "$pkg"
	else
		HARDN_STATUS "info" "Package $pkg not installed. Skipping removal."
	fi
done

HARDN_STATUS "pass" "Unnecessary services checked and disabled/removed where applicable."

# shellcheck disable=SC2317
return 0 2>/dev/null || hardn_module_exit 0
set -e
