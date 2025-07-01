#!/bin/bash

is_installed() {
    if command -v apt >/dev/null 2>&1; then
        dpkg -s "$1" >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf list installed "$1" >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum list installed "$1" >/dev/null 2>&1
    elif command -v rpm >/dev/null 2>&1; then
        rpm -q "$1" >/dev/null 2>&1
    else
        return 1 # Cannot determine package manager
    fi
}



# What this script does:
#  - Sets a password on GRUB boot loader to prevent altering boot configuration
#  - Prevents unauthorized access to single user mode and GRUB command line
#  - Implements Lynis security control BOOT-5122 (https://cisofy.com/lynis/controls/BOOT-5122/)
#  - Creates a superuser account for GRUB with password protection
#  - Configures GRUB to require authentication for editing boot entries
#  - Backs up original configuration before making changes
#  - Provides verification of successful implementation
#
# Implementation details:
#  - Uses PBKDF2 with SHA-512 for secure password hashing
#  - Modifies /etc/grub.d/40_custom to add password protection
#  - Creates a separate user configuration file for better maintainability
#  - Regenerates GRUB configuration to apply changes
#  - Logs verification results for auditing purposes
#
# References:
#  - Lynis BOOT-5122: https://cisofy.com/lynis/controls/BOOT-5122/
#  - GRUB Documentation: https://www.gnu.org/software/grub/manual/grub/grub.html#Security
#  - Ubuntu Community Help: https://help.ubuntu.com/community/Grub2/Passwords
#
#######################################

HARDN_STATUS "info" "Setting up the GRUB boot loader password..."

# Define color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
RESET='\033[0m'

# Log file for recording actions
LOG_FILE="/var/log/hardn-grub-setup.log"
VERIFICATION_LOG="/var/log/hardn-grub-verification.log"

# Print formatted messages
# Log functions with different severity levels
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

error() {
    HARDN_STATUS "error" "$1"
    log "ERROR: $1"
    # If this is the main script (not sourced), then exit
    if [ "${BASH_SOURCE[0]}" = "$0" ]; then
        exit 1
    else
        # Otherwise just return with error code
        return 1
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

# Check if running as root
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "This script must be run as root"
        return 1
    fi
    return 0
}

# Check GRUB version
check_grub_version() {
    local grub_version

    if command -v grub-install >/dev/null 2>&1; then
        grub_version=$(grub-install --version 2>/dev/null | awk '{print $NF}' | cut -d. -f1)
    elif command -v grub2-install >/dev/null 2>&1; then
        grub_version=$(grub2-install --version 2>/dev/null | awk '{print $NF}' | cut -d. -f1)
    else
        warning "Could not determine GRUB version. Proceeding anyway."
        return 0
    fi

    if [ -z "$grub_version" ]; then
        warning "Could not determine GRUB version. Proceeding anyway."
    elif [ "$grub_version" -lt 2 ]; then
        warning "This script is designed for GRUB 2. Your version may not support all features."
    else
        info "Detected GRUB version $grub_version. Compatible with this script."
    fi

    return 0
}

# Detect GRUB environment (paths, commands, etc.)
detect_grub_environment() {
    info "Detecting GRUB environment..."

    # Check if GRUB is installed
    if ! command -v grub-install >/dev/null 2>&1 && ! command -v grub2-install >/dev/null 2>&1; then
        warning "GRUB installation commands not found. Is GRUB installed?"
        # Check for common GRUB files to confirm installation
        if [ -d /boot/grub ] || [ -d /boot/grub2 ]; then
            info "GRUB directories found in /boot. Proceeding with caution."
        else
            error "No evidence of GRUB installation found. Please install GRUB first."
            return 1
        fi
    fi

    # Detect distribution for distribution-specific handling
    local distro=""
    if [ -f /etc/os-release ]; then
        distro=$(grep -oP '(?<=^ID=).+' /etc/os-release | tr -d '"')
        info "Detected distribution: $distro"
    else
        warning "Could not detect distribution. Using generic approach."
    fi

    # Check for GRUB configuration directories
    if [ -d /etc/grub.d ]; then
        info "Found GRUB configuration directory: /etc/grub.d"
    else
        warning "GRUB configuration directory /etc/grub.d not found."
        warning "This script may not work correctly on your system."
    fi

    return 0
}

# Check for required dependencies
check_dependencies() {
    if command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
        return 0
    fi

    info "grub-mkpasswd-pbkdf2 not found. Installing required packages..."

    # Try to install on different distributions
    if command -v apt &> /dev/null; then
        apt update -qq && apt install -y grub-common
    elif command -v dnf &> /dev/null; then
        dnf install -y grub2-tools
    elif command -v yum &> /dev/null; then
        yum install -y grub2-tools
    else
        error "Could not install required dependencies. Please install grub-common or grub2-tools manually."
        return 1
    fi

    if ! command -v grub-mkpasswd-pbkdf2 &> /dev/null; then
        error "Failed to install grub-mkpasswd-pbkdf2. Please install it manually."
        return 1
    fi

    success "Successfully installed required dependencies."
    return 0
}

# THIS PART NEEDS WORK, SCRIPT DEFAULTS TO NON INTERACTIVE MODE
# the default credentials are:
# Username: admin
# Password: HardnGrubPassword123!
# These are set in a function called 'generate_password_hash'
generate_password_hash() {
    info "Generating GRUB password hash..."

    # Check if we have a proper terminal for input
    if [ ! -t 0 ] || [ ! -t 1 ]; then
        warning "No proper terminal detected for password input."
        warning "Using alternative input method..."

        # Try to use dialog if available
        if command -v dialog >/dev/null 2>&1; then
            local temp_file
            temp_file=$(mktemp)
            trap 'rm -f "$temp_file"' EXIT

            # Use dialog to get password
            if dialog --title "GRUB Password" --passwordbox "Enter a strong password for GRUB (minimum 10 characters):" 10 60 2>"$temp_file"; then
                local password
                password=$(cat "$temp_file")
                rm -f "$temp_file"

                temp_file=$(mktemp)
                if dialog --title "GRUB Password" --passwordbox "Confirm password:" 10 60 2>"$temp_file"; then
                    local password_confirm
                    password_confirm=$(cat "$temp_file")
                    rm -f "$temp_file"

                    if [ "$password" != "$password_confirm" ]; then
                        dialog --title "Error" --msgbox "Passwords do not match. Please try again." 8 40
                        return 1
                    fi

                    if [ ${#password} -lt 10 ]; then
                        dialog --title "Error" --msgbox "Password is too short. Please use at least 10 characters." 8 40
                        return 1
                    fi

                    # Generate hash from the password
                    local password_hash
                    password_hash=$(echo -e "$password\n$password" | grub-mkpasswd-pbkdf2 2>/dev/null | grep "PBKDF2 hash of your password is" | sed 's/PBKDF2 hash of your password is //')

                    if [ -z "$password_hash" ]; then
                        dialog --title "Error" --msgbox "Password hash generation failed." 8 40
                        return 1
                    fi

                    echo "$password_hash"
                    return 0
                fi
            fi
            return 1
        else
            # Fallback to a default password with warning
            warning "No interactive terminal and no dialog utility available."
            warning "Using default password 'HardnGrubPassword123!' for GRUB."
            warning "SECURITY RISK: Please change this password after reboot!"

            local default_password="HardnGrubPassword123!"
            local password_hash
            password_hash=$(echo -e "$default_password\n$default_password" | grub-mkpasswd-pbkdf2 2>/dev/null | grep "PBKDF2 hash of your password is" | sed 's/PBKDF2 hash of your password is //')

            if [ -z "$password_hash" ]; then
                error "Password hash generation failed even with default password."
                return 1
            fi

            echo "$password_hash"
            return 0
        fi
    fi

    # Standard terminal input method
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

    # Check for successful password hash generation
    if [ -z "$password_hash" ]; then
        error "Password hash generation failed."
        return 1
    fi

    success "Password hash generated successfully."
    echo "$password_hash"
}

# Generate password hash non-interactively (for automated deployments)
# Default username is: admin
# Default password is: HardnGrubPassword123!
# These credentials are set in the secure_grub() function'
generate_password_hash_noninteractive() {
    local default_password="$1"

    if [ -z "$default_password" ]; then
        error "Non-interactive mode requires a default password"
        return 1
    fi

    # Check password strength
    if [ ${#default_password} -lt 10 ]; then
        warning "Default password is too short. Please use at least 10 characters."
        return 1
    fi

    info "Using provided default password in non-interactive mode"

    # Generate hash from the password
    local password_hash
    password_hash=$(echo -e "$default_password\n$default_password" | grub-mkpasswd-pbkdf2 2>/dev/null | grep "PBKDF2 hash of your password is" | sed 's/PBKDF2 hash of your password is //')

    # Check for successful password hash generation
    if [ -z "$password_hash" ]; then
        error "Password hash generation failed"
        return 1
    fi

    success "Password hash generated successfully (non-interactive mode)"
    echo "$password_hash"
}

# Update GRUB configuration with password protection
update_grub_config() {
    local password_hash="$1"
    local grub_username="admin"
    local non_interactive=0

    # Check if we're in non-interactive mode
    [ ! -t 0 ] && non_interactive=1

    info "Updating GRUB configuration with password protection..."

    # Check if password protection is already configured
    if [ -f /etc/grub.d/40_custom ] && grep -q "set superusers=" /etc/grub.d/40_custom; then
        warning "GRUB password protection appears to be already configured."

        if [ $non_interactive -eq 1 ]; then
            # In non-interactive mode, always overwrite
            info "Non-interactive mode: Overwriting existing configuration."
        else
            read -r -p "Do you want to overwrite the existing configuration? [y/N]: " answer
            answer=${answer:-N}  # Default to N if Enter is pressed

            if [[ ! $answer =~ ^[Yy]$ ]]; then
                info "Keeping existing configuration."
                return 0
            fi
        fi
    fi

    # Backing up the original 40_custom file
    if [ -f /etc/grub.d/40_custom ]; then
        cp /etc/grub.d/40_custom "/etc/grub.d/40_custom.bak.$(date +%Y%m%d-%H%M%S).$$"
        success "Backup of original GRUB custom configuration created."
    fi

    # Create /boot/grub2/user.cfg if it doesn't exist
    local grub_dir=""
    if [ -d /boot/grub2 ]; then
        grub_dir="/boot/grub2"
    elif [ -d /boot/grub ]; then
        grub_dir="/boot/grub"
    else
        # Create directory if it doesn't exist
        mkdir -p /boot/grub2
        grub_dir="/boot/grub2"
        info "Created directory $grub_dir"
    fi

    local user_cfg="${grub_dir}/user.cfg"

    # Create or update user.cfg file using heredoc
    cat > "$user_cfg" << EOF
# GRUB2 user configuration file - created by HARDN-XDR
# $(date)
set superusers="${grub_username}"
password_pbkdf2 ${grub_username} ${password_hash}
EOF

    chmod 600 "$user_cfg"
    success "Created GRUB2 user configuration file at $user_cfg"

    local temp_file
    temp_file=$(mktemp)
    # The use of a trap, will help ensure temporary file security
    trap 'rm -f "$temp_file"' EXIT

    # Add the superuser and password configuration at the top using heredoc
    cat > "$temp_file" << EOF
#!/bin/sh
exec tail -n +3 \$0
# This file provides an easy way to add custom menu entries.
# Simply type the menu entries you want to add after this comment.
# Be careful not to change the 'exec tail' line above.

set superusers="${grub_username}"
password_pbkdf2 ${grub_username} ${password_hash}

# Include the user configuration file if it exists
if [ -f ${user_cfg} ]; then
  source ${user_cfg}
fi
EOF

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
            return 1
        fi
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        local grub_cfg=""
        if [ -d /boot/grub2 ]; then
            grub_cfg="/boot/grub2/grub.cfg"
        else
            grub_cfg="/boot/grub/grub.cfg"
        fi

        if grub2-mkconfig -o "$grub_cfg"; then
            success "GRUB configuration updated successfully."
            return 0
        else
            error "Failed to update GRUB configuration."
            return 1
        fi
    else
        error "Could not find update-grub or grub2-mkconfig. Please update GRUB configuration manually."
        return 1
    fi
}

# Verify that GRUB configuration was properly updated
verify_grub_config() {
    info "Verifying GRUB configuration..."

    local grub_cfg=""
    if [ -f /boot/grub/grub.cfg ]; then
        grub_cfg="/boot/grub/grub.cfg"
    elif [ -f /boot/grub2/grub.cfg ]; then
        grub_cfg="/boot/grub2/grub.cfg"
    fi

    # Create a verification log
    {
        echo "=== GRUB Configuration Verification ==="
        echo "Date: $(date)"
        echo "User: $(whoami)"
        echo "GRUB config file: $grub_cfg"

        if [ -n "$grub_cfg" ]; then
            echo "File exists: Yes"
            echo "File permissions: $(ls -l "$grub_cfg")"
            echo "File size: $(du -h "$grub_cfg" | cut -f1)"

            echo "Checking for superusers setting..."
            if grep -q "set superusers=" "$grub_cfg"; then
                echo "  Found: Yes"
                grep -n "set superusers=" "$grub_cfg" | head -1
            else
                echo "  Found: No"
            fi

            echo "Checking for password_pbkdf2 setting..."
            if grep -q "password_pbkdf2" "$grub_cfg"; then
                echo "  Found: Yes"
                grep -n "password_pbkdf2" "$grub_cfg" | head -1 | sed 's/\(password_pbkdf2 [^ ]* \).*/\1****/'
            else
                echo "  Found: No"
            fi

            echo "Custom configuration file:"
            if [ -f /etc/grub.d/40_custom ]; then
                echo "  Exists: Yes"
                echo "  Content (sensitive info redacted):"
                grep -v "password_pbkdf2" /etc/grub.d/40_custom || echo "  No non-sensitive content found"
            else
                echo "  Exists: No"
            fi

            echo "User configuration file:"
            if [ -f /boot/grub2/user.cfg ]; then
                echo "  Exists: Yes"
                echo "  Permissions: $(ls -l /boot/grub2/user.cfg)"
            elif [ -f /boot/grub/user.cfg ]; then
                echo "  Exists: Yes"
                echo "  Permissions: $(ls -l /boot/grub/user.cfg)"
            else
                echo "  Exists: No"
            fi
        else
            echo "GRUB configuration file not found!"
        fi

        echo "=== End of Verification ==="
    } > "$VERIFICATION_LOG" 2>&1

    chmod 600 "$VERIFICATION_LOG"

    if [ -n "$grub_cfg" ] && grep -q "set superusers=" "$grub_cfg" &&
       grep -q "password_pbkdf2" "$grub_cfg"; then
        success "GRUB password protection verified in configuration."
        info "Detailed verification log saved to $VERIFICATION_LOG"
        return 0
    else
        warning "Could not verify GRUB password protection in final configuration."
        warning "This might be normal if your GRUB configuration is in a non-standard location."
        warning "Please check manually after reboot."
        info "Detailed verification log saved to $VERIFICATION_LOG"
        return 1
    fi
}

# Ask user if they want to reboot to apply changes
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

# Debug function to help troubleshoot execution issues
debug_grub_module() {
    {
        echo "===== GRUB MODULE DEBUG INFO ====="
        echo "Date/Time: $(date)"
        echo "Script path: $0"
        echo "BASH_SOURCE: ${BASH_SOURCE[*]}"
        echo "Called directly? $([ "${BASH_SOURCE[0]}" = "$0" ] && echo "Yes" || echo "No")"
        echo "Current directory: $(pwd)"
        echo "Parent process: $(ps -o comm= $PPID)"
        echo "User: $(whoami)"
        echo "Environment variables:"
        env | grep -E '^(HARDN|PATH)' || echo "No HARDN environment variables found"
        echo "Function availability:"
        declare -F | grep -E 'secure_grub|print_msg|error|success|info|warning' || echo "Functions not properly exported"
        echo "GRUB installation:"
        command -v grub-install || command -v grub2-install || echo "GRUB installation commands not found"
        echo "GRUB configuration files:"
        ls -la /etc/grub.d/ 2>/dev/null || echo "/etc/grub.d/ not found"
        echo "=================================="
    } >&2
}

# Main function with optional parameter for non-interactive mode
secure_grub() {
    local default_password="${1:-}"
    local non_interactive=0

    # Initialize log file
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    log "Starting GRUB password protection setup"

    # Secure Boot detection
    if [ -d /sys/firmware/efi ]; then
        if command -v mokutil >/dev/null 2>&1 && mokutil --sb-state 2>/dev/null | grep -q 'SecureBoot enabled'; then
            info "Secure Boot is enabled. Skipping GRUB password protection."
            whiptail --title "GRUB Security" --msgbox "Secure Boot is enabled. GRUB password protection is not required and will be skipped." 10 60 2>/dev/null || true
            return 0
        fi
    fi

    # Check if we're in non-interactive mode
    if [ -n "$default_password" ] || [ ! -t 0 ]; then
        non_interactive=1
        info "Running in non-interactive mode"
        [ -z "$default_password" ] && error "Non-interactive mode requires a default password parameter"
    else
        # Ask user if they want to enable GRUB pass
        if command -v whiptail >/dev/null 2>&1; then
            if ! whiptail --title "GRUB Password Protection" --yesno "Do you want to enable GRUB password protection?\n\nThis protects the bootloader from unauthorized changes, but is not required if Secure Boot is enabled." 12 70; then
                info "User declined GRUB password protection. Skipping setup."
                whiptail --title "GRUB Security" --msgbox "GRUB password protection was skipped at your request." 10 60 2>/dev/null || true
                return 0
            fi
        else
            echo
            echo "You can enable GRUB password protection to prevent unauthorized changes."
            read -r -p "Enable GRUB password protection? [y/N]: " answer
            answer=${answer:-N}
            if [[ ! $answer =~ ^[Yy]$ ]]; then
                info "User declined GRUB password protection. Skipping setup."
                return 0
            fi
        fi
        # Clear visual indicator that user input is required
        echo
        echo "╔════════════════════════════════════════════════════════════╗"
        echo "║                GRUB PASSWORD CONFIGURATION                 ║"
        echo "║                                                            ║"
        echo "║  You will be prompted to create a password for GRUB.       ║"
        echo "║  This password protects your bootloader from unauthorized  ║"
        echo "║  modifications and increases system security.              ║"
        echo "║                                                            ║"
        echo "╚════════════════════════════════════════════════════════════╝"
        echo
    fi

    info "Starting GRUB password protection setup..."

    # Add detailed debugging
    debug_grub_module

    info "Checking if running as root..."
    check_root || return 1

    info "Checking GRUB version..."
    check_grub_version || true  # Continue even if this fails

    info "Detecting GRUB environment..."
    detect_grub_environment || return 1

    info "Checking dependencies..."
    check_dependencies || return 1

    info "Generating password hash..."
    local password_hash

    # Choose password generation method based on mode
    if [ $non_interactive -eq 1 ] && [ -n "$default_password" ]; then
        password_hash=$(generate_password_hash_noninteractive "$default_password")
    else
        password_hash=$(generate_password_hash)
    fi

    # Check if password hash was successfully generated
    if [ -z "$password_hash" ]; then
        error "Password hash generation failed. Exiting."
        return 1
    fi

    info "Updating GRUB configuration..."
    if ! update_grub_config "$password_hash"; then
        error "Failed to secure GRUB. Exiting."
        return 1
    fi

    info "Verifying GRUB configuration..."
    verify_grub_config

    # Only ask for reboot in interactive mode
    if [ $non_interactive -eq 0 ]; then
        ask_for_reboot
    else
        info "GRUB has been secured with a password. System needs to be rebooted to apply changes."
    fi

    log "GRUB password protection setup completed successfully"
    return 0
}

# Export key functions for use by the parent script
export -f secure_grub


# Execute the main function when the script is run directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    info "Running GRUB module directly"
    secure_grub "$@"
else
    info "GRUB module loaded from $(ps -o comm= $PPID)"

    # Check if being run by hardn-main.sh
    if [[ "$(ps -o comm= $PPID)" == *"hardn-main"* ]] || [[ "$0" == *"hardn-main"* ]]; then
        # Always execute when sourced from hardn-main.sh
        # Set HARDN_EXECUTING_MODULE to prevent recursive execution
        if [ -z "${HARDN_EXECUTING_MODULE:-}" ]; then
            export HARDN_EXECUTING_MODULE="grub"
            info "Executing GRUB configuration automatically"

            # Use a default password when run from hardn-main.sh to avoid terminal issues
            # This is a security compromise but ensures automation works
            # Default username is: admin
            # Default password is: HardnGrubPassword123!
            DEFAULT_PASSWORD="HardnGrubPassword123!"
            warning "Using default password for GRUB due to automation."
            warning "SECURITY RISK: Please change this password after installation!"
            warning "Default password is: $DEFAULT_PASSWORD"

            secure_grub "$DEFAULT_PASSWORD"
            unset HARDN_EXECUTING_MODULE
        else
            info "GRUB module loaded but execution skipped (already running)"
        fi
    else
        info "GRUB module loaded but not executed (not called from hardn-main.sh)"
    fi
fi
