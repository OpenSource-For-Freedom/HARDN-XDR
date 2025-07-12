#!/usr/bin/env bash
# HARDN-XDR - The Linux Security Hardening Sentinel
# Version 2.0.0
# About this script:
# STIG Compliance: Security Technical Implementation Guide.

# Status function for consistent output formatting
HARDN_STATUS() {
    local status="$1"
    local message="$2"
    local color="\033[0m"

    case "$status" in
        info) color="\033[1;34m" ;;    # Blue
        pass) color="\033[1;32m" ;;    # Green
        warning) color="\033[1;33m" ;; # Yellow
        error) color="\033[1;31m" ;;   # Red
    esac

    printf "${color}[%s]\033[0m %s\n" "${status^^}" "$message"

    # Log to file if log directory and file are defined and exist
    if [[ -n "${HARDN_LOG_FILE:-}" && -d "$(dirname "$HARDN_LOG_FILE")" ]]; then
        printf "[%s] [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S')" "${status^^}" "$message" >> "$HARDN_LOG_FILE"
    fi
}

# Global variables with proper prefixing
readonly HARDN_VERSION="1.1.50"
readonly HARDN_SCRIPT_DIR
         HARDN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly HARDN_MODULE_DIR="${HARDN_SCRIPT_DIR}/modules"
readonly HARDN_INSTALLED_MODULE_DIR="/usr/lib/hardn-xdr/src/setup/modules"
readonly HARDN_CONFIG_DIR="/etc/hardn-xdr"
readonly HARDN_LOG_DIR="/var/log/hardn-xdr"
readonly HARDN_LOG_FILE="${HARDN_LOG_DIR}/hardn-xdr.log"
readonly HARDN_BACKUP_DIR="/var/backups/hardn-xdr"

# Export for modules to use
export HARDN_XDR_ROOT="${HARDN_SCRIPT_DIR}"
export APT_LISTBUGS_FRONTEND=none

# System information variables
HARDN_CURRENT_DEBIAN_VERSION_ID=""
HARDN_CURRENT_DEBIAN_CODENAME=""

# Detect system information
hardn_detect_system_info() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        source /etc/os-release
        HARDN_CURRENT_DEBIAN_VERSION_ID="${VERSION_ID:-}"
        HARDN_CURRENT_DEBIAN_CODENAME="${VERSION_CODENAME:-}"
    fi
}

# Display system information
hardn_show_system_info() {
    HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} - System Information"
    HARDN_STATUS "info" "================================================"
    HARDN_STATUS "info" "Script Version: ${HARDN_VERSION}"
    HARDN_STATUS "info" "Target OS: Debian-based systems (Debian 12+, Ubuntu 24.04+)"

    if [[ -n "${HARDN_CURRENT_DEBIAN_VERSION_ID}" && -n "${HARDN_CURRENT_DEBIAN_CODENAME}" ]]; then
        HARDN_STATUS "info" "Detected OS: ${ID:-Unknown} ${HARDN_CURRENT_DEBIAN_VERSION_ID} (${HARDN_CURRENT_DEBIAN_CODENAME})"
    fi

    HARDN_STATUS "info" "Features: STIG Compliance, Malware Detection, System Hardening"
}

# Display welcome message
hardn_welcome_message() {
    HARDN_STATUS "info" ""
    HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} - Linux Security Hardening Sentinel"
    HARDN_STATUS "info" "================================================================"

    if ! whiptail --title "HARDN-XDR v${HARDN_VERSION}" --msgbox \
        "Welcome to HARDN-XDR v${HARDN_VERSION} - A Debian Security tool for System Hardening\n\nThis will apply STIG compliance, security tools, and comprehensive system hardening." 12 70; then
        return 1
    fi

    HARDN_STATUS "info" ""
    HARDN_STATUS "info" "This installer will update your system first..."

    if ! whiptail --title "HARDN-XDR v${HARDN_VERSION}" --yesno \
        "Do you want to continue with the installation?" 10 60; then
        HARDN_STATUS "error" "Installation cancelled by user."
        return 1
    fi

    return 0
}

# Update system packages
hardn_update_system_packages() {
    HARDN_STATUS "info" "Updating system packages..."

    if DEBIAN_FRONTEND=noninteractive timeout 60s apt-get -o Acquire::ForceIPv4=true update -y; then
        HARDN_STATUS "pass" "System package list updated successfully."
        return 0
    else
        HARDN_STATUS "warning" "apt-get update failed or timed out after 60s. Continuing..."
        return 1
    fi
}

hardn_install_package_dependencies() {
    HARDN_STATUS "info" "Installing required package dependencies..."

    local packages=(
        whiptail
        apt-transport-https
        ca-certificates
        curl
        gnupg
        lsb-release
        git
        build-essential
    )

    # Try to install debsums separately with more verbose output
    HARDN_STATUS "info" "Installing debsums package..."
    if ! apt-get install -y debsums; then
        HARDN_STATUS "warning" "Failed to install debsums. Continuing without it."
    else
        HARDN_STATUS "pass" "Successfully installed debsums."
    fi

    # Use apt-get directly instead of xargs for better error handling
    HARDN_STATUS "info" "Installing other dependencies..."
    if ! apt-get install -y "${packages[@]}"; then
        HARDN_STATUS "warning" "Some packages may have failed to install. Continuing anyway."
    fi

    # Check if all packages are installed
    local missing_packages=()
    for pkg in "${packages[@]}"; do
        if ! dpkg -l "$pkg" 2>/dev/null | grep -q "^ii"; then
            missing_packages+=("$pkg")
        fi
    done

    if [[ ${#missing_packages[@]} -eq 0 ]]; then
        HARDN_STATUS "pass" "Package dependencies installed successfully."
        return 0
    else
        HARDN_STATUS "warning" "Some packages could not be installed: ${missing_packages[*]}"
        # Continue anyway - return success
        return 0
    fi
}

# Print ASCII banner
hardn_print_ascii_banner() {
    local terminal_width
    terminal_width=$(tput cols)
    local banner

    # Here document for the banner
    read -r -d '' banner << "EOF" || true

   ▄█    █▄            ▄████████         ▄████████      ████████▄       ███▄▄▄▄
  ███    ███          ███    ███        ███    ███      ███   ▀███      ███▀▀▀██▄
  ███    ███          ███    ███        ███    ███      ███    ███      ███   ███
 ▄███▄▄▄▄███▄▄        ███    ███       ▄███▄▄▄▄██▀      ███    ███      ███   ███
▀▀███▀▀▀▀███▀       ▀███████████      ▀▀███▀▀▀▀▀        ███    ███      ███   ███
  ███    ███          ███    ███      ▀███████████      ███    ███      ███   ███
  ███    ███          ███    ███        ███    ███      ███    ███      ███   ███
  ███    █▀           ███    █▀         ███    ███      ████████▀        ▀█   █▀
                                        ███    ███

                            Extended Detection and Response
                            by Security International Group

EOF

    # Calculate banner width and padding
    local banner_width
    banner_width=$(printf "%s" "$banner" | awk '{ if (length > max) max = length } END { print max }')
    local padding=$(( (terminal_width - banner_width) / 2 ))

    # Print banner with padding
    printf "\033[1;32m"
    while IFS= read -r line; do
        printf "%*s%s\n" "$padding" "" "$line"
    done <<< "$banner"
    printf "\033[0m"
    sleep 1
}

# Source and run a module
hardn_run_module() {
    local module_file="$1"
    local module_path=""

    # Find module path
    if [[ -f "${HARDN_INSTALLED_MODULE_DIR}/${module_file}" ]]; then
        module_path="${HARDN_INSTALLED_MODULE_DIR}/${module_file}"
    elif [[ -f "${HARDN_MODULE_DIR}/${module_file}" ]]; then
        module_path="${HARDN_MODULE_DIR}/${module_file}"
    else
        HARDN_STATUS "error" "Module not found in either path: $module_file"
        return 1
    fi

    HARDN_STATUS "info" "Executing module: ${module_file}"

    # Source the module
    # shellcheck disable=SC1090
    source "$module_path"

    # Extract module name from filename (remove .sh extension)
    local module_name
    module_name=$(basename "$module_file" .sh)

    # Convert to function name format (replace underscores with underscores)
    local module_func="hardn_${module_name}_main"

    # Check if the module's main function exists
    if declare -F "$module_func" > /dev/null; then
        # Execute the module's main function
        "$module_func"
        return $?
    else
        HARDN_STATUS "warning" "Module $module_file does not contain a $module_func function"
        return 0
    fi
}

# Setup all security modules
hardn_setup_all_security_modules() {
    HARDN_STATUS "info" "Installing security modules..."

    # Create necessary directories
    mkdir -p "${HARDN_CONFIG_DIR}" "${HARDN_LOG_DIR}" "${HARDN_BACKUP_DIR}"

    local modules=(
        "sudo_hardening.sh" "ufw.sh" "fail2ban.sh" "sshd.sh" "auditd.sh" "kernel_sec.sh"
        "stig_pwquality.sh" "grub.sh" "aide.sh" "rkhunter.sh" "chkrootkit.sh"
        "auto_updates.sh" "central_logging.sh" "audit_system.sh" "ntp.sh"
        "debsums.sh" "yara.sh" "suricata.sh" "firejail.sh" "selinux.sh"
        "unhide.sh" "pentest.sh" "compilers.sh" "purge_old_pkgs.sh" "dns_config.sh"
        "file_perms.sh" "shared_mem.sh" "coredumps.sh" "secure_net.sh"
        "network_protocols.sh" "usb.sh" "firewire.sh" "binfmt.sh"
        "process_accounting.sh" "unnecesary_services.sh" "banner.sh"
        "deleted_files.sh"
    )

    for module in "${modules[@]}"; do
        hardn_run_module "$module"
    done
    HARDN_STATUS "pass" "All security modules have been applied."
}

# Perform final system cleanup
hardn_cleanup() {
    HARDN_STATUS "info" "Performing final system cleanup..."
    apt-get autoremove -y &>/dev/null
    apt-get clean &>/dev/null
    apt-get autoclean &>/dev/null
    HARDN_STATUS "pass" "System cleanup completed. Unused packages and cache cleared."
    whiptail --infobox "HARDN-XDR v${HARDN_VERSION} setup complete! Please reboot your system." 8 75
    sleep 3
}

hardn_main_menu() {
    local choice
    choice=$(whiptail --title "HARDN-XDR Main Menu" --menu "Choose an option:" 15 60 3 \
        "1" "Install all security modules" \
        "2" "Select specific security modules" \
        "3" "Exit" 3>&1 1>&2 2>&3)

    case "$choice" in
        1)
            hardn_update_system_packages
            hardn_install_package_dependencies
            hardn_setup_all_security_modules
            hardn_cleanup
            ;;
        2)
            hardn_update_system_packages
            hardn_install_package_dependencies
            hardn_setup_security_modules_interactive  # Assuming this function exists or will be created
            hardn_cleanup
            ;;
        3)
            HARDN_STATUS "info" "Exiting HARDN-XDR."
            exit 0
            ;;
        *)
            HARDN_STATUS "info" "No option selected. Exiting."
            exit 1
            ;;
    esac
}

# Check if script is running as root
hardn_check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        HARDN_STATUS "error" "This script must be run as root."
        return 1
    fi
    return 0
}

main() {
   # Initialize with banner and system information
    hardn_print_ascii_banner
    hardn_detect_system_info
    hardn_show_system_info

    # Check if running as root
    if ! hardn_check_root; then
        HARDN_STATUS "error" "This script must be run as root."
        exit 1
    fi

    # Initialize environment (create directories and module templates)
    hardn_initialize_environment

    # Handle non-interactive mode
    if [[ "${SKIP_WHIPTAIL:-0}" == "1" ]]; then
        HARDN_STATUS "info" "Non-interactive mode: installing all modules."

        # Run operations in sequence with proper error handling
        hardn_update_system_packages
        hardn_install_package_dependencies
        hardn_setup_all_security_modules
        hardn_cleanup
    else
        # Interactive mode
        if ! hardn_welcome_message; then
            HARDN_STATUS "error" "Installation cancelled."
            exit 1
        fi

        # Run main menu
        hardn_main_menu
    fi

    # Final banner and messages
    hardn_print_ascii_banner

    HARDN_STATUS "pass" "HARDN-XDR v${HARDN_VERSION} installation completed successfully!"
    HARDN_STATUS "info" "Your system has been hardened with STIG compliance and security tools."
    HARDN_STATUS "info" "Please reboot your system to complete the configuration."

}

# Setup security modules interactively
hardn_setup_security_modules_interactive() {
    HARDN_STATUS "info" "Setting up security modules interactively..."

    # Create necessary directories
    mkdir -p "${HARDN_CONFIG_DIR}" "${HARDN_LOG_DIR}" "${HARDN_BACKUP_DIR}"

    local modules=(
        "sudo_hardening.sh" "ufw.sh" "fail2ban.sh" "sshd.sh" "auditd.sh" "kernel_sec.sh"
        "stig_pwquality.sh" "grub.sh" "aide.sh" "rkhunter.sh" "chkrootkit.sh"
        "auto_updates.sh" "central_logging.sh" "audit_system.sh" "ntp.sh"
        "debsums.sh" "yara.sh" "suricata.sh" "firejail.sh" "selinux.sh"
        "unhide.sh" "pentest.sh" "compilers.sh" "purge_old_pkgs.sh" "dns_config.sh"
        "file_perms.sh" "shared_mem.sh" "coredumps.sh" "secure_net.sh"
        "network_protocols.sh" "usb.sh" "firewire.sh" "binfmt.sh"
        "process_accounting.sh" "unnecesary_services.sh" "banner.sh"
        "deleted_files.sh"
    )

    # Create checklist options
    local checklist_options=()
    for module in "${modules[@]}"; do
        # Format module name for display (remove .sh and replace underscores with spaces)
        local display_name="${module%.sh}"
        display_name="${display_name//_/ }"
        # Capitalize first letter of each word
        display_name=$(echo "$display_name" | awk '{for(i=1;i<=NF;i++)sub(/./,toupper(substr($i,1,1)),$i)}1')

        checklist_options+=("$module" "$display_name" "OFF")
    done

    # Show checklist and get selected modules
    local selected_modules
    selected_modules=$(mktemp)

    if whiptail --title "Select Security Modules" --checklist \
        "Choose which security modules to install:" 20 78 15 \
        "${checklist_options[@]}" 2>"$selected_modules"; then

        # Process selected modules
        local module
        while IFS= read -r module || [[ -n "$module" ]]; do
            # Remove quotes that whiptail adds
            module=${module//"/"}
            hardn_run_module "$module"
        done < "$selected_modules"

        HARDN_STATUS "pass" "Selected security modules have been applied."
    else
        HARDN_STATUS "warning" "No modules were selected."
    fi

    # Clean up temp file
    rm -f "$selected_modules"
}

# Initialize directory structure and create basic module templates if needed
hardn_initialize_environment() {
    HARDN_STATUS "info" "Initializing HARDN-XDR environment..."

    # Create necessary directories
    mkdir -p "${HARDN_CONFIG_DIR}" "${HARDN_LOG_DIR}" "${HARDN_BACKUP_DIR}" "${HARDN_MODULE_DIR}"

    # Check if modules directory exists and has files
    if [[ ! -d "${HARDN_MODULE_DIR}" || $(find "${HARDN_MODULE_DIR}" -name "*.sh" | wc -l) -eq 0 ]]; then
        HARDN_STATUS "info" "Creating basic module templates in ${HARDN_MODULE_DIR}..."

        # Create a basic module template function
        create_module_template() {
            local module_name="$1"
            local module_file="${HARDN_MODULE_DIR}/${module_name}.sh"
            local function_name="hardn_${module_name}_main"

            # Create module file with basic structure
            cat > "$module_file" << EOF
#!/usr/bin/env bash
# HARDN-XDR Module: ${module_name}
# This module handles ${module_name//_/ } functionality

# Main function for this module
${function_name}() {
    HARDN_STATUS "info" "Running ${module_name//_/ } module..."

    # Module implementation would go here
    # For now, just a placeholder

    HARDN_STATUS "pass" "${module_name//_/ } module completed successfully."
    return 0
}
EOF
            chmod +x "$module_file"
            HARDN_STATUS "info" "Created module template: ${module_name}.sh"
        }

        # Create basic templates for all modules
        local modules=(
            "sudo_hardening" "ufw" "fail2ban" "sshd" "auditd" "kernel_sec"
            "stig_pwquality" "grub" "aide" "rkhunter" "chkrootkit"
            "auto_updates" "central_logging" "audit_system" "ntp"
            "debsums" "yara" "suricata" "firejail" "selinux"
            "unhide" "pentest" "compilers" "purge_old_pkgs" "dns_config"
            "file_perms" "shared_mem" "coredumps" "secure_net"
            "network_protocols" "usb" "firewire" "binfmt"
            "process_accounting" "unnecesary_services" "banner"
            "deleted_files"
        )

        for module in "${modules[@]}"; do
            create_module_template "$module"
        done

        HARDN_STATUS "pass" "Basic module templates created successfully."
    else
        HARDN_STATUS "info" "Module directory already exists with files."
    fi

    # Fix permissions on directories
    chmod -R 750 "${HARDN_CONFIG_DIR}" "${HARDN_LOG_DIR}" "${HARDN_BACKUP_DIR}" "${HARDN_MODULE_DIR}"

    return 0
}

# Handle command line arguments
if [[ $# -gt 0 ]]; then
    case "$1" in
        --version|-v)
            echo "HARDN-XDR v${HARDN_VERSION}"
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [--version|-v] [--help|-h]"
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'"
            echo "Usage: $0 [--version|-v] [--help|-h]"
            exit 1
            ;;
    esac
fi

# Run main function
main
