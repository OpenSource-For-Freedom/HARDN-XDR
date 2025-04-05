#!/bin/sh

########################################
#            HARDN - Setup             #
#  Please have repo cloned before hand #
#       Installs + Pre-config          #
#    Must have python-3 loaded already #
#       Author: Chris Bingham          #
#           Date: 4/5/2025             #
########################################


# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
   echo "This script must be run as root. Use: sudo ./setup.sh"
   exit 1
fi

update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    apt update && apt upgrade -y
}

# Install package dependencies
install_pkgdeps() {
    printf "\033[1;31m[+] Installing package dependencies...\033[0m\n"
    # List of packages to install
    apt install -y wget curl git gawk mariadb-common mysql-common policycoreutils \
        python-matplotlib-data unixodbc-common gawk-doc
}

# Function to check package dependencies
check_pkgdeps() {
    # Implementation of check_pkgdeps function
    echo "Checking package dependencies..."
    # Return empty for now as the original implementation is missing
    return 0
}

# Function to offer resolving issues
offer_to_resolve_issues() {
    deps_to_resolve="$1"
    if [ -z "$deps_to_resolve" ]; then
        echo "No dependencies to resolve."
        return 0
    fi

    echo "Dependencies to resolve:"
    echo "$deps_to_resolve"
    echo
    printf "Do you want to resolve these dependencies? (y/n): "
    read answer
    case "$answer" in
        [Yy]*)
            echo "$deps_to_resolve" | sed 's/\s//g;s/<[^>]*>//g' > dependencies_to_resolve.txt
            echo "List of dependencies to resolve saved in dependencies_to_resolve.txt"
            ;;
        *)
            echo "No action taken."
            ;;
    esac
}

# Install and configure SELinux
install_selinux() {
    printf "\033[1;31m[+] Installing and configuring SELinux...\033[0m\n"

    # Install SELinux packages
    apt update
    apt install -y selinux-utils selinux-basics policycoreutils policycoreutils-python-utils selinux-policy-default

    # Check if installation was successful
    if ! command -v getenforce > /dev/null 2>&1; then
        printf "\033[1;31m[-] SELinux installation failed. Please check system logs.\033[0m\n"
        return 1
    fi

    # Configure SELinux to enforcing mode
    setenforce 1 2>/dev/null || printf "\033[1;31m[-] Could not set SELinux to enforcing mode immediately\033[0m\n"

    # Configure SELinux to be enforcing at boot
    if [ -f /etc/selinux/config ]; then
        sed -i 's/SELINUX=disabled/SELINUX=enforcing/' /etc/selinux/config
        sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
        printf "\033[1;31m[+] SELinux configured to enforcing mode at boot\033[0m\n"
    else
        printf "\033[1;31m[-] SELinux config file not found\033[0m\n"
    fi

    printf "\033[1;31m[+] SELinux installation and configuration completed\033[0m\n"
}

# Install system security tools
install_security_tools() {
    printf "\033[1;31m[+] Installing required system security tools...\033[0m\n"
    apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums rkhunter libpam-pwquality libvirt-daemon-system libvirt-clients qemu-kvm docker.io docker-compose openssh-server
}

# UFW configuration
configure_ufw() {
    printf "\033[1;31m[+] Configuring UFW...\033[0m\n"
    ufw allow out 53,80,443/tcp
    ufw allow out 53,123/udp
    ufw allow out 67,68/udp
    ufw reload
}

# Enable and start Fail2Ban and AppArmor services
enable_services() {
    printf "\033[1;31m[+] Enabling and starting Fail2Ban and AppArmor services...\033[0m\n"
    systemctl enable --now fail2ban
    systemctl enable --now apparmor
}

# Install chkrootkit, LMD, and rkhunter
install_additional_tools() {
    printf "\033[1;31m[+] Installing chkrootkit, LMD, and rkhunter...\033[0m\n"
    apt install -y chkrootkit

    # Install Linux Malware Detect (LMD)
    printf "\033[1;31m[+] Installing Linux Malware Detect...\033[0m\n"

    # Create a temporary directory for the installation
    temp_dir=$(mktemp -d)
    cd "$temp_dir" || {
        printf "\033[1;31m[-] Failed to create temporary directory\033[0m\n"
        install_maldet_failed=true
    }

    # Try to install from GitHub
    if [ "$install_maldet_failed" != "true" ]; then
        printf "\033[1;31m[+] Cloning Linux Malware Detect from GitHub...\033[0m\n"
        if git clone https://github.com/rfxn/linux-malware-detect.git; then
            cd linux-malware-detect || {
                printf "\033[1;31m[-] Failed to change to maldetect directory\033[0m\n"
                install_maldet_failed=true
            }

            if [ "$install_maldet_failed" != "true" ]; then
                printf "\033[1;31m[+] Running maldetect installer...\033[0m\n"
                chmod +x install.sh
                if ./install.sh; then
                    printf "\033[1;31m[+] Linux Malware Detect installed successfully from GitHub\033[0m\n"
                    install_maldet_failed=false
                else
                    printf "\033[1;31m[-] Maldetect installer failed\033[0m\n"
                    install_maldet_failed=true
                fi
            fi
        else
            printf "\033[1;31m[-] Failed to clone maldetect repository\033[0m\n"
            install_maldet_failed=true
        fi
    fi

    # If GitHub method failed, try apt
    if [ "$install_maldet_failed" = "true" ]; then
        printf "\033[1;31m[+] Attempting to install maldetect via apt...\033[0m\n"
        if apt install -y maldetect; then
            printf "\033[1;31m[+] Maldetect installed via apt\033[0m\n"
            if command -v maldet >/dev/null 2>&1; then
                maldet -u
                printf "\033[1;31m[+] Maldetect updated successfully\033[0m\n"
                install_maldet_failed=false
            fi
        else
            printf "\033[1;31m[-] Apt installation failed\033[0m\n"
            install_maldet_failed=true
        fi
    fi

    # If both methods failed, provide manual instructions
    if [ "$install_maldet_failed" = "true" ]; then
        printf "\033[1;31m[-] All installation methods for maldetect failed.\033[0m\n"
        printf "\033[1;31m[-] Please install manually after setup completes using one of these methods:\033[0m\n"
        printf "\033[1;31m[-] 1. apt install maldetect\033[0m\n"
        printf "\033[1;31m[-] 2. git clone https://github.com/rfxn/linux-malware-detect.git && cd linux-malware-detect && ./install.sh\033[0m\n"
    fi

    # Clean up and return to original directory
    cd /tmp || true
    rm -rf "$temp_dir"

    # Install rkhunter
    printf "\033[1;31m[+] Installing rkhunter...\033[0m\n"
    apt install -y rkhunter
    rkhunter --update
    rkhunter --propupd
}

# Reload AppArmor profiles
reload_apparmor() {
    printf "\033[1;31m[+] Reloading AppArmor profiles...\033[0m\n"

    # Use systemd to reload AppArmor instead of manually parsing files
    if systemctl is-active --quiet apparmor; then
        printf "\033[1;31m[+] Reloading AppArmor service...\033[0m\n"
        systemctl reload apparmor
    else
        printf "\033[1;31m[+] Starting AppArmor service...\033[0m\n"
        systemctl start apparmor
    fi

    # Verify AppArmor status
    if aa-status >/dev/null 2>&1; then
        printf "\033[1;31m[+] AppArmor is running properly\033[0m\n"
    else
        printf "\033[1;31m[-] Warning: AppArmor may not be running correctly\033[0m\n"
        printf "\033[1;31m[-] You may need to reboot your system\033[0m\n"
    fi
}

# Configure cron jobs
configure_cron() {
    printf "\033[1;31m[+] Configuring cron jobs...\033[0m\n"

    # Remove existing cron jobs
    (crontab -l 2>/dev/null | grep -v "lynis audit system --cronjob" | \
     grep -v "apt update && apt upgrade -y" | \
     grep -v "/opt/eset/esets/sbin/esets_update" | \
     grep -v "chkrootkit" | \
     grep -v "maldet --update" | \
     grep -v "maldet --scan-all" | \
     crontab -) || true

    # Create new cron jobs
    (crontab -l 2>/dev/null || true) > mycron
    cat >> mycron << 'EOFCRON'
0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1
0 3 * * * /opt/eset/esets/sbin/esets_update
0 4 * * * chkrootkit
0 5 * * * maldet --update
0 6 * * * maldet --scan-all / >> /var/log/maldet_scan.log 2>&1
EOFCRON
    crontab mycron
    rm mycron
}

# Disable USB storage
disable_usb_storage() {
    printf "\033[1;31m[+] Disabling USB storage...\033[0m\n"
    echo 'blacklist usb-storage' > /etc/modprobe.d/usb-storage.conf
    if modprobe -r usb-storage 2>/dev/null; then
        printf "\033[1;31m[+] USB storage successfully disabled.\033[0m\n"
    else
        printf "\033[1;31m[-] Warning: USB storage module in use, cannot unload.\033[0m\n"
    fi
}

# Update system packages again
update_sys_pkgs() {
    if ! update_system_packages; then
        printf "\033[1;31m[-] System update failed.\033[0m\n"
        exit 1
    fi
}

setup_complete() {
    echo " "
    echo "======================================================="
    echo "             [+] HARDN - Setup Complete                "
    echo "  [+] Please reboot your system to apply changes       "
    echo "======================================================="
    echo " "
}

# Main function
main() {
    update_system_packages
    install_pkgdeps

    # Check dependencies
    deps_and_conflicts=$(check_pkgdeps)
    if [ -n "$deps_and_conflicts" ]; then
        echo "All dependencies and conflicts:"
        echo "$deps_and_conflicts"
        echo

        # Extract only the lines prefixed with "Depends"
        depends_only=$(echo "$deps_and_conflicts" | grep -E '^\s*Depends:')

        if [ -n "$depends_only" ]; then
            echo "Found dependencies:"
            echo "$depends_only"
            echo
            printf "Do you want to offer resolving these dependencies? (y/n): "
            read offer_answer
            case "$offer_answer" in
                [Yy]*)
                    offer_to_resolve_issues "$depends_only"
                    apt install $depends_only -y
                    ;;
                *)
                    echo "Skipping dependency resolution."
                    ;;
            esac
        fi
    fi

    # Call each function in the proper order
    install_selinux
    install_security_tools
    configure_ufw
    enable_services
    install_additional_tools
    reload_apparmor
    configure_cron
    disable_usb_storage
    update_sys_pkgs
    setup_complete
}

# Run the main function
main
