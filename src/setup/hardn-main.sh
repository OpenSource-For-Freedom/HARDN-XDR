#!/bin/bash

# HARDN-XDR - The Linux Security Hardening Sentinel
# Version 2.0.0
# Developed and built by Christopher Bingham and Tim Burns
# About this script:
# STIG Compliance: Security Technical Implementation Guide.

HARDN_VERSION="2.1.0"
export APT_LISTBUGS_FRONTEND=none
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGS_CSV_PATH="${SCRIPT_DIR}/../../progs.csv"
CURRENT_DEBIAN_VERSION_ID=""
CURRENT_DEBIAN_CODENAME=""

HARDN_STATUS() {
    local status="$1"
    local message="$2"
    case "$status" in
        "pass")
            echo -e "\033[1;32m[PASS]\033[0m $message"
            ;;
        "warning")
            echo -e "\033[1;33m[WARNING]\033[0m $message"
            ;;
        "error")
            echo -e "\033[1;31m[ERROR]\033[0m $message"
            ;;
        "info")
            echo -e "\033[1;34m[INFO]\033[0m $message"
            ;;
        *)
            echo -e "\033[1;37m[UNKNOWN]\033[0m $message"
            ;;
    esac
}   
detect_os_details() {
    if [[ -r /etc/os-release ]]; then
        source /etc/os-release
        CURRENT_DEBIAN_CODENAME="${VERSION_CODENAME}"
        CURRENT_DEBIAN_VERSION_ID="${VERSION_ID}"
    fi
}

detect_os_details

show_system_info() {
    echo "HARDN-XDR v${HARDN_VERSION} - System Information"
    echo "================================================"
    echo "Script Version: ${HARDN_VERSION}"
    echo "Target OS: Debian-based systems (Debian 12+, Ubuntu 24.04+)"
    if [[ -n "${CURRENT_DEBIAN_VERSION_ID}" && -n "${CURRENT_DEBIAN_CODENAME}" ]]; then
        echo "Detected OS: ${ID:-Unknown} ${CURRENT_DEBIAN_VERSION_ID} (${CURRENT_DEBIAN_CODENAME})"
    fi
    echo "Features: STIG Compliance, Malware Detection, System Hardening"
    echo "Security Tools: UFW, Fail2Ban, AppArmor, AIDE, rkhunter, and more"
    echo ""
}

welcomemsg() {
    echo ""
    echo ""
    echo "HARDN-XDR v${HARDN_VERSION} - Linux Security Hardening Sentinel"
    echo "================================================================"
    whiptail --title "HARDN-XDR v${HARDN_VERSION}" --msgbox "Welcome to HARDN-XDR v${HARDN_VERSION} - A Debian Security tool for System Hardening\n\nThis will apply STIG compliance, security tools, and comprehensive system hardening." 12 70
    echo ""
    echo "This installer will update your system first..."
    if whiptail --title "HARDN-XDR v${HARDN_VERSION}" --yesno "Do you want to continue with the installation?" 10 60; then
        true  
    else
        echo "Installation cancelled by user."
        exit 1
    fi
}

preinstallmsg() {
    echo ""
    whiptail --title "HARDN-XDR" --msgbox "Welcome to HARDN-XDR. A Linux Security Hardening program." 10 60
    echo "The system will be configured to ensure STIG and Security compliance."
   
}

update_system_packages() {
    HARDN_STATUS "pass" "Updating system packages..."
    if DEBIAN_FRONTEND=noninteractive timeout 10s apt-get -o Acquire::ForceIPv4=true update -y; then
        HARDN_STATUS "pass" "System package list updated successfully."
    else
        HARDN_STATUS "warning" "apt-get update failed or timed out after 60 seconds. Check your network or apt sources, but continuing script."
    fi
}

# install_package_dependencies
install_package_dependencies() {
    HARDN_STATUS "pass" "Installing package dependencies from ${PROGS_CSV_PATH}..."

    if ! command -v git >/dev/null 2>&1; then
        HARDN_STATUS "info" "Git is not installed. Attempting to install git..."
        if DEBIAN_FRONTEND=noninteractive apt-get install -y git >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Successfully installed git."
        else
            HARDN_STATUS "error" "Failed to install git. Some packages might fail to install if they require git."
            # Do not exit, allow script to continue if git is not strictly needed by all packages
        fi
    else
        HARDN_STATUS "info" "Git is already installed."
    fi

    # Check if the CSV file exists
    if [[ ! -f "${PROGS_CSV_PATH}" ]]; then
        HARDN_STATUS "error" "Package list file not found: ${PROGS_CSV_PATH}"
        return 1
    fi

    # Read the CSV file, skipping the header
    while IFS=, read -r name version debian_min_version debian_codenames_str rest || [[ -n "$name" ]]; do
        # Skip comments and empty lines
        [[ -z "$name" || "$name" =~ ^[[:space:]]*# ]] && continue

        name=$(echo "$name" | xargs)
        version=$(echo "$version" | xargs)
        debian_min_version=$(echo "$debian_min_version" | xargs)
        debian_codenames_str=$(echo "$debian_codenames_str" | xargs | tr -d '"') # Remove quotes from codenames string

        if [[ -z "$name" ]]; then
            HARDN_STATUS "warning" "Skipping line with empty package name."
            continue
        fi

        HARDN_STATUS "info" "Processing package: $name (Version: $version, Min Debian: $debian_min_version, Codenames: '$debian_codenames_str')"

        # Check OS compatibility
        os_compatible=false
        if [[ ",${debian_codenames_str}," == *",${CURRENT_DEBIAN_CODENAME},"* ]]; then
            if [[ "${debian_min_version}" == "12" ]]; then
                os_compatible=true
            else
                HARDN_STATUS "warning" "Skipping $name: Requires Debian version >= $debian_min_version, but current is $CURRENT_DEBIAN_VERSION_ID."
            fi
        else
            HARDN_STATUS "warning" "Skipping $name: Not compatible with Debian codename $CURRENT_DEBIAN_CODENAME (requires one of: $debian_codenames_str)."
        fi

        if ! $os_compatible; then
            continue
        fi

        # Installation logic based on version
        case "$version" in
            "latest")
                if ! dpkg -s "$name" >/dev/null 2>&1; then
                    HARDN_STATUS "info" "Attempting to install package: $name (latest from apt)..."
                    if DEBIAN_FRONTEND=noninteractive apt install -y "$name"; then
                        HARDN_STATUS "pass" "Successfully installed $name."
                    else
                        HARDN_STATUS "warning" "apt install failed for $name, trying apt-get..."
                        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$name"; then
                             HARDN_STATUS "pass" "Successfully installed $name with apt-get."
                        else
                            HARDN_STATUS "error" "Failed to install $name with both apt and apt-get. Please check manually."
                        fi
                    fi
                else
                    HARDN_STATUS "info" "Package $name is already installed."
                fi
                ;;
            "source")
                HARDN_STATUS "warning" "INFO: 'source' installation type for $name. This type requires manual implementation in the script."
                HARDN_STATUS "warning" "Example steps for a source install (e.g., for a package named 'mytool'):"
                HARDN_STATUS "warning" "  1. Ensure build dependencies are installed (e.g., build-essential, cmake, etc.)."
                HARDN_STATUS "warning" "  2. wget https://example.com/mytool-src.tar.gz -O /tmp/mytool-src.tar.gz"
                HARDN_STATUS "warning" "  3. tar -xzf /tmp/mytool-src.tar.gz -C /tmp"
                HARDN_STATUS "warning" "  4. cd /tmp/mytool-* || exit 1"
                HARDN_STATUS "warning" "  5. ./configure && make && sudo make install"
                HARDN_STATUS "warning" "Skipping $name as its specific source installation steps are not defined."
                ;;
            "custom")
                HARDN_STATUS "warning" "INFO: 'custom' installation type for $name. This type requires manual implementation in the script."
                HARDN_STATUS "warning" "Example steps for a custom install (e.g., for a package named 'mycustomapp'):"
                HARDN_STATUS "warning" "  1. Add custom repository: curl -sSL https://example.com/repo/gpg | sudo apt-key add -"
                HARDN_STATUS "warning" "  2. echo 'deb https://example.com/repo ${CURRENT_DEBIAN_CODENAME} main' | sudo tee /etc/apt/sources.list.d/mycustomapp.list"
                HARDN_STATUS "warning" "  3. sudo apt update"
                HARDN_STATUS "warning" "  4. sudo apt install -y mycustomapp"
                HARDN_STATUS "warning" "Skipping $name as its specific custom installation steps are not defined."
                ;;
            *)
                HARDN_STATUS "error" "Unknown version '$version' for package $name. Skipping..."
                ;;
        esac
    done < <(tail -n +2 "${PROGS_CSV_PATH}")
    HARDN_STATUS "pass" "Package dependency installation attempt completed."
}

print_ascii_banner() {

    local terminal_width
    terminal_width=$(tput cols)
    local banner
    banner=$(cat << "EOF"

   ▄█    █▄            ▄████████         ▄████████      ████████▄       ███▄▄▄▄   
  ███    ███          ███    ███        ███    ███      ███   ▀███      ███▀▀▀██▄ 
  ███    ███          ███    ███        ███    ███      ███    ███      ███   ███ 
 ▄███▄▄▄▄███▄▄        ███    ███       ▄███▄▄▄▄██▀      ███    ███      ███   ███ 
▀▀███▀▀▀▀███▀       ▀███████████      ▀▀███▀▀▀▀▀        ███    ███      ███   ███ 
  ███    ███          ███    ███      ▀███████████      ███    ███      ███   ███ 
  ███    ███          ███    ███        ███    ███      ███   ▄███      ███   ███ 
  ███    █▀           ███    █▀         ███    ███      ████████▀        ▀█   █▀  
                                        ███    ███ 
                           
                            Extended Detection and Response
                            by Security International Group
                                  
EOF
)
    local banner_width
    banner_width=$(echo "$banner" | awk '{print length($0)}' | sort -n | tail -1)
    local padding=$(( (terminal_width - banner_width) / 2 ))
    local i
    printf "\033[1;31m"
    while IFS= read -r line; do
        for ((i=0; i<padding; i++)); do
            printf " "
        done
        printf "%s\n" "$line"
    done <<< "$banner"
    sleep 2
    printf "\033[0m"

}

setup_security(){
    # OS detection is done by detect_os_details() 
    # global variables CURRENT_DEBIAN_VERSION_ID and CURRENT_DEBIAN_CODENAME are available.
    HARDN_STATUS "pass" "Using detected system: Debian ${CURRENT_DEBIAN_VERSION_ID} (${CURRENT_DEBIAN_CODENAME}) for security setup."
    HARDN_STATUS "info" "Setting up security tools and configurations..."
    source ./modules/ufw.sh 
	source ./modules/deleted_files.sh 
	source ./modules/ntp.sh
	source ./modules/usb.sh
	source ./modules/network_protocols.sh
	source ./modules/file_perms.sh
	source ./modules/shared_mem.sh
	source ./modules/coredumps.sh
	source ./modules/auto_updates.sh
	source ./modules/secure_net.sh
 	source ./modules/stig_pwquality.sh
	# TODO: fix chkrootkit's download URL; the one in the module DOES NOT exist.
	#source ./modules/chkrootkit.sh
	source ./modules/auditd.sh
	source ./modules/suricata.sh
	source ./modules/debsums.sh
	source ./modules/aide.sh
	source ./modules/yara.sh
	source ./modules/banner.sh
	source ./modules/compilers.sh
	source ./modules/grub.sh
	source ./modules/binfmt.sh
	source ./modules/purge_old_pkgs.sh
	source ./modules/dns_config.sh
	source ./modules/firewire.sh
	source ./modules/process_accounting.sh
	source ./modules/kernel_sec.sh
	source ./modules/central_logging.sh
	source ./modules/unnecesary_services.sh
	source ./modules/audit_system.sh
	source ./modules/pentest.sh
	source ./modules/rkhunter.sh 
}

cleanup() {
    HARDN_STATUS "info" "Performing final system cleanup..."
    apt-get autoremove -y >/dev/null 2>&1
    apt-get clean >/dev/null 2>&1
    apt-get autoclean >/dev/null 2>&1
    HARDN_STATUS "pass" "System cleanup completed. Unused packages and cache cleared."
    whiptail --infobox "HARDN-XDR v${HARDN_VERSION} setup complete! Please reboot your system." 8 75
    sleep 3

}

main() {
    print_ascii_banner
    show_system_info
    welcomemsg
    update_system_packages
    install_package_dependencies "../../progs.csv"
    setup_security
    cleanup
    print_ascii_banner

    HARDN_STATUS "pass" "HARDN-XDR v${HARDN_VERSION} installation completed successfully!"
    HARDN_STATUS "info" "Your system has been hardened with STIG compliance and security tools."
    HARDN_STATUS "warning" "Please reboot your system to complete the configuration."
}

# Command line argument handling
if [[ $# -gt 0 ]]; then
    case "$1" in
        --version|-v)
            echo "HARDN-XDR v${HARDN_VERSION}"
            echo "Linux Security Hardening Sentinel"
            echo "Extended Detection and Response"
            echo ""
            echo "Target Systems: Debian 12+, Ubuntu 24.04+"
            echo "Features: STIG Compliance, Malware Detection, System Hardening"
            echo "Developed by: Christopher Bingham and Tim Burns"
            echo ""
            echo "This is the final public release of HARDN-XDR."
            exit 0
            ;;
        --help|-h)
            echo "HARDN-XDR v${HARDN_VERSION} - Linux Security Hardening Sentinel"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --version, -v    Show version information"
            echo "  --help, -h       Show this help message"
            echo ""
            echo "This script applies comprehensive security hardening to Debian-based systems"
            echo "including STIG compliance, malware detection, and security monitoring."
            echo ""
            echo "WARNING: This script makes significant system changes. Run only on systems"
            echo "         intended for security hardening."
            exit 0
            ;;
        *)
            echo "Error: Unknown option '$1'"
            echo "Use '$0 --help' for usage information."
            exit 1
            ;;
    esac
fi

main
