#######################################
# GRUB Configuration
# This module handles the hardening of GRUB bootloader settings
# It is part of the HARDN-XDR security hardening framework

# https://help.ubuntu.com/community/Grub2/Passwords
# Set a password on GRUB boot loader to prevent altering boot configuratio


HARDN_STATUS "info" "Checking and configuring GRUB settings..."

# Define color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

# Print color messages/output
print_msg() {
        local color="$1"
        local msg="$2"
        printf "${color}${BOLD}%s${RESET}\n" "$msg"
}

error(){
        print_msg "$RED" "Error: $1" >&2
        # If this is the main script (not sourced), then exit
        if [ "${BASH_SOURCE[0]}" = "$0" ]; then
            exit 1
        else
            # Otherwise just return with error code
            return 1
        fi
}

success(){
        print_msg "$GREEN" "Success: $1"
}

info(){
        print_msg "$BLUE" "Info: $1"
}

warning(){
        print_msg "$YELLOW" "Warning: $1"
}

check_root() {
        [ "$(id -u)" -ne 0 ] && error "Please run this script as root."
}

# Different GRUB versions might have different configuration requirements.
# This necessitates a GRUB version check
check_grub_version() {
        local grub_version
        grub_version=$(grub-install --version 2>/dev/null | awk '{print $NF}' | cut -d. -f1)

        if [ -z "$grub_version" ]; then
            warning "Could not determine GRUB version. Proceeding anyway."
        elif [ "$grub_version" -lt 2 ]; then
            warning "This script is designed for GRUB 2. Your version may not support all features."
        else
            info "Detected GRUB version $grub_version. Compatible with this script."
        fi
}

check_dependencies() {
        command -v grub-mkpasswd-pbkdf2 &> /dev/null && return 0
        info "grub-mkpasswd-pbkdf2 not found. Installing grub-common..."

        apt update && apt install -y grub-common && {
            success "Successfully installed grub-common."
            return 0
        }

        error "Failed to install grub-common. Exiting."
}

generate_password_hash() {
        info "Generating GRUB password hash..."

        [ ! -t 0 ] && {
            error "This script requires an interactive terminal for password input."
        }

        # Add trap for Ctrl+C
        trap 'echo ""; warning "Password generation cancelled."; return 1' INT

        # More secure password input
        local password password_confirm
        echo "Please enter a strong password for GRUB (minimum 10 characters recommended):"
        read -r -s password
        echo
        echo "Please confirm the password:"
        read -r -s password_confirm
        echo

        if [ "$password" != "$password_confirm" ]; then
            warning "Passwords do not match. Please try again."
            trap - INT
            return 1
        fi

        # Check password strength
        if [ ${#password} -lt 10 ]; then
            warning "Password is too short. Please use at least 10 characters."
            trap - INT
            return 1
        fi

        # Generate hash from the password
        local password_hash
        password_hash=$(echo -e "$password\n$password" | grub-mkpasswd-pbkdf2 2>/dev/null | grep "PBKDF2 hash of your password is" | sed 's/PBKDF2 hash of your password is //')

        # Reset the trap
        trap - INT

        # Checking for successful password hash generation.
        [ -z "$password_hash" ] && error "Password did not generate. Exiting"

        success "Password hash generated successfully."
        echo "$password_hash"
}

update_grub_config() {
        local password_hash="$1"
        local grub_username="admin"

        info "Updating GRUB configuration with password protection..."

        # Check if password protection is already configured
        if [ -f /etc/grub.d/40_custom ] && grep -q "set superusers=" /etc/grub.d/40_custom; then
            warning "GRUB password protection appears to be already configured."
            read -r -p "Do you want to overwrite the existing configuration? [y/N]: " answer
            answer=${answer:-N}  # Default to N if Enter is pressed

            if [[ ! $answer =~ ^[Yy]$ ]]; then
                info "Keeping existing configuration."
                return 0
            fi
        fi

        # Backing up the original 40_custom file
        if [ -f /etc/grub.d/40_custom ]; then
            cp /etc/grub.d/40_custom "/etc/grub.d/40_custom.bak.$(date +%Y%m%d-%H%M%S).$$"
            success "Backup of original GRUB custom configuration created."
        fi

        # Create /boot/grub2/user.cfg if it doesn't exist
        local grub2_dir="/boot/grub2"
        local user_cfg="${grub2_dir}/user.cfg"

        # Create directory if it doesn't exist
        if [ ! -d "$grub2_dir" ]; then
            mkdir -p "$grub2_dir"
            info "Created directory $grub2_dir"
        fi

        # Create or update user.cfg file
        {
            echo "# GRUB2 user configuration file - created by HARDN-XDR"
            echo "# $(date)"
            echo "set superusers=\"$grub_username\""
            echo "password_pbkdf2 $grub_username $password_hash"
        } > "$user_cfg"

        chmod 600 "$user_cfg"
        success "Created GRUB2 user configuration file at $user_cfg"

        local temp_file
        temp_file=$(mktemp)
        # The use of a trap, will help ensure temporary file security
        trap 'rm -f "$temp_file"' EXIT

        # Add the superuser and password configuration at the top
        {
            echo "#!/bin/sh"
            echo "exec tail -n +3 \$0"
            echo "# This file provides an easy way to add custom menu entries."
            echo "# Simply type the menu entries you want to add after this comment."
            echo "# Be careful not to change the 'exec tail' line above."
            echo ""
            echo "set superusers=\"$grub_username\""
            echo "password_pbkdf2 $grub_username $password_hash"
            echo ""
            echo "# Include the user configuration file if it exists"
            echo "if [ -f /boot/grub2/user.cfg ]; then"
            echo "  source /boot/grub2/user.cfg"
            echo "fi"
        } > "$temp_file"

        # Copy the rest of the original file if it exists and has content beyond the header
        if [ -f /etc/grub.d/40_custom ]; then
            # Skip the first 6 lines (the standard header)
            tail -n +7 /etc/grub.d/40_custom >> "$temp_file" 2>/dev/null || true
        fi

        # Replace the original file with our modified version
        mv "$temp_file" /etc/grub.d/40_custom
        chmod 755 /etc/grub.d/40_custom
        success "GRUB custom configuration updated with password protection."

        info "Regenerating GRUB configuration..."
        if command -v update-grub >/dev/null 2>&1; then
            if update-grub; then
                success "GRUB configuration updated successfully."
                return 0
            else
                error "Failed to update GRUB configuration."
            fi
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            local grub_cfg="/boot/grub2/grub.cfg"
            [ -d /boot/grub ] && grub_cfg="/boot/grub/grub.cfg"

            if grub2-mkconfig -o "$grub_cfg"; then
                success "GRUB configuration updated successfully."
                return 0
            else
                error "Failed to update GRUB configuration."
            fi
        else
            error "Could not find update-grub or grub2-mkconfig. Please update GRUB configuration manually."
        fi
}

# Checking that the GRUB changes were properly applied.
verify_grub_config() {
        info "Verifying GRUB configuration..."

        local grub_cfg=""
        if [ -f /boot/grub/grub.cfg ]; then
            grub_cfg="/boot/grub/grub.cfg"
        elif [ -f /boot/grub2/grub.cfg ]; then
            grub_cfg="/boot/grub2/grub.cfg"
        fi

        if [ -n "$grub_cfg" ] && grep -q "set superusers=" "$grub_cfg" &&
           grep -q "password_pbkdf2" "$grub_cfg"; then
            success "GRUB password protection verified in configuration."
        else
            warning "Could not verify GRUB password protection in final configuration."
            warning "This might be normal if your GRUB configuration is in a non-standard location."
            warning "Please check manually after reboot."
        fi
}

ask_for_reboot() {
        info "GRUB has been secured with a password."
        info "To test the configuration, you need to reboot your system."
        info "After reboot, press Esc or Shift to enter the GRUB menu."
        info "Try entering the command line (c) or editing entries (e)."
        info "You should be prompted for the GRUB username (admin) and password."

        # Check if there are any processes that might prevent a clean reboot
        if command -v needrestart >/dev/null 2>&1; then
            needrestart -k -r a -q || warning "Some services may need to be restarted after reboot."
        fi

        read -r -p "Do you want to reboot now? [Y/n]: " answer
        answer=${answer:-Y}  # Default to Y if Enter is pressed

        case "$answer" in
            [Yy]*)
                info "Rebooting system..."
                sync  # Ensure all changes are written to disk
                reboot
                ;;
            *)
                info "Reboot skipped. Remember to reboot later to apply the changes."
                ;;
        esac
}

# Main
secure_grub() {
        # Save current environment variables before setting strict mode
        local IFS_OLD="$IFS"
        local LC_ALL_OLD="${LC_ALL:-}"
        local LANG_OLD="${LANG:-}"

        # Function to restore environment variables
        restore_env() {
            IFS="$IFS_OLD"
            LC_ALL="$LC_ALL_OLD"
            LANG="$LANG_OLD"
        }

        # Setting strict shell options for this function only
        set -euo pipefail
        IFS=$'\n\t'  # Set IFS to newline and tab to avoid issues with spaces in filenames

        # Disable unicode for performance increase
        LC_ALL=C
        LANG=C

        # Ensure environment is restored on exit
        trap restore_env EXIT

        info "Starting GRUB password protection setup..."

        check_root
        check_grub_version
        check_dependencies

        local password_hash
        password_hash=$(generate_password_hash)

        # Check if password hash was successfully generated
        if [ -z "$password_hash" ]; then
            error "Password hash generation failed. Exiting."
            restore_env  # Explicitly call restore_env before returning
            return 1
        fi

        if ! update_grub_config "$password_hash"; then
            error "Failed to secure GRUB. Exiting."
            restore_env  # Explicitly call restore_env before returning
            return 1
        fi

        verify_grub_config

        # Explicitly call restore_env before asking for reboot
        restore_env
        ask_for_reboot
}

