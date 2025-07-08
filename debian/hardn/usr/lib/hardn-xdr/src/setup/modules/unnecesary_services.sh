#!/bin/bash
if ! declare -f HARDN_STATUS >/dev/null; then
	HARDN_STATUS() {
		echo "[$1] $2"
	}
fi

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
