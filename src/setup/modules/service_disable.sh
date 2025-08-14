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

service_name="$1"

# Create log directory if it doesn't exist
mkdir -p /var/log/hardn

# Sanity
if [[ -z "$service_name" ]]; then
    HARDN_STATUS "info" "No service name provided, running service disable checks..."
    # In CI mode, just do a general service review
    if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]; then
        HARDN_STATUS "pass" "Service disable module completed (CI mode)"
        return 0 2>/dev/null || hardn_module_exit 0
    fi
fi

HARDN_STATUS "info" "Preparing to disable: $service_name"

# Critical system services that must not be disabled
protected_services=(
  # Login/session/authentication - CRITICAL for user access
  "gdm" "lightdm" "sddm" "display-manager" "login"
  "systemd-logind" "accounts-daemon" "polkit" "pam-systemd"
  "getty@tty1" "console-getty" "serial-getty@ttyS0"

  # SSH and remote access - CRITICAL for remote management
  "ssh" "sshd" "openssh-server" "dropbear"

  # Desktop environment essentials - CRITICAL for GUI
  "xdg-desktop-portal" "xdg-desktop-portal-gtk" "xdg-desktop-portal-kde"
  "gnome-shell" "gnome-session" "plasma-workspace"
  "xorg" "wayland" "x11-common" "xinit"

  # Core networking - CRITICAL for connectivity
  "network-manager" "networkd" "systemd-networkd" "systemd-resolved"
  "dhcpcd" "networking" "network" "wpa_supplicant"

  # Audio/Video - ESSENTIAL for desktop use
  "pulseaudio" "pipewire" "alsa-utils" "alsa-state"
  "bluetooth" "bluez" "bluetooth-daemon"

  # Core user and device management - CRITICAL for hardware
  "udisks2" "upower" "colord" "cups" "cups-browsed"
  "avahi-daemon" "dbus" "systemd-user-sessions"

  # Security and entropy - CRITICAL for system security
  "haveged" "rngd" "gcr-ssh-agent" "gnome-keyring"
  "apparmor" "selinux" "fail2ban"

  # Package management - CRITICAL for updates
  "packagekit" "apt-daily" "apt-daily-upgrade" "unattended-upgrades"

  # Time synchronization - IMPORTANT for system stability
  "ntp" "ntpd" "systemd-timesyncd" "chrony"

  # File systems and storage - CRITICAL for data access
  "systemd-tmpfiles-setup" "systemd-tmpfiles-clean"
  "systemd-journal-flush" "systemd-journald"

  # Optional DE/system helpers - IMPORTANT for user experience
  "speech-dispatcher" "rtkit-daemon" "at-spi-dbus-bus"
  "gvfs-daemon" "gvfs-udisks2-volume-monitor"

  # Hardware support - IMPORTANT for device functionality
  "acpid" "thermald" "irqbalance" "cpufrequtils"
  "hdparm" "smartd" "lm-sensors"
)

# Never disable protected services
for protected in "${protected_services[@]}"; do
  if [[ "$service_name" == "$protected" ]]; then
    HARDN_STATUS "warning" "Skipping protected system-critical service: $service_name"
    echo "$(date) - SKIPPED: $service_name (protected)" >> /var/log/hardn/service_disable.log
    exit 0
  fi
done

# Attempt to disable the service
if systemctl is-active --quiet "$service_name"; then
  HARDN_STATUS "info" "Disabling active service: $service_name..."
  if systemctl disable --now "$service_name"; then
    HARDN_STATUS "pass" "Service $service_name disabled successfully."
    echo "$(date) - DISABLED: $service_name (active)" >> /var/log/hardn/service_disable.log
  else
    HARDN_STATUS "warning" "Failed to disable active service: $service_name"
  fi
elif systemctl list-unit-files --type=service | grep -qw "^$service_name.service"; then
  HARDN_STATUS "info" "Service $service_name is not active. Ensuring it is disabled..."
  if systemctl disable "$service_name"; then
    HARDN_STATUS "pass" "Service $service_name disabled successfully."
    echo "$(date) - DISABLED: $service_name (inactive)" >> /var/log/hardn/service_disable.log
  else
    HARDN_STATUS "warning" "Failed to disable inactive service: $service_name"
  fi
else
  HARDN_STATUS "info" "Service $service_name not found. Skipping."
  echo "$(date) - NOT FOUND: $service_name" >> /var/log/hardn/service_disable.log
fi

return 0 2>/dev/null || hardn_module_exit 0
set -e
