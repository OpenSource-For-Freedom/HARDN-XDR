#!/bin/bash
if ! declare -f HARDN_STATUS >/dev/null; then
	HARDN_STATUS() {
		echo "[$1] $2"
	}
fi

HARDN_STATUS "info" "Disabling unnecessary and insecure services per STIG requirements..."
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

# STIG-required service disabling - insecure and unnecessary services
disable_service_if_active telnet
disable_service_if_active telnetd
disable_service_if_active in.telnetd
disable_service_if_active rpcbind
disable_service_if_active nfs-server
disable_service_if_active nfs-client
disable_service_if_active nfs-common
disable_service_if_active portmap
disable_service_if_active rpc.statd
disable_service_if_active rpc.idmapd

# Additional insecure services to disable
disable_service_if_active avahi-daemon
disable_service_if_active cups
disable_service_if_active smbd
disable_service_if_active snmpd
disable_service_if_active apache2
disable_service_if_active mysql
disable_service_if_active bind9
disable_service_if_active vsftpd
disable_service_if_active proftpd
disable_service_if_active tftp
disable_service_if_active tftpd
disable_service_if_active xinetd
disable_service_if_active inetd

# Network services that should be disabled unless specifically needed
disable_service_if_active rsh
disable_service_if_active rlogin
disable_service_if_active rexec
disable_service_if_active finger
disable_service_if_active echo
disable_service_if_active discard
disable_service_if_active daytime
disable_service_if_active chargen


packages_to_remove="telnet telnetd rsh-client rsh-server rlogin finger talk ntalk rwho rusers rcp rexec"
packages_to_remove+=" vsftpd proftpd tftpd tftp postfix exim4"
for pkg in $packages_to_remove; do
	if dpkg -s "$pkg" >/dev/null 2>&1; then
		HARDN_STATUS "error" "Removing insecure package: $pkg..."
		apt remove -y "$pkg"
	else
		HARDN_STATUS "info" "Package $pkg not installed. Skipping removal."
	fi
done

HARDN_STATUS "pass" "STIG-required insecure and unnecessary services disabled/removed."
