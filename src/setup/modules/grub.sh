#!/bin/bash

# HARDN-XDR: GRUB Bootloader Password Hardening Module for Debian 12
# (Interactive Only with Dialog + Rollback Support)

# Global variables with module prefix to avoid collisions
HARDN_GRUB_DEFAULT_USERNAME="admin"
HARDN_GRUB_BACKUP_DIR="/etc/grub.d/backups"
HARDN_GRUB_CUSTOM_FILE="/etc/grub.d/40_custom"


enforce_source() {
        # Enforce sourcing by hardn-main.sh
        if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
            echo "Error: This script must be sourced by hardn-main.sh, not executed directly." >&2
            echo "Usage: source ${BASH_SOURCE[0]}" >&2
            return 1
        fi
}

# Verify we're being sourced by the correct script
verify_correct_source() {
        if [[ ! "${BASH_SOURCE[1]}" =~ hardn-main\.sh$ ]]; then
            echo "Error: This script must be sourced by hardn-main.sh" >&2
            return 1
        fi
}


# Verify HARDN_XDR_ROOT is set (should be set by hardn-main.sh)
verify_xdr_root_set() {
    if [[ -z "${HARDN_XDR_ROOT}" ]]; then
        echo "Error: HARDN_XDR_ROOT environment variable not set" >&2
        echo "This script must be sourced by hardn-main.sh" >&2
        return 1
    fi
}

# Prompt user for password using dialog and hash it
hardn_grub_prompt_for_password_hash() {
        # Check for dialog dependency
        command -v dialog >/dev/null 2>&1 || {
            printf " 'dialog' is required for interactive password prompts.\n" >&2
            return 1
        }

        # Create secure temporary files
        local tmp1 tmp2 password password_confirm
        tmp1=$(mktemp) || return 1
        tmp2=$(mktemp) || { rm -f "$tmp1"; return 1; }

        # Clean up temp files on exit
        trap 'rm -f "$tmp1" "$tmp2"' RETURN

        # Get and confirm password
        dialog --title "GRUB Password" --passwordbox "Enter a strong password for GRUB (min 10 characters):" 10 60 2>"$tmp1"
        dialog --title "Confirm Password" --passwordbox "Re-enter the password to confirm:" 10 60 2>"$tmp2"

        read -r password < "$tmp1"
        read -r password_confirm < "$tmp2"

        # Validate password
        [[ "$password" != "$password_confirm" ]] && {
            dialog --msgbox " Passwords do not match." 8 40
            return 1
        }

        [[ ${#password} -lt 10 ]] && {
            dialog --msgbox " Password must be at least 10 characters long." 8 50
            return 1
        }

        # Ensure expect is available
        command -v expect >/dev/null 2>&1 || {
        printf "Installing 'expect' for password hashing...\n"
        apt-get update -qq && apt-get install -y expect
}

        # Generate password hash
        local hash
        hash=$(expect << EOF
        spawn grub-mkpasswd-pbkdf2
        expect "Enter password:"
        send "$password\r"
        expect "Reenter Password:"
        send "$password\r"
        expect "PBKDF2 hash:"
        expect eof
EOF
    awk '/PBKDF2/ { print $NF }')
}


# Backup the current 40_custom config
hardn_grub_backup_config() {
    mkdir -p "$HARDN_GRUB_BACKUP_DIR"
    cp "$HARDN_GRUB_CUSTOM_FILE" "$HARDN_GRUB_BACKUP_DIR/40_custom.bak.$(date +%F-%H%M%S)" || return 1
    printf "Backup of GRUB custom config saved to %s.\n" "$HARDN_GRUB_BACKUP_DIR"
    return 0
}

# Restore the most recent backup
hardn_grub_rollback_config() {
        local latest_backup
        latest_backup=$(find "$HARDN_GRUB_BACKUP_DIR" -name "40_custom.bak.*" -type f -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)

        if [[ -n "$latest_backup" ]]; then
            cp "$latest_backup" "$HARDN_GRUB_CUSTOM_FILE" || return 1
            printf "Restored GRUB configuration from backup: %s\n" "$latest_backup"
            hardn_grub_regenerate || return 1
        else
            printf "No backup found to restore.\n" >&2
            return 1
        fi
        return 0
}

# Write GRUB config with password
hardn_grub_update_config() {
        local hash="$1"
        [[ -z "$hash" ]] && return 1

    cat > "$HARDN_GRUB_CUSTOM_FILE" <<EOF
#!/bin/sh
set superusers="$HARDN_GRUB_DEFAULT_USERNAME"
password_pbkdf2 $HARDN_GRUB_DEFAULT_USERNAME $hash
exec tail -n +4 \$0
EOF

    chmod +x "$HARDN_GRUB_CUSTOM_FILE" || return 1
    printf "GRUB custom configuration updated.\n"
    return 0
}

# Regenerate grub.cfg for Debian 12
hardn_grub_regenerate() {
        printf " Regenerating GRUB configuration...\n"

        if command -v update-grub >/dev/null 2>&1; then
            update-grub
        elif command -v grub-mkconfig >/dev/null 2>&1; then
            grub-mkconfig -o /boot/grub/grub.cfg
        else
            printf " Could not regenerate GRUB config.\n" >&2
            return 1
        fi

        printf " GRUB config regenerated.\n"
        return 0
}

# Main function to secure GRUB
hardn_grub_secure() {
        printf " Securing GRUB with password (interactive)...\n"

        enforce_source

        local password_hash
        password_hash=$(hardn_grub_prompt_for_password_hash) || {
            printf " Aborted: Password prompt failed.\n"
            return 1
        }

        hardn_grub_backup_config || return 1

        hardn_grub_update_config "$password_hash" || {
            printf " Failed to update config. Rolling back.\n"
            hardn_grub_rollback_config
            return 1
        }

        hardn_grub_regenerate || {
            printf " GRUB regeneration failed. Rolling back.\n"
            hardn_grub_rollback_config
            return 1
        }

        printf " GRUB password protection enabled.\n"
        printf "Username: %s\n" "$HARDN_GRUB_DEFAULT_USERNAME"
        printf "Please reboot to test password protection.\n"
        return 0
}

# Export functions for use by hardn-main.sh
# Only export the main entry point function to minimize global namespace pollution
export -f hardn_grub_secure

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced by hardn-main.sh, not executed directly." >&2
    exit 1
fi


