#!/usr/bin/env bash
# HARDN-XDR - The Linux Security Hardening Sentinel
# Version 2.0.0
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
        "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
        "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
        "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
        "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
        *)          echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
    esac
}

check_root() {
    [[ $EUID -eq 0 ]] || { HARDN_STATUS "error" "Please run as root."; exit 1; }
}

show_system_info() {
    HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} - System Information"
    HARDN_STATUS "info" "================================================"
    HARDN_STATUS "info" "Script Version: ${HARDN_VERSION}"
    HARDN_STATUS "info" "Target OS: Debian-based systems (Debian 12+, Ubuntu 24.04+)"
    if [[ -n "${CURRENT_DEBIAN_VERSION_ID}" && -n "${CURRENT_DEBIAN_CODENAME}" ]]; then
        HARDN_STATUS "info" "Detected OS: ${ID:-Unknown} ${CURRENT_DEBIAN_VERSION_ID} (${CURRENT_DEBIAN_CODENAME})"
    fi
    HARDN_STATUS "info" "Features: STIG Compliance, Malware Detection, System Hardening"
}

welcomemsg() {
    HARDN_STATUS "info" ""
    HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} - Linux Security Hardening Sentinel"
    HARDN_STATUS "info" "================================================================"
    whiptail --title "HARDN-XDR v${HARDN_VERSION}" --msgbox \
        "Welcome to HARDN-XDR v${HARDN_VERSION} - A Debian Security tool for System Hardening\n\nThis will apply STIG compliance, security tools, and comprehensive system hardening." 12 70
    HARDN_STATUS "info" ""
    HARDN_STATUS "info" "This installer will update your system first..."
    if whiptail --title "HARDN-XDR v${HARDN_VERSION}" --yesno \
        "Do you want to continue with the installation?" 10 60; then
        return 0
    else
        HARDN_STATUS "error" "Installation cancelled by user."
        exit 1
    fi
}

preinstallmsg() {
    HARDN_STATUS "info" ""
    whiptail --title "HARDN-XDR" --msgbox "Welcome to HARDN-XDR. A Linux Security Hardening program." 10 60
    HARDN_STATUS "info" "The system will be configured to ensure STIG and Security compliance."
}

update_system_packages() {
    HARDN_STATUS "info" "Updating system packages..."
    if DEBIAN_FRONTEND=noninteractive timeout 60s apt-get -o Acquire::ForceIPv4=true update -y; then
        HARDN_STATUS "pass" "System package list updated successfully."
    else
        HARDN_STATUS "warning" "apt-get update failed or timed out after 60s. Continuing..."
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
    if apt-get install -y "${packages[@]}"; then
        HARDN_STATUS "pass" "Package dependencies installed successfully."
    else
        HARDN_STATUS "error" "Failed to install package dependencies. Please check your system configuration."
        exit 1
    fi
}

print_ascii_banner() {
    local terminal_width=$(tput cols)
    local banner=$(cat << "EOF"

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
    local banner_width=$(echo "$banner" | awk '{print length}' | sort -n | tail -1)
    local padding=$(( (terminal_width - banner_width) / 2 ))
    printf "\033[1;32m"
    while IFS= read -r line; do
        printf "%*s%s\n" "$padding" "" "$line"
    done <<< "$banner"
    printf "\033[0m"
    sleep 2
}

run_module() {
    local module_file="$1"
    local module_path_installed="/usr/lib/hardn-xdr/src/setup/modules/$module_file"
    local module_path_local="${SCRIPT_DIR}/modules/$module_file"
    if [[ -f "$module_path_installed" ]]; then
        HARDN_STATUS "info" "Executing module (installed path): ${module_file}"
        source "$module_path_installed"
    elif [[ -f "$module_path_local" ]]; then
        HARDN_STATUS "info" "Executing module (local dev path): ${module_file}"
        source "$module_path_local"
    else
        HARDN_STATUS "error" "Module not found in either path: $module_file"
    fi
}

setup_all_security_modules() {
    HARDN_STATUS "info" "Installing security modules..."
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

cleanup() {
    HARDN_STATUS "info" "Performing final system cleanup..."
    apt-get autoremove -y &>/dev/null
    apt-get clean &>/dev/null
    apt-get autoclean &>/dev/null
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
    check_root
    if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
        HARDN_STATUS "info" "Non-interactive mode: installing all modules."
        update_system_packages
        install_package_dependencies
        setup_all_security_modules
        cleanup
    else
        welcomemsg
        main_menu
    fi

    print_ascii_banner

    HARDN_STATUS "pass" "HARDN-XDR v${HARDN_VERSION} installation completed successfully!"
    HARDN_STATUS "info" "Your system has been hardened with STIG compliance and security tools."
    HARDN_STATUS "info" "Please reboot your system to complete the configuration."
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        --version|-v)
            HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION}"
            exit 0
            ;;
        --help|-h)
            HARDN_STATUS "info" "Usage: \$0 [--version]|[--help]"
            exit 0
            ;;
        *)
            HARDN_STATUS "error" "Unknown option '$1'"
            exit 1
            ;;
    esac
fi

main
