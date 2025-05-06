#!/bin/bash
set -e # Exit on errors

# Authors: 
# - Chris B. 
# - Tim B. 


                                                 # Author(s):                         
                                              #- Chris Bingham                    
                                              #  - Tim Burns                        
                                  
                                              #Date: 4/5-12/2025   

print_ascii_banner() {
    CYAN_BOLD="\033[1;36m"
    RESET="\033[0m"

    printf "${CYAN_BOLD}"
    cat << "EOF"
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
                                                   
                                                    v 1.1.2
EOF
    printf "${RESET}"
}

print_ascii_banner
sleep 5 


SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGES_SCRIPT="$SCRIPT_DIR/hardn-packages.sh"
GRUB_SCRIPT="$SCRIPT_DIR/hardn-grub.sh"

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use: sudo ./setup.sh"
    exit 1
fi

set_generic_hostname() {
    printf "\033[1;31m[+] Setting a generic hostname...\033[0m\n"
    hostnamectl set-hostname "MY-PC"
    echo "127.0.1.1 MY-PC" | tee -a /etc/hosts
    if [ $? -eq 0 ]; then
        printf "\033[1;32m[+] Hostname successfully changed to MY-PC.\033[0m\n"
    else
        printf "\033[1;31m[-] Failed to change hostname. Ensure you have the necessary permissions.\033[0m\n"
    fi

}






update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    apt update -y && apt upgrade -y
    apt --fix-broken install -y
}






install_pkgdeps() {
    printf "\033[1;31m[+] Installing package dependencies...\033[0m\n"
    apt install -y wget curl git gawk mariadb-common mysql-common policycoreutils \
        unixodbc-common firejail python3-pyqt6 fonts-liberation
}





call_grub_script() {
    printf "\033[1;31m[+] Calling hardn-grub.sh script...\033[0m\n"
    if [ -f "$GRUB_SCRIPT" ]; then
        printf "\033[1;31m[+] Setting executable permissions for hardn-grub.sh...\033[0m\n"
        chmod +x "$GRUB_SCRIPT"
        "$GRUB_SCRIPT"
        if [ $? -ne 0 ]; then
            printf "\033[1;31m[-] hardn-grub.sh execution failed. Exiting setup.\033[0m\n"
            exit 1
        fi
    else
        printf "\033[1;31m[-] hardn-grub.sh not found at: %s. Exiting setup.\033[0m\n" "$GRUB_SCRIPT"
        exit 1
    fi
}






install_security_tools() {
    printf "\033[1;31m[+] Installing required system security tools...\033[0m\n"
    apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums \
        libpam-pwquality libvirt-daemon-system libvirt-clients qemu-system-x86 openssh-server openssh-client rkhunter 
}



enable_fail2ban() {
    printf "\033[1;31m[+] Installing and enabling Fail2Ban...\033[0m\n"
    apt update
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

  
    systemctl restart apparmor || {
        printf "\033[1;31m[-] Failed to restart AppArmor service.\033[0m\n"
        return 1
    }

    systemctl enable --now apparmor || {
        printf "\033[1;31m[-] Failed to enable AppArmor service.\033[0m\n"
        return 1
    }

    printf "\033[1;32m[+] AppArmor successfully installed and reloaded.\033[0m\n"
}







enable_aide() {
    printf "\033[1;31m[+] Checking if AIDE is already installed and initialized…\033[0m\n"
    if command -v aide >/dev/null 2>&1 && [ -f /var/lib/aide/aide.db ]; then
        printf "\033[1;32m[+] AIDE already initialized. Skipping.\033[0m\n"
        return 0
    fi

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
        printf "\033[1;33m[-] rkhunter install failed, skipping rkhunter setup.\033[0m\n"
        return 0
    fi

   
    sed -i 's|^WEB_CMD=.*|#WEB_CMD=|' /etc/rkhunter.conf

    
    sed -i 's|^MIRRORS_MODE=.*|MIRRORS_MODE=1|' /etc/rkhunter.conf

    
    chown -R root:root /var/lib/rkhunter
    chmod -R 755 /var/lib/rkhunter

    
    if ! rkhunter --update; then
        printf "\033[1;33m[-] rkhunter update failed, skipping propupd.\033[0m\n"
        return 0
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
    apt install -y libpam-pwquality
    sed -i 's/^# minlen.*/minlen = 14/' /etc/security/pwquality.conf
    sed -i 's/^# dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^# ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^# ocredit.*/ocredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^# lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
    sed -i '/pam_pwquality.so/ s/$/ retry=3 enforce_for_root/' /etc/pam.d/common-password || true
}






stig_lock_inactive_accounts() {
    useradd -D -f 35
    for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
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
    chmod 644 /etc/passwd /etc/group
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
-e 2
EOF

    chown root:root /etc/audit/rules.d/*.rules
    chmod 600 /etc/audit/rules.d/*.rules
    mkdir -p /var/log/audit
    chown -R root:root /var/log/audit
    chmod 700 /var/log/audit

    augenrules --load
    systemctl enable auditd || { printf "\033[1;31m[-] Failed to enable auditd. Ensure the script is run as root.\033[0m\n"; return 1; }
    systemctl start auditd || { printf "\033[1;31m[-] Failed to start auditd. Ensure the script is run as root.\033[0m\n"; return 1; }
    systemctl restart auditd || { printf "\033[1;31m[-] Failed to restart auditd. Ensure the script is run as root.\033[0m\n"; return 1; }
    auditctl -e 1 || printf "\033[1;31m[-] Failed to enable auditd.\033[0m\n"
}




   
stig_kernel_setup() {
    printf "\033[1;31m[+] Setting up STIG-compliant kernel parameters...\033[0m\n"
    tee /etc/sysctl.d/stig-kernel.conf > /dev/null <<EOF



kernel.randomize_va_space = 2        
kernel.exec-shield = 1               
kernel.panic_on_oops = 1             
kernel.panic = 10                    
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
net.ipv4.conf.all.forwarding = 0         
net.ipv4.conf.default.forwarding = 0


EOF

    
    sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
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

    # Allow Debian updates, app updates, and dependency updates
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
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    update_system_packages

    printf "\033[1;31m[+] Setting generic hostname...\033[0m\n"
    set_generic_hostname

    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m             [+] HARDN - Setting Up                     \033[0m\n"
    printf "\033[1;31m       [+] Installing required Security Services        \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"
    install_pkgdeps
    call_grub_script
    

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
    printf "\033[1;31m[+] Installing scheduled jobs via cron_packages()\033[0m\n"
   

}

main
