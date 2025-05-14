#!/bin/bash
set -e # Exit on errors

# Usage/help message
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


install_security_tools() {
    printf "\033[1;31m[+] Installing required system security tools...\033[0m\n"
    apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums \
        libpam-pwquality libvirt-daemon-system libvirt-clients qemu-system-x86 openssh-server openssh-client rkhunter 
}


enable_fail2ban() {
    printf "\033[1;31m[+] Installing and enabling Fail2Ban...\033[0m\n"
    apt install -y fail2ban
    systemctl enable --now fail2ban
    printf "\033[1;32m[+] Fail2Ban installed and enabled successfully.\033[0m\n"

    printf "\033[1;31m[+] Configuring Fail2Ban for SSH...\033[0m\n"
    cat << EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 5
bantime = 3600
EOF

    systemctl restart fail2ban
    printf "\033[1;32m[+] Fail2Ban configured and restarted successfully.\033[0m\n"
}

enable_apparmor() {
    printf "\033[1;31m[+] Installing and enabling AppArmor…\033[0m\n"
    apt install -y apparmor apparmor-utils apparmor-profiles || {
        printf "\033[1;31m[-] Failed to install AppArmor.\033[0m\n"
        return 1
    }

    systemctl enable --now apparmor || {
        printf "\033[1;31m[-] Failed to enable AppArmor service.\033[0m\n"
        return 1
    }

    aa-complain /etc/apparmor.d/* || {
        printf "\033[1;31m[-] Failed to set profiles to complain mode. Continuing...\033[0m\n"
    }

    printf "\033[1;32m[+] AppArmor installed. Profiles are in complain mode for testing.\033[0m\n"
    printf "\033[1;33m[!] Review profile behavior before switching to enforce mode.\033[0m\n"
}


enable_aide() {
    printf "\033[1;31m[+] Installing AIDE and initializing database…\033[0m\n"
    apt install -y aide aide-common || {
        printf "\033[1;31m[-] Failed to install AIDE.\033[0m\n"
        return 1
    }
    aideinit || {
        printf "\033[1;31m[-] Failed to initialize AIDE database.\033[0m\n"
        return 1
    }
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db || {
        printf "\033[1;31m[-] Failed to replace AIDE database.\033[0m\n"
        return 1
    }

    printf "\033[1;32m[+] AIDE successfully installed and configured.\033[0m\n"
}


enable_rkhunter(){
    printf "\033[1;31m[+] Installing rkhunter...\033[0m\n"
    if ! apt install -y rkhunter; then
        return 0
    fi

    # Fix permissions for rkhunter data directory
    sudo chown -R root:root /var/lib/rkhunter
    sudo chmod -R 755 /var/lib/rkhunter

    # Ensure mirrors and update settings are correct
    sed -i 's|^#*MIRRORS_MODE=.*|MIRRORS_MODE=1|' /etc/rkhunter.conf
    sed -i 's|^#*UPDATE_MIRRORS=.*|UPDATE_MIRRORS=1|' /etc/rkhunter.conf
    sed -i 's|^WEB_CMD=.*|#WEB_CMD=|' /etc/rkhunter.conf

    # Try to update rkhunter data files
    if ! rkhunter --update; then
        printf "\033[1;33m[!] rkhunter update failed. Check your network connection or proxy settings.\033[0m\n"
    fi

    rkhunter --propupd
    printf "\033[1;32m[+] rkhunter installed and updated.\033[0m\n"
}


configure_firejail() {
    printf "\033[1;31m[+] Configuring Firejail for Firefox and Chrome...\033[0m\n"

    if ! command -v firejail > /dev/null 2>&1; then
        printf "\033[1;31m[-] Firejail is not installed. Please install it first.\033[0m\n"
        return 1
    fi

    if command -v firefox > /dev/null 2>&1; then
        printf "\033[1;31m[+] Setting up Firejail for Firefox...\033[0m\n"
        ln -sf /usr/bin/firejail /usr/local/bin/firefox
    else
        printf "\033[1;31m[-] Firefox is not installed. Skipping Firejail setup for Firefox.\033[0m\n"
    fi

    if command -v google-chrome > /dev/null 2>&1; then
        printf "\033[1;31m[+] Setting up Firejail for Google Chrome...\033[0m\n"
        ln -sf /usr/bin/firejail /usr/local/bin/google-chrome
    else
        printf "\033[1;31m[-] Google Chrome is not installed. Skipping Firejail setup for Chrome.\033[0m\n"
    fi

    printf "\033[1;31m[+] Firejail configuration completed.\033[0m\n"
}


stig_password_policy() {
    sed -i 's/^#\? *minlen *=.*/minlen = 14/' /etc/security/pwquality.conf
    sed -i 's/^#\? *dcredit *=.*/dcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *ucredit *=.*/ucredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *ocredit *=.*/ocredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *lcredit *=.*/lcredit = -1/' /etc/security/pwquality.conf

    if command -v pam-auth-update > /dev/null; then
        pam-auth-update --package
        echo "[+] pam_pwquality profile activated via pam-auth-update"
    else
        echo "[!] pam-auth-update not found. Install 'libpam-runtime' to manage PAM profiles safely."
    fi
}


stig_lock_inactive_accounts() {
    useradd -D -f 35
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        chage --inactive 35 "$user"
    done
}


stig_login_banners() {
    echo "You are accessing a fully secured SIG Information System (IS)..." > /etc/issue
    echo "Use of this IS constitutes consent to monitoring..." > /etc/issue.net
    chmod 644 /etc/issue /etc/issue.net
}

stig_secure_filesystem() {
    printf "\033[1;31m[+] Securing filesystem permissions...\033[0m\n"
    chown root:root /etc/passwd /etc/group /etc/gshadow
    chmod 644 /etc/passwd
    chmod 640 /etc/group  # safer for PAM modules

    chown root:shadow /etc/shadow /etc/gshadow
    chmod 640 /etc/shadow /etc/gshadow

    printf "\033[1;31m[+] Configuring audit rules...\033[0m\n"
    apt install -y auditd audispd-plugins
    tee /etc/audit/rules.d/stig.rules > /dev/null <<EOF
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
# -e 2  # Immutable mode. Uncomment only for production.
EOF

    chown root:root /etc/audit/rules.d/*.rules
    chmod 600 /etc/audit/rules.d/*.rules
    mkdir -p /var/log/audit
    chown -R root:root /var/log/audit
    chmod 700 /var/log/audit

    augenrules --load
    systemctl enable auditd || { printf "\033[1;31m[-] Failed to enable auditd.\033[0m\n"; return 1; }
    systemctl start auditd || { printf "\033[1;31m[-] Failed to start auditd.\033[0m\n"; return 1; }
    systemctl restart auditd || { printf "\033[1;31m[-] Failed to restart auditd.\033[0m\n"; return 1; }
    auditctl -e 1 || printf "\033[1;31m[-] Failed to enable auditd.\033[0m\n"
}


stig_kernel_setup() {
    printf "\033[1;31m[+] Setting up STIG-compliant kernel parameters (login-safe)...\033[0m\n"
    tee /etc/sysctl.d/stig-kernel-safe.conf > /dev/null <<EOF
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF

    sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
    sysctl -w kernel.randomize_va_space=2 || printf "\033[1;31m[-] Failed to set kernel.randomize_va_space.\033[0m\n"
}

grub_security() {
    # Skip if UEFI < VM support
    if [ -d /sys/firmware/efi ]; then
        echo "[*] UEFI system detected. Skipping GRUB configuration..."
        return 0
    fi

    # Check for Virtual Machine environment
    if grep -q 'hypervisor' /proc/cpuinfo; then
        echo "[*] Virtual machine detected. Proceeding with GRUB configuration..."
    else
        echo "[+] No virtual machine detected. Proceeding with GRUB configuration..."
    fi

    # Detect GRUB path < support grub2
    if [ -f /boot/grub/grub.cfg ]; then
        GRUB_CFG="/boot/grub/grub.cfg"
        GRUB_DIR="/boot/grub"
    elif [ -f /boot/grub2/grub.cfg ]; then
        GRUB_CFG="/boot/grub2/grub.cfg"
        GRUB_DIR="/boot/grub2"
    else
        echo "[-] GRUB config not found. Please verify GRUB installation."
        return 1
    fi

    echo "[+] Configuring GRUB security settings..."


    BACKUP_CFG="$GRUB_CFG.bak.$(date +%Y%m%d%H%M%S)"
    cp "$GRUB_CFG" "$BACKUP_CFG"
    echo "[+] Backup created at $BACKUP_CFG"


    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash security=1 /' /etc/default/grub


    if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
        sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
    else
        echo "GRUB_TIMEOUT=5" >> /etc/default/grub
    fi


    if command -v update-grub >/dev/null 2>&1; then
        update-grub || echo "[-] Failed to update GRUB using update-grub."
    elif command -v grub2-mkconfig >/dev/null 2>&1; then
        grub2-mkconfig -o "$GRUB_CFG" || echo "[-] Failed to update GRUB using grub2-mkconfig."
    else
        echo "[-] Neither update-grub nor grub2-mkconfig found. Please install GRUB tools."
        return 1
    fi


    chmod 600 "$GRUB_CFG"
    chown root:root "$GRUB_CFG"
    echo "[+] GRUB configuration secured: $GRUB_CFG"
}


stig_disable_usb() {
    echo "install usb-storage /bin/false" > /etc/modprobe.d/hardn-blacklist.conf
    update-initramfs -u || printf "\033[1;31m[-] Failed to update initramfs.\033[0m\n"
}


stig_disable_core_dumps() {
    echo "* hard core 0" | tee -a /etc/security/limits.conf > /dev/null
    echo "fs.suid_dumpable = 0" | tee /etc/sysctl.d/99-coredump.conf > /dev/null
    sysctl -w fs.suid_dumpable=0
}

stig_disable_ctrl_alt_del() {
    systemctl mask ctrl-alt-del.target
    systemctl daemon-reexec
}

stig_disable_ipv6() {
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
    sysctl -p
}

stig_configure_firewall() {
    printf "\033[1;31m[+] Configuring UFW...\033[0m\n"

    if ! command -v ufw > /dev/null 2>&1; then
        printf "\033[1;31m[-] UFW is not installed. Installing UFW...\033[0m\n"
        apt install -y ufw || { printf "\033[1;31m[-] Failed to install UFW.\033[0m\n"; return 1; }
    fi

    printf "\033[1;31m[+] Resetting UFW to default settings...\033[0m\n"
    ufw --force reset || { printf "\033[1;31m[-] Failed to reset UFW.\033[0m\n"; return 1; }

    printf "\033[1;31m[+] Setting UFW default policies...\033[0m\n"
    ufw default deny incoming
    ufw default allow outgoing

    printf "\033[1;31m[+] Allowing outbound HTTP and HTTPS traffic...\033[0m\n"
    ufw allow out 80/tcp
    ufw allow out 443/tcp

    printf "\033[1;31m[+] Allowing traffic for Debian updates and app dependencies...\033[0m\n"
    ufw allow out 53/udp  # DNS resolution
    ufw allow out 53/tcp  # DNS resolution
    ufw allow out 123/udp # NTP (time synchronization)
    ufw allow out to archive.debian.org port 80 proto tcp
    ufw allow out to security.debian.org port 443 proto tcp

    printf "\033[1;31m[+] Enabling and reloading UFW...\033[0m\n"
    echo "y" | ufw enable || { printf "\033[1;31m[-] Failed to enable UFW.\033[0m\n"; return 1; }
    ufw reload || { printf "\033[1;31m[-] Failed to reload UFW.\033[0m\n"; return 1; }

    printf "\033[1;32m[+] UFW configuration completed successfully.\033[0m\n"
}

stig_set_randomize_va_space() {
    printf "\033[1;31m[+] Setting kernel.randomize_va_space...\033[0m\n"
    echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/hardn.conf
    sysctl -w kernel.randomize_va_space=2 || printf "\033[1;31m[-] Failed to set randomize_va_space.\033[0m\n"
    sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
}

update_firmware() {
    printf "\033[1;31m[+] Checking for firmware updates...\033[0m\n"
    apt install -y fwupd
    fwupdmgr refresh || printf "\033[1;31m[-] Failed to refresh firmware metadata.\033[0m\n"
    fwupdmgr get-updates || printf "\033[1;31m[-] Failed to check for firmware updates.\033[0m\n"
    if fwupdmgr update; then
        printf "\033[1;32m[+] Firmware updates applied successfully.\033[0m\n"
    else
        printf "\033[1;33m[+] No firmware updates available or update process skipped.\033[0m\n"
    fi
    apt update -y
}

apply_stig_hardening() {
    printf "\033[1;31m[+] Applying STIG hardening tasks...\033[0m\n"

    stig_password_policy || { printf "\033[1;31m[-] Failed to apply password policy.\033[0m\n"; exit 1; }
    stig_lock_inactive_accounts || { printf "\033[1;31m[-] Failed to lock inactive accounts.\033[0m\n"; exit 1; }
    stig_login_banners || { printf "\033[1;31m[-] Failed to set login banners.\033[0m\n"; exit 1; }
    stig_kernel_setup || { printf "\033[1;31m[-] Failed to configure kernel parameters.\033[0m\n"; exit 1; }
    stig_secure_filesystem || { printf "\033[1;31m[-] Failed to secure filesystem permissions.\033[0m\n"; exit 1; }
    stig_disable_usb || { printf "\033[1;31m[-] Failed to disable USB storage.\033[0m\n"; exit 1; }
    stig_disable_core_dumps || { printf "\033[1;31m[-] Failed to disable core dumps.\033[0m\n"; exit 1; }
    stig_disable_ctrl_alt_del || { printf "\033[1;31m[-] Failed to disable Ctrl+Alt+Del.\033[0m\n"; exit 1; }
    stig_disable_ipv6 || { printf "\033[1;31m[-] Failed to disable IPv6.\033[0m\n"; exit 1; }
    stig_configure_firewall || { printf "\033[1;31m[-] Failed to configure firewall.\033[0m\n"; exit 1; }
    stig_set_randomize_va_space || { printf "\033[1;31m[-] Failed to set randomize_va_space.\033[0m\n"; exit 1; }
    update_firmware || { printf "\033[1;31m[-] Failed to update firmware.\033[0m\n"; exit 1; }

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
    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m             [+] HARDN - Updating and Detecting OS      \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"
    detect_os
    update_system_packages
    install_pkgdeps
    grub_security
    
    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m            [+] HARDN - Installing Security Tools       \033[0m\n"
    printf "\033[1;31m                [+] Applying Security Settings          \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"
    install_security_tools
    enable_aide
    enable_apparmor
    configure_firejail
    enable_fail2ban
    enable_rkhunter

    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m             [+] HARDN - STIG Hardening                 \033[0m\n"
    printf "\033[1;31m       [+] Applying STIG hardening to system            \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"
    apply_stig_hardening

    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m             [+] HARDN - Enable services                \033[0m\n"
    printf "\033[1;31m                 [+] Applying Services                  \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"
    sleep 3
    setup_complete

}
main