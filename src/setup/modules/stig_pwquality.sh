#!/bin/bash
# STIG password quality module for HARDN-XDR
# This script is designed to be sourced by hardn-main.sh

# Configure PAM password quality according to STIG requirements
hardn_configure_pam_pwquality() {
    local pam_file="/etc/pam.d/common-password"
    local alt_files=("/etc/pam.d/system-auth" "/etc/pam.d/password-auth")
    local pwquality_line="password requisite pam_pwquality.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1"
    local status=0

    HARDN_STATUS "info" "Configuring PAM password quality..."

    # Find appropriate PAM configuration file
    if [ ! -f "$pam_file" ]; then
        for alt_file in "${alt_files[@]}"; do
            if [ -f "$alt_file" ]; then
                pam_file="$alt_file"
                break
            fi
        done
    fi

    # Check if PAM file exists
    if [ ! -f "$pam_file" ]; then
        HARDN_STATUS "warning" "PAM password configuration file not found, skipping configuration"
        return 1
    fi

    # Create backup of original file
    cp -f "$pam_file" "${pam_file}.hardn.bak" 2>/dev/null || {
        HARDN_STATUS "warning" "Failed to create backup of $pam_file"
        status=1
    }

    # Check if pwquality module is already configured
    if ! grep -q "pam_pwquality.so" "$pam_file"; then
        # Add pwquality configuration
        echo "$pwquality_line" >> "$pam_file" 2>/dev/null || {
            HARDN_STATUS "error" "Failed to update $pam_file"
            return 1
        }
        HARDN_STATUS "pass" "Added password quality requirements to $pam_file"
    else
        HARDN_STATUS "info" "PAM password quality already configured in $pam_file"
    fi

    return $status
}
