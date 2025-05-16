#!/bin/bash

set -e

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGES_SCRIPT="$SCRIPT_DIR/hardn-packages.sh"

LOG_FILE="/var/log/hardn-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1


if [ "$(id -u)" -ne 0; then
    echo "This script must be run as root. Use: sudo hardn"
    exit 1
fi


printf "[DEBUG] Script started with arguments: $@\n"

center_text() {
    local text="$1"
    local width=$(tput cols)
    local text_width=${#text}
    local padding=$(( (width - text_width) / 2 ))
    printf "%${padding}s%s\n" "" "$text"
}

print_menu() {
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    GREEN_BOLD="\033[1;32m"
    RESET="\033[0m"
    BORDER="══════════════════════════════════════════════════════════════════════════════════════════════════════"

    clear
    echo -e "${GREEN_BOLD}"
    center_text "$BORDER"
    center_text "  ▄█    █▄            ▄████████         ▄████████      ████████▄       ███▄▄▄▄   "
    center_text "  ███    ███          ███    ███        ███    ███      ███   ▀███      ███▀▀▀██▄ "
    center_text "  ███    ███          ███    ███        ███    ███      ███    ███      ███   ███ "
    center_text " ▄███▄▄▄▄███▄▄        ███    ███       ▄███▄▄▄▄██▀      ███    ███      ███   ███ "
    center_text "▀▀███▀▀▀▀███▀       ▀███████████      ▀▀███▀▀▀▀▀        ███    ███      ███   ███ "
    center_text "  ███    ███          ███    ███      ▀███████████      ███    ███      ███   ███ "
    center_text "  ███    ███          ███    ███        ███    ███      ███   ▄███      ███   ███ "
    center_text "  ███    █▀           ███    █▀         ███    ███      ████████▀        ▀█   █▀  "
    center_text "                                        ███    ███                              "
    center_text "$BORDER"
    center_text "Please select an option:"
    center_text "$BORDER"
    echo
    center_text "Usage: sudo hardn [options]"
    echo
    center_text "Options:"
    echo
    echo "-s,         Run HARDN"
    echo "-u,         Update system packages"
    echo "-cl,        Check HARDN logs"
    echo "-i,         Install security tools"
    echo "-d-st,      Disable security tools"
    echo "-e-st,      Enable security tools"
    echo "-d-aa,      Disable AppArmor"
    echo "-e-aa,      Enable AppArmor"
    echo "-d-fb,      Disable Fail2Ban"
    echo "-e-fb,      Enable Fail2Ban"
    echo "-d-f,       Disable Firejail"
    echo "-e-f,       Enable Firejail"
    echo "-d-rk,      Disable RKHunter"
    echo "-e-rk,      Enable RKHunter"
    echo "-d-a,       Disable AIDE"
    echo "-e-a,       Enable AIDE"
    echo "-d-u,       Disable UFW"
    echo "-e-u,       Enable UFW"
    echo "-t,         Show installed security tools"
    echo "-stig,      Show STIG hardening tasks"
    echo "-h,         Show this help menu"
    echo
    center_text "$BORDER"
    echo -e "${RESET}"
    exit 0
fi


if [[ -z "$1" ]]; then
    echo "No option provided. Use -h or --help for usage information."
    exit 1
fi


CYAN_BOLD="\033[1;36m"
RESET="\033[0m"
}


update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    if ! apt update -y && apt upgrade -y; then
        printf "\033[1;31m[-] Failed to update and upgrade packages.\033[0m\n"
        exit 1
    fi

    if ! sudo apt-get install -f; then
        printf "\033[1;31m[-] Failed to fix broken dependencies.\033[0m\n"
        exit 1
    fi

    if ! apt --fix-broken install -y; then
        printf "\033[1;31m[-] Failed to fix broken packages.\033[0m\n"
        exit 1
    fi

    printf "\033[1;32m[+] System packages updated successfully.\033[0m\n"
}


flags(){ 
    echo "[DEBUG] Entered flags function with argument: $1"
    if [[ -n "$1" ]]; then
        case $1 in
            -s|--setup)
                echo "[DEBUG] Running main function"
                main
                ;;
            -u|--update)
                echo "[DEBUG] Running update_system_packages function"
                update_system_packages
                ;;
            -cl|--check-HARDN-logs)
                echo "[DEBUG] Checking HARDN logs"
                if [ -f /HARDN_alerts.txt ]; then
                    echo "HARDN logs found:"
                    cat /HARDN_alerts.txt
                else
                    echo "No HARDN logs found."
                fi
                ;;
            -i|--install-security-tools)
                echo "[DEBUG] Running install_security_tools function"
                install_security_tools
                ;;
            -d-st|--disable-security-tools)
                systemctl disable --now ufw fail2ban apparmor firejail rkhunter aide
                echo "Security tools disabled."
                ;;
            -e-st|--enable-security-tools)
                systemctl enable --now ufw fail2ban apparmor firejail rkhunter aide
                echo "Security tools enabled."
                ;;
            -d-aa|--disable-apparmor)
                systemctl disable --now apparmor
                echo "AppArmor disabled."
                ;;
            -e-aa|--enable-apparmor)
                systemctl enable --now apparmor
                echo "AppArmor enabled."
                ;;
            -d-fb|--disable-fail2ban)
                systemctl disable --now fail2ban
                echo "Fail2Ban disabled."
                ;;
            -e-fb|--enable-fail2ban)
                systemctl enable --now fail2ban
                echo "Fail2Ban enabled."
                ;;
            -d-f|--disable-firejail)
                systemctl disable --now firejail
                echo "Firejail disabled."
                ;;
            -e-f|--enable-firejail)
                systemctl enable --now firejail
                echo "Firejail enabled."
                ;;
            -d-rk|--disable-rkhunter)
                systemctl disable --now rkhunter
                echo "RKHunter disabled."
                ;;
            -e-rk|--enable-rkhunter)
                systemctl enable --now rkhunter
                echo "RKHunter enabled."
                ;;
            -d-a|--disable-aide)
                systemctl disable --now aide
                echo "AIDE disabled."
                ;;
            -e-a|--enable-aide)
                systemctl enable --now aide
                echo "AIDE enabled."
                ;;
            -d-u|--disable-ufw)
                systemctl disable --now ufw
                echo "UFW disabled."
                ;;
            -e-u|--enable-ufw)
                systemctl enable --now ufw
                echo "UFW enabled."
                ;;
            -t|--show-tools)
                echo "Installed security tools:"
                echo "  - AppArmor"
                echo "  - Fail2Ban"
                echo "  - Firejail"
                echo "  - RKHunter"
                echo "  - AIDE"
                echo "  - UFW"
                ;;
            -stig|--show-stig)
                echo "STIG hardening tasks:"
                echo "  - Password policy"
                echo "  - Lock inactive accounts"
                echo "  - Login banners"
                echo "  - Kernel parameters"
                echo "  - Secure filesystem permissions"
                echo "  - Disable USB storage"
                echo "  - Disable core dumps"
                echo "  - Disable Ctrl+Alt+Del"
                echo "  - Disable IPv6"
                echo "  - Configure firewall (UFW)"
                echo "  - Set randomize_va_space"
                ;;
            -h|--help)
                "$0" -h
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use -h or --help for usage information."
                exit 1
                ;;
        esac
    else
        echo "[DEBUG] No argument provided to flags function"
        echo "No option provided. Use -h or --help for usage information."
        exit 1
    fi
}

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

install_pkgdeps() {

    printf "\033[1;31m[+] Installing package dependencies...\033[0m\n"
    apt install -y git fwupd gawk mariadb-common policycoreutils dpkg-dev \
        unixodbc-common firejail unattended-upgrades python3-pyqt6 fonts-liberation libpam-pwquality

}

enable_auto_updates() {
    printf "\033[1;31m[+] Enabling automatic updates...\033[0m\n"
    apt install -y unattended-upgrades || {
        printf "\033[1;31m[-] Failed to install unattended-upgrades.\033[0m\n"
        return 1
    }

    dpkg-reconfigure -plow unattended-upgrades
    printf "\033[1;32m[+] Automatic updates enabled.\033[0m\n"
}

install_security_tools() {
    printf "\033[1;31m[+] Installing required system security tools...\033[0m\n"
    apt update -y
    apt install -y ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums aide \
        libpam-pwquality libvirt-daemon-system libvirt-clients qemu-system-x86 openssh-server openssh-client rkhunter 

}

install_maldet() {
    printf "\033[1;31m[+] Installing Linux Malware Detect (maldet)...\033[0m\n"

    wget https://www.rfxn.com/downloads/maldetect-current.tar.gz -O /tmp/maldetect-current.tar.gz || {
        printf "\033[1;31m[-] Failed to download maldet.\033[0m\n"
        return 1
    }

    tar -xvzf /tmp/maldetect-current.tar.gz -C /tmp || {
        printf "\033[1;31m[-] Failed to extract maldet.\033[0m\n"
        return 1
    }
   
    maldet_dir=$(find /tmp -maxdepth 1 -type d -name "maldetect-*" | head -n 1)
    if [ -z "$maldet_dir" ]; then
        printf "\033[1;31m[-] Maldetect directory not found.\033[0m\n"
        return 1
    fi
    cd "$maldet_dir" || {
        printf "\033[1;31m[-] Failed to navigate to maldet directory.\033[0m\n"
        return 1
    }
    sudo ./install.sh || {
        printf "\033[1;31m[-] Failed to install maldet.\033[0m\n"
        return 1
    }

    sudo maldet --update || {
        printf "\033[1;31m[-] Failed to update maldet signatures.\033[0m\n"
        return 1
    }

    printf "\033[1;32m[+] maldet installed and updated successfully.\033[0m\n"
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

    systemctl enable apparmor || { 
        printf "\033[1;31m[-] Failed to enable AppArmor at boot.\033[0m\n"
        exit 1
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

    if [ -f /var/lib/aide/aide.db ]; then
        printf "\033[1;33m[!] AIDE database already exists. Skipping initialization and continuing.\033[0m\n"
        return 0
    fi

    aideinit || {
        printf "\033[1;31m[-] Failed to initialize AIDE database.\033[0m\n"
        return 1
    }

    aide --check || {
        printf "\033[1;31m[-] AIDE check failed. Please review the logs.\033[0m\n"
        return 1
    }
    
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db || {
        printf "\033[1;31m[-] Failed to replace AIDE database.\033[0m\n"
        return 1
    }

    printf "\033[1;32m[+] AIDE successfully installed and configured.\033[0m\n"
}

enable_rkhunter(){
    printf "\033[1;31m[+] Installing rkhunter...\033[0m\n" | tee -a HARDN_alerts.txt
    if ! apt install -y rkhunter; then
        printf "\033[1;33m[!] Saving output to HARDN_alerts.txt" | tee -a HARDN_alerts.txt
        return 0
    fi

   
    sudo chown -R root:root /var/lib/rkhunter
    sudo chmod -R 755 /var/lib/rkhunter

   
    sed -i 's|^#*MIRRORS_MODE=.*|MIRRORS_MODE=1|' /etc/rkhunter.conf
    sed -i 's|^#*UPDATE_MIRRORS=.*|UPDATE_MIRRORS=1|' /etc/rkhunter.conf
    sed -i 's|^WEB_CMD=.*|WEB_CMD="/bin/true"|' /etc/rkhunter.conf

   
    if ! rkhunter --update --nocolors --check; then
        printf "\033[1;33m[!] rkhunter update failed. Check your network connection or proxy settings. Continuing...\033[0m\n" | tee -a HARDN_alerts.txt
    fi

    rkhunter --propupd || printf "\033[1;33m[!] Failed to update rkhunter properties. Continuing...\033[0m\n" | tee -a HARDN_alerts.txt
    printf "\033[1;32m[+] rkhunter installed and updated.\033[0m\n" | tee -a HARDN_alerts.txt
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
    sed -i 's/^#\? *enforcing *=.*/enforcing = 1/' /etc/security/pwquality.conf

   
    echo "PASS_MIN_DAYS 1" >> /etc/login.defs
    echo "PASS_MAX_DAYS 90" >> /etc/login.defs
    echo "PASS_WARN_AGE 7" >> /etc/login.defs

  
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
    chmod 644 /etc/group
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




stig_harden_ssh() {
    printf "\033[1;31m[+] Hardening SSH configuration...\033[0m\n"

    sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
    sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
    echo "AllowUsers your_user" >> /etc/ssh/sshd_config
    echo "Ciphers aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config
    echo "MACs hmac-sha2-512,hmac-sha2-256" >> /etc/ssh/sshd_config

    systemctl restart sshd || {
        printf "\033[1;31m[-] Failed to restart SSH service. Check your configuration.\033[0m\n"
        return 1
    }

    printf "\033[1;32m[+] SSH configuration hardened successfully.\033[0m\n"
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
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.tcp_timestamps = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF

    sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
    sysctl -w kernel.randomize_va_space=2 || printf "\033[1;31m[-] Failed to set kernel.randomize_va_space.\033[0m\n"
}



grub_security() {
    
    if [ -d /sys/firmware/efi ]; then
        echo "[*] UEFI system detected. Skipping GRUB configuration..."
        return 0
    fi

  
    if grep -q 'hypervisor' /proc/cpuinfo; then
        echo "[*] Virtual machine detected. Proceeding with GRUB configuration..."
    else
        echo "[+] No virtual machine detected. Proceeding with GRUB configuration..."
    fi

    echo "[+] Setting GRUB password..."
    grub-mkpasswd-pbkdf2 | tee /etc/grub.d/40_custom_password

    # Detect GRUB 
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

    # Update GRUB 
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
    stig_set_randomize_va_space() {
    printf "\033[1;31m[+] Setting kernel.randomize_va_space...\033[0m\n"
    echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/hardn.conf
    sysctl --system || { printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"; exit 1; }
    sysctl -w kernel.randomize_va_space=2 || { printf "\033[1;31m[-] Failed to set kernel.randomize_va_space.\033[0m\n"; exit 1; }
}
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

detect_environment() {
    printf "\033[1;31m[+] Detecting system environment...\033[0m\n"

    if [ -d /sys/firmware/efi ]; then
        echo "[*] UEFI system detected. Configuring for UEFI..."
        # Add UEFI-specific configurations here if needed
    else
        echo "[*] Legacy BIOS system detected. Configuring for BIOS..."
        # Add BIOS-specific configurations here if needed
    fi

    if grep -q 'hypervisor' /proc/cpuinfo; then
        echo "[*] Virtual machine detected. Applying VM-specific optimizations..."
        # Add VM-specific configurations here if needed
    else
        echo "[*] Bare metal system detected. Applying bare metal optimizations..."
        # Add bare metal-specific configurations here if needed
    fi
}

check_internet() {
    printf "\033[1;31m[+] Checking internet connectivity...\033[0m\n"
    if ! ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        printf "\033[1;31m[-] Internet connectivity is not available. Please check your network.\033[0m\n"
        exit 1
    fi
    printf "\033[1;32m[+] Internet connectivity is available.\033[0m\n"
}

main() {
    printf "\033[1;31m[+] Initializing HARDN setup...\033[0m\n"

    detect_environment
    enable_auto_updates
    check_internet
    echo -e "\033[1;31m
================================================================================
                          [*] DETECTING OPERATING SYSTEM
================================================================================
\033[0m"
    detect_os

    echo -e "\033[1;31m
================================================================================
                          [*] INSTALLING PACKAGE DEPENDENCIES
================================================================================
\033[0m"
    install_pkgdeps

    echo -e "\033[1;31m
================================================================================
                          [*] INSTALLING SECURITY TOOLS
================================================================================
\033[0m"
    install_security_tools
    install_maldet

    echo -e "\033[1;31m
================================================================================
                          [*] ENABLING FAIL2BAN
================================================================================
\033[0m"
    enable_fail2ban

    echo -e "\033[1;31m
================================================================================
                          [*] ENABLING APPARMOR
================================================================================
\033[0m"
    enable_apparmor

    echo -e "\033[1;31m
================================================================================
                          [*] ENABLING AIDE
================================================================================
\033[0m"
    enable_aide

    echo -e "\033[1;31m
================================================================================
                          [*] ENABLING RKHUNTER
================================================================================
\033[0m"
    enable_rkhunter

    echo -e "\033[1;31m
================================================================================
                          [*] CONFIGURING FIREJAIL
================================================================================
\033[0m"
    configure_firejail

    echo -e "\033[1;31m
================================================================================
                          [*] APPLYING PASSWORD POLICY
================================================================================
\033[0m"
    stig_password_policy || { printf "\033[1;31m[-] Failed to apply password policy.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] HARDENING SSH CONFIGURATION
================================================================================
\033[0m"
    stig_harden_ssh || { printf "\033[1;31m[-] Failed to secure ssh.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] LOCKING INACTIVE ACCOUNTS
================================================================================
\033[0m"
    stig_lock_inactive_accounts || { printf "\033[1;31m[-] Failed to lock inactive accounts.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] SETTING LOGIN BANNERS
================================================================================
\033[0m"
    stig_login_banners || { printf "\033[1;31m[-] Failed to set login banners.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] CONFIGURING KERNEL PARAMETERS
================================================================================
\033[0m"
    stig_kernel_setup || { printf "\033[1;31m[-] Failed to configure kernel parameters.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] SECURING FILESYSTEM PERMISSIONS
================================================================================
\033[0m"
    stig_secure_filesystem || { printf "\033[1;31m[-] Failed to secure filesystem permissions.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] DISABLING USB STORAGE
================================================================================
\033[0m"
    stig_disable_usb || { printf "\033[1;31m[-] Failed to disable USB storage.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] DISABLING CORE DUMPS
================================================================================
\033[0m"
    stig_disable_core_dumps || { printf "\033[1;31m[-] Failed to disable core dumps.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] DISABLING CTRL+ALT+DEL
================================================================================
\033[0m"
    stig_disable_ctrl_alt_del || { printf "\033[1;31m[-] Failed to disable Ctrl+Alt+Del.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] DISABLING IPV6
================================================================================
\033[0m"
    stig_disable_ipv6 || { printf "\033[1;31m[-] Failed to disable IPv6.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] CONFIGURING FIREWALL (UFW)
================================================================================
\033[0m"
    stig_configure_firewall || { printf "\033[1;31m[-] Failed to configure firewall.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] SETTING RANDOMIZE VA SPACE
================================================================================
\033[0m"
    stig_set_randomize_va_space || { printf "\033[1;31m[-] Failed to set randomize_va_space.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] UPDATING FIRMWARE
================================================================================
\033[0m"
    update_firmware || { printf "\033[1;31m[-] Failed to update firmware.\033[0m\n"; exit 1; }

    echo -e "\033[1;31m
================================================================================
                          [*] CONFIGURING GRUB SECURITY
================================================================================
\033[0m"
    grub_security

    echo -e "\033[1;31m
================================================================================
                          [*] APPLYING STIG HARDENING TASKS
================================================================================
\033[0m"

    echo -e "\033[1;31m
================================================================================
                          [*] ENABLING UFW
================================================================================
\033[0m"
    systemctl enable --now ufw

  
    printf "\033[1;31m[+] Running validation script...\033[0m\n"
    bash "$PACKAGES_SCRIPT"

    if [ $? -ne 0 ]; then
        printf "\033[1;31m[-] Validation script encountered errors. Please check the log file.\033[0m\n"
        exit 1
    fi

    setup_complete

    printf "\033[1;32m[+] Validation script completed successfully.\033[0m\n"
    printf "\033[1;32m[+] HARDN setup completed successfully.\033[0m\n"
}


if [[ $# -eq 0 || "$1" == "-s" ]]; then
    main
fi

if [[ $# -eq 0 || "$1" == "-h" || "$1" == "--help" ]]; then
    print_menu -h
    exit 0
fi


flags "$@"