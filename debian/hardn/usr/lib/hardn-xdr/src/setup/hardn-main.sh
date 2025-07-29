#!/usr/bin/env bash

HARDN_VERSION="1.1.63"
export APT_LISTBUGS_FRONTEND=none

# Auto-detect CI or headless environment
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -n "$GITLAB_CI" || ! -t 0 ]]; then
    export SKIP_WHIPTAIL=1
    echo "[INFO] CI environment detected, running in non-interactive mode"
fi


if [ -f /usr/lib/hardn-xdr/src/setup/hardn-common.sh ]; then
    source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
else
    echo "[ERROR] hardn-common.sh not found at expected path!"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURRENT_DEBIAN_VERSION_ID=""
CURRENT_DEBIAN_CODENAME=""

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

    hardn_msgbox "Welcome to HARDN-XDR v${HARDN_VERSION} - A Debian Security tool for System Hardening\n\nThis will apply STIG compliance, security tools, and comprehensive system hardening." 12 70

    HARDN_STATUS "info" ""
    HARDN_STATUS "info" "This installer will update your system first..."

    if hardn_yesno "Do you want to continue with the installation?" 10 60; then
        return 0
    else
        HARDN_STATUS "error" "Installation cancelled by user."
        exit 1
    fi
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
   # Declaring and assigning terminal width and banner separately to avoid masking return variables
   # https://github.com/koalaman/shellcheck/wiki/SC2155
    export TERM=xterm
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
          banner_width=$(echo "$banner" | awk '{print length}' | sort -n | tail -1)
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
    local module_paths=(
        "/usr/lib/hardn-xdr/src/setup/modules/$module_file"
        "${SCRIPT_DIR}/modules/$module_file"
    )

    for module_path in "${module_paths[@]}"; do
        if [[ -f "$module_path" ]]; then
            HARDN_STATUS "info" "Executing module: ${module_file} from ${module_path}"
            # shellcheck source=/usr/lib/hardn-xdr/src/setup/modules/
            # shellcheck source=./modules/
            source "$module_path"
            return 0
        fi
    done

    HARDN_STATUS "error" "Module not found in any expected location: $module_file"
    for path in "${module_paths[@]}"; do
        HARDN_STATUS "error" "  - $path"
    done
    return 1
}

setup_security_modules() {
    HARDN_STATUS "info" "Installing security modules..."
    local modules=(
        "ufw.sh" "fail2ban.sh" "sshd.sh" "auditd.sh" "kernel_sec.sh"
        "stig_pwquality.sh" "aide.sh" "rkhunter.sh" "chkrootkit.sh"
        "auto_updates.sh" "central_logging.sh" "audit_system.sh" "ntp.sh"
        "debsums.sh" "yara.sh" "suricata.sh" "firejail.sh" "selinux.sh"
        "unhide.sh" "pentest.sh" "compilers.sh" "purge_old_pkgs.sh" "dns_config.sh"
        "file_perms.sh" "apparmor.sh" "shared_mem.sh" "coredumps.sh" "secure_net.sh"
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
    apt-get autoclean -y &>/dev/null
    HARDN_STATUS "pass" "System cleanup completed. Unused packages and cache cleared."

    if [[ "$SKIP_WHIPTAIL" != "1" ]]; then
        whiptail --infobox "HARDN-XDR v${HARDN_VERSION} setup complete! Please reboot your system." 8 75
        sleep 3
    else
        HARDN_STATUS "info" "HARDN-XDR v${HARDN_VERSION} setup complete! Please reboot your system."
    fi
}

main_menu() {
    local modules=(
        "ufw.sh" "fail2ban.sh" "sshd.sh" "auditd.sh" "kernel_sec.sh"
        "stig_pwquality.sh" "aide.sh" "rkhunter.sh" "chkrootkit.sh"
        "auto_updates.sh" "central_logging.sh" "audit_system.sh" "ntp.sh"
        "debsums.sh" "yara.sh" "suricata.sh" "firejail.sh" "selinux.sh"
        "unhide.sh" "pentest.sh" "compilers.sh" "purge_old_pkgs.sh" "dns_config.sh"
        "file_perms.sh" "shared_mem.sh" "coredumps.sh" "secure_net.sh"
        "network_protocols.sh" "usb.sh" "firewire.sh" "binfmt.sh"
        "process_accounting.sh" "unnecesary_services.sh" "banner.sh"
        "deleted_files.sh"
    )
    local checklist_args=()
    for module in "${modules[@]}"; do
        checklist_args+=("$module" "Install $module" "OFF")
    done
    checklist_args+=("ALL" "Install all modules" "OFF")

    local selected
    selected=$(whiptail --title "HARDN-XDR Module Selection" --checklist "Select modules to install (SPACE to select, TAB to move):" 25 80 15 "${checklist_args[@]}" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        HARDN_STATUS "info" "No modules selected. Exiting."
        exit 1
    fi

    update_system_packages
    install_package_dependencies

    if [[ "$selected" == *"ALL"* ]]; then
        setup_security_modules
    else
        # Remove quotes from whiptail output
        selected=$(echo $selected | tr -d '"')
        for module in $selected; do
            run_module "$module"
        done
        HARDN_STATUS "pass" "Selected security modules have been applied."
    fi
    cleanup
}

# main
main() {
    print_ascii_banner
    show_system_info
    check_root

    if [[ "$SKIP_WHIPTAIL" == "1" || "$AUTO_MODE" == "true" ]]; then
        HARDN_STATUS "info" "Running in non-interactive mode"
        update_system_packages
        install_package_dependencies
        setup_security_modules
        cleanup
        return 0
    fi

    welcomemsg
    main_menu
}

# Entry
if [[ $# -gt 0 ]]; then
    case "$1" in
        --version|-v)
            echo "HARDN-XDR version 1.1.x"
            exit 0
            ;;
        --help|-h)
            echo "Usage: hardn-xdr [OPTIONS]"
            echo "Options:"
            echo "  --version, -v     Display version information"
            echo "  --help, -h        Display this help message"
            echo "  --auto            Run in automatic mode without prompts"
            echo "  --ci              Run in CI environment mode"
            exit 0
            ;;
        --auto)
            export AUTO_MODE=true
            ;;
        --ci)
            export CI_MODE=true
            export SKIP_WHIPTAIL=1
            export AUTO_MODE=true
            ;;
    esac
fi

main
