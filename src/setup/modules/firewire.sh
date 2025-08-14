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

# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh

# Check for container environment first
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - hardware module management is typically handled by the host"
    HARDN_STATUS "info" "FireWire modules are usually not loaded in containers"
    HARDN_STATUS "pass" "FireWire protection: handled by container runtime/host"
    return 0 2>/dev/null || hardn_module_exit 0
fi

HARDN_STATUS "info" "Checking/Disabling FireWire (IEEE 1394) drivers..."
firewire_modules="firewire_core firewire_ohci firewire_sbp2"
changed=0
blacklist_file="/etc/modprobe.d/blacklist-firewire.conf"

for module_name in $firewire_modules; do
	if lsmod | grep -q "^${module_name}"; then
		HARDN_STATUS "info" "FireWire module $module_name is loaded. Attempting to unload..."
		if rmmod "$module_name" 2>/dev/null; then
			HARDN_STATUS "pass" "FireWire module $module_name unloaded successfully."
			changed=1
		else
			HARDN_STATUS "warning" "Could not unload FireWire module $module_name (may be in use or built-in)"
		fi
	else
		HARDN_STATUS "info" "FireWire module $module_name is not currently loaded."
	fi
done

if [[ ! -f "$blacklist_file" ]]; then
	touch "$blacklist_file"
	HARDN_STATUS "pass" "Created FireWire blacklist file: $blacklist_file"
fi

for module_name in $firewire_modules; do
	if ! grep -q "blacklist $module_name" "$blacklist_file"; then
		echo "blacklist $module_name" >> "$blacklist_file"
		HARDN_STATUS "pass" "Blacklisted FireWire module $module_name in $blacklist_file"
		changed=1
	else
		HARDN_STATUS "info" "FireWire module $module_name already blacklisted in $blacklist_file."
	fi
done

if [[ "$changed" -eq 1 ]]; then
	HARDN_STATUS "pass" "FireWire drivers checked. Unloaded and/or blacklisted where applicable"
else
	HARDN_STATUS "info" "FireWire drivers checked. No changes made (likely already disabled/not present)"
fi

return 0 2>/dev/null || hardn_module_exit 0
set -e
