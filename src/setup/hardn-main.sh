#!/bin/bash

# HARDN-XDR - The Linux Security Hardening Sentinel
# Version 2.0.0
# Developed and built by Christopher Bingham and Tim Burns
# About this script:
# STIG Compliance: Security Technical Implementation Guide.


HARDN_VERSION="1.1.50"
export APT_LISTBUGS_FRONTEND=none
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

install_package_dependencies() {
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
        debsums
    )
  
    if apt-get install -y ${packages[@]}; then
        HARDN_STATUS "pass" "Package dependencies installed successfully."
    else
        HARDN_STATUS "error" "Failed to install package dependencies. Please check your system configuration."
        exit 1
    fi
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
    printf "\033[1;32m"
    while IFS= read -r line; do
        for ((i=0; i<padding; i++)); do
            printf " "
        done
        printf "%s\n" "$line"
    done <<< "$banner"
    sleep 2
    printf "\033[0m"

}

run_module() {
    local module_file="$1"
    local module_path="./modules/${module_file}"
    if [ -f "$module_path" ]; then
        HARDN_STATUS "info" "Executing module: ${module_file}"
        # shellcheck source=./modules/ufw.sh
        source "$module_path"
    else
        HARDN_STATUS "error" "Module not found: ${module_path}"
    fi
}

setup_all_security_modules() {
    HARDN_STATUS "info" "Installing all security modules..."
    local modules=(
        "ufw.sh" "fail2ban.sh" "sshd.sh" "auditd.sh" "kernel_sec.sh"
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
        run_module "$module"
    done

    HARDN_STATUS "pass" "All security modules have been applied."
}

setup_security(){
    HARDN_STATUS "info" "Setting up security tools and configurations..."

    local modules=(
        "ufw.sh" "Configure UFW Firewall" ON
        "fail2ban.sh" "Install and configure Fail2Ban" ON
        "sshd.sh" "Harden SSH Server" ON
        "auditd.sh" "Setup Auditd for system monitoring" ON
        "kernel_sec.sh" "Apply Kernel Security Hardening" ON
        "stig_pwquality.sh" "Enforce STIG password quality" ON
        "grub.sh" "Harden GRUB bootloader" ON
        "aide.sh" "Install AIDE for file integrity" ON
        "rkhunter.sh" "Install rkhunter (Rootkit Hunter)" ON
        "chkrootkit.sh" "Install chkrootkit" ON
        "auto_updates.sh" "Configure automatic updates" ON
        "central_logging.sh" "Setup Central Logging" ON
        "audit_system.sh" "Apply general system audit and hardening" ON
        "ntp.sh" "Configure NTP for time synchronization" ON
        "debsums.sh" "Install debsums to verify package integrity" ON
        "yara.sh" "Install YARA for malware scanning" ON
        "suricata.sh" "Install Suricata IDS/IPS" ON
        "firejail.sh" "Install Firejail for sandboxing" ON
        "selinux.sh" "Install SELinux" ON
        "unhide.sh" "Install unhide to find hidden processes" ON
        "pentest.sh" "Install penetration testing tools" ON
        "compilers.sh" "Remove compilers from the system" ON
        "purge_old_pkgs.sh" "Purge old and unused packages" ON
        "dns_config.sh" "Secure DNS configuration" ON
        "file_perms.sh" "Set secure file permissions" ON
        "shared_mem.sh" "Harden shared memory" ON
        "coredumps.sh" "Disable coredumps" ON
        "secure_net.sh" "Apply secure network settings" ON
        "network_protocols.sh" "Disable uncommon network protocols" ON
        "usb.sh" "Disable USB storage" ON
        "firewire.sh" "Disable FireWire" ON
        "binfmt.sh" "Disable binfmt_misc" ON
        "process_accounting.sh" "Enable process accounting" ON
        "unnecesary_services.sh" "Disable unnecessary services" ON
        "banner.sh" "Set a login banner" ON
        "deleted_files.sh" "Check for deleted files held by processes" ON
    )

    local choices
    choices=$(whiptail --title "HARDN-XDR Security Modules" --checklist \
        "Choose which security modules to apply:" 25 85 18 \
        "${modules[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$choices" ]; then
        HARDN_STATUS "warning" "No modules selected. Skipping security setup."
        return
    fi

    for choice in $choices; do
        # Remove quotes from the choice
        local module_file=$(echo "$choice" | tr -d '"')
        run_module "$module_file"
    done

    HARDN_STATUS "pass" "Selected security modules have been applied."
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

main_menu() {
    local choice
    choice=$(whiptail --title "HARDN-XDR Main Menu" --menu "Choose an option:" 15 60 3 \
        "1" "Install all security modules" \
        "2" "Select specific security modules" \
        "3" "Exit" 3>&1 1>&2 2>&3)

    case "$choice" in
        1)
            update_system_packages
            install_package_dependencies
            setup_all_security_modules
            cleanup
            ;;
        2)
            update_system_packages
            install_package_dependencies
            setup_security
            cleanup
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

main() {
    print_ascii_banner
    show_system_info
    welcomemsg
    main_menu

    print_ascii_banner

    HARDN_STATUS "pass" "HARDN-XDR v${HARDN_VERSION} installation completed successfully!"
    HARDN_STATUS "info" "Your system has been hardened with STIG compliance and security tools."
    HARDN_STATUS "info" "Please reboot your system to complete the configuration."
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
