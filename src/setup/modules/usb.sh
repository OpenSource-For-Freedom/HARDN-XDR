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
# Remove set -e to handle errors gracefully in CI environment


# USB storage blocking for security hardening (automated mode)
HARDN_STATUS "info" "Configuring USB storage blocking for enhanced security"
HARDN_STATUS "warning" "USB storage devices will be blocked for security purposes"

ROOT_USB=$(lsblk -o NAME,TRAN,MOUNTPOINT | grep -E 'usb.*\/$' || true)

if [[ -n "$ROOT_USB" ]]; then
  HARDN_STATUS "warning" "System is running from USB storage. Skipping USB block to avoid system lockout."
  exit 0  # Changed from return 0 for consistency
fi

# Optional: Check if keyboard is present before blocking
KEYBOARD_OK=$(udevadm info -q property --export -n /dev/input/event* | grep ID_INPUT_KEYBOARD || true)
if [[ -z "$KEYBOARD_OK" ]]; then
  HARDN_STATUS "error" "No valid USB keyboard detected. Blocking USB now may cause login failure."
  return 1
fi

# Proceed with blocking
cat > /etc/modprobe.d/99-usb-storage.conf << 'EOF'
blacklist usb-storage
blacklist uas
EOF

HARDN_STATUS "info" "USB storage modules blacklisted."

cat > /etc/udev/rules.d/99-usb-storage.rules << 'EOF'
# Add valid udev rules here if needed
EOF

HARDN_STATUS "info" "Udev rules written."

udevadm control --reload-rules && udevadm trigger && HARDN_STATUS "pass" "Udev rules reloaded."

# Try unloading storage
if lsmod | grep -q usb_storage; then
  if rmmod usb_storage; then
    HARDN_STATUS "pass" "usb-storage module unloaded."
  else
    HARDN_STATUS "warning" "Failed to unload usb-storage."
  fi
else
  HARDN_STATUS "info" "usb-storage module not currently loaded."
fi

# Ensure HID is enabled
if ! lsmod | grep -q usbhid; then
  if modprobe usbhid; then
    HARDN_STATUS "pass" "usbhid module loaded."
  else
    HARDN_STATUS "warning" "Could not load usbhid (may be normal in CI environment)!"
  fi
else
  HARDN_STATUS "pass" "usbhid module already active."
fi

HARDN_STATUS "pass" "USB policy: storage blocked, HID enabled."

# shellcheck disable=SC2317
return 0 2>/dev/null || hardn_module_exit 0
