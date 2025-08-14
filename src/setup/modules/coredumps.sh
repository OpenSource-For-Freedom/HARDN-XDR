#!/bin/bash
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
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
}
#!/bin/bash
set -e

# Check for container environment
if is_container_environment; then
    check_container_limitations
    
    # Check if we can modify kernel parameters
    if [[ ! -w /proc/sys ]]; then
        HARDN_STATUS "warning" "Container has read-only /proc/sys - kernel parameters cannot be modified"
        HARDN_STATUS "info" "Core dump settings should be configured on the container host"
        return 0 2>/dev/null || hardn_module_exit 0
    fi
fi

HARDN_STATUS "info" "Disabling core dumps..."

# Configure limits.conf if writable and not in container
if [[ -w /etc/security/limits.conf ]] && ! is_container_environment; then
    if ! grep -q "^\* hard core 0" /etc/security/limits.conf 2>/dev/null; then
        echo "* hard core 0" >> /etc/security/limits.conf
        HARDN_STATUS "info" "Added core dump limits to /etc/security/limits.conf"
    fi
else
    HARDN_STATUS "info" "Skipping limits.conf modification (container environment or file not writable)"
fi

# Use safe sysctl functions for kernel parameters
safe_sysctl_set "fs.suid_dumpable" "0"
safe_sysctl_set "kernel.core_pattern" "/dev/null"

HARDN_STATUS "pass" "Core dump protection configured"
HARDN_STATUS "info" "Settings applied: suid_dumpable=0, core_pattern=/dev/null"

return 0 2>/dev/null || hardn_module_exit 0
