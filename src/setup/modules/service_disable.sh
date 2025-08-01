#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
# Remove set -e to handle errors gracefully in CI environment

service_name="$1"

# Create log directory if it doesn't exist
mkdir -p /var/log/hardn

# Sanity 
if [[ -z "$service_name" ]]; then
    HARDN_STATUS "info" "No service name provided, running service disable checks..."
    # In CI mode, just do a general service review
    if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]; then
        HARDN_STATUS "pass" "Service disable module completed (CI mode)"
        exit 0
    fi
fi

HARDN_STATUS "info" "Preparing to disable: $service_name"

# Critical system services that must not be disabled
protected_services=(
  # Login/session
  "gdm" "lightdm" "sddm" "display-manager"
  "systemd-logind" "accounts-daemon" "polkit"

  # Desktop environment essentials
  "xdg-desktop-portal" "xdg-desktop-portal-gtk" "xdg-desktop-portal-kde"
  "gnome-shell" "gnome-session" "plasma-workspace"

  # Core user and device mgmt
  "network-manager" "bluetooth" "wpa_supplicant" "avahi-daemon"
  "udisks2" "upower" "colord"

  # Security and entropy
  "dbus" "haveged" "rngd" "gcr-ssh-agent"

  # Optional DE/system helpers
  "speech-dispatcher" "rtkit-daemon"
)

# Never disable protected services
for protected in "${protected_services[@]}"; do
  if [[ "$service_name" == "$protected" ]]; then
    HARDN_STATUS "warning" "Skipping protected system-critical service: $service_name"
    echo "$(date) - SKIPPED: $service_name (protected)" >> /var/log/hardn/service_disable.log
    return 0
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

#Safe return or exit
exit 0