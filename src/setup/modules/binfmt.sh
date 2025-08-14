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


disable_binfmt_misc() {
    HARDN_STATUS "error" "Checking/Disabling non-native binary format support (binfmt_misc)..."
    if mount | grep -q 'binfmt_misc'; then
        HARDN_STATUS "info" "binfmt_misc is mounted. Attempting to unmount..."
        if umount /proc/sys/fs/binfmt_misc; then
            HARDN_STATUS "pass" "binfmt_misc unmounted successfully."
        else
            HARDN_STATUS "error" "Failed to unmount binfmt_misc. It might be busy or not a separate mount."
        fi
    fi

    if lsmod | grep -q "^binfmt_misc"; then
        HARDN_STATUS "info" "binfmt_misc module is loaded. Attempting to unload..."
        if rmmod binfmt_misc; then
            HARDN_STATUS "pass" "binfmt_misc module unloaded successfully."
        else
            HARDN_STATUS "error" "Failed to unload binfmt_misc module. It might be in use or built-in."
        fi
    else
        HARDN_STATUS "pass" "binfmt_misc module is not currently loaded."
    fi

    # Prevent module from loading on boot
    local modprobe_conf="/etc/modprobe.d/disable-binfmt_misc.conf"

    if [[ ! -f "$modprobe_conf" ]]; then
        echo "install binfmt_misc /bin/true" > "$modprobe_conf"
        HARDN_STATUS "pass" "Added modprobe rule to prevent binfmt_misc from loading on boot: $modprobe_conf"

    else
        if ! grep -q "install binfmt_misc /bin/true" "$modprobe_conf"; then
            echo "install binfmt_misc /bin/true" >> "$modprobe_conf"
            HARDN_STATUS "pass" "Appended modprobe rule to prevent binfmt_misc from loading to $modprobe_conf"
        else
            HARDN_STATUS "info" "Modprobe rule to disable binfmt_misc already exists in $modprobe_conf."
        fi
    fi
    HARDN_STATUS "pass" "Non-native binary format support (binfmt_misc) checked/disabled"
}

return 0 2>/dev/null || hardn_module_exit 0
set -e
