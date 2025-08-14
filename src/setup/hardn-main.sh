#!/usr/bin/env bash

HARDN_VERSION="1.1.63"
export APT_LISTBUGS_FRONTEND=none

# Auto-detect CI or headless environment
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -n "$GITLAB_CI" || ! -t 0 ]]; then
    export SKIP_WHIPTAIL=1
    echo "[INFO] CI environment detected, running in non-interactive mode"
fi


if [ -f /usr/lib/hardn-xdr/src/setup/hardn-common.sh ]; then
    # shellcheck source=src/setup/hardn-common.sh
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
    HARDN_STATUS "info" "Target OS: Debian-based systems (Debian 12+, Ubuntu 24.04+, PakOS)"
    if [[ -n "${CURRENT_DEBIAN_VERSION_ID}" && -n "${CURRENT_DEBIAN_CODENAME}" ]]; then
        HARDN_STATUS "info" "Detected OS: ${ID:-Unknown} ${CURRENT_DEBIAN_VERSION_ID} (${CURRENT_DEBIAN_CODENAME})"
        
        # Special message for PakOS
        if [[ "${PAKOS_DETECTED:-0}" == "1" ]]; then
            HARDN_STATUS "info" "PakOS Support: Enabled (Debian-derivative compatibility mode)"
        fi
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
            # shellcheck source=src/setup/modules/aide.sh
            source "$module_path" >/dev/null 2>&1
            local source_result=$?

            if [[ $source_result -eq 0 ]]; then
                return 0
            else
                HARDN_STATUS "error" "Module execution failed: $module_path"
                return 1
            fi
        fi
    done

    HARDN_STATUS "error" "Module not found in any expected location: $module_file"
    for path in "${module_paths[@]}"; do
        HARDN_STATUS "error" "  - $path"
    done
    return 1
}

# Container/VM essential modules for DISA/FEDHIVE compliance
get_container_vm_essential_modules() {
    echo "auditd.sh kernel_sec.sh sshd.sh credential_protection.sh aide.sh"
    echo "auto_updates.sh file_perms.sh shared_mem.sh coredumps.sh"
    echo "network_protocols.sh process_accounting.sh debsums.sh purge_old_pkgs.sh"
    echo "banner.sh central_logging.sh audit_system.sh ntp.sh dns_config.sh"
    echo "binfmt.sh service_disable.sh stig_pwquality.sh pakos_config.sh"
}

# Container/VM conditional modules (performance vs security trade-off)
get_container_vm_conditional_modules() {
    echo "ufw.sh fail2ban.sh selinux.sh apparmor.sh suricata.sh yara.sh"
    echo "rkhunter.sh chkrootkit.sh unhide.sh secure_net.sh"
}

# Desktop-focused modules (skip in container/VM environments for performance)
get_desktop_focused_modules() {
    echo "usb.sh firewire.sh firejail.sh compilers.sh pentest.sh"
    echo "behavioral_analysis.sh persistence_detection.sh process_protection.sh"
    echo "deleted_files.sh unnecessary_services.sh"
}

# Legacy full module list for backwards compatibility
get_full_module_list() {
    echo "ufw.sh fail2ban.sh sshd.sh auditd.sh kernel_sec.sh"
    echo "stig_pwquality.sh aide.sh rkhunter.sh chkrootkit.sh"
    echo "auto_updates.sh central_logging.sh audit_system.sh ntp.sh"
    echo "debsums.sh yara.sh suricata.sh firejail.sh selinux.sh"
    echo "unhide.sh pentest.sh compilers.sh purge_old_pkgs.sh dns_config.sh"
    echo "file_perms.sh apparmor.sh shared_mem.sh coredumps.sh secure_net.sh"
    echo "network_protocols.sh usb.sh firewire.sh binfmt.sh"
    echo "process_accounting.sh unnecessary_services.sh banner.sh"
    echo "deleted_files.sh credential_protection.sh service_disable.sh"
}

# Detect if we're in a container/VM optimized environment
is_container_vm_environment() {
    # Check for container environment
    if is_container_environment; then
        return 0
    fi
    
    # Check for VM indicators
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        if systemd-detect-virt --quiet 2>/dev/null; then
            return 0
        fi
    fi
    
    # Check for VM-specific indicators
    if [[ -d /proc/vz ]] || \
       [[ -f /proc/user_beancounters ]] || \
       grep -qi hypervisor /proc/cpuinfo 2>/dev/null || \
       [[ -n "$HARDN_CONTAINER_VM_MODE" ]]; then
        return 0
    fi
    
    return 1
}

setup_security_modules() {
    local environment_type=""
    local modules=()
    
    # Determine environment and select appropriate modules
    if is_container_vm_environment; then
        environment_type="Container/VM"
        HARDN_STATUS "info" "Container/VM environment detected - optimizing for DISA/FEDHIVE compliance"
        
        # Essential modules for compliance
        readarray -t modules < <(get_container_vm_essential_modules | tr ' ' '\n')
        
        # Add conditional modules with user choice in interactive mode
        if [[ "$SKIP_WHIPTAIL" != "1" ]]; then
            if hardn_yesno "Include additional security modules (may impact performance)?" 10 60; then
                readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
                modules+=("${conditional[@]}")
            fi
        else
            # In non-interactive mode, include conditional modules
            readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
            modules+=("${conditional[@]}")
        fi
        
        # Skip desktop-focused modules
        HARDN_STATUS "info" "Skipping desktop-focused modules for optimal container/VM performance"
        
    else
        environment_type="Desktop/Physical"
        HARDN_STATUS "info" "Desktop/Physical environment detected - applying full hardening suite"
        readarray -t modules < <(get_full_module_list | tr ' ' '\n')
    fi
    
    HARDN_STATUS "info" "Applying ${#modules[@]} security modules for $environment_type environment..."
    
    local failed_modules=0
    for module in "${modules[@]}"; do
        if [[ -n "$module" ]]; then
            if run_module "$module"; then
                HARDN_STATUS "pass" "Module completed: $module"
            else
                HARDN_STATUS "warning" "Module failed: $module"
                ((failed_modules++))
            fi
        fi
    done
    
    if [[ $failed_modules -eq 0 ]]; then
        HARDN_STATUS "pass" "All $environment_type security modules have been applied successfully."
    else
        HARDN_STATUS "warning" "$failed_modules modules failed. Check logs for details."
    fi
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
    local environment_type=""
    local modules=()
    
    # Determine environment and get appropriate module list
    if is_container_vm_environment; then
        environment_type="Container/VM (DISA/FEDHIVE optimized)"
        # Combine essential and conditional modules for menu
        readarray -t essential < <(get_container_vm_essential_modules | tr ' ' '\n')
        readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
        readarray -t desktop < <(get_desktop_focused_modules | tr ' ' '\n')
        
        modules=("${essential[@]}" "${conditional[@]}" "${desktop[@]}")
    else
        environment_type="Desktop/Physical"
        readarray -t modules < <(get_full_module_list | tr ' ' '\n')
    fi
    
    HARDN_STATUS "info" "Environment detected: $environment_type"
    
    local checklist_args=()
    
    # Add modules with categorization for container/VM environments only
    if is_container_vm_environment; then
        # Essential modules (pre-selected)
        readarray -t essential < <(get_container_vm_essential_modules | tr ' ' '\n')
        for module in "${essential[@]}"; do
            if [[ -n "$module" ]]; then
                checklist_args+=("$module" "[ESSENTIAL] Install $module (DISA/FEDHIVE compliance)" "ON")
            fi
        done
        
        # Conditional modules (optional)
        readarray -t conditional < <(get_container_vm_conditional_modules | tr ' ' '\n')
        for module in "${conditional[@]}"; do
            if [[ -n "$module" ]]; then
                checklist_args+=("$module" "[OPTIONAL] Install $module (performance trade-off)" "OFF")
            fi
        done
        
        # Desktop modules (discouraged)
        readarray -t desktop < <(get_desktop_focused_modules | tr ' ' '\n')
        for module in "${desktop[@]}"; do
            if [[ -n "$module" ]]; then
                checklist_args+=("$module" "[DESKTOP] Install $module (not recommended)" "OFF")
            fi
        done
        
        checklist_args+=("ALL" "Install recommended modules for this environment" "OFF")
    else
        # Original clean interface for desktop/physical systems
        for module in "${modules[@]}"; do
            if [[ -n "$module" ]]; then
                checklist_args+=("$module" "Install $module" "OFF")
            fi
        done
        
        checklist_args+=("ALL" "Install all modules" "OFF")
    fi

    local title="HARDN-XDR Module Selection"
    if is_container_vm_environment; then
        title="$title - $environment_type"
    fi

    local selected
    if ! selected=$(whiptail --title "$title" --checklist "Select modules to install (SPACE to select, TAB to move):" 25 80 15 "${checklist_args[@]}" 3>&1 1>&2 2>&3); then
        HARDN_STATUS "info" "No modules selected. Exiting."
        exit 1
    fi

    update_system_packages
    install_package_dependencies

    if [[ "$selected" == *"ALL"* ]]; then
        setup_security_modules
    else
        # Remove quotes from whiptail output
        selected=$(echo "$selected" | tr -d '"')
        local failed_modules=0
        for module in $selected; do
            if run_module "$module"; then
                HARDN_STATUS "pass" "Module completed: $module"
            else
                HARDN_STATUS "warning" "Module failed: $module"
                ((failed_modules++))
            fi
        done
        
        if [[ $failed_modules -eq 0 ]]; then
            HARDN_STATUS "pass" "Selected security modules have been applied successfully."
        else
            HARDN_STATUS "warning" "$failed_modules modules failed. Check logs for details."
        fi
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
