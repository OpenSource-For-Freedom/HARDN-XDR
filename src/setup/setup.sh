#!/bin/sh

########################################
#            HARDN - Setup             #
#  Please have repo cloned beforehand  #
#       Installs + Pre-config          #
#    Must have python-3 loaded already #
#             Author(s):               #
#         - Chris Bingham              #
#           - Tim Burns                #
#        Date: 4/5-12/2025             #
########################################

# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use: sudo ./setup.sh"
    exit 1
fi

# Check if the script is being run by a valid user account
if ! id "$(whoami)" > /dev/null 2>&1; then
    echo "This script must be run by a valid user account."
    exit 1
fi

# Check if the user has sudo/admin privileges
if ! groups "$(whoami)" | grep -q '\bsudo\b'; then
    echo "This script requires sudo/admin privileges. Add the user to the sudo group."
    exit 1
fi

# Check if a separate user account is set up
if [ "$(whoami)" = "root" ]; then
    echo "This script must not be run directly as root. Please use a separate user account with sudo privileges."
    exit 1
fi

update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    apt update && apt upgrade -y
}

# Install package dependencies
install_pkgdeps() {
    printf "\033[1;31m[+] Installing package dependencies...\033[0m\n"
    apt install -y wget curl git gawk mariadb-common mysql-common policycoreutils \
        python-matplotlib-data unixodbc-common gawk-doc
}

# Install and configure SELinux
install_selinux() {
    printf "\033[1;31m[+] Installing and configuring SELinux...\033[0m\n"
    apt update
    apt install -y selinux-utils selinux-basics policycoreutils policycoreutils-python-utils selinux-policy-default
    if ! command -v getenforce > /dev/null 2>&1; then
        printf "\033[1;31m[-] SELinux installation failed. Please check system logs.\033[0m\n"
        return 1
    fi
    setenforce 1 2>/dev/null || printf "\033[1;31m[-] Could not set SELinux to enforcing mode immediately\033[0m\n"
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
    apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums rkhunter libpam-pwquality libvirt-daemon-system libvirt-clients qemu-kvm openssh-server openssh-client scap-workbench \
        libpam-cracklib libpam-tally2
}

# UFW configuration
configure_ufw() {
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow ssh
    ufw reload
}

# Enable, start, and configure Fail2Ban and AppArmor services
enable_services() {
    printf "\033[1;31m[+] Enabling and starting Fail2Ban and AppArmor services...\033[0m\n"
    systemctl enable --now fail2ban
    systemctl enable --now apparmor

# tightening up fail2ban - needs testing 
    printf "\033[1;31m[+] Configuring Fail2Ban...\033[0m\n"
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 24h
findtime = 10m
maxretry = 3
ignoreip = 127.0.0.1/8 ::1

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 2

[recidive]
enabled = true
logpath = /var/log/fail2ban.log
bantime = 1w
findtime = 1d
maxretry = 5

[apache-auth]
enabled = true
logpath = /var/log/apache2/*error.log
maxretry = 3

[nginx-http-auth]
enabled = true
logpath = /var/log/nginx/error.log
maxretry = 3
EOF

    systemctl restart fail2ban
    printf "\033[1;31m[+] Fail2Ban configured and restarted.\033[0m\n"
}
}

# Install chkrootkit, LMD, and rkhunter
install_additional_tools() {
    printf "\033[1;31m[+] Installing chkrootkit, LMD, and rkhunter...\033[0m\n"
    apt install -y chkrootkit
    printf "\033[1;31m[+] Installing Linux Malware Detect...\033[0m\n"
    temp_dir=$(mktemp -d)
    cd "$temp_dir" || { printf "\033[1;31m[-] Failed to create temporary directory\033[0m\n"; return 1; }
    if git clone https://github.com/rfxn/linux-malware-detect.git; then
        cd linux-malware-detect || { printf "\033[1;31m[-] Failed to change to maldetect directory\033[0m\n"; return 1; }
        chmod +x install.sh
        ./install.sh
    else
        printf "\033[1;31m[-] Failed to clone maldetect repository\033[0m\n"
    fi
    cd /tmp || true
    rm -rf "$temp_dir"
    apt install -y rkhunter
    rkhunter --update
    rkhunter --propupd
}

# Reload AppArmor profiles
reload_apparmor() {
    printf "\033[1;31m[+] Reloading AppArmor profiles...\033[0m\n"
    systemctl reload apparmor || systemctl start apparmor
    if aa-status >/dev/null 2>&1; then
        printf "\033[1;31m[+] AppArmor is running properly\033[0m\n"
    else
        printf "\033[1;31m[-] Warning: AppArmor may not be running correctly\033[0m\n"
    fi
}
}

# Configure cron jobs
configure_cron() {
    printf "\033[1;31m[+] Configuring cron jobs...\033[0m\n"
    (crontab -l 2>/dev/null | grep -v "lynis audit system --cronjob" | \
     grep -v "apt update && apt upgrade -y" | \
     grep -v "chkrootkit" | \
     grep -v "maldet --update" | \
     grep -v "maldet --scan-all" | \
    grep -v "setenforce 1" | \
    grep -v "oscap xccdf eval" | \ 
    crontab -) || true
    (crontab -l 2>/dev/null || true) > mycron
    cat >> mycron << 'EOFCRON'
0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1
0 4 * * * chkrootkit
0 5 * * * maldet --update
0 6 * * * maldet --scan-all / >> /var/log/maldet_scan.log 2>&1
0 2 * * * setenforce 1
0 3 * * * oscap xccdf eval --profile stig /usr/share/xml/scap/ssg/content/ssg-debian10-ds.xml >> /var/log/openscap_scan.log 2>&1
EOFCRON
    crontab mycron
    rm mycron
}

# Disable USB - allow HID devices only 
disable_usb_storage() {
    printf "\033[1;31m[+] Disabling USB storage devices while allowing HID devices...\033[0m\n"
    echo 'install usb-storage /bin/false' > /etc/modprobe.d/usb-storage.conf
    modprobe -r usb-storage || printf "\033[1;31m[-] Warning: USB storage module in use, cannot unload.\033[0m\n"
    printf "\033[1;31m[+] USB storage devices blocked successfully.\033[0m\n"
}
}

# OPENSCAP- did have some issues with bindings
install_openscap() {
    printf "\033[1;31m[+] Installing OpenSCAP...\033[0m\n"
    apt install -y openscap-utils libopenscap8
    printf "\033[1;31m[+] OpenSCAP installed.\033[0m\n"
}

run_openscap_scan() {
    printf "\033[1;31m[+] Running OpenSCAP scan...\033[0m\n"
    oscap xccdf eval --profile stig /usr/share/xml/scap/ssg/content/ssg-debian10-ds.xml
    printf "\033[1;31m[+] OpenSCAP scan completed.\033[0m\n"
}

# Disable guest accounts>> no point 
disable_guest_accounts() {
    printf "\033[1;31m[+] Disabling guest accounts...\033[0m\n"
    usermod -L guest || printf "\033[1;31m[-] Warning: Could not disable guest account.\033[0m\n"
    printf "\033[1;31m[+] Guest accounts disabled.\033[0m\n"
}


# AUDITD for STIG 
configure_auditd() {
    printf "\033[1;31m[+] Configuring auditd for STIG compliance...\033[0m\n"
    apt install -y auditd audispd-plugins
    cat > /etc/audit/audit.rules <<EOF
    -w /etc/passwd -p wa -k identity
    -w /etc/shadow -p wa -k identity
    -w /etc/group -p wa -k identity
    -w /etc/gshadow -p wa -k identity
    -w /etc/sudoers -p wa -k identity
    -w /var/log/lastlog -p wa -k logins
    -w /var/log/faillog -p wa -k logins
EOF
    systemctl restart auditd
    printf "\033[1;31m[+] auditd configured and restarted.\033[0m\n"
}

setup_complete() {
    echo "======================================================="
    echo "             [+] HARDN - Setup Complete                "
    echo "  [+] Please reboot your system to apply changes       "
    echo "======================================================="
}

# Main function
main() {
    update_system_packages
    install_pkgdeps
    install_selinux
    install_security_tools
    configure_ufw
    enable_services
    install_additional_tools
    reload_apparmor
    configure_cron
    disable_usb_storage
    install_openscap
    run_openscap_scan
    configure_auditd
    setup_complete
}

# Run the main function
main