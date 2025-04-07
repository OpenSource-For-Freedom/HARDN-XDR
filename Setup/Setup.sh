#!/usr/bin/env bash

# ADDED PYTHON EVE FOR PIP INSTALL
# Ensure the script is run as root
# TODO add functionality to handle fixing unmet dependencies and --fix-broken install, and add the requirements.txt to this dir
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root. Use: sudo ./Setup.sh"
   exit 1
fi

update_system_packages() {
    printf "\e[1;31m[+] Updating system packages...\e[0m\n"
    sudo apt update && apt upgrade -y
}

# Check for package dependencies
pkgdeps=(
    gawk
    mariadb-common
    mysql-common
    policycoreutils
    python-matplotlib-data
    unixodbc-common
    gawk-doc
)

# Function to check package dependencies
check_pkgdeps() {
    for pkg in "${pkgdeps[@]}"; do
        echo "Package: $pkg"
        apt-cache depends "$pkg" | grep -E '^\s*(PreDepends|Depends|Conflicts):'
        echo  # Add a blank line between packages
    done
}

# Function to offer resolving issues
offer_to_resolve_issues() {
    local deps_to_resolve="$1"
    echo "Dependencies to resolve:"
    echo "$deps_to_resolve"
    echo
    read -p "Do you want to resolve these dependencies? (y/n): " answer
    if [[ $answer =~ ^[Yy]$ ]]; then
        echo "$deps_to_resolve" | sed 's/\s//g;s/<[^>]*>//g' >  dependencies_to_resolve.txt
        echo "List of dependencies to resolve saved in dependencies_to_resolve.txt"
    else
        echo "No action taken."
    fi
}

# Install and configure SELinux
install_selinux() {
    printf "\e[1;31m[+] Installing and configuring SELinux...\e[0m\n"

    # Install SELinux packages
    sudo apt update
    sudo apt install -y selinux-utils selinux-basics policycoreutils policycoreutils-python-utils selinux-policy-default

    # Check if installation was successful
    if ! command -v getenforce &> /dev/null; then
        printf "\e[1;31m[-] SELinux installation failed. Please check system logs.\e[0m\n"
        return 1
    fi

    # Configure SELinux to enforcing mode
    setenforce 1 2>/dev/null || printf "\e[1;31m[-] Could not set SELinux to enforcing mode immediately\e[0m\n"

    # Configure SELinux to be enforcing at boot
    if [ -f /etc/selinux/config ]; then
        sed -i 's/SELINUX=disabled/SELINUX=enforcing/' /etc/selinux/config
        sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
        printf "\e[1;31m[+] SELinux configured to enforcing mode at boot\e[0m\n"
    else
        printf "\e[1;31m[-] SELinux config file not found\e[0m\n"
    fi

    printf "\e[1;31m[+] SELinux installation and configuration completed\e[0m\n"
}

# Install system security tools
install_security_tools() {
    printf "\e[1;31m[+] Installing required system security tools...\e[0m\n"
    sudo apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums rkhunter libpam-pwquality libvirt-daemon-system libvirt-clients qemu-kvm docker.io docker-compose openssh-server
}

# UFW configuration
configure_ufw() {
    printf "\e[1;31m[+] Configuring UFW...\e[0m\n"
    ufw allow out 53,80,443/tcp
    ufw allow out 53,123/udp
    ufw allow out 67,68/udp
    ufw reload
}

# Enable and start Fail2Ban and AppArmor services
enable_services() {
    printf "\e[1;31m[+] Enabling and starting Fail2Ban and AppArmor services...\e[0m\n"
    sudo systemctl enable --now fail2ban
    sudo systemctl enable --now apparmor
}

# Install chkrootkit, LMD, and rkhunter
install_additional_tools() {
    printf "\e[1;31m[+] Installing chkrootkit, LMD, and rkhunter...\e[0m\n"
    apt install -y chkrootkit
    wget http://www.rfxn.com/downloads/maldetect-current.tar.gz
    tar -xzf maldetect-current.tar.gz
    cd maldetect-* || return
    sudo ./install.sh
    cd .. || return
    rm -rf maldetect-*
    rm maldetect-current.tar.gz
    apt install -y rkhunter
    rkhunter --update
    rkhunter --propupd
}

# Reload AppArmor profiles
reload_apparmor() {
    printf "\e[1;31m[+] Reloading AppArmor profiles...\e[0m\n"
    apparmor_parser -r /etc/apparmor.d/*
}

# Configure cron jobs
configure_cron() {
    printf "\e[1;31m[+] Configuring cron jobs...\e[0m\n"
    remove_existing_cron_jobs() {
        crontab -l 2>/dev/null | grep -v "lynis audit system --cronjob" \
        | grep -v "apt update && apt upgrade -y" \
        | grep -v "/opt/eset/esets/sbin/esets_update" \
        | grep -v "chkrootkit" \
        | grep -v "maldet --update" \
        | grep -v "maldet --scan-all" \
        | crontab -
    }
    remove_existing_cron_jobs
    crontab -l 2>/dev/null > mycron
    cat <<EOF >> mycron
0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1
0 3 * * * /opt/eset/esets/sbin/esets_update
0 4 * * * chkrootkit
0 5 * * * maldet --update
0 6 * * * maldet --scan-all / >> /var/log/maldet_scan.log 2>&1
EOF
    crontab mycron
    rm mycron
}

# Disable USB storage
disable_usb_storage() {
    printf "\e[1;31m[+] Disabling USB storage...\e[0m\n"
    echo 'blacklist usb-storage' > /etc/modprobe.d/usb-storage.conf
    modprobe -r usb-storage && printf "\e[1;31m[+] USB storage successfully disabled.\e[0m\n" || printf "\e[1;31m[-] Warning: USB storage module in use, cannot unload.\e[0m\n"
}

# Update system packages again
update_sys_pkgs() {
    update_system_packages || { printf "\e[1;31m[-] System update failed.\e[0m\n"; exit 1; }
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
    check_pkgdeps

    # Main execution
    deps_and_conflicts=$(check_pkgdeps)
    echo "All dependencies and conflicts:"
    echo "$deps_and_conflicts"
    echo

    # Extract only the lines prefixed with "Depends"
    depends_only=$(echo "$deps_and_conflicts" | grep -E '^\s*Depends:')

    if [ -n "$depends_only" ]; then
        echo "Found dependencies:"
        echo "$depends_only"
        echo
        read -p "Do you want to offer resolving these dependencies? (y/n): " offer_answer
        if [[ $offer_answer =~ ^[Yy]$ ]]; then
            offer_to_resolve_issues "$depends_only"
            sudo apt install $depends_only -y
        else
            echo "Skipping dependency resolution."
        fi
    fi

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