#!/bin/sh
set -e # Exit on errors




                                                 # Author(s):                         
                                              #- Chris Bingham                    
                                              #  - Tim Burns                        
                                  
                                              #Date: 4/5-12/2025   


print_ascii_banner() {
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
                                      ▗▄▄▖    ▗▄▄▄▖    ▗▄▄▄▖    ▗▖ ▗▖    ▗▄▄▖ 
                                     ▐▌       ▐▌         █      ▐▌ ▐▌    ▐▌ ▐▌
                                      ▝▀▚▖    ▐▛▀▀▘      █      ▐▌ ▐▌    ▐▛▀▘ 
                                     ▗▄▄▞▘    ▐▙▄▄▖      █      ▝▚▄▞▘    ▐▌   
                                       
                                                    v 1.1.2               
                                    
                                                               
                                  
EOF
}

print_ascii_banner

sleep 5 &>/dev/null




if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use: sudo ./setup.sh"
    exit 1
fi

set_generic_hostname() {
    printf "\033[1;31m[+] Setting a generic hostname...\033[0m\n"
    sudo hostnamectl set-hostname "MY-PC"
    if [ $? -eq 0 ]; then
        printf "\033[1;32m[+] Hostname successfully changed to MY-PC.\033[0m\n"
    else
        printf "\033[1;31m[-] Failed to change hostname. Ensure you have the necessary permissions.\033[0m\n"
    fi

}

update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    sudo apt update -y && apt upgrade -y
}

install_pkgdeps() {
    printf "\033[1;31m[+] Installing package dependencies...\033[0m\n"
    sudo apt install -y wget curl git gawk mariadb-common mysql-common policycoreutils \
        python3-matplotlib unixodbc-common firejail python3-pyqt6
}


install_selinux() {
    printf "\033[1;31m[+] Installing and configuring SELinux as sudo...\033[0m\n"
    sudo apt update
    sudo apt install -y selinux-utils selinux-basics policycoreutils policycoreutils-python-utils selinux-policy-default
    if ! command -v getenforce > /dev/null 2>&1; then
        printf "\033[1;31m[-] SELinux installation failed. Please check system logs.\033[0m\n"
        return 1
    fi
    if getenforce | grep -q "Disabled"; then
        printf "\033[1;31m[-] SELinux is disabled. Configuring it to enforcing mode at boot...\033[0m\n"
        sudo sed -i 's/^SELINUX=.*/SELINUX=enforcing/' /etc/selinux/config
        printf "\033[1;31m[+] SELinux configured to enforcing mode at boot.\033[0m\n"
    else
        sudo setenforce 1 || printf "\033[1;31m[-] Could not set SELinux to enforcing mode immediately. Please reboot to apply changes.\033[0m\n"
    fi
    printf "\033[1;31m[+] SELinux installation and configuration completed.\033[0m\n"
}

install_security_tools() {
    printf "\033[1;31m[+] Installing required system security tools...\033[0m\n"
    sudo apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums \
        libpam-pwquality libvirt-daemon-system libvirt-clients qemu-system-x86 openssh-server openssh-client
}

enable_services() {
    printf "\033[1;31m[+] Enabling and starting Fail2Ban and AppArmor services...\033[0m\n"
    sudo systemctl enable --now fail2ban
    sudo systemctl enable --now apparmor
    printf "\033[1;31m[+] Applying stricter AppArmor profiles...\033[0m\n"
    sudo aa-enforce /etc/apparmor.d/* || printf "\033[1;31m[-] Warning: Failed to enforce some AppArmor profiles.\033[0m\n"
    sudo systemctl restart fail2ban
}

install_additional_tools() {
    printf "\033[1;31m[+] Installing chkrootkit and LMD as sudo...\033[0m\n"
    sudo apt install -y chkrootkit
    temp_dir=$(mktemp -d)
    cd "$temp_dir" || { printf "\033[1;31m[-] Failed to create temp directory\033[0m\n"; return 1; }
    if sudo git clone https://github.com/rfxn/linux-malware-detect.git; then
        cd linux-malware-detect || { printf "\033[1;31m[-] Could not enter maldetect dir\033[0m\n"; return 1; }
        sudo chmod +x install.sh
        sudo ./install.sh
    else
        printf "\033[1;31m[-] Failed to clone maldetect repo\033[0m\n"
    fi
    cd /tmp || true
    sudo rm -rf "$temp_dir"
}


install_aide() {
    printf "\033[1;31m[+] Installing and configuring AIDE...\033[0m\n"
    {
        sudo apt install -y aide aide-common &&
        sudo aideinit -y &&
        sudo aide --config-check --config=/etc/aide/aide.conf &&
        sudo aideinit &&
        if [ -f /var/lib/aide/aide.db.new ]; then
            sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
            sudo chmod 600 /var/lib/aide/aide.db
            printf "\033[1;31m[+] AIDE installation and initial database setup completed with proper permissions.\033[0m\n"
        else
            printf "\033[1;31m[-] AIDE database file not found. Continuing...\033[0m\n"
        fi
    } > /var/log/aide_install.log 2>&1 &
    printf "\033[1;31m[+] AIDE installation running in the background. Check /var/log/aide_install.log for details.\033[0m\n"
}

configure_firejail() {
    printf "\033[1;31m[+] Configuring Firejail for Firefox and Chrome...\033[0m\n"

    # Ensure Firejail is installed
    if ! command -v firejail > /dev/null 2>&1; then
        printf "\033[1;31m[-] Firejail is not installed. Please install it first.\033[0m\n"
        return 1
    fi

    # Configure Firejail for Firefox
    if command -v firefox > /dev/null 2>&1; then
        printf "\033[1;31m[+] Setting up Firejail for Firefox...\033[0m\n"
        sudo ln -sf /usr/bin/firejail /usr/local/bin/firefox
    else
        printf "\033[1;31m[-] Firefox is not installed. Skipping Firejail setup for Firefox.\033[0m\n"
    fi

    # Configure Firejail for Chrome
    if command -v google-chrome > /dev/null 2>&1; then
        printf "\033[1;31m[+] Setting up Firejail for Google Chrome...\033[0m\n"
        sudo ln -sf /usr/bin/firejail /usr/local/bin/google-chrome
    else
        printf "\033[1;31m[-] Google Chrome is not installed. Skipping Firejail setup for Chrome.\033[0m\n"
    fi

    printf "\033[1;31m[+] Firejail configuration completed.\033[0m\n"
}




install_rust() {
    printf "\033[1;31m[+] Installing Rust...\033[0m\n"

    if command -v rustc > /dev/null 2>&1; then
        printf "\033[1;32m[+] Rust is already installed. Skipping installation.\033[0m\n"
        return 0
    fi

    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    export PATH="$HOME/.cargo/bin:$PATH"

    if command -v rustc > /dev/null 2>&1; then
        printf "\033[1;32m[+] Rust installed successfully.\033[0m\n"
        rustc --version
    else
        printf "\033[1;31m[-] Rust installation failed. Please check the logs.\033[0m\n"
        return 1
    fi
}

   

stig_password_policy() {
    sudo apt install -y libpam-pwquality
    sudo sed -i 's/^# minlen.*/minlen = 14/' /etc/security/pwquality.conf
    sudo sed -i 's/^# dcredit.*/dcredit = -1/' /etc/security/pwquality.conf
    sudo sed -i 's/^# ucredit.*/ucredit = -1/' /etc/security/pwquality.conf
    sudo sed -i 's/^# ocredit.*/ocredit = -1/' /etc/security/pwquality.conf
    sudo sed -i 's/^# lcredit.*/lcredit = -1/' /etc/security/pwquality.conf
    sudo sed -i '/pam_pwquality.so/ s/$/ retry=3 enforce_for_root/' /etc/pam.d/common-password || true
}

stig_lock_inactive_accounts() {
    sudo useradd -D -f 35
    for user in $(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd); do
        sudo chage --inactive 35 "$user"
    done
}

stig_login_banners() {
    echo "You are accessing a fully secured SIG Information System (IS)..." > /etc/issue
    echo "Use of this IS constitutes consent to monitoring..." > /etc/issue.net
    sudo chmod 644 /etc/issue /etc/issue.net
}
stig_secure_filesystem() {
    printf "\033[1;31m[+] Securing filesystem permissions...\033[0m\n"
    sudo chown root:root /etc/passwd /etc/group /etc/gshadow
    sudo chmod 644 /etc/passwd /etc/group
    sudo chown root:shadow /etc/shadow /etc/gshadow
    sudo chmod 000 /etc/shadow
    sudo chmod 640 /etc/gshadow
}

stig_audit_rules() {
    sudo apt install -y auditd audispd-plugins
    sudo tee /etc/audit/rules.d/stig.rules > /dev/null <<EOF
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-e 2
EOF

   sudo augenrules --load
   sudo systemctl enable --now auditd
}

    
stig_kernel_setup() {
    printf "\033[1;31m[+] Setting up STIG-compliant kernel parameters...\033[0m\n"
    sudo tee /etc/sysctl.d/stig-kernel.conf > /dev/null <<EOF
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
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF
    sudo sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
}

stig_disable_usb() {
    echo "install usb-storage /bin/false" > /etc/modprobe.d/hardn-blacklist.conf
    sudo update-initramfs -u || printf "\033[1;31m[-] Failed to update initramfs.\033[0m\n"
}

stig_disable_core_dumps() {
    echo "* hard core 0" | sudo tee -a /etc/security/limits.conf > /dev/null
    echo "fs.suid_dumpable = 0" | sudo tee /etc/sysctl.d/99-coredump.conf > /dev/null
    sudo sysctl -w fs.suid_dumpable=0
}

stig_disable_ctrl_alt_del() {
    sudo systemctl mask ctrl-alt-del.target
    sudo systemctl daemon-reexec
}



stig_disable_ipv6() {
    sudo echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
    sudo echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
    sudo sysctl -p
}

echo "You are accessing a fully secured SIG Information System (IS)..." > /etc/issue
echo "Use of this IS constitutes consent to monitoring..." > /etc/issue.net
sudo chmod 644 /etc/issue /etc/issue.net

configure_ufw() {
    printf "\033[1;31m[+] Configuring UFW...\033[0m\n"
    sudo ufw default deny incoming
    sudo ufw default allow outgoing
    sudo ufw allow out 53    # Allow DNS for LMD signature updates and Rust installs
    sudo ufw allow out 443   # Allow HTTPS for LMD signature updates and Rust installs
    sudo ufw enable || printf "\033[1;31m[-] Warning: Could not enable UFW.\033[0m\n"
    sudo ufw reload || printf "\033[1;31m[-] Warning: Could not reload UFW.\033[0m\n"
    printf "\033[1;31m[+] UFW configuration completed.\033[0m\n"

}

enforce_apparmor_whitelist() {
    printf "\033[1;31m[+] Enforcing AppArmor whitelist...\033[0m\n"
    if [ ! -f /etc/apparmor.d/local/hardn.whitelist ]; then
        echo "/usr/local/bin/hardn rix," > /etc/apparmor.d/local/hardn.whitelist
    fi
    sudo apparmor_parser -r /etc/apparmor.d/local/hardn.whitelist || printf "\033[1;31m[-] Failed to enforce AppArmor whitelist.\033[0m\n"
}

set_randomize_va_space() {
    printf "\033[1;31m[+] Setting kernel.randomize_va_space...\033[0m\n"
    echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/hardn.conf
    sudo sysctl -w kernel.randomize_va_space=2 || printf "\033[1;31m[-] Failed to set randomize_va_space.\033[0m\n"
    sudo sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
}

update_firmware() {
    printf "\033[1;31m[+] Checking for firmware updates...\033[0m\n"
    sudo apt install -y fwupd
    sudo fwupdmgr refresh || printf "\033[1;31m[-] Failed to refresh firmware metadata.\033[0m\n"
    sudo fwupdmgr get-updates || printf "\033[1;31m[-] Failed to check for firmware updates.\033[0m\n"
    if fwupdmgr update; then
        printf "\033[1;32m[+] Firmware updates applied successfully.\033[0m\n"
    else
        printf "\033[1;33m[+] No firmware updates available or update process skipped.\033[0m\n"
    fi
    sudo apt update -y
}


apply_stig_hardening() {
    stig_password_policy
    stig_lock_inactive_accounts
    stig_login_banners
    stig_kernel_setup
    stig_secure_filesystem
    stig_audit_rules
    stig_disable_usb
    stig_disable_core_dumps
    stig_disable_ctrl_alt_del
    stig_disable_ipv6
    set_randomize_va_space
    enforce_apparmor_whitelist
    update_firmware
    
}

setup_complete() {
    echo "======================================================="
    echo "             [+] HARDN - Setup Complete                "
    echo "             calling Validation Script                 "
    echo "                                                       "
    echo "======================================================="
}

main() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    update_system_packages

    printf "\033[1;31m[+] Setting generic hostname...\033[0m\n"
    set_generic_hostname
    apply_stig_hardening
  
  
    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m             [+] HARDN - Setting Up                     \033[0m\n"
    printf "\033[1;31m       [+] Installing required Security Services        \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"

    install_pkgdeps
    install_selinux

    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m                  [+] HARDN - SELinux                   \033[0m\n"
    printf "\033[1;31m       [+] SELinux will not run until after reboot      \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"

    install_security_tools

    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m            [+] HARDN - Installing Security Tools       \033[0m\n"
    printf "\033[1;31m                [+] Applying Secruity Settings          \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"

    install_aide
    configure_firejail
    configure_ufw
    enable_services

    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m             [+] HARDN - Enable services                \033[0m\n"
    printf "\033[1;31m                 [+] Applying Services                  \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"

    install_additional_tools
    install_rust

    printf "\033[1;31m========================================================\033[0m\n"
    printf "\033[1;31m             [+] HARDN - STIG Hardening                 \033[0m\n"
    printf "\033[1;31m       [+] Applying STIG hardening to system            \033[0m\n"
    printf "\033[1;31m========================================================\033[0m\n"

    
    setup_complete
}

main

sleep 3 &>/dev/null

PACKAGES_SCRIPT="/home/tim/DEV/HARDN/src/setup/packages.sh"
printf "\033[1;31m[+] Looking for packages.sh at: %s\033[0m\n" "$PACKAGES_SCRIPT"
if [ -f "$PACKAGES_SCRIPT" ]; then
    printf "\033[1;31m[+] Setting executable permissions for packages.sh...\033[0m\n"
    chmod +x "$PACKAGES_SCRIPT"
    printf "\033[1;31m[+] Setting sudo permissions for packages.sh...\033[0m\n"
    echo "tim ALL=(ALL) NOPASSWD: $PACKAGES_SCRIPT" | sudo tee /etc/sudoers.d/packages-sh > /dev/null
    printf "\033[1;31m[+] Calling packages.sh with sudo...\033[0m\n"
    sudo "$PACKAGES_SCRIPT"
else
    printf "\033[1;31m[-] packages.sh not found at: %s. Skipping...\033[0m\n" "$PACKAGES_SCRIPT"
fi




