#!/bin/bash

# secure_grub.sh - Automates the process of securing GRUB with a password
# Part of the HARDN-XDR project

check_root () {
    [ "$(id -u)" -ne 0 ] && echo "Please run this script as root." && exit 1
}

setup_status_function() {
    # Import the HARDN status function if available
    if [ -f "../hardn-main.sh" ]; then
        source "../hardn-main.sh"
    else
        # Define a simple status function if the main script is not available
        HARDN_STATUS() {
            local type="$1"
            local message="$2"
            case "$type" in
                info) echo -e "\033[0;34m[INFO]\033[0m $message" ;;
                pass) echo -e "\033[0;32m[PASS]\033[0m $message" ;;
                warning) echo -e "\033[0;33m[WARNING]\033[0m $message" ;;
                error) echo -e "\033[0;31m[ERROR]\033[0m $message" ;;
                *) echo "$message" ;;
            esac
        }
    fi
}

check_dependencies() {
        # Check if grub-mkpasswd-pbkdf2 is available in PATH
        command -v grub-mkpasswd-pbkdf2 &> /dev/null && return 0

        # Tool not found, attempt to install it
        HARDN_STATUS "info" "grub-mkpasswd-pbkdf2 not found. Installing grub-common..."

        # Use && to only proceed if the previous command succeeds
        # This avoids nested if statements
        apt update && apt install -y grub-common && {
            HARDN_STATUS "pass" "Successfully installed grub-common."
            return 0
        }

        # If we reach here, installation failed
        HARDN_STATUS "error" "Failed to install grub-common. Exiting."
    exit 1
}

generate_password_hash() {
        HARDN_STATUS "info" "Generating GRUB password hash..."

        [ ! -t 0 ] && {
            HARDN_STATUS "error" "This script requires an interactive terminal for password input."
            exit 1
        }

        echo "Please enter a strong password for GRUB:"
        local password_hash
        password_hash=$(grub-mkpasswd-pbkdf2 | grep "PBKDF2 hash of your password is" | sed 's/PBKDF2 hash of your password is //')

        if [ -z "$password_hash" ]; then
            HARDN_STATUS "error" "Failed to generate password hash. Exiting."
            exit 1
        fi

        HARDN_STATUS "pass" "Password hash generated successfully."
        echo "$password_hash"
}

update_grub_config() {
        local password_hash="$1"
        local grub_username="admin"

        HARDN_STATUS "info" "Updating GRUB configuration with password protection..."

        # Backup the original 40_custom file
        if [ -f /etc/grub.d/40_custom ]; then
            cp /etc/grub.d/40_custom "/etc/grub.d/40_custom.bak.$(date +%Y%m%d-%H%M%S)"
        fi

        local temp_file=$(mktemp)

        # Add the superuser and password configuration at the top
        echo "#!/bin/sh" > "$temp_file"
        echo "exec tail -n +3 \$0" >> "$temp_file"
        echo "# This file provides an easy way to add custom menu entries." >> "$temp_file"
        echo "# Simply type the menu entries you want to add after this comment." >> "$temp_file"
        echo "# Be careful not to change the 'exec tail' line above." >> "$temp_file"
        echo "" >> "$temp_file"
        echo "set superusers="$grub_username"" >> "$temp_file"
        echo "password_pbkdf2 $grub_username $password_hash" >> "$temp_file"

        # Copy the rest of the original file if it exists and has content beyond the header
        if [ -f /etc/grub.d/40_custom ]; then
            # Skip the first 6 lines (the standard header)
            tail -n +7 /etc/grub.d/40_custom >> "$temp_file"
        fi

        # Replace the original file with our modified version
        mv "$temp_file" /etc/grub.d/40_custom
        chmod 755 /etc/grub.d/40_custom

        HARDN_STATUS "info" "Regenerating GRUB configuration..."
        if update-grub; then
            HARDN_STATUS "pass" "GRUB configuration updated successfully."
        else
            HARDN_STATUS "error" "Failed to update GRUB configuration."
            return 1
        fi

        return 0
}

ask_for_reboot() {
        HARDN_STATUS "info" "GRUB has been secured with a password."
        HARDN_STATUS "info" "To test the configuration, you need to reboot your system."
        HARDN_STATUS "info" "After reboot, press Esc or Shift to enter the GRUB menu."
        HARDN_STATUS "info" "Try entering the command line (c) or editing entries (e)."
        HARDN_STATUS "info" "You should be prompted for the GRUB username (admin) and password."

        read -r -p "Do you want to reboot now? [Y/n]: " answer
        answer=${answer:-Y}  # Default to Y if Enter is pressed

        case "$answer" in
            [Yy]*)
                HARDN_STATUS "info" "Rebooting system..."
                reboot
                ;;
            *)
                HARDN_STATUS "info" "Reboot skipped. Remember to reboot later to apply the changes."
                ;;
        esac
}

# Main
secure_grub() {

        HARDN_STATUS "info" "Starting GRUB password protection setup..."

        check_root
        setup_status_function
        check_dependencies

        # Generate password hash
        local password_hash
        password_hash=$(generate_password_hash)

        # Check if password hash was successfully generated
        [ -z "$password_hash" ] && {
            HARDN_STATUS "error" "Password hash generation failed. Exiting."
            exit 1
        }


        # Update GRUB configuration
        update_grub_config "$password_hash" || {
            HARDN_STATUS "error" "Failed to secure GRUB. Exiting."
            exit 1
        }

        ask_for_reboot
}

# main function
secure_grub
