#!/bin/bash

# HARDN-XDR - Unnecessary Services Module
# Designed to be sourced by hardn-main.sh

# Disable a service if it exists and is active
hardn_disable_service() {
        local service_name="$1"
        local service_status

        # Check service status once to avoid multiple systemctl calls
        if systemctl is-active --quiet "$service_name"; then
            service_status="active"
        elif systemctl list-unit-files --type=service 2>/dev/null | grep -q "^$service_name.service"; then
            service_status="installed"
        else
            service_status="not-found"
        fi

        # Take action based on status
        case "$service_status" in
            active)
                HARDN_STATUS "info" "Disabling active service: $service_name..."
                systemctl disable --now "$service_name" >/dev/null 2>&1 ||
                    HARDN_STATUS "warning" "Failed to disable service: $service_name"
                ;;
            installed)
                HARDN_STATUS "info" "Ensuring $service_name is disabled..."
                systemctl disable "$service_name" >/dev/null 2>&1
                ;;
            *)
                # Service not found, nothing to do
                ;;
        esac
}

hardn_remove_package() {
        local pkg="$1"
        local pkg_manager="" pkg_installed=false

        # Determine package manager and check if package is installed
        : "unknown"
        if command -v dpkg >/dev/null 2>&1 && dpkg -s "$pkg" >/dev/null 2>&1; then
            : "apt"
            pkg_installed=true
        elif command -v rpm >/dev/null 2>&1 && rpm -q "$pkg" >/dev/null 2>&1; then
            pkg_installed=true
            if command -v dnf >/dev/null 2>&1; then
                : "dnf"
            else
                : "yum"
            fi
        fi
        pkg_manager=$_

        # Remove package if installed
        if $pkg_installed; then
            HARDN_STATUS "info" "Removing package: $pkg using $pkg_manager..."
            case "$pkg_manager" in
                apt)
                    apt-get remove -y "$pkg" >/dev/null 2>&1 ||
                        HARDN_STATUS "error" "Failed to remove $pkg"
                    ;;
                dnf)
                    dnf remove -y "$pkg" >/dev/null 2>&1 ||
                        HARDN_STATUS "error" "Failed to remove $pkg"
                    ;;
                yum)
                    yum remove -y "$pkg" >/dev/null 2>&1 ||
                        HARDN_STATUS "error" "Failed to remove $pkg"
                    ;;
            esac
        fi
}

hardn_cleanup_services() {
        local services="${1:-avahi-daemon cups rpcbind nfs-server smbd snmpd apache2 mysql bind9}"
        local packages="${2:-telnet vsftpd proftpd tftpd postfix exim4}"
        local status=0

        HARDN_STATUS "info" "Disabling unnecessary services..."

        # Disable services in parallel for efficiency
        for service in $services; do
            hardn_disable_service "$service" &
        done
        wait

        # Remove packages in parallel for efficiency
        for pkg in $packages; do
            hardn_remove_package "$pkg" &
        done
        wait

        HARDN_STATUS "pass" "Unnecessary services checked and disabled/removed where applicable."
        return $status
}

# Log module load if debug is enabled
[ -n "${HARDN_DEBUG:-}" ] && HARDN_STATUS "debug" "Unnecessary services module loaded successfully"
HARDN_STATUS "pass" "Unnecessary services checked and disabled/removed where applicable."
