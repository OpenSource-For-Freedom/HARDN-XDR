#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Preparing to disable: $1"

service_name="$1"
protected_services=(
  "gdm" "lightdm" "sddm"
  "network-manager" "systemd-logind"
  "polkit" "accounts-daemon"
  "display-manager"
)

for protected in "${protected_services[@]}"; do
  if [[ "$service_name" == "$protected" ]]; then
    HARDN_STATUS "warning" "Skipping critical system service: $service_name"
    exit 0
  fi
done

if systemctl is-active --quiet "$service_name"; then
  HARDN_STATUS "error" "Disabling active service: $service_name..."
  systemctl disable --now "$service_name" || HARDN_STATUS "warning" "Failed to disable service: $service_name"
elif systemctl list-unit-files --type=service | grep -qw "^$service_name.service"; then
  HARDN_STATUS "info" "Service $service_name is not active, ensuring it is disabled..."
  systemctl disable "$service_name" || HARDN_STATUS "warning" "Failed to disable service: $service_name"
else
  HARDN_STATUS "info" "Service $service_name not found. Skipping."
fi