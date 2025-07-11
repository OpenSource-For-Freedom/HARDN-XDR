#!/bin/bash

# HARDN-XDR - Unhide Module
# Designed to be sourced by hardn-main.sh

# Install and configure unhide tool
hardn_unhide_setup() {
    local pkg_manager status=0

    # Determine package manager
    if command -v apt >/dev/null 2>&1; then
        pkg_manager="apt"
    elif command -v dnf >/dev/null 2>&1; then
        pkg_manager="dnf"
    elif command -v yum >/dev/null 2>&1; then
        pkg_manager="yum"
    else
        HARDN_STATUS "error" "No supported package manager found"
        return 1
    fi

    # Install unhide based on package manager
    HARDN_STATUS "info" "Installing unhide..."
    case "$pkg_manager" in
        apt)
            apt update -qq >/dev/null 2>&1
            apt install -y unhide >/dev/null 2>&1 || status=1
            ;;
        dnf)
            dnf install -y unhide >/dev/null 2>&1 || status=1
            ;;
        yum)
            yum install -y unhide >/dev/null 2>&1 || status=1
            ;;
    esac

    # Verify installation
    if command -v unhide >/dev/null 2>&1; then
        local version
        version=$(unhide -v 2>&1 | head -n1)
        HARDN_STATUS "pass" "Unhide installed successfully: $version"
    else
        HARDN_STATUS "error" "Failed to install unhide"
        return 1
    fi

    return $status
}

# Run unhide scan
hardn_unhide_scan() {
    local scan_type="${1:-all}"
    local status=0

    HARDN_STATUS "info" "Running unhide scan ($scan_type)..."

    case "$scan_type" in
        proc)
            unhide proc >/dev/null || status=1
            ;;
        sys)
            unhide sys >/dev/null || status=1
            ;;
        brute)
            unhide brute >/dev/null || status=1
            ;;
        all)
            # Run scans in parallel for efficiency
            unhide proc >/dev/null &
            pid1=$!
            unhide sys >/dev/null &
            pid2=$!
            wait $pid1 || status=1
            wait $pid2 || status=1
            ;;
        *)
            HARDN_STATUS "error" "Invalid scan type: $scan_type"
            return 1
            ;;
    esac

    if [ $status -eq 0 ]; then
        HARDN_STATUS "pass" "Unhide scan completed successfully"
    else
        HARDN_STATUS "warning" "Unhide scan completed with issues"
    fi

    return $status
}

# Display usage information
hardn_unhide_usage() {
    HARDN_STATUS "info" "Usage examples:"
    HARDN_STATUS "info" "  hardn_unhide_scan proc  # Scan using /proc"
    HARDN_STATUS "info" "  hardn_unhide_scan sys   # Scan using /sys"
    HARDN_STATUS "info" "  hardn_unhide_scan brute # Brute force scan"
    HARDN_STATUS "info" "  hardn_unhide_scan all   # Run all scan types"
}

# Log module load if debug is enabled
[ -n "${HARDN_DEBUG:-}" ] && HARDN_STATUS "debug" "Unhide module loaded successfully"
