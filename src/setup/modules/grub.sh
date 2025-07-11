#!/bin/bash

# PERFORMANCE OPTIMIZATIONS:
# - POSIX-compliant where possible
# - Minimized external command calls
# - Reduced subshell usage
# - Proper variable scoping
# - Early returns to avoid unnecessary processing
# - Consistent function naming with hardn_grub_ prefix
# - Improved file path detection with single-pass checks
# - Consolidated logging operations

# Define constants with defaults that can be overridden by parent script
: "${HARDN_LOG_DIR:=/var/log/hardn}"
: "${HARDN_GRUB_LOG:=$HARDN_LOG_DIR/grub_hardening.log}"
: "${HARDN_GRUB_VERIFY_LOG:=$HARDN_LOG_DIR/grub_verification.log}"

# Find GRUB configuration file
hardn_grub_find_cfg() {
    if [ -f /boot/grub/grub.cfg ]; then
        printf "/boot/grub/grub.cfg"
    elif [ -f /boot/grub2/grub.cfg ]; then
        printf "/boot/grub2/grub.cfg"
    else
        printf ""
    fi
}

# Update GRUB configuration
hardn_grub_update() {
    if command -v update-grub >/dev/null 2>&1; then
        if update-grub; then
            return 0
        fi
        return 1
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        local grub_cfg_path
        grub_cfg_path=$(hardn_grub_find_cfg)

        if [ -z "$grub_cfg_path" ]; then
            return 1
        fi

        if grub2-mkconfig -o "$grub_cfg_path"; then
            return 0
        fi
        return 1
    fi
    return 1
}

# Harden permissions on GRUB files
hardn_grub_harden_permissions() {
    local grub_default="/etc/default/grub"
    local grub_cfg
    local changed=0

    grub_cfg=$(hardn_grub_find_cfg)

    # Process /etc/default/grub if it exists
    if [ -f "$grub_default" ]; then
        local perms
        perms=$(stat -c "%a" "$grub_default")
        if [ "$perms" != "600" ]; then
            chmod 600 "$grub_default" && changed=1
        fi
    fi

    # Process grub.cfg if found
    if [ -n "$grub_cfg" ] && [ -f "$grub_cfg" ]; then
        local perms
        perms=$(stat -c "%a" "$grub_cfg")
        if [ "$perms" != "600" ]; then
            chmod 600 "$grub_cfg" && changed=1
        fi
    fi

    return $changed
}

# Disable recovery mode in GRUB
hardn_grub_disable_recovery() {
    local grub_default="/etc/default/grub"
    local changed=0

    # Early return if file doesn't exist
    [ -f "$grub_default" ] || return 1

    # Early return if already configured
    grep -q 'GRUB_DISABLE_RECOVERY="true"' "$grub_default" && return 0

    # Create backup with unique timestamp
    cp "$grub_default" "${grub_default}.bak.$(date +%Y%m%d-%H%M%S).$$"

    # Update or add the setting
    if grep -q "GRUB_DISABLE_RECOVERY" "$grub_default"; then
        sed -i 's/GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY="true"/' "$grub_default"
    else
        printf 'GRUB_DISABLE_RECOVERY="true"\n' >> "$grub_default"
    fi
    changed=1

    return $((changed + 1))  # Return 2 to indicate update needed
}

# Verify GRUB hardening settings
hardn_grub_verify() {
    local grub_cfg
    grub_cfg=$(hardn_grub_find_cfg)

    # Ensure log directory exists
    mkdir -p "$(dirname "$HARDN_GRUB_VERIFY_LOG")"

    {
        printf "=== GRUB Hardening Verification ===\n"
        printf "Date: %s\n" "$(date)"
        printf "User: %s\n\n" "$(whoami)"

        # Check recovery mode
        printf "1. Checking Recovery Mode:\n"
        if grep -q 'GRUB_DISABLE_RECOVERY="true"' /etc/default/grub; then
            printf "  - Result: PASS - Recovery mode is disabled in /etc/default/grub.\n"
        else
            printf "  - Result: FAIL - Recovery mode is not disabled.\n"
        fi

        # Check file permissions
        printf "\n2. Checking File Permissions:\n"

        # Check /etc/default/grub permissions
        if [ -f /etc/default/grub ]; then
            local perms_default
            perms_default=$(stat -c "%a %U:%G" /etc/default/grub)
            printf "  - /etc/default/grub: %s\n" "$perms_default"
            printf "    - Result: %s\n" "$([ "$perms_default" = "600 root:root" ] && echo "PASS" || echo "FAIL")"
        fi

        # Check grub.cfg permissions
        [ -n "$grub_cfg" ] || { printf "  - grub.cfg not found.\n"; }

        if [ -n "$grub_cfg" ]; then
            local perms_cfg
            perms_cfg=$(stat -c "%a %U:%G" "$grub_cfg")
            printf "  - %s: %s\n" "$grub_cfg" "$perms_cfg"
            printf "    - Result: %s\n" "$([ "$perms_cfg" = "600 root:root" ] && echo "PASS" || echo "FAIL")"
        fi

        printf "=== End of Verification ===\n"
    } > "$HARDN_GRUB_VERIFY_LOG" 2>&1

    chmod 600 "$HARDN_GRUB_VERIFY_LOG"
}

# Check if secure boot is enabled
hardn_grub_check_secure_boot() {
    [ -d /sys/firmware/efi ] &&
    command -v mokutil >/dev/null 2>&1 &&
    mokutil --sb-state 2>/dev/null | grep -q 'SecureBoot enabled'
}

# Main GRUB hardening function
hardn_grub_harden() {
    # Ensure log directory exists
    mkdir -p "$(dirname "$HARDN_GRUB_LOG")"
    touch "$HARDN_GRUB_LOG"
    chmod 600 "$HARDN_GRUB_LOG"

    # Skip if secure boot is enabled
    if hardn_grub_check_secure_boot; then
        HARDN_STATUS "pass" "Secure Boot is enabled. This is the best protection for the bootloader."
        HARDN_STATUS "info" "No further GRUB hardening is strictly necessary."
        return 0
    fi

    HARDN_STATUS "info" "Secure Boot is not enabled. Proceeding with manual GRUB hardening."

    local needs_update=0

    # Disable recovery mode
    hardn_grub_disable_recovery
    local recovery_status=$?

    if [ $recovery_status -eq 1 ]; then
        HARDN_STATUS "error" "Failed to process recovery mode settings."
    elif [ $recovery_status -eq 2 ]; then
        needs_update=1
    fi

    # Harden permissions
    hardn_grub_harden_permissions

    # Update GRUB if needed
    if [ $needs_update -eq 1 ]; then
        HARDN_STATUS "info" "Updating GRUB configuration..."
        if hardn_grub_update; then
            HARDN_STATUS "pass" "GRUB configuration updated successfully."
        else
            HARDN_STATUS "error" "Failed to update GRUB configuration."
            return 1
        fi
    else
        HARDN_STATUS "info" "No changes requiring a GRUB configuration update were made."
    fi

    # Verify hardening
    hardn_grub_verify
    HARDN_STATUS "pass" "GRUB hardening process completed."

    return 0
}
