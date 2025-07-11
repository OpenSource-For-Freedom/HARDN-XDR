#!/bin/bash

# Function to check for deleted files in use
hardn_check_deleted_files() {
    HARDN_STATUS "info" "Checking for deleted files in use..."

    if ! command -v lsof >/dev/null 2>&1; then
        HARDN_STATUS "error" "lsof command not found. Cannot check for deleted files in use."
        return 1
    fi

    local deleted_files
    deleted_files=$(lsof +L1 2>/dev/null | awk '$0 !~ /^$/ {print $9}' | grep -v '^$')

    if [[ -n "$deleted_files" ]]; then
        HARDN_STATUS "warning" "Found deleted files in use:"
        printf "%s\n" "$deleted_files"
        HARDN_STATUS "warning" "Please consider rebooting the system to release these files."
        return 2
    else
        HARDN_STATUS "pass" "No deleted files in use found."
        return 0
    fi
}

# This script is meant to be sourced, not executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    printf "Error: This script should be sourced by hardn-main.sh, not executed directly.\n" >&2
    exit 1
fi
