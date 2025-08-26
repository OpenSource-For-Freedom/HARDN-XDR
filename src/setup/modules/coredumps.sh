#!/bin/bash

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
    else
        HARDN_STATUS "info" "Core dump limits already present in /etc/security/limits.conf"
    fi
else
    HARDN_STATUS "info" "Skipping limits.conf modification (container environment or file not writable)"
fi

# Use safe sysctl functions for kernel parameters (idempotent + logging)
safe_sysctl_set "fs.suid_dumpable" "0"
safe_sysctl_set "kernel.core_pattern" "/dev/null"

# Verify applied settings
if [[ "$(cat /proc/sys/fs/suid_dumpable 2>/dev/null)" == "0" ]] && \
   [[ "$(cat /proc/sys/kernel/core_pattern 2>/dev/null)" == "/dev/null" ]]; then
    HARDN_STATUS "pass" "Core dump protection verified"
else
    HARDN_STATUS "fail" "Core dump protection verification failed"
fi

# Systemd-coredump override (if systemd is present)
if is_systemd_available && systemctl list-unit-files | grep -q "systemd-coredump"; then
    mkdir -p /etc/systemd/system/systemd-coredump.service.d
    cat <<EOF >/etc/systemd/system/systemd-coredump.service.d/disable.conf
[Service]
ExecStart=
ExecStart=/bin/true
EOF
    systemctl daemon-reexec
    systemctl try-restart systemd-coredump.service 2>/dev/null || true
    HARDN_STATUS "info" "Systemd-coredump service override applied"
fi

HARDN_STATUS "info" "Settings applied: suid_dumpable=0, core_pattern=/dev/null"

return 0 2>/dev/null || hardn_module_exit 0
set -e
