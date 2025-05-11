#!/bin/bash
set -e # Exit on errors

if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    echo "Usage: sudo hardn [options]"
    echo "Runs the HARDN system hardening setup."
    exit 0
fi

print_ascii_banner() {
    CYAN_BOLD="\033[1;36m"
    RESET="\033[0m"
    cat <<EOF
${CYAN_BOLD}
                              ▄█    █▄       ▄████████    ▄████████ ████████▄  ███▄▄▄▄   
                             ███    ███     ███    ███   ███    ███ ███   ▀███ ███▀▀▀██▄ 
                             ███    ███     ███    ███   ███    ███ ███    ███ ███   ███ 
                            ▄███▄▄▄▄███▄▄   ███    ███  ▄███▄▄▄▄██▀ ███    ███ ███   ███ 
                           ▀▀███▀▀▀▀███▀  ▀███████████ ▀▀███▀▀▀▀▀   ███    ███ ███   ███ 
                             ███    ███     ███    ███ ▀███████████ ███    ███ ███   ███ 
                             ███    ███     ███    ███   ███    ███ ███   ▄███ ███   ███ 
                             ███    █▀      ███    █▀    ███    ███ ████████▀   ▀█   █▀  
                                                         ███    ███ 
                                    
                                                   S E T U P
                                                   
                                                    v 1.1.4
${RESET}
EOF
}

print_ascii_banner
sleep 5 


SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGES_SCRIPT="$SCRIPT_DIR/hardn-packages.sh"


if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use: sudo hardn"
    exit 1
fi


detect_os() {
    if [ -f /etc/os-release ] && [ -r /etc/os-release ]; then
        . /etc/os-release
        export OS_NAME="$NAME"
        export OS_VERSION="$VERSION_ID"

        case "$OS_NAME" in
            "Debian GNU/Linux")
                if [[ "$OS_VERSION" == "11" || "$OS_VERSION" == "12" ]]; then
                    echo "Detected supported OS: $OS_NAME $OS_VERSION"
                else
                    echo "Unsupported Debian version: $OS_VERSION. Exiting."
                    exit 1
                fi
                ;;
            "Ubuntu")
                if [[ "$OS_VERSION" == "22.04" || "$OS_VERSION" == "24.04" ]]; then
                    echo "Detected supported OS: $OS_NAME $OS_VERSION"
                else
                    echo "Unsupported Ubuntu version: $OS_VERSION. Exiting."
                    exit 1
                fi
                ;;
            *)
                echo "Unsupported OS: $OS_NAME. Exiting."
                exit 1
                ;;
        esac
    else
        echo "Unable to read /etc/os-release. Exiting."
        exit 1
    fi
}


update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    apt update -y && apt upgrade -y
    sudo apt-get install -f
    apt --fix-broken install -y
}

install_pkgdeps() {
    printf "\033[1;31m[+] Installing package dependencies...\033[0m\n"
    apt install -y git gawk mariadb-common policycoreutils dpkg-dev \
        unixodbc-common firejail python3-pyqt6 fonts-liberation libpam-pwquality
}


install_tools() {
    printf "\033[1;31m[+] Installing tools as root...\033[0m\n"
    local TOOLS_DIR="$SCRIPT_DIR/tools"
    local TOOLS=(
        "install_aide.sh"
        "install_apparmor_profiles.sh"
        "install_yara.sh"
        "install_apparmor.sh"
        "install_chkrootkit.sh"
        "install_debsums.sh"
        "install_fail2ban.sh"
        "install_firejail.sh"
        "install_fwupd.sh"
        "install_libpam_pwquality.sh"
        "install_libvirt-clients.sh"
        "install_libvirt-daemon-system.sh"
        "install_lynis.sh"
        "install_openssh-client.sh"
        "install_openssh-server.sh"
        "install_python3_pyqt6.sh"
        "install_qemu-system-x86.sh"
        "install_rkhunter.sh"
        "install_tcpd.sh"
        "install_ufw.sh"
        
    )
    for tool in "${TOOLS[@]}"; do
        if [ -x "$TOOLS_DIR/$tool" ]; then
            bash "$TOOLS_DIR/$tool" || { printf "\033[1;31m[-] Failed: $tool\033[0m\n"; exit 1; }
        else
            printf "\033[1;33m[!] Script not found or not executable: $TOOLS_DIR/$tool\033[0m\n"
            exit 1
        fi
    done
    printf "\033[1;32m[+] Tools installed successfully.\033[0m\n"

   
}


apply_stig_hardening() {
    printf "\033[1;31m[+] Applying STIG hardening tasks...\033[0m\n"
    local STIG_DIR="$SCRIPT_DIR/tools/stig"
    local STIG_STEPS=(
        "stig_password_policy.sh"
        "stig_lock_inactive_accounts.sh"
        "stig_login_banners.sh"
        "stig_kernel_setup.sh"
        "stig_secure_filesystem.sh"
        "stig_disable_usb.sh"
        "stig_disable_core_dumps.sh"
        "stig_disable_ctrl_alt_del.sh"
        "stig_disable_ipv6.sh"
        "stig_configure_firewall.sh"
        "stig_set_randomize_va_space.sh"
        "update_firmware.sh"
    )
    for step in "${STIG_STEPS[@]}"; do
        if [ -x "$STIG_DIR/$step" ]; then
            bash "$STIG_DIR/$step" || { printf "\033[1;31m[-] Failed: $step\033[0m\n"; exit 1; }
        else
            printf "\033[1;33m[!] Script not found or not executable: $STIG_DIR/$step\033[0m\n"
            exit 1
        fi
    done
    printf "\033[1;32m[+] STIG hardening tasks applied successfully.\033[0m\n"
}

setup_complete() {
    echo "======================================================="
    echo "             [+] HARDN - Setup Complete                "
    echo "             calling Validation Script                 "
    echo "                                                       "
    echo "======================================================="

    sleep 3

    printf "\033[1;31m[+] Looking for hardn-packages.sh at: %s\033[0m\n" "$PACKAGES_SCRIPT"
    if [ -f "$PACKAGES_SCRIPT" ]; then
        printf "\033[1;31m[+] Setting executable permissions for hardn-packages.sh...\033[0m\n"
        chmod +x "$PACKAGES_SCRIPT"

        printf "\033[1;31m[+] Setting sudo permissions for hardn-packages.sh...\033[0m\n"
        echo "root ALL=(ALL) NOPASSWD: $PACKAGES_SCRIPT" \
          | sudo tee /etc/sudoers.d/hardn-packages-sh > /dev/null
        sudo chmod 440 /etc/sudoers.d/hardn-packages-sh

        printf "\033[1;31m[+] Calling hardn-packages.sh with sudo...\033[0m\n"
        sudo "$PACKAGES_SCRIPT"
    else
        printf "\033[1;31m[-] hardn-packages.sh not found at: %s. Skipping...\033[0m\n" "$PACKAGES_SCRIPT"
    fi

}

main() {
    printf "\033[1;31m[+] Starting HARDN setup...\033[0m\n"
    printf "\033[1;31m[+] Checking for root privileges...\033[0m\n"

    detect_os
    printf "\033[1;31m[+] Detected OS: %s %s\033[0m\n" "$OS_NAME" "$OS_VERSION"
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    update_system_packages
    printf "\033[1;31m[+] System packages updated.\033[0m\n"
    printf "\033[1;31m[+] Installing package dependencies...\033[0m\n"
    install_pkgdeps
    printf "\033[1;31m[+] Package dependencies installed.\033[0m\n"
    printf "\033[1;31m[+] Installing tools...\033[0m\n"
    install_tools
    printf "\033[1;31m[+] Tools installed.\033[0m\n"
    printf "\033[1;31m[+] Applying STIG hardening...\033[0m\n"
    apply_stig_hardening
    printf "\033[1;31m[+] STIG hardening applied.\033[0m\n"
    printf "\033[1;31m[+] Setting up system...\033[0m\n"
    setup_complete
    

}
main