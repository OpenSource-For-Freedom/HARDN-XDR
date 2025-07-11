#!/bin/bash
# Service disabling module for HARDN-XDR
# This script is designed to be sourced by hardn-main.sh

hardn_service_disable() {
    local service_name="$1" status=0 service_state=""

    # Determine service state
    if systemctl is-active --quiet "$service_name"; then
        service_state="active"
    elif systemctl list-unit-files --type=service | grep -qw "^$service_name.service"; then
        service_state="installed"
    else
        service_state="not_found"
    fi

    # Handle service based on its state
    case "$service_state" in
        active)
            HARDN_STATUS "info" "Disabling active service: $service_name..."
            if systemctl disable --now "$service_name"; then
                HARDN_STATUS "pass" "Successfully disabled active service: $service_name"
            else
                HARDN_STATUS "warning" "Failed to disable service: $service_name"
                status=1
            fi
            ;;
        installed)
            HARDN_STATUS "info" "Service $service_name is not active, disabling..."
            if systemctl disable "$service_name"; then
                HARDN_STATUS "pass" "Successfully disabled service: $service_name"
            else
                HARDN_STATUS "warning" "Failed to disable service: $service_name"
                status=1
            fi
            ;;
        not_found)
            HARDN_STATUS "info" "Service $service_name not found. Skipping."
            ;;
    esac

    return $status
}

hardn_service_disable_multiple() {
    local services=("$@") pids=() max_jobs=5

    HARDN_STATUS "info" "Disabling specified services in parallel..."

    # Process services in parallel with job control
    for service in "${services[@]}"; do
        (hardn_service_disable "$service") &
        pids+=($!)

        # Limit concurrent processes
        [[ ${#pids[@]} -ge $max_jobs ]] && { wait "${pids[0]}"; pids=("${pids[@]:1}"); }
    done

    # Wait for remaining processes
    [[ ${#pids[@]} -gt 0 ]] && wait "${pids[@]}"

    HARDN_STATUS "info" "Service disabling completed."
    return 0
}

# Legacy function name for backward compatibility
hardn_spec_srv() {
    hardn_service_disable "$1"
    return $?
}
