#!/bin/bash
HARDN_STATUS "info" "Disabling specified services..."
service_name="$1"
if systemctl is-active --quiet "$service_name"; then
	HARDN_STATUS "error" "Disabling active service: $service_name..."
	systemctl disable --now "$service_name" || HARDN_STATUS "warning" "Failed to disable service: $service_name (may not be installed or already disabled)."
elif systemctl list-unit-files --type=service | grep -qw "^$service_name.service"; then
	HARDN_STATUS "error" "Service $service_name is not active, ensuring it is disabled..."
	systemctl disable "$service_name" || HARDN_STATUS "warning" "Failed to disable service: $service_name (may not be installed or already disabled)."
else
	HARDN_STATUS "info" "Service $service_name not found or not installed. Skipping."
fi
