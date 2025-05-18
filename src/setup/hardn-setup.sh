#!/bin/bash

set -e

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGES_SCRIPT="$SCRIPT_DIR/hardn-packages.sh"

RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
PURPLE="\033[0;35m"
CYAN="\033[0;36m"
BOLD="\033[1m"
RESET="\033[0m"

LOG_FILE="/var/log/hardn-setup.log"
exec > >(tee -a "$LOG_FILE") 2>&1


display_status() {
    local message="$1"
    local width
    width=$(tput cols)
    
   
    local border_char="="
    local border=$(printf '%*s' 60 | tr ' ' "$border_char")
    
  
    local msg="[+] $message"
    
   
    local padding=$(( (width - ${#border}) / 2 ))
    local pad_msg=$(( (width - ${#msg}) / 2 ))
    
    echo -e "\n"
    echo -e "$(printf "%*s" $padding)${GREEN}${border}${RESET}"
    echo -e "$(printf "%*s" $pad_msg)${GREEN}${msg}${RESET}"
    echo -e "$(printf "%*s" $padding)${GREEN}${border}${RESET}"
    echo -e ""
}

if [ "$(id -u)" -ne 0 ]; then
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
    center_text "  ▄█     █▄            ▄████████         ▄████████      ████████▄       ███▄▄▄▄   "
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
    echo "-d-y,       Disable YARA"
    echo "-e-y,       Enable YARA"
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
                echo "YARA rules disabled."
                echo "Security tools disabled."
                ;;
            -e-st|--enable-security-tools)
                systemctl enable --now ufw fail2ban apparmor firejail rkhunter aide
                # Explicitly enable YARA as it doesn't have a systemd service
                enable_yara
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
            -d-y|--disable-yara)
                # Remove YARA cron job if it exists
                if grep -q "/usr/bin/yara.*index.yar" /etc/crontab; then
                    sed -i '/\/usr\/bin\/yara.*index.yar/d' /etc/crontab
                    echo "YARA cron job removed."
                fi
                # Remove YARA rules directory
                if [ -d /etc/yara/rules ]; then
                    rm -rf /etc/yara/rules
                    echo "YARA rules directory removed."
                fi
                echo "YARA rules disabled."
                ;;
            -e-y|--enable-yara)
                enable_yara
                echo "YARA rules enabled."
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
                echo "  - YARA (pattern matching and malware detection)"
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
    printf "\033[1;31m[+] Removing any existing AIDE installation...\033[0m\n"
    
    # Use DEBIAN_FRONTEND and -y flags to ensure non-interactive operation
    DEBIAN_FRONTEND=noninteractive apt-get -y remove --purge aide aide-common
    rm -rf /etc/aide /var/lib/aide
    
    printf "\033[1;31m[+] Installing AIDE and initializing database…\033[0m\n"
    DEBIAN_FRONTEND=noninteractive apt-get -y install aide aide-common || {
        printf "\033[1;31m[-] Failed to install AIDE.\033[0m\n"
        return 1
    }
    
    # Ensure the aide config directory exists
    mkdir -p /etc/aide
    
    # Create a proper AIDE configuration if it doesn't exist
    if [ ! -f /etc/aide/aide.conf ]; then
        printf "\033[1;31m[+] Creating AIDE configuration file...\033[0m\n"
        cat > /etc/aide/aide.conf << 'EOF'
# AIDE configuration file

# Set the database file paths
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new

# Rules
# The first rule to match a file determines the group a file belongs to.
# See aide.conf(5) for more information.

# Groups for AIDE
Binlib = p+i+n+u+g+s+b+m+c+md5+sha1
ConfFiles = p+i+n+u+g+sha1+rmd160
Logs = p+i+n+u+g+S
Devices = p+i+n+u+g+s+b+c+md5+sha1
Databases = p+i+n+u+g
StaticDir = p+i+n+u+g
ManPages = p+i+n+u+g+md5+sha1

# Rules
/bin ConfFiles
/sbin ConfFiles
/usr/bin ConfFiles
/usr/sbin ConfFiles
/etc ConfFiles
/lib Binlib
/lib64 Binlib
/boot ConfFiles
/root ConfFiles
/var/log Logs
/var/lib/aide Databases
EOF
    fi
    
    printf "\033[1;31m[+] Creating AIDE systemd service and timer...\033[0m\n"
    
    # Create AIDE systemd service
    cat > /etc/systemd/system/aide-check.service << 'EOF'
[Unit]
Description=AIDE Check Service
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/bin/aide --check -c /etc/aide/aide.conf
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Create AIDE systemd timer
    cat > /etc/systemd/system/aide-check.timer << 'EOF'
[Unit]
Description=Daily AIDE Check Timer

[Timer]
OnCalendar=daily
Persistent=true
AccuracySec=1h
RandomizedDelaySec=30min

[Install]
WantedBy=timers.target
EOF

    # Enable the timer
    systemctl daemon-reload
    systemctl enable aide-check.timer
    systemctl start aide-check.timer
    
    if [ -f /var/lib/aide/aide.db ]; then
        printf "\033[1;33m[!] AIDE database already exists. Skipping initialization and continuing.\033[0m\n"
        return 0
    fi

    printf "\033[1;31m[+] Initializing AIDE database with explicit config path...\033[0m\n"
    aide --init --config=/etc/aide/aide.conf || {
        printf "\033[1;31m[-] Failed to initialize AIDE database.\033[0m\n"
        return 1
    }
    
    if [ -f /var/lib/aide/aide.db.new ]; then
        cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db || {
            printf "\033[1;31m[-] Failed to replace AIDE database.\033[0m\n"
            return 1
        }
        chmod 600 /var/lib/aide/aide.db
    else
        printf "\033[1;31m[-] AIDE database initialization failed - no new database created.\033[0m\n"
        return 1
    fi

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

enable_yara() {
    printf "\033[1;31m[+] Configuring YARA rules...\033[0m\n"
    
    # Make sure YARA is installed
    if ! command -v yara >/dev/null 2>&1; then
        printf "\033[1;31m[+] Installing YARA...\033[0m\n"
        DEBIAN_FRONTEND=noninteractive apt-get -y install yara || {
            printf "\033[1;31m[-] Failed to install YARA.\033[0m\n"
            return 1
        }
    fi
    
    # Create directories for YARA rules
    yara_rules_dir="/etc/yara/rules"
    mkdir -p "$yara_rules_dir"
    
    # Download common YARA rules
    printf "\033[1;31m[+] Downloading YARA rules...\033[0m\n"
    yara_rules_zip="/tmp/yara-rules.zip"
    
    if ! wget -q "https://github.com/Yara-Rules/rules/archive/refs/heads/master.zip" -O "$yara_rules_zip"; then
        printf "\033[1;31m[-] Failed to download YARA rules.\033[0m\n"
        return 1
    fi
    
    # Create a temporary directory for extracted files
    tmp_extract_dir="/tmp/yara-rules-extract"
    mkdir -p "$tmp_extract_dir"
    
    # Use -o flag to overwrite files without prompting in non-interactive mode
    printf "\033[1;31m[+] Extracting YARA rules...\033[0m\n"
    if ! unzip -q -o "$yara_rules_zip" -d "$tmp_extract_dir"; then
        printf "\033[1;31m[-] Failed to extract YARA rules.\033[0m\n"
        rm -f "$yara_rules_zip"
        rm -rf "$tmp_extract_dir"
        return 1
    fi
    
    # Copy rules to the system - find the extracted directory which contains the rules
    rules_dir=$(find "$tmp_extract_dir" -type d -name "rules-*" | head -n 1)
    if [ -z "$rules_dir" ]; then
        printf "\033[1;31m[-] Failed to find extracted YARA rules directory.\033[0m\n"
        rm -f "$yara_rules_zip"
        rm -rf "$tmp_extract_dir"
        return 1
    fi
    
    printf "\033[1;31m[+] Copying YARA rules to $yara_rules_dir...\033[0m\n"
    cp -rf "$rules_dir"/* "$yara_rules_dir/" || {
        printf "\033[1;31m[-] Failed to copy YARA rules.\033[0m\n"
        rm -f "$yara_rules_zip"
        rm -rf "$tmp_extract_dir"
        return 1
    }
    
    # Set proper ownership and permissions
    printf "\033[1;31m[+] Setting proper permissions on YARA rules...\033[0m\n"
    chown -R root:root "$yara_rules_dir"
    chmod -R 644 "$yara_rules_dir"
    find "$yara_rules_dir" -type d -exec chmod 755 {} \;
    
    # Ensure index.yar exists, or create one
    if [ ! -f "$yara_rules_dir/index.yar" ]; then
        printf "\033[1;31m[+] Creating index.yar file for YARA rules...\033[0m\n"
        # Find all .yar files and include them in index.yar
        find "$yara_rules_dir" -name "*.yar" -not -name "index.yar" | while read -r rule_file; do
            echo "include \"${rule_file#$yara_rules_dir/}\"" >> "$yara_rules_dir/index.yar"
        done
    fi
    
    # Test that YARA works
    printf "\033[1;31m[+] Testing YARA functionality...\033[0m\n"
    if ! yara -r "$yara_rules_dir/index.yar" /tmp >/dev/null 2>&1; then
        printf "\033[1;33m[!] YARA test failed. Rules might need adjustment.\033[0m\n"
        # Create a single test rule if the test failed
        echo 'rule test_rule {strings: $test = "test" condition: $test}' > "$yara_rules_dir/test.yar"
        echo 'include "test.yar"' > "$yara_rules_dir/index.yar"
        if ! yara -r "$yara_rules_dir/index.yar" /tmp >/dev/null 2>&1; then
            printf "\033[1;31m[-] YARA installation appears to have issues.\033[0m\n"
        else
            printf "\033[1;32m[+] Basic YARA test rule works. Original rules may need fixing.\033[0m\n"
        fi
    else
        printf "\033[1;32m[+] YARA rules successfully installed and tested.\033[0m\n"
    fi
    
    # Configure a daily scan for key directories
    printf "\033[1;31m[+] Setting up YARA scanning in crontab...\033[0m\n"
    # Remove any existing YARA cron job to avoid duplicates
    if grep -q "/usr/bin/yara.*index.yar" /etc/crontab; then
        sed -i '/\/usr\/bin\/yara.*index.yar/d' /etc/crontab
    fi
    # Add the standardized YARA cron job
    echo "0 3 * * * root /usr/bin/yara -r /etc/yara/rules/index.yar /home /var/www /tmp >> /var/log/yara_scan.log 2>&1" >> /etc/crontab
    printf "\033[1;32m[+] YARA scan added to crontab.\033[0m\n"
    
    # Create log file with proper permissions
    touch /var/log/yara_scan.log
    chmod 640 /var/log/yara_scan.log
    chown root:adm /var/log/yara_scan.log
    
    # Clean up
    printf "\033[1;31m[+] Cleaning up temporary YARA files...\033[0m\n"
    rm -f "$yara_rules_zip"
    rm -rf "$tmp_extract_dir"
    
    printf "\033[1;32m[+] YARA configuration completed successfully.\033[0m\n"
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

    # Load audit rules and enable auditd
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
    printf "\033[1;31m[+] Setting kernel.randomize_va_space...\033[0m\n"
    echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/hardn.conf
    sysctl --system || { printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"; exit 1; }
    sysctl -w kernel.randomize_va_space=2 || { printf "\033[1;31m[-] Failed to set kernel.randomize_va_space.\033[0m\n"; exit 1; }
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

# Function to print a collective green banner for each step
banner_step() {
    local message="$1"
    local GREEN="\033[0;32m"
    local RESET="\033[0m"
    local width=$(tput cols 2>/dev/null || echo 80)
    local border
    border=$(printf '%*s' "$width" | tr ' ' '=')
    local msg="                          [+] $message"
    local pad_msg=$(( (width - ${#msg}) / 2 ))
    local pad_border=0

    echo -e "\n${GREEN}$(printf "%*s" $pad_border)${border}${RESET}"
    printf "${GREEN}%*s%s${RESET}\n" $pad_msg "" "$msg"
    echo -e "${GREEN}$(printf "%*s" $pad_border)${border}${RESET}\n"
}

main() {
    banner_step "Initializing HARDN setup"
    detect_environment

    banner_step "Enabling automatic updates"
    enable_auto_updates

    banner_step "Checking internet connectivity"
    check_internet

    banner_step "Detecting operating system"
    detect_os

    banner_step "Installing package dependencies"
    install_pkgdeps

    banner_step "Installing security tools"
    install_security_tools
    install_maldet

    banner_step "Enabling Fail2Ban"
    enable_fail2ban

    banner_step "Enabling AppArmor"
    enable_apparmor

    banner_step "Enabling AIDE"
    enable_aide

    banner_step "Enabling RKHunter"
    enable_rkhunter

    banner_step "Configuring YARA"
    enable_yara

    banner_step "Configuring Firejail"
    configure_firejail

    banner_step "Applying password policy"
    stig_password_policy || { echo -e "\033[0;32m[-] Failed to apply password policy.\033[0m"; exit 1; }

    banner_step "Hardening SSH configuration"
    stig_harden_ssh || { echo -e "\033[0;32m[-] Failed to secure ssh.\033[0m"; exit 1; }

    banner_step "Locking inactive accounts"
    stig_lock_inactive_accounts || { echo -e "\033[0;32m[-] Failed to lock inactive accounts.\033[0m"; exit 1; }

    banner_step "Setting login banners"
    stig_login_banners || { echo -e "\033[0;32m[-] Failed to set login banners.\033[0m"; exit 1; }

    banner_step "Configuring kernel parameters"
    stig_kernel_setup || { echo -e "\033[0;32m[-] Failed to configure kernel parameters.\033[0m"; exit 1; }

    banner_step "Securing filesystem permissions"
    stig_secure_filesystem || { echo -e "\033[0;32m[-] Failed to secure filesystem permissions.\033[0m"; exit 1; }

    banner_step "Disabling USB storage"
    stig_disable_usb || { echo -e "\033[0;32m[-] Failed to disable USB storage.\033[0m"; exit 1; }

    banner_step "Disabling core dumps"
    stig_disable_core_dumps || { echo -e "\033[0;32m[-] Failed to disable core dumps.\033[0m"; exit 1; }

    banner_step "Disabling Ctrl+Alt+Del"
    stig_disable_ctrl_alt_del || { echo -e "\033[0;32m[-] Failed to disable Ctrl+Alt+Del.\033[0m"; exit 1; }

    banner_step "Disabling IPv6"
    stig_disable_ipv6 || { echo -e "\033[0;32m[-] Failed to disable IPv6.\033[0m"; exit 1; }

    banner_step "Configuring firewall (UFW)"
    stig_configure_firewall || { echo -e "\033[0;32m[-] Failed to configure firewall.\033[0m"; exit 1; }

    banner_step "Setting randomize VA space"
    stig_set_randomize_va_space || { echo -e "\033[0;32m[-] Failed to set randomize_va_space.\033[0m"; exit 1; }

    banner_step "Updating firmware"
    update_firmware || { echo -e "\033[0;32m[-] Failed to update firmware.\033[0m"; exit 1; }

    banner_step "Configuring GRUB security"
    grub_security

    banner_step "Applying STIG hardening tasks"

    banner_step "Enabling UFW"
    systemctl enable --now ufw

    echo -e "\033[0;32m[+] Running validation script...\033[0m"
    bash "$PACKAGES_SCRIPT"

    if [ $? -ne 0 ]; then
        echo -e "\033[0;32m[-] Validation script encountered errors. Please check the log file.\033[0m"
        exit 1
    fi

    setup_complete

    echo -e "\033[0;32m[+] Validation script completed successfully.\033[0m"
    echo -e "\033[0;32m[+] HARDN setup completed successfully.\033[0m"
}



check_first_run() {
    local marker_file="/etc/hardn/.first_run_complete"
    
  
    if [ ! -d "/etc/hardn" ]; then
        mkdir -p /etc/hardn
    fi
    
 
    if [ ! -f "$marker_file" ]; then
        return 0
    else
        return 1
    fi
}

mark_first_run_complete() {
    local marker_file="/etc/hardn/.first_run_complete"
    touch "$marker_file"
    chmod 600 "$marker_file"
}

# Main execution logic
if [ "$0" = "/usr/bin/hardn-main.sh" ] || [ "$(basename "$0")" = "hardn-main.sh" ]; then
    # If the script is executed as hardn-main.sh, always run the rice process
    main
elif [[ "$1" == "-s" ]]; then
    # If -s flag is provided, run the rice process
    main
    mark_first_run_complete
elif [[ $# -eq 0 ]]; then
    # No arguments provided
    if check_first_run; then
        # First run - show help and run the rice process
        print_menu -h
        sleep 3
        main
        mark_first_run_complete
    else
        # Not the first run - display the help menu
        print_menu -h
    fi
elif [[ "$1" == "-h" || "$1" == "--help" ]]; then
    # Help flag - always show the menu
    print_menu -h
    exit 0
else
    # Process other flags
    flags "$@"
fi

