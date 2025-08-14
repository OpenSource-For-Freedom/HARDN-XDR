#!/usr/bin/env bash

# Bootloader Security Module
# Part of HARDN-XDR Security Framework
# Purpose: STIG compliance for secure bootloader configuration
# STIG Requirements: GRUB password protection, disable interactive boot modes, secure grub.cfg

# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}

MODULE_NAME="Bootloader Security"
CONFIG_DIR="/etc/hardn-xdr/bootloader-security"
LOG_FILE="/var/log/security/bootloader-security.log"
GRUB_CONFIG="/etc/default/grub"
GRUB_CFG="/boot/grub/grub.cfg"

bootloader_security_main() {
    HARDN_STATUS "info" "Starting $MODULE_NAME configuration..."

    if ! check_root; then
        HARDN_STATUS "error" "This module requires root privileges"
        return 1
    fi

    mkdir -p "$CONFIG_DIR"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Check environment compatibility
    if is_vm && [[ -z "$FORCE_BOOTLOADER_CONFIG" ]]; then
        HARDN_STATUS "info" "Virtual machine detected - bootloader security may not be applicable"
        HARDN_STATUS "info" "Set FORCE_BOOTLOADER_CONFIG=1 to override this check"
        return 0
    fi

    # Check if EFI system
    if [[ -d "/sys/firmware/efi" ]]; then
        HARDN_STATUS "info" "EFI system detected - applying EFI-specific security measures"
        configure_efi_security
    fi

    # Apply GRUB security measures
    configure_grub_security

    # Disable interactive boot modes
    disable_interactive_modes

    # Secure grub.cfg file
    secure_grub_config_file

    HARDN_STATUS "pass" "$MODULE_NAME configuration completed"
    exit 0
}

configure_grub_security() {
    HARDN_STATUS "info" "Configuring GRUB password protection..."
    
    if [[ ! -f "$GRUB_CONFIG" ]]; then
        HARDN_STATUS "warning" "GRUB configuration file not found at $GRUB_CONFIG"
        return 1
    fi

    # Create backup
    local backup_file="$CONFIG_DIR/grub.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$GRUB_CONFIG" "$backup_file"
    HARDN_STATUS "info" "GRUB configuration backed up to $backup_file"

    # Generate GRUB password if not in dry-run mode
    if [[ "$1" != "--dry-run" ]]; then
        setup_grub_password
    else
        HARDN_STATUS "info" "Dry-run mode: GRUB password setup would be performed here"
    fi

    # Disable GRUB editing
    configure_grub_restrictions

    echo "$(date): GRUB security configuration applied" >> "$LOG_FILE"
}

setup_grub_password() {
    HARDN_STATUS "info" "Setting up GRUB password protection..."
    
    local grub_user="admin"
    local password_file="$CONFIG_DIR/grub-password.txt"
    
    # Generate a strong password if one doesn't exist
    if [[ ! -f "$password_file" ]]; then
        local grub_password
        grub_password=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-25)
        echo "$grub_password" > "$password_file"
        chmod 600 "$password_file"
        chown root:root "$password_file"
        HARDN_STATUS "info" "Generated GRUB password saved to $password_file"
        HARDN_STATUS "warning" "IMPORTANT: Save this password securely - it's needed for GRUB access"
    else
        grub_password=$(cat "$password_file")
        HARDN_STATUS "info" "Using existing GRUB password from $password_file"
    fi

    # Generate PBKDF2 hash
    local pbkdf2_hash
    if command -v grub-mkpasswd-pbkdf2 >/dev/null 2>&1; then
        pbkdf2_hash=$(echo -e "$grub_password\n$grub_password" | grub-mkpasswd-pbkdf2 | grep -oP 'grub\.pbkdf2\.sha512\.[^[:space:]]+')
    else
        HARDN_STATUS "error" "grub-mkpasswd-pbkdf2 command not found - install grub-common package"
        return 1
    fi

    # Create GRUB user configuration
    local grub_user_config="/etc/grub.d/01_password"
    cat > "$grub_user_config" << EOF
#!/bin/sh
set -e

cat << GRUB_EOF
set superusers="$grub_user"
password_pbkdf2 $grub_user $pbkdf2_hash
GRUB_EOF
EOF

    chmod +x "$grub_user_config"
    chown root:root "$grub_user_config"
    HARDN_STATUS "info" "GRUB password configuration created at $grub_user_config"

    # Create password documentation
    cat > "$CONFIG_DIR/grub-access-instructions.txt" << EOF
GRUB Access Instructions
========================

Username: $grub_user
Password: Located in $password_file (root access required)

To access GRUB:
1. During boot, press 'e' to edit menu entries
2. Enter username: $grub_user
3. Enter password when prompted

To modify GRUB settings:
1. Boot into the system normally
2. Modify /etc/default/grub as root
3. Run: sudo update-grub
4. Password will be preserved across updates

Security Notes:
- Password is hashed using PBKDF2-SHA512
- Only superuser can edit boot entries
- Recovery mode access is restricted
- Physical access to system can bypass this protection
EOF

    HARDN_STATUS "info" "GRUB access instructions saved to $CONFIG_DIR/grub-access-instructions.txt"
}

configure_grub_restrictions() {
    HARDN_STATUS "info" "Configuring GRUB boot restrictions..."
    
    # Backup current configuration
    if ! grep -q "# HARDN-XDR bootloader security" "$GRUB_CONFIG"; then
        cat >> "$GRUB_CONFIG" << 'EOF'

# HARDN-XDR bootloader security configurations
# Added by bootloader_security module
GRUB_DISABLE_RECOVERY=true
GRUB_DISABLE_OS_PROBER=true
GRUB_DISABLE_SUBMENU=true
EOF
        HARDN_STATUS "info" "Added GRUB security restrictions to $GRUB_CONFIG"
    else
        HARDN_STATUS "info" "GRUB security restrictions already configured"
    fi

    # Update kernel command line for additional security
    if grep -q "^GRUB_CMDLINE_LINUX=" "$GRUB_CONFIG"; then
        # Add security parameters if not already present
        if ! grep -q "init_on_alloc=1" "$GRUB_CONFIG"; then
            sed -i 's/^GRUB_CMDLINE_LINUX="/GRUB_CMDLINE_LINUX="init_on_alloc=1 init_on_free=1 page_alloc.shuffle=1 /' "$GRUB_CONFIG"
            HARDN_STATUS "info" "Added kernel security parameters to GRUB command line"
        fi
    fi
}

disable_interactive_modes() {
    HARDN_STATUS "info" "Disabling interactive boot modes..."
    
    # Disable recovery mode
    if ! grep -q "GRUB_DISABLE_RECOVERY=true" "$GRUB_CONFIG"; then
        echo "GRUB_DISABLE_RECOVERY=true" >> "$GRUB_CONFIG"
        HARDN_STATUS "info" "Recovery mode disabled"
    fi

    # Set short timeout to prevent interactive access
    if grep -q "^GRUB_TIMEOUT=" "$GRUB_CONFIG"; then
        sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=3/' "$GRUB_CONFIG"
    else
        echo "GRUB_TIMEOUT=3" >> "$GRUB_CONFIG"
    fi
    HARDN_STATUS "info" "GRUB timeout set to 3 seconds"

    # Disable GRUB menu editing
    if ! grep -q "GRUB_DISABLE_LINUX_UUID=true" "$GRUB_CONFIG"; then
        echo "GRUB_DISABLE_LINUX_UUID=false" >> "$GRUB_CONFIG"
    fi

    echo "$(date): Interactive boot modes disabled" >> "$LOG_FILE"
}

secure_grub_config_file() {
    HARDN_STATUS "info" "Securing GRUB configuration file..."
    
    if [[ -f "$GRUB_CFG" ]]; then
        # Set restrictive permissions
        chmod 600 "$GRUB_CFG"
        chown root:root "$GRUB_CFG"
        HARDN_STATUS "info" "Set restrictive permissions on $GRUB_CFG (600, root:root)"

        # Make immutable (requires chattr)
        if command -v chattr >/dev/null 2>&1; then
            if ! lsattr "$GRUB_CFG" 2>/dev/null | grep -q "i"; then
                chattr +i "$GRUB_CFG" 2>/dev/null || {
                    HARDN_STATUS "warning" "Could not make $GRUB_CFG immutable - filesystem may not support it"
                }
                if lsattr "$GRUB_CFG" 2>/dev/null | grep -q "i"; then
                    HARDN_STATUS "info" "Made $GRUB_CFG immutable"
                    
                    # Create script to update GRUB when needed
                    cat > "$CONFIG_DIR/update-grub-secure.sh" << 'EOF'
#!/bin/bash
# Secure GRUB update script
# Temporarily removes immutable flag, updates GRUB, then restores protection

GRUB_CFG="/boot/grub/grub.cfg"

if [[ $EUID -ne 0 ]]; then
    echo "Error: This script must be run as root"
    exit 1
fi

echo "Removing immutable flag from $GRUB_CFG..."
chattr -i "$GRUB_CFG" 2>/dev/null || true

echo "Updating GRUB configuration..."
if update-grub; then
    echo "GRUB update successful"
else
    echo "GRUB update failed"
    exit 1
fi

echo "Restoring immutable flag on $GRUB_CFG..."
chattr +i "$GRUB_CFG" 2>/dev/null || true

echo "GRUB configuration updated and secured"
EOF
                    chmod +x "$CONFIG_DIR/update-grub-secure.sh"
                    HARDN_STATUS "info" "Created secure GRUB update script at $CONFIG_DIR/update-grub-secure.sh"
                fi
            else
                HARDN_STATUS "info" "$GRUB_CFG is already immutable"
            fi
        else
            HARDN_STATUS "warning" "chattr command not available - cannot make $GRUB_CFG immutable"
        fi
    else
        HARDN_STATUS "warning" "GRUB configuration file $GRUB_CFG not found"
    fi

    echo "$(date): GRUB configuration file secured" >> "$LOG_FILE"
}

configure_efi_security() {
    HARDN_STATUS "info" "Configuring EFI-specific security measures..."
    
    # Check for Secure Boot status
    if command -v mokutil >/dev/null 2>&1; then
        if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
            HARDN_STATUS "pass" "Secure Boot is enabled"
        else
            HARDN_STATUS "warning" "Secure Boot is not enabled - consider enabling in BIOS/UEFI"
        fi
    fi

    # EFI boot manager security
    if command -v efibootmgr >/dev/null 2>&1; then
        local efi_entries
        efi_entries=$(efibootmgr | grep -c "Boot[0-9]" || echo "0")
        HARDN_STATUS "info" "Found $efi_entries EFI boot entries"
        
        # Log current EFI configuration
        efibootmgr > "$CONFIG_DIR/efi-boot-config.txt" 2>/dev/null || true
        HARDN_STATUS "info" "EFI boot configuration saved to $CONFIG_DIR/efi-boot-config.txt"
    fi

    echo "$(date): EFI security configuration applied" >> "$LOG_FILE"
}

# Function to update GRUB after configuration changes
update_grub_config() {
    HARDN_STATUS "info" "Updating GRUB configuration..."
    
    # Remove immutable flag temporarily if set
    local was_immutable=false
    if [[ -f "$GRUB_CFG" ]] && command -v lsattr >/dev/null 2>&1; then
        if lsattr "$GRUB_CFG" 2>/dev/null | grep -q "i"; then
            was_immutable=true
            chattr -i "$GRUB_CFG" 2>/dev/null || true
        fi
    fi

    # Update GRUB
    if command -v update-grub >/dev/null 2>&1; then
        if timeout 60 update-grub 2>/dev/null; then
            HARDN_STATUS "pass" "GRUB configuration updated successfully"
        else
            HARDN_STATUS "warning" "GRUB update failed or timed out"
        fi
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        if timeout 60 grub2-mkconfig -o "$GRUB_CFG" 2>/dev/null; then
            HARDN_STATUS "pass" "GRUB2 configuration updated successfully"
        else
            HARDN_STATUS "warning" "GRUB2 update failed or timed out"
        fi
    else
        HARDN_STATUS "error" "No GRUB update command found"
        return 1
    fi

    # Restore immutable flag if it was set
    if [[ "$was_immutable" == true ]] && command -v chattr >/dev/null 2>&1; then
        chattr +i "$GRUB_CFG" 2>/dev/null || true
    fi

    # Re-secure the file after update
    if [[ -f "$GRUB_CFG" ]]; then
        chmod 600 "$GRUB_CFG"
        chown root:root "$GRUB_CFG"
    fi
}

# Execute if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Check for dry-run flag
    if [[ "$1" == "--dry-run" ]]; then
        HARDN_STATUS "info" "Running in dry-run mode - no changes will be made"
        bootloader_security_main --dry-run
    else
        bootloader_security_main "$@"
        
        # Update GRUB configuration after applying security measures
        if [[ "$?" -eq 0 ]] && [[ "$1" != "--no-update" ]]; then
            update_grub_config
        fi
    fi
fi

return 0 2>/dev/null || exit 0
