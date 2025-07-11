#!/bin/bash

# HARDN-XDR GRUB Hardening Module 
# Securely hardens GRUB without breaking boot


LOG_DIR="/var/log/hardn"
LOG_FILE="$LOG_DIR/grub_hardening.log"
VERIFICATION_LOG="$LOG_DIR/grub_verification.log"

HARDN_STATUS() {
    local status="$1"
    local message="$2"
    local color="\033[0m"
    case "$status" in
        info) color="\033[1;34m" ;;
        pass) color="\033[1;32m" ;;
        warning) color="\033[1;33m" ;;
        error) color="\033[1;31m" ;;
    esac
    echo -e "${color}[${status^^}]\033[0m $message"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

backup_grub_default() {
    local file="/etc/default/grub"
    if [ -f "$file" ]; then
        cp "$file" "${file}.bak.$(date +%F_%H%M%S)"
        chmod 644 "${file}.bak."*
        HARDN_STATUS "info" "Backup of $file created."
    fi
}

safely_disable_recovery_mode() {
    local grub_default="/etc/default/grub"
    if [ ! -f "$grub_default" ]; then
        HARDN_STATUS "warning" "$grub_default not found."
        return 0
    fi

    if grep -q 'GRUB_DISABLE_RECOVERY="true"' "$grub_default"; then
        HARDN_STATUS "info" "Recovery mode already disabled."
        return 0
    fi

    if grep -q "GRUB_DISABLE_RECOVERY" "$grub_default"; then
        sed -i 's/GRUB_DISABLE_RECOVERY=.*/GRUB_DISABLE_RECOVERY="true"/' "$grub_default"
    else
        echo 'GRUB_DISABLE_RECOVERY="true"' >> "$grub_default"
    fi
    HARDN_STATUS "pass" "Recovery mode disabled."
}

fix_grub_permissions() {
    [ -f /etc/default/grub ] && chmod 644 /etc/default/grub
    [ -f /boot/grub/grub.cfg ] && chmod 644 /boot/grub/grub.cfg
    [ -f /boot/grub2/grub.cfg ] && chmod 644 /boot/grub2/grub.cfg
    HARDN_STATUS "info" "Set readable permissions for GRUB config files."
}

regenerate_grub_safely() {
    if command -v update-grub >/dev/null 2>&1; then
        update-grub && HARDN_STATUS "pass" "GRUB config regenerated."
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        grub2-mkconfig -o /boot/grub2/grub.cfg && HARDN_STATUS "pass" "GRUB config regenerated (grub2-mkconfig)."
    else
        HARDN_STATUS "warning" "Could not regenerate GRUB config. Please do so manually."
    fi
}

verify_and_log() {
    mkdir -p "$LOG_DIR"
    {
        echo "=== GRUB Hardening Verification ==="
        echo "Date: $(date)"
        grep 'GRUB_DISABLE_RECOVERY' /etc/default/grub || echo "Missing GRUB_DISABLE_RECOVERY setting"
        [ -f /etc/default/grub ] && stat -c "/etc/default/grub: %a %U:%G" /etc/default/grub
        [ -f /boot/grub/grub.cfg ] && stat -c "/boot/grub/grub.cfg: %a %U:%G" /boot/grub/grub.cfg
        [ -f /boot/grub2/grub.cfg ] && stat -c "/boot/grub2/grub.cfg: %a %U:%G" /boot/grub2/grub.cfg
        echo "=== End of Verification ==="
    } > "$VERIFICATION_LOG"
    chmod 600 "$VERIFICATION_LOG"
    HARDN_STATUS "info" "Verification log saved to $VERIFICATION_LOG"
}

grub_hardening_module() {
    HARDN_STATUS "info" "Starting GRUB hardening module..."
    mkdir -p "$LOG_DIR"
    touch "$LOG_FILE" && chmod 600 "$LOG_FILE"

    backup_grub_default
    safely_disable_recovery_mode
    fix_grub_permissions
    regenerate_grub_safely
    verify_and_log

    HARDN_STATUS "pass" "GRUB hardening module completed."
    return 0
}

# Only run if executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    grub_hardening_module "$@"
fi