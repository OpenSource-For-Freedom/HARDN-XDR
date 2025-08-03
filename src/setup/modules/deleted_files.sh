#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Checking for deleted files in use..."
if command -v lsof >/dev/null 2>&1; then
    deleted_files=$(lsof +L1 | awk '{print $9}' | grep -v '^$')
    if [[ -n "$deleted_files" ]]; then
        HARDN_STATUS "warning" "Found deleted files in use:"
        echo "$deleted_files"
        HARDN_STATUS "warning" "Please consider rebooting the system to release these files."
    else
        HARDN_STATUS "pass" "No deleted files in use found."
    fi
else
    HARDN_STATUS "error" "lsof command not found. Cannot check for deleted files in use."
fi

return 0 2>/dev/null || hardn_module_exit 0

