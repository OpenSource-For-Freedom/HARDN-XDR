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
                systemctl disable --now ufw fail2ban apparmor firejail rkhunter aide suricata psad debsecan needrestart logwatch tripwire
                echo "YARA rules disabled."
                echo "Security tools disabled."
                ;;
            -e-st|--enable-security-tools)
                systemctl enable --now ufw fail2ban apparmor firejail rkhunter aide suricata psad debsecan needrestart logwatch tripwire
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
                echo "  - Suricata (NIDS)"
                echo "  - PSAD (Port Scan Attack Detector)"
                echo "  - Debsecan (Debian Security Analyzer)"
                echo "  - Needrestart (Service Restart Checker)"
                echo "  - Logwatch"
                echo "  - Tripwire"
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
    apt update -y

    # On Ubuntu enable “universe” so additional packages are available
    DEBIAN_FRONTEND=noninteractive apt install -y \
      tripwire logwatch \
      unixodbc-common firejail unattended-upgrades \
      python3-pyqt6 fonts-liberation libpam-pwquality
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

enable_suricata() {
    printf "\033[1;31m[+] Installing and configuring Suricata (NIDS)...\033[0m\n"

    {
        echo 5
        sleep 0.2

        printf "\033[1;31m[+] Installing Suricata package...\033[0m\n"
        apt-get update -y && apt-get install -y suricata || {
            printf "\033[1;31m[-] Failed to install Suricata.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        }
        echo 20
        sleep 0.2

        printf "\033[1;31m[+] Updating Suricata rules...\033[0m\n"
        suricata-update || {
            printf "\033[1;31m[-] Failed to update Suricata rules. Check network or suricata-update output.\033[0m\n"
        }
        echo 40
        sleep 0.2

        # Basic configuration:
        # we'll use 'any' for HOME_NET.
        if [ -f /etc/suricata/suricata.yaml ]; then
            printf "\\033[1;31m[+] Configuring Suricata HOME_NET to 'any' by default...\\033[0m\\n"
            sed -i 's|^HOME_NET: .*|HOME_NET: "any"|' /etc/suricata/suricata.yaml
            echo 60
            sleep 0.2

            printf "\\033[1;31m[+] Skipping manual edit of suricata.yaml for non-interactive setup.\\033[0m\\n"
            echo 70
            sleep 0.2

            # Attempt to get the default interface
            local default_iface
            default_iface=$(ip route | grep '^default' | awk '{print $5}' | head -n1)
            if [ -n "$default_iface" ]; then
                printf "\033[1;31m[+] Setting Suricata to listen on default interface: %s\033[0m\n" "$default_iface"
                sed -i "s/interface: .*/interface: $default_iface/" /etc/suricata/suricata.yaml
            else
                printf "\033[1;33m[!] Could not detect default network interface for Suricata. Please configure manually in /etc/suricata/suricata.yaml.\033[0m\n"
            fi
            echo 80
            sleep 0.2
        else
            printf "\033[1;31m[-] Suricata configuration file /etc/suricata/suricata.yaml not found.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi

        printf "\033[1;31m[+] Enabling and starting Suricata service...\033[0m\n"
        systemctl enable --now suricata || {
            printf "\033[1;31m[-] Failed to enable or start Suricata service.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        }
        echo 100
        sleep 0.2
    } | whiptail --gauge "Installing and configuring Suricata (NIDS)..." 8 60 0

    printf "\033[1;32m[+] Suricata installed and configured.\033[0m\n"
}

enable_psad() {
    printf "\\033[1;31m[+] Installing and configuring PSAD (Port Scan Attack Detector)...\\033[0m\\n"
   

    if [ -f /etc/psad/psad.conf ]; then
        printf "\\033[1;31m[+] Configuring PSAD basic settings...\\033[0m\\n"

        DEFAULT_EMAIL="root@localhost"
        EMAIL_ADDRESSES=$(whiptail --inputbox "Enter email address(es) for PSAD alerts (comma-separated if multiple):" 10 78 "$DEFAULT_EMAIL" --title "PSAD Configuration" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus -ne 0 ] || [ -z "$EMAIL_ADDRESSES" ]; then
            EMAIL_ADDRESSES="$DEFAULT_EMAIL"
            printf "\\033[1;33m[!] No email address entered or cancelled, using default: %s\\033[0m\\n" "$EMAIL_ADDRESSES"
        fi
        sed -i "s|^EMAIL_ADDRESSES[[:space:]]*.*;|EMAIL_ADDRESSES             $EMAIL_ADDRESSES;|" /etc/psad/psad.conf

        DEFAULT_HOSTNAME=$(hostname -f)
        SYSTEM_HOSTNAME=$(whiptail --inputbox "Enter hostname for PSAD reports:" 10 78 "$DEFAULT_HOSTNAME" --title "PSAD Configuration" 3>&1 1>&2 2>&3)
        exitstatus=$?
        if [ $exitstatus -ne 0 ] || [ -z "$SYSTEM_HOSTNAME" ]; then
            SYSTEM_HOSTNAME="$DEFAULT_HOSTNAME"
            printf "\\033[1;33m[!] No hostname entered or cancelled, using default: %s\\033[0m\\n" "$SYSTEM_HOSTNAME"
        fi
        sed -i "s|^HOSTNAME[[:space:]]*.*;|HOSTNAME                  $SYSTEM_HOSTNAME;|" /etc/psad/psad.conf
        
        # Ensure UFW logging is enabled for PSAD to work with UFW
        if command -v ufw >/dev/null 2>&1; then
            if ! ufw status verbose | grep -q "Logging: on"; then
                 printf "\033[1;33m[!] UFW logging is not enabled. Enabling UFW logging for PSAD...\033[0m\n"
                 ufw logging on
            fi
        fi
    else
        printf "\033[1;31m[-] PSAD configuration file /etc/psad/psad.conf not found.\033[0m\n"
        return 1
    fi

    printf "\033[1;31m[+] Updating PSAD signatures...\033[0m\n"
    psad --sig-update || printf "\033[1;33m[!] Failed to update PSAD signatures. Continuing...\033[0m\n"

    printf "\033[1;31m[+] Enabling and starting PSAD service...\033[0m\n"
    systemctl enable --now psad || {
        printf "\033[1;31m[-] Failed to enable or start PSAD service.\033[0m\n"
        return 1
    }
    printf "\033[1;32m[+] PSAD installed and configured.\033[0m\n"
}

enable_debsecan() {
    if ! command -v debsecan >/dev/null 2>&1; then
        printf "\033[1;31m[+] Installing Debsecan (Debian Security Analyzer)...\033[0m\n"
        apt install -y debsecan || {
            printf "\033[1;31m[-] Failed to install debsecan.\033[0m\n"
            return 1
        }
    else
        printf "\033[1;32m[+] Debsecan is already installed.\033[0m\n"
    fi

   
    cat > /etc/systemd/system/debsecan-report.service << 'EOF'
[Unit]
Description=Run debsecan and email report

[Service]
Type=oneshot
ExecStart=/usr/bin/debsecan --format report --suite $(lsb_release -cs) | mail -s "Debsecan Vulnerability Report" root
EOF

  
    cat > /etc/systemd/system/debsecan-report.timer << 'EOF'
[Unit]
Description=Daily Debsecan Vulnerability Scan

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now debsecan-report.timer

    printf "\033[1;32m[+] Debsecan installed and scheduled to run daily. Use 'debsecan' to check for vulnerabilities.\033[0m\n"
}

enable_needrestart() {
    printf "\\033[1;31m[+] Installing Needrestart...\\033[0m\\n"
  
    
    whiptail --title "Needrestart Notice" --msgbox "The 'needrestart' tool will be configured to only list services that require a restart after package updates. This is safer for automated scripts and avoids unexpected service restarts. You can review and restart services manually if needed." 12 70
    if [ ! -d /etc/needrestart/conf.d ]; then
        mkdir -p /etc/needrestart/conf.d
    fi
    echo '$nrconf{restart} = "l";' > /etc/needrestart/conf.d/99-hardn-noninteractive.conf
    
    printf "\\033[1;32m[+] Needrestart installed and configured for non-interactive list mode.\\033[0m\\n"
}

enable_tripwire() {
    printf "\\033[1;31m[+] Configuring Tripwire...\\033[0m\\n"
    if ! command -v tripwire >/dev/null 2>&1; then
        printf "\\033[1;31m[-] Tripwire is not installed. Please ensure it was installed via apt.\\033[0m\\n"
        return 1
    fi

    # Show whiptail gauge for Tripwire configuration
    {
        echo 10
        sleep 0.2

        # Ensure Tripwire policy aligns with system hardening
        local policy_file="/etc/tripwire/twpol.txt"
        local example_policy="/usr/share/doc/tripwire/examples/twpol.txt.example"

        if [ ! -f "$policy_file" ]; then
            if [ -f "$example_policy" ]; then
                cp "$example_policy" "$policy_file"
            else
                printf "\\033[1;31m[-] Example Tripwire policy not found.\\033[0m\\n"
                echo 100
                sleep 0.2
                return 1
            fi
        fi
        echo 30
        sleep 0.2

        # HARDN based policy: ensure critical files are monitored
        grep -q "/etc/shadow" "$policy_file" || echo '(
        rulename = "System Files",
        severity = 100
    )
    {
        /etc/passwd -> $(SEC_CRIT);
        /etc/shadow -> $(SEC_CRIT);
        /etc/group -> $(SEC_CRIT);
        /etc/gshadow -> $(SEC_CRIT);
        /etc/ssh/sshd_config -> $(SEC_CRIT);
        /etc/audit/ -> $(SEC_CRIT);
        /etc/apparmor.d/ -> $(SEC_CRIT);
        /etc/ufw/ -> $(SEC_CRIT);
        /etc/aide/ -> $(SEC_CRIT);
        /etc/yara/ -> $(SEC_CRIT);
        /etc/suricata/ -> $(SEC_CRIT);
        /etc/psad/ -> $(SEC_CRIT);
        /etc/fail2ban/ -> $(SEC_CRIT);
        /etc/logwatch/ -> $(SEC_CRIT);
        /etc/needrestart/ -> $(SEC_CRIT);
        /etc/selinux/ -> $(SEC_CRIT);
        /etc/modprobe.d/ -> $(SEC_CRIT);
        /etc/sysctl.d/ -> $(SEC_CRIT);
        /etc/security/ -> $(SEC_CRIT);
        /boot/ -> $(SEC_CRIT);
        /root/ -> $(SEC_CRIT);
        /var/lib/aide/ -> $(SEC_CRIT);
        /var/lib/rkhunter/ -> $(SEC_CRIT);
        /var/lib/tripwire/ -> $(SEC_CRIT);
        /var/log/ -> $(SEC_CRIT);
    }' >> "$policy_file"
        echo 50
        sleep 0.2

        # Rebuild policy file
        if [ -f /etc/tripwire/site.key ]; then
            twadmin --create-polfile -S /etc/tripwire/site.key "$policy_file"
        fi
        echo 70
        sleep 0.2

        if [ ! -f /etc/tripwire/tw.cfg ] || [ ! -f /etc/tripwire/tw.pol ]; then
            whiptail --title "Tripwire Initialization Required" --msgbox "Tripwire needs to be initialized. This involves setting up site and local passphrases. After this script finishes, please run: \n\nsudo tripwire-setup-keyfiles\nsudo tripwire --init\n\nFollow the on-screen prompts carefully. Refer to Tripwire documentation for details." 18 78
            printf "\\033[1;33m[!] User intervention required for Tripwire initialization.\\033[0m\\n"
        else
            printf "\\033[1;32m[+] Tripwire configuration files found.\\033[0m\\n"
        fi
        echo 85
        sleep 0.2

        # Check if the database exists
        if [ ! -f /var/lib/tripwire/$(hostname -f).twd ]; then
            printf "\\033[1;33m[!] Tripwire database not found. Please run 'sudo tripwire --init' after setup.\\033[0m\\n"
        else
            printf "\\033[1;32m[+] Tripwire database found.\\033[0m\\n"
        fi
        echo 100
        sleep 0.2
    } | whiptail --gauge "Configuring Tripwire..." 8 60 0

    printf "\\033[1;32m[+] Tripwire policy aligned with system hardening. Ensure it is properly initialized and a cron job is set for regular checks.\\033[0m\\n"
}

enable_logwatch() {
    printf "\033[1;31m[+] Configuring Logwatch...\033[0m\n"
    if ! command -v logwatch >/dev/null 2>&1; then
        printf "\033[1;31m[-] Logwatch is not installed. Please ensure it was installed via apt.\033[0m\n"
        return 1
    fi

    mkdir -p /etc/logwatch/conf

    if [ ! -f /etc/logwatch/conf/logwatch.conf ]; then
        printf "\033[1;33m[!] No custom Logwatch configuration found. Creating a basic one...\033[0m\n"
        cat > /etc/logwatch/conf/logwatch.conf <<EOF
LogDir = /var/log
TmpDir = /var/cache/logwatch
MailTo = root
MailFrom = Logwatch
Print = No
Range = yesterday
Detail = Low
Service = All
EOF
        printf "\033[1;32m[+] Basic Logwatch configuration created in /etc/logwatch/conf/logwatch.conf.\033[0m\n"
        printf "\033[1;33m[!] Review and customize it, especially 'MailTo'.\033[0m\n"
    else
        printf "\033[1;32m[+] Custom Logwatch configuration found at /etc/logwatch/conf/logwatch.conf.\033[0m\n"
    fi

    # Ensure TmpDir exists and permissions are correct
    mkdir -p /var/cache/logwatch
    chown root:root /var/cache/logwatch
    chmod 700 /var/cache/logwatch

    # Ensure logwatch cron job exists 
    # (Debian/Ubuntu default: /etc/cron.daily/00logwatch)
    if [ ! -f /etc/cron.daily/00logwatch ]; then
        printf "\033[1;33m[!] Logwatch daily cron job missing. Creating...\033[0m\n"
        cat > /etc/cron.daily/00logwatch <<'EOF'
#!/bin/sh
/usr/sbin/logwatch --output mail
EOF
        chmod 755 /etc/cron.daily/00logwatch
    fi

    printf "\033[1;32m[+] Logwatch setup complete. Reports will be emailed to root daily.\033[0m\n"
}


enable_maldet() {
    printf "[+] Checking for Linux Malware Detect (maldet)...\n"

    # Use whiptail gauge for visual status
    {
        echo 10
        sleep 0.2

        if ! command -v maldet >/dev/null 2>&1; then
            printf "\033[1;31m[-] maldet is not installed. Please install maldet manually.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 40
        sleep 0.2

        printf "\033[1;31m[+] Enabling maldet (if applicable)...\033[0m\n"
        if systemctl list-unit-files | grep -q maldet; then
            sudo systemctl enable --now maldet || {
                printf "\033[1;31m[-] Failed to enable maldet service. Attempting to recreate the service file...\033[0m\n"

                # Recreate the systemd service file
                cat << EOF | sudo tee /etc/systemd/system/maldet.service > /dev/null
[Unit]
Description=Maldet Malware Scanner
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/maldetect/maldet --monitor /path/to/monitor
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

                sudo systemctl daemon-reload
                sudo systemctl enable --now maldet || {
                    printf "\033[1;31m[-] Failed to start maldet service after recreating the service file.\033[0m\n"
                    echo 100
                    sleep 0.2
                    return 1
                }
            }
            printf "\033[1;32m[+] maldet service enabled and running.\033[0m\n"
        else
            printf "\033[1;33m[!] maldet does not provide a systemd service. Skipping enable step.\033[0m\n"
        fi
        echo 70
        sleep 0.2

        printf "\033[1;31m[+] Confirming maldet is functional...\033[0m\n"
        if maldet --version >/dev/null 2>&1; then
            printf "\033[1;32m[+] maldet is installed and operational.\033[0m\n"
        else
            printf "\033[1;31m[-] maldet check failed. Please verify installation.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 100
        sleep 0.2
    } | whiptail --gauge "Checking and enabling Linux Malware Detect (maldet)..." 8 60 0
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
    printf "\033[1;31m[+] Checking AppArmor installation and enabling...\033[0m\n"
    if ! dpkg -l | grep -qw apparmor; then
        printf "\033[1;31m[-] AppArmor is not installed. Please install apparmor, apparmor-utils, and apparmor-profiles first.\033[0m\n"
        return 1
    fi

    systemctl enable --now apparmor || { 
        printf "\033[1;31m[-] Failed to enable or start AppArmor.\033[0m\n"
        exit 1
    }

    aa-complain /etc/apparmor.d/* || {
        printf "\033[1;31m[-] Failed to set profiles to complain mode. Continuing...\033[0m\n"
    }

    printf "\033[1;32m[+] AppArmor enabled. Profiles are in complain mode for testing.\033[0m\n"
    printf "\033[1;33m[!] Review profile behavior before switching to enforce mode.\033[0m\n"
}

enable_aide() {
    printf "\033[1;31m[+] Installing and configuring AIDE...\033[0m\n"

    {
        echo 10
        sleep 0.2

        # Install AIDE if not present
        if ! dpkg -l | grep -qw aide; then
            DEBIAN_FRONTEND=noninteractive apt-get -y install aide aide-common || {
                printf "\033[1;31m[-] Failed to install AIDE.\033[0m\n"
                echo 100
                sleep 0.2
                return 1
            }
        fi

        echo 30
        sleep 0.2

        # Ensure config directory and permissions
        mkdir -p /etc/aide
        chmod 750 /etc/aide
        chown root:root /etc/aide

        # Write a minimal config that skips volatile/user filesystems
        cat > /etc/aide/aide.conf << 'EOF'
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new

# Basic rules
NORMAL = p+i+n+u+g+s+b+m+c+md5+sha1

# Monitor only important system dirs, skip volatile/user data
/etc    HARD
/bin    NORMAL
/sbin   NORMAL
/usr    NORMAL
/lib    NORMAL
/boot   NORMAL
/var    NORMAL
/root   NORMAL
/tmp    NORMAL
/dev    NORMAL
/etc/ssh    NORMAL

!/proc
!/sys
!/dev
!/run
!/run/user         
!/mnt
!/media
!/home
!/home/user*/.cache
EOF

        chmod 640 /etc/aide/aide.conf
        chown root:root /etc/aide/aide.conf

        echo 50
        sleep 0.2

        # Initialize database if not present
        if [ ! -f /var/lib/aide/aide.db ]; then
            aide --init --config=/etc/aide/aide.conf || {
                printf "\033[1;31m[-] Failed to initialize AIDE database.\033[0m\n"
                echo 100
                sleep 0.2
                return 1
            }
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
            chmod 600 /var/lib/aide/aide.db
        fi

        echo 70
        sleep 0.2

        # Setup systemd timer for daily check
        cat > /etc/systemd/system/aide-check.service << 'EOF'
[Unit]
Description=AIDE Check Service
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/bin/aide --check -c /etc/aide/aide.conf
EOF

        cat > /etc/systemd/system/aide-check.timer << 'EOF'
[Unit]
Description=Daily AIDE Check Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

        chmod 644 /etc/systemd/system/aide-check.*
        systemctl daemon-reload
        systemctl enable --now aide-check.timer

        echo 100
        sleep 0.2
    } | whiptail --gauge "Installing and configuring AIDE..." 8 60 0

    printf "\033[1;32m[+] AIDE installed, enabled, and basic config applied.\033[0m\n"
}

enable_rkhunter(){
    printf "\033[1;31m[+] Checking for rkhunter installation...\033[0m\n" | tee -a HARDN_alerts.txt
    whiptail --title "rkhunter Notice" --msgbox "The 'rkhunter' tool will be configured to run daily and check for rootkits and malware. You can review the logs in /var/log/rkhunter.log." 12 70

    if ! command -v rkhunter >/dev/null 2>&1; then
        printf "\033[1;31m[-] rkhunter is not installed. Please install rkhunter manually.\033[0m\n" | tee -a HARDN_alerts.txt
        return 1
    fi

    sudo chown -R root:root /var/lib/rkhunter
    sudo chmod -R 755 /var/lib/rkhunter

    sed -i 's|^#*MIRRORS_MODE=.*|MIRRORS_MODE=1|' /etc/rkhunter.conf
    sed -i 's|^#*UPDATE_MIRRORS=.*|UPDATE_MIRRORS=1|' /etc/rkhunter.conf
    sed -i 's|^WEB_CMD=.*|WEB_CMD="/bin/true"|' /etc/rkhunter.conf

    {
        echo 5
        sleep 0.2
        printf "\033[1;31m[+] Updating rkhunter signatures...\033[0m\n" | tee -a HARDN_alerts.txt
        if ! rkhunter --update --nocolors --skip-keypress; then
            printf "\033[1;33m[!] rkhunter update failed. Check your network connection or proxy settings. Continuing...\033[0m\n" | tee -a HARDN_alerts.txt
        fi
        echo 25
        sleep 0.2

        printf "\033[1;31m[+] Updating rkhunter property database...\033[0m\n" | tee -a HARDN_alerts.txt
        rkhunter --propupd --nocolors --skip-keypress || printf "\033[1;33m[!] Failed to update rkhunter properties. Continuing...\033[0m\n" | tee -a HARDN_alerts.txt
        echo 45
        sleep 0.2

        printf "\033[1;31m[+] Running rkhunter scan...\033[0m\n" | tee -a HARDN_alerts.txt
        TMP_SCAN_LOG=$(mktemp)
        (rkhunter --check --sk --nocolors --skip-keypress | tee "$TMP_SCAN_LOG") &
        SCAN_PID=$!
        PROGRESS=45
        while kill -0 $SCAN_PID 2>/dev/null; do
            PROGRESS=$((PROGRESS+5))
            [ $PROGRESS -gt 90 ] && PROGRESS=90
            echo $PROGRESS
            sleep 1
        done
        wait $SCAN_PID
        echo 95
        sleep 0.2

        printf "\033[1;31m[+] Cleaning up temporary files...\033[0m\n" | tee -a HARDN_alerts.txt
        rm -f "$TMP_SCAN_LOG"
        echo 100
        sleep 0.2
    } | whiptail --gauge "rkhunter: update, property db, scan, cleanup..." 8 60 0

    printf "\033[1;32m[+] rkhunter installed, updated, and scan complete.\033[0m\n" | tee -a HARDN_alerts.txt
}

enable_yara() {
    printf "\033[1;31m[+] Configuring YARA rules...\033[0m\n"
    whiptail --title "YARA Notice" --msgbox "The 'YARA' tool will be configured to scan for malware and suspicious files. You can review the logs in /var/log/yara_scan.log." 12 70

    {
        echo 5
        sleep 0.2

        if ! command -v yara >/dev/null 2>&1; then
            printf "\033[1;31m[+] Configuring YARA...\033[0m\n"
            DEBIAN_FRONTEND=noninteractive apt-get -y install yara || {
                printf "\033[1;31m[-] Failed to install YARA.\033[0m\n"
                echo 100
                sleep 0.2
                return 1
            }
        fi
        echo 15
        sleep 0.2

        yara_rules_dir="/etc/yara/rules"
        mkdir -p "$yara_rules_dir"
        echo 20
        sleep 0.2

        printf "\033[1;31m[+] Downloading YARA rules...\033[0m\n"
        yara_rules_zip="/tmp/yara-rules.zip"
        if ! wget -q "https://github.com/Yara-Rules/rules/archive/refs/heads/master.zip" -O "$yara_rules_zip"; then
            printf "\033[1;31m[-] Failed to download YARA rules.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 30
        sleep 0.2

        tmp_extract_dir="/tmp/yara-rules-extract"
        mkdir -p "$tmp_extract_dir"

        printf "\033[1;31m[+] Extracting YARA rules...\033[0m\n"
        if ! unzip -q -o "$yara_rules_zip" -d "$tmp_extract_dir"; then
            printf "\033[1;31m[-] Failed to extract YARA rules.\033[0m\n"
            rm -f "$yara_rules_zip"
            rm -rf "$tmp_extract_dir"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 40
        sleep 0.2

        rules_dir=$(find "$tmp_extract_dir" -type d -name "rules-*" | head -n 1)
        if [ -z "$rules_dir" ]; then
            printf "\033[1;31m[-] Failed to find extracted YARA rules directory.\033[0m\n"
            rm -f "$yara_rules_zip"
            rm -rf "$tmp_extract_dir"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 50
        sleep 0.2

        printf "\033[1;31m[+] Copying YARA rules to $yara_rules_dir...\033[0m\n"
        cp -rf "$rules_dir"/* "$yara_rules_dir/" || {
            printf "\033[1;31m[-] Failed to copy YARA rules.\033[0m\n"
            rm -f "$yara_rules_zip"
            rm -rf "$tmp_extract_dir"
            echo 100
            sleep 0.2
            return 1
        }
        echo 60
        sleep 0.2

        printf "\033[1;31m[+] Setting proper permissions on YARA rules...\033[0m\n"
        chown -R root:root "$yara_rules_dir"
        chmod -R 644 "$yara_rules_dir"
        find "$yara_rules_dir" -type d -exec chmod 755 {} \;
        echo 65
        sleep 0.2

        if [ ! -f "$yara_rules_dir/index.yar" ]; then
            printf "\033[1;31m[+] Creating index.yar file for YARA rules...\033[0m\n"
            find "$yara_rules_dir" -name "*.yar" -not -name "index.yar" | while read -r rule_file; do
                echo "include \"${rule_file#$yara_rules_dir/}\"" >> "$yara_rules_dir/index.yar"
            done
        fi
        echo 70
        sleep 0.2

        printf "\033[1;31m[+] Testing YARA functionality...\033[0m\n"
        if ! yara -r "$yara_rules_dir/index.yar" /tmp >/dev/null 2>&1; then
            printf "\033[1;33m[!] YARA test failed. Rules might need adjustment.\033[0m\n"
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
        echo 80
        sleep 0.2

        printf "\033[1;31m[+] Setting up YARA scanning in crontab...\033[0m\n"
        if grep -q "/usr/bin/yara.*index.yar" /etc/crontab; then
            sed -i '/\/usr\/bin\/yara.*index.yar/d' /etc/crontab
        fi

        touch /var/log/yara_scan.log
        chmod 640 /var/log/yara_scan.log
        chown root:adm /var/log/yara_scan.log
        echo 90
        sleep 0.2

        printf "\033[1;31m[+] Cleaning up temporary YARA files...\033[0m\n"
        rm -f "$yara_rules_zip"
        rm -rf "$tmp_extract_dir"
        echo 100
        sleep 0.2
    } | whiptail --gauge "Installing and configuring YARA..." 8 60 0

    printf "\033[1;32m[+] YARA configuration completed successfully.\033[0m\n"
}

config_selinux() {
    {
        echo 10
        sleep 0.2

        printf "\033[1;31m[+] Installing and configuring SELinux...\033[0m\n"

        # If AppArmor is in enforce mode, set all profiles to complain (passive) mode
        if command -v aa-status >/dev/null 2>&1; then
            if aa-status | grep -q "profiles are in enforce mode"; then
                printf "\033[1;33m[!] AppArmor is in enforce mode. Switching all profiles to complain mode (passive)...\033[0m\n"
                aa-complain /etc/apparmor.d/* || printf "\033[1;31m[-] Failed to set AppArmor profiles to complain mode.\033[0m\n"
            fi
        fi
        echo 30
        sleep 0.2

        setenforce 1 2>/dev/null || whiptail --msgbox "Could not set SELinux to enforcing mode immediately" 8 60
        echo 50
        sleep 0.2

        if [ -f /etc/selinux/config ]; then
            sed -i 's/SELINUX=disabled/SELINUX=enforcing/' /etc/selinux/config
            sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
            echo 80
            sleep 0.2
            whiptail --infobox "SELinux configured to enforcing mode at boot" 7 60
        else
            echo 80
            sleep 0.2
            whiptail --msgbox "SELinux config file not found" 8 60
        fi

        echo 100
        sleep 0.2
    } | whiptail --gauge "Installing and configuring SELinux..." 8 60 0

    whiptail --infobox "SELinux installation and configuration completed" 7 60
}



configure_firejail() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Configuring Firejail for Firefox, Chrome, Brave, and Tor Browser...\033[0m\n"

        if ! command -v firejail > /dev/null 2>&1; then
            printf "\033[1;31m[-] Firejail is not installed. Please install it first.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 20
        sleep 0.2

        if command -v firefox > /dev/null 2>&1; then
            printf "\033[1;31m[+] Setting up Firejail for Firefox...\033[0m\n"
            ln -sf /usr/bin/firejail /usr/local/bin/firefox
        else
            printf "\033[1;31m[-] Firefox is not installed. Skipping Firejail setup for Firefox.\033[0m\n"
        fi
        echo 40
        sleep 0.2

        if command -v google-chrome > /dev/null 2>&1; then
            printf "\033[1;31m[+] Setting up Firejail for Google Chrome...\033[0m\n"
            ln -sf /usr/bin/firejail /usr/local/bin/google-chrome
        else
            printf "\033[1;31m[-] Google Chrome is not installed. Skipping Firejail setup for Chrome.\033[0m\n"
        fi
        echo 60
        sleep 0.2

        if command -v brave-browser > /dev/null 2>&1; then
            printf "\033[1;31m[+] Setting up Firejail for Brave Browser...\033[0m\n"
            ln -sf /usr/bin/firejail /usr/local/bin/brave-browser
        else
            printf "\033[1;31m[-] Brave Browser is not installed. Skipping Firejail setup for Brave.\033[0m\n"
        fi
        echo 80
        sleep 0.2

        if command -v torbrowser-launcher > /dev/null 2>&1; then
            printf "\033[1;31m[+] Setting up Firejail for Tor Browser...\033[0m\n"
            ln -sf /usr/bin/firejail /usr/local/bin/torbrowser-launcher
        else
            printf "\033[1;31m[-] Tor Browser is not installed. Skipping Firejail setup for Tor Browser.\033[0m\n"
        fi
        echo 100
        sleep 0.2

        printf "\033[1;31m[+] Firejail configuration completed.\033[0m\n"
    } | whiptail --gauge "Configuring Firejail for browsers..." 8 60 0
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
   
    center_issue_text() {
        local text="$1"
        local width=80
        local text_len=${#text}
        if [ "$text_len" -ge "$width" ]; then
            echo "$text"
        else
            local pad=$(( (width - text_len) / 2 ))
            printf "%*s%s\n" "$pad" "" "$text"
        fi
    }

    {
        echo -e "\033[1;32m"
        center_issue_text "════════════════════════════"
        center_issue_text "   _____   _____    _____   "
        center_issue_text "  / ____| |_   _|  / ____|  "
        center_issue_text " | (___     | |   | |  __   "
        center_issue_text "  \___ \  | |   | |  | |  "
        center_issue_text "  ____) |  _| |_  | |__| |  "
        center_issue_text " |_____/  |_____|  \____|  "
        center_issue_text "                            "
        center_issue_text "════════════════════════════"
        echo -e "\033[0m"
        center_issue_text "You are accessing a SECURITY INTERNATIONAL GROUP (SIG) Information System (IS) that is provided for SIG-authorized use only."
        center_issue_text "By using this IS (which includes any device attached to this IS), you consent to the following conditions:"
        center_issue_text "- The USG routinely intercepts and monitors communications on this IS for purposes including, but not limited to,"
        center_issue_text "  penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE),"
        center_issue_text "  and counterintelligence (CI) investigations."
        center_issue_text "- At any time, the USG may inspect and seize data stored on this IS."
        center_issue_text "- Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search,"
        center_issue_text "  and may be disclosed or used for any USG-authorized purpose."
        center_issue_text "- This IS includes security measures (e.g., authentication and access controls) to protect USG interests--not for your personal"
        center_issue_text "  benefit or privacy."
        center_issue_text "- Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of"
        center_issue_text "  the content of privileged communications, or work product, related to personal representation or services by attorneys,"
        center_issue_text "  psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential."
        center_issue_text "  See User Agreement for details."
    } > /etc/issue

    chmod 644 /etc/issue /etc/issue.net
}

stig_secure_filesystem() {
    {
        echo 5
        sleep 0.2
        printf "\033[1;31m[+] Securing filesystem permissions...\033[0m\n"

        chown root:root /etc/passwd /etc/group /etc/gshadow
        chmod 644 /etc/passwd
        chmod 644 /etc/group
        chown root:shadow /etc/shadow /etc/gshadow
        chmod 640 /etc/shadow /etc/gshadow
        echo 30
        sleep 0.2

        printf "\033[1;31m[+] Configuring audit rules...\033[0m\n"
        apt install -y auditd audispd-plugins
        tee /etc/audit/rules.d/stig.rules > /dev/null <<EOF
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
EOF
        echo 50
        sleep 0.2

        chown root:root /etc/audit/rules.d/*.rules
        chmod 600 /etc/audit/rules.d/*.rules
        mkdir -p /var/log/audit
        chown -R root:root /var/log/audit
        chmod 700 /var/log/audit
        echo 70
        sleep 0.2

        augenrules --load
        systemctl enable auditd || { printf "\033[1;31m[-] Failed to enable auditd.\033[0m\n"; echo 100; sleep 0.2; return 1; }
        systemctl start auditd || { printf "\033[1;31m[-] Failed to start auditd.\033[0m\n"; echo 100; sleep 0.2; return 1; }
        systemctl restart auditd || { printf "\033[1;31m[-] Failed to restart auditd.\033[0m\n"; echo 100; sleep 0.2; return 1; }
        auditctl -e 1 || printf "\033[1;31m[-] Failed to enable auditd.\033[0m\n"
        echo 100
        sleep 0.2
    } | whiptail --gauge "Securing filesystem permissions and configuring auditd..." 8 60 0

    printf "\033[1;32m[+] Filesystem permissions and auditd configuration complete.\033[0m\n"
}




stig_harden_ssh() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Hardening SSH configuration...\033[0m\n"

        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        echo 30
        sleep 0.2

        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        echo 45
        sleep 0.2

        sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
        echo 60
        sleep 0.2

        sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
        echo 70
        sleep 0.2

        # Remove existing AllowUsers, Ciphers, MACs lines to avoid duplicates
        sed -i '/^AllowUsers /d' /etc/ssh/sshd_config
        sed -i '/^Ciphers /d' /etc/ssh/sshd_config
        sed -i '/^MACs /d' /etc/ssh/sshd_config

        echo "AllowUsers your_user" >> /etc/ssh/sshd_config
        echo "Ciphers aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config
        echo "MACs hmac-sha2-512,hmac-sha2-256" >> /etc/ssh/sshd_config
        echo 85
        sleep 0.2

        systemctl restart sshd || {
            printf "\033[1;31m[-] Failed to restart SSH service. Check your configuration.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        }
        echo 100
        sleep 0.2
    } | whiptail --gauge "Hardening SSH configuration..." 8 60 0

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
    {
        echo 10
        sleep 0.2

        if [ -d /sys/firmware/efi ]; then
            echo "[*] UEFI system detected. Skipping GRUB configuration..."
            echo 100
            sleep 0.2
            return 0
        fi
        echo 20
        sleep 0.2

        if grep -q 'hypervisor' /proc/cpuinfo; then
            echo "[*] Virtual machine detected. Proceeding with GRUB configuration..."
        else
            echo "[+] No virtual machine detected. Proceeding with GRUB configuration..."
        fi
        echo 30
        sleep 0.2

        echo "[+] Setting GRUB password..."
        grub-mkpasswd-pbkdf2 | tee /etc/grub.d/40_custom_password
        echo 40
        sleep 0.2

        # Detect GRUB 
        if [ -f /boot/grub/grub.cfg ]; then
            GRUB_CFG="/boot/grub/grub.cfg"
            GRUB_DIR="/boot/grub"
        elif [ -f /boot/grub2/grub.cfg ]; then
            GRUB_CFG="/boot/grub2/grub.cfg"
            GRUB_DIR="/boot/grub2"
        else
            echo "[-] GRUB config not found. Please verify GRUB installation."
            echo 100
            sleep 0.2
            return 1
        fi
        echo 50
        sleep 0.2

        echo "[+] Configuring GRUB security settings..."
        BACKUP_CFG="$GRUB_CFG.bak.$(date +%Y%m%d%H%M%S)"
        cp "$GRUB_CFG" "$BACKUP_CFG"
        echo "[+] Backup created at $BACKUP_CFG"
        echo 60
        sleep 0.2

        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash security=1 /' /etc/default/grub

        if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
            sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
        else
            echo "GRUB_TIMEOUT=5" >> /etc/default/grub
        fi
        echo 70
        sleep 0.2

        # Update GRUB 
        if command -v update-grub >/dev/null 2>&1; then
            update-grub || echo "[-] Failed to update GRUB using update-grub."
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            grub2-mkconfig -o "$GRUB_CFG" || echo "[-] Failed to update GRUB using grub2-mkconfig."
        else
            echo "[-] Neither update-grub nor grub2-mkconfig found. Please install GRUB tools."
            echo 100
            sleep 0.2
            return 1
        fi
        echo 90
        sleep 0.2

        chmod 600 "$GRUB_CFG"
        chown root:root "$GRUB_CFG"
        echo "[+] GRUB configuration secured: $GRUB_CFG"
        echo 100
        sleep 0.2
    } | whiptail --gauge "Configuring GRUB security..." 8 60 0
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
    # Disable IPv6 at runtime and persistently
    if sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q ' = 0'; then
        echo "Disabling IPv6..."
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
    else
        echo "IPv6 is already disabled."
    fi
}

stig_configure_firewall() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Configuring UFW...\033[0m\n"

        if ! command -v ufw > /dev/null 2>&1; then
            printf "\033[1;31m[-] UFW is not installed. Installing UFW...\033[0m\n"
            apt install -y ufw || { printf "\033[1;31m[-] Failed to install UFW.\033[0m\n"; echo 100; sleep 0.2; return 1; }
        fi
        echo 25
        sleep 0.2

        printf "\033[1;31m[+] Resetting UFW to default settings...\033[0m\n"
        ufw --force reset || { printf "\033[1;31m[-] Failed to reset UFW.\033[0m\n"; echo 100; sleep 0.2; return 1; }
        echo 40
        sleep 0.2

        printf "\033[1;31m[+] Setting UFW default policies...\033[0m\n"
        ufw default deny incoming
        ufw default allow outgoing
        echo 55
        sleep 0.2

        printf "\033[1;31m[+] Allowing outbound HTTP and HTTPS traffic...\033[0m\n"
        ufw allow out 80/tcp
        ufw allow out 443/tcp
        echo 65
        sleep 0.2

        printf "\033[1;31m[+] Allowing traffic for Debian updates and app dependencies...\033[0m\n"
        ufw allow out 53/udp  # DNS resolution
        ufw allow out 53/tcp  # DNS resolution
        ufw allow out 123/udp # NTP (time synchronization)
        ufw allow out to archive.debian.org port 80 proto tcp
        ufw allow out to security.debian.org port 443 proto tcp
        echo 80
        sleep 0.2

        printf "\033[1;31m[+] Enabling and reloading UFW...\033[0m\n"
        echo "y" | ufw enable || { printf "\033[1;31m[-] Failed to enable UFW.\033[0m\n"; echo 100; sleep 0.2; return 1; }
        ufw reload || { printf "\033[1;31m[-] Failed to reload UFW.\033[0m\n"; echo 100; sleep 0.2; return 1; }
        echo 100
        sleep 0.2
    } | whiptail --gauge "Configuring UFW firewall..." 8 60 0

    printf "\033[1;32m[+] UFW configuration completed successfully.\033[0m\n"
}

stig_set_randomize_va_space() {
    printf "\033[1;31m[+] Setting kernel.randomize_va_space...\033[0m\n"
    echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/hardn.conf
    sysctl --system || { printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"; exit 1; }
    sysctl -w kernel.randomize_va_space=2 || { printf "\033[1;31m[-] Failed to set kernel.randomize_va_space.\033[0m\n"; exit 1; }
}

update_firmware() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Checking for firmware updates...\033[0m\n"
        apt install -y fwupd
        echo 30
        sleep 0.2

        fwupdmgr refresh || printf "\033[1;31m[-] Failed to refresh firmware metadata.\033[0m\n"
        echo 50
        sleep 0.2

        fwupdmgr get-updates || printf "\033[1;31m[-] Failed to check for firmware updates.\033[0m\n"
        echo 70
        sleep 0.2

        if fwupdmgr update; then
            printf "\033[1;32m[+] Firmware updates applied successfully.\033[0m\n"
        else
            printf "\033[1;33m[+] No firmware updates available or update process skipped.\033[0m\n"
        fi
        echo 90
        sleep 0.2

        apt update -y
        echo 100
        sleep 0.2
    } | whiptail --gauge "Checking and applying firmware updates..." 8 60 0
}

setup_complete() {
    echo "======================================================="
    echo "             [+] HARDN - Setup Complete                "
    echo "             calling Validation Script                 "
    echo "                                                       "
    echo "======================================================="

    sleep 2

    printf "\033[1;31m[+] Looking for hardn-packages.sh at: %s\033[0m\n" "$PACKAGES_SCRIPT"
    if [ -f "$PACKAGES_SCRIPT" ]; then
        printf "\033[1;31m[+] Setting executable permissions for hardn-packages.sh...\033[0m\n"
        chmod +x "$PACKAGES_SCRIPT"

        printf "\033[1;31m[+] Setting sudo permissions for hardn-packages.sh...\033[0m\n"
        echo "root ALL=(ALL) NOPASSWD: $PACKAGES_SCRIPT" \
          | sudo tee /etc/sudoers.d/hardn-packages-sh > /dev/null
        sudo chmod 440 /etc/sudoers.d/hardn-packages-sh

        # Use whiptail gauge to show progress while running the script
        (
            echo 10
            sleep 0.5
            echo 30
            sleep 0.5
            echo 50
            sudo "$PACKAGES_SCRIPT" && status=0 || status=1
            echo 90
            sleep 0.5
            echo 100
            sleep 0.2
            exit $status
        ) | whiptail --gauge "Running hardn-packages.sh validation script..." 8 60 0

        if [ "${status:-0}" -eq 0 ]; then
            whiptail --title "HARDN Setup" --msgbox "Validation script completed successfully!" 8 60
        else
            whiptail --title "HARDN Setup" --msgbox "Validation script encountered errors. Please check the log file." 8 60
        fi
    else
        printf "\033[1;31m[-] hardn-packages.sh not found at: %s. Skipping...\033[0m\n" "$PACKAGES_SCRIPT"
        whiptail --title "HARDN Setup" --msgbox "hardn-packages.sh not found at: $PACKAGES_SCRIPT. Skipping validation." 8 60
    fi
}

detect_environment() {
    printf "\033[1;31m[+] Detecting system environment...\033[0m\n"

    if [ -d /sys/firmware/efi ]; then
        echo "[*] UEFI system detected. Configuring for UEFI..."
     
    else
        echo "[*] Legacy BIOS system detected. Configuring for BIOS..."
  
    fi

    if grep -q 'hypervisor' /proc/cpuinfo; then
        echo "[*] Virtual machine detected. Applying VM-specific optimizations..."
        
    else
        echo "[*] Bare metal system detected. Applying bare metal optimizations..."
      
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

    banner_step "Configuring LMD"
    enable_maldet

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

    banner_step "Configuring Suricata (NIDS)"
    enable_suricata

    banner_step "Configuring PSAD (Port Scan Detector)"
    enable_psad

    banner_step "Installing Debsecan (Vulnerability Scanner)"
    enable_debsecan

    banner_step "Installing Needrestart (Service Restart Checker)"
    enable_needrestart

    banner_step "Configuring OSSEC HIDS"
    enable_ossec

    banner_step "Configuring Tripwire"
    enable_tripwire

    banner_step "Configuring Logwatch"
    enable_logwatch

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



# Add a whiptail interaction to confirm cron jobs and alerting setup
confirm_cron_alerting_setup() {
    whiptail --title "Cron Jobs and Alerting Setup" \
        --yesno "Do you want to proceed with setting up cron jobs and alerting (e.g., AIDE, Fail2Ban)?" 10 60

    if [ $? -eq 0 ]; then
        printf "\033[1;32m[+] User confirmed cron jobs and alerting setup. Proceeding...\033[0m\n"
    else
        printf "\033[1;31m[-] User declined cron jobs and alerting setup. Skipping...\033[0m\n"
        return 1
    fi
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

