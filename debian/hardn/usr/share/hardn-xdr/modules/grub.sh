#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'


LOG_DIR="/var/log/hardn"
LOG_FILE="$LOG_DIR/grub_hardening.log"

HARDN_STATUS() {
    local status="$1"
    local message="$2"
    local color="$RESET"
    case "$status" in
        "info")    color="$BLUE" ;;
        "pass")    color="$GREEN" ;;
        "warning") color="$YELLOW" ;;
        "error")   color="$RED" ;;
    esac
    echo -e "${BOLD}${color}[${status^^}]${RESET} $message"
}


log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

error() {
    HARDN_STATUS "error" "$1"
    log "ERROR: $1"

   
    if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
        exit 1
    else
      
        return 0
    fi
}

success() {
    HARDN_STATUS "pass" "$1"
    log "SUCCESS: $1"
}

info() {
    HARDN_STATUS "info" "$1"
    log "INFO: $1"
}

warning() {
    HARDN_STATUS "warning" "$1"
    log "WARNING: $1"
}


check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root"
        return 1
    fi
    return 0
}


update_grub() {
    info "Regenerating GRUB configuration..."
    if command -v update-grub >/dev/null 2>&1; then
        if update-grub; then
            success "GRUB configuration regenerated successfully."
            return 0
        else
            error "Failed to regenerate GRUB configuration with update-grub."
            return 1
        fi
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        local grub_cfg_path
        if [ -f /boot/grub2/grub.cfg ]; then
            grub_cfg_path="/boot/grub2/grub.cfg"
        elif [ -f /boot/grub/grub.cfg ]; then
            grub_cfg_path="/boot/grub/grub.cfg"
        else
            error "Could not find grub.cfg file for grub2-mkconfig."
            return 1
        fi

        if grub2-mkconfig -o "$grub_cfg_path"; then
            success "GRUB configuration regenerated successfully."
            return 0
        else
            error "Failed to regenerate GRUB configuration with grub2-mkconfig."
            return 1
        fi
    else
        error "Could not find update-grub or grub2-mkconfig. Please update GRUB configuration manually."
        return 1
    fi
}



hardn_permissions() {
    info "Hardening permissions for GRUB configuration files..."
    local changed=0
    local grub_default="/etc/default/grub"
    local grub_cfg=""

    if [ -f /boot/grub/grub.cfg ]; then
        grub_cfg="/boot/grub/grub.cfg"
    elif [ -f /boot/grub2/grub.cfg ]; then
        grub_cfg="/boot/grub2/grub.cfg"
    fi


    if [ -f "$grub_default" ]; then
        local perms
        perms=$(stat -c "%a" "$grub_default")
        if [ "$perms" != "600" ]; then
            info "Setting permissions of $grub_default to 600 (currently $perms)."
            chmod 600 "$grub_default"
            success "Permissions for $grub_default set to 600."
        else
            info "Permissions for $grub_default are already correctly set to 600."
        fi
    else
        warning "$grub_default not found. Skipping permissions hardening for it."
    fi


    if [ -n "$grub_cfg" ]; then
        local perms
        perms=$(stat -c "%a" "$grub_cfg")
        if [ "$perms" != "600" ]; then
            info "Setting permissions of $grub_cfg to 600 (currently $perms)."
            chmod 600 "$grub_cfg"
            success "Permissions for $grub_cfg set to 600."
        else
            info "Permissions for $grub_cfg are already correctly set to 600."
        fi
    else
        warning "grub.cfg not found. Skipping permissions hardening for it."
    fi
}


disable_recovery_mode() {
    info "Disabling GRUB recovery mode..."
    local grub_default="/etc/default/grub"
    local changed=0

    if [ ! -f "$grub_default" ]; then
        error "$grub_default not found. Cannot disable recovery mode."
        return 1
    fi


    if grep -q 'GRUB_DISABLE_RECOVERY="true"' "$grub_default"; then
        info "GRUB recovery mode is already disabled. No changes needed."
        return 0
    fi

    cp "$grub_default" "${grub_default}.bak.$(date +%Y%m%d-%H%M%S).$$"
    success "Backup of $grub_default created."

    if grep -q "GRUB_DISABLE_RECOVERY" "$grub_default"; then
        info "Found existing GRUB_DISABLE_RECOVERY setting. Changing it to true."
        sed -i 's/GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY="true"/' "$grub_default"
        changed=1
    else

        info "GRUB_DISABLE_RECOVERY setting not found. Adding it."
        echo 'GRUB_DISABLE_RECOVERY="true"' >> "$grub_default"
        changed=1
    fi

    if [ $changed -eq 1 ]; then
        success "Successfully configured GRUB to disable recovery mode."
        return 2
    fi

    return 0
}


verify_grub_hardening() {
    info "Verifying GRUB hardening..."
    local grub_cfg=""
    if [ -f /boot/grub/grub.cfg ]; then
        grub_cfg="/boot/grub/grub.cfg"
    fi
    if [ -f /boot/grub2/grub.cfg ]; then
        grub_cfg="/boot/grub2/grub.cfg"
    fi


    {
        echo "=== GRUB Hardening Verification ==="
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo ""
        echo "1. Checking Recovery Mode:"
        if grep -q 'GRUB_DISABLE_RECOVERY="true"' /etc/default/grub; then
            echo "  - Result: PASS - Recovery mode is disabled in /etc/default/grub."
        else
            echo "  - Result: FAIL - Recovery mode is not disabled."
        fi
        echo ""
        echo "2. Checking File Permissions:"
        local perms_default
        perms_default=$(stat -c "%a %U:%G" /etc/default/grub)
        echo "  - /etc/default/grub: $perms_default"
        if [[ "$perms_default" == "600 root:root" ]]; then
            echo "    - Result: PASS"
        else
            echo "    - Result: FAIL"
        fi

        if [ -n "$grub_cfg" ]; then
            local perms_cfg
            perms_cfg=$(stat -c "%a %U:%G" "$grub_cfg")
            echo "  - ${grub_cfg}: $perms_cfg"
            if [[ "$perms_cfg" == "600 root:root" ]]; then
                echo "    - Result: PASS"
            else
                echo "    - Result: FAIL"
            fi
        else
            echo "  - grub.cfg not found."
        fi
        echo "=== End of Verification ==="
    } > "$VERIFICATION_LOG" 2>&1

    chmod 600 "$VERIFICATION_LOG"
    success "Detailed verification log saved to $VERIFICATION_LOG"
    cat "$VERIFICATION_LOG"
}



hardn_grub() {

    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    log "--- Starting GRUB Hardening Script ---"

    check_root || return 1


    if [ -d /sys/firmware/efi ] && command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -q 'SecureBoot enabled'; then
        success "Secure Boot is enabled. This is the best protection for the bootloader."
        info "No further GRUB hardening is strictly necessary."
        log "Secure Boot enabled. Exiting."
        return 0
    else
        info "Secure Boot is not enabled. Proceeding with manual GRUB hardening."
    fi

    local needs_update=0

    disable_recovery_mode
    local recovery_status=$?
    if [ $recovery_status -eq 1 ]; then
        error "Failed to process recovery mode settings."
    elif [ $recovery_status -eq 2 ]; then
        needs_update=1
    fi

    hardn_permissions

    # If recovery mode was changed update grub
    if [ $needs_update -eq 1 ]; then
        update_grub || return 1
    else
        info "No changes requiring a GRUB configuration update were made."
    fi

    verify_grub_hardening

    success "GRUB hardening process completed."
    log "--- GRUB Hardening Script Finished ---"
    return 0
}


if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    hardn_grub "$@"
fi
