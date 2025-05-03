#!/bin/sh
set -e # Exit on errors
LOG_FILE="/dev/null"


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
                     
                                               V A L I D A T I O N
                                                     
                                                    v 1.1.2
                                                                       
                                                                     
                                       
                                                              
EOF
    printf "${RESET}"
}

print_ascii_banner

sleep 7

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
PACKAGES_SCRIPT="$SCRIPT_DIR/fips.sh"



if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Re-running with sudo..."
    if command -v sudo >/dev/null; then
        exec sudo "$0" "$@"
    else
        echo "Error: sudo is not installed. Please run this script as root."
        exit 1
    fi
fi


FIX_MODE=false

initialize_log() {
    echo "========================================" > "$LOG_FILE"
    echo " HARDN - Packages Validation Log" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    echo "[+] Log initialized at $(date)" >> "$LOG_FILE"
}

fix_if_needed() {
    local check_cmd="$1"
    local fix_cmd="$2"
    local success_msg="$3"
    local failure_msg="$4"

    if eval "$check_cmd"; then
        echo "[+] $success_msg" | tee -a "$LOG_FILE"
    else
        echo "[-] $failure_msg" | tee -a "$LOG_FILE"
        if $FIX_MODE; then
            echo "[*] Attempting to fix..." | tee -a "$LOG_FILE"
            if eval "$fix_cmd"; then
                # Re-check after fix
                if eval "$check_cmd"; then
                    echo "[+] Fixed: $success_msg" | tee -a "$LOG_FILE"
                else
                    echo "[-] Failed to fix: $failure_msg" | tee -a "$LOG_FILE"
                fi
            else
                echo "[-] Failed to fix: $failure_msg" | tee -a "$LOG_FILE"
            fi
        fi
    fi
}

ensure_aide_initialized() {
    if [ ! -f /var/lib/aide/aide.db ]; then
        echo "[*] Initializing AIDE database..."
        sudo aideinit
        sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
        sudo chmod 600 /var/lib/aide/aide.db
        echo "[+] AIDE database initialized."
    fi
}

validate_packages() {
    echo "[+] Validating package configurations..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "! ping -c 1 google.com >/dev/null 2>&1" \
        "sudo systemctl restart networking && sudo dhclient" \
        "Internet connectivity is restored" \
        "Internet connectivity is not available"

    echo "[*] Checking internet connectivity..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "sudo ufw status | grep -q 'Status: active'" \
        "sudo apt-get install -y ufw && sudo ufw enable" \
        "UFW is active" \
        "UFW is not active"

    echo "[*] Checking UFW status..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "sudo systemctl is-active --quiet fail2ban" \
        "sudo systemctl start fail2ban" \
        "Fail2Ban is active" \
        "Fail2Ban not running"

    echo "[*] Checking Fail2Ban status..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "command -v aa-status >/dev/null && sudo systemctl is-active --quiet apparmor" \
        "sudo systemctl start apparmor" \
        "AppArmor is active" \
        "AppArmor not active"

    echo "[*] Checking AppArmor status..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "command -v firejail >/dev/null" \
        "sudo apt-get install -y firejail" \
        "Firejail is installed" \
        "Firejail missing"

    echo "[*] Checking Firejail installation..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "command -v chkrootkit >/dev/null" \
        "sudo apt-get install -y chkrootkit" \
        "chkrootkit installed" \
        "chkrootkit missing"

    echo "[*] Checking chkrootkit installation..." | tee -a "$LOG_FILE"

    # Improved maldet block: checks all locations and installs from GitHub if missing
    fix_if_needed \
        "[ -x /usr/local/maldetect/maldet ] || [ -x /usr/local/bin/maldet ] || command -v maldet >/dev/null" \
        "( [ ! -d /tmp/linux-malware-detect ] && cd /tmp && git clone https://github.com/rfxn/linux-malware-detect.git ) && cd /tmp/linux-malware-detect && sudo ./install.sh && sudo ln -sf /usr/local/maldetect/maldet /usr/local/bin/maldet && ( [ -x /usr/local/maldetect/maldet ] || [ -x /usr/local/bin/maldet ] || command -v maldet >/dev/null )" \
        "Linux Malware Detect (maldet) is installed" \
        "Linux Malware Detect (maldet) is not installed"

    echo "[*] Checking maldet installation..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "command -v rkhunter >/dev/null" \
        "sudo apt-get install -y rkhunter" \
        "rkhunter installed" \
        "rkhunter missing"

    echo "[*] Checking rkhunter installation..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "sudo systemctl is-active --quiet auditd" \
        "sudo systemctl start auditd" \
        "auditd is running" \
        "auditd not running"

    echo "[*] Checking auditd status..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "command -v aide >/dev/null" \
        "sudo apt-get install -y aide" \
        "AIDE is installed" \
        "AIDE not installed"

    echo "[*] Checking AIDE installation..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "sudo aide --check >/dev/null 2>&1" \
        "sudo aideinit && sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db" \
        "AIDE database check passed" \
        "AIDE database check failed"

    echo "[*] Performing AIDE database check..." | tee -a "$LOG_FILE"
}

validate_stig_hardening() {
    echo "[+] Validating STIG compliance..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "grep -q 'minlen = 14' /etc/security/pwquality.conf" \
        "sudo sed -i 's/^#\\? *minlen.*/minlen = 14/' /etc/security/pwquality.conf" \
        "Password policy minlen is set" \
        "Password policy minlen missing or wrong"

    fix_if_needed \
        "stat -c '%a' /etc/shadow | grep -q 000" \
        "sudo chmod 000 /etc/shadow" \
        "/etc/shadow permissions are 000" \
        "Incorrect /etc/shadow permissions"

    fix_if_needed \
        "grep -q 'net.ipv6.conf.all.disable_ipv6 = 1' /etc/sysctl.d/99-sysctl.conf" \
        "echo 'net.ipv6.conf.all.disable_ipv6 = 1' | sudo tee -a /etc/sysctl.d/99-sysctl.conf && sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1" \
        "IPv6 is disabled" \
        "IPv6 not disabled"

    fix_if_needed \
        "grep -q 'fs.suid_dumpable = 0' /etc/sysctl.d/99-coredump.conf" \
        "echo 'fs.suid_dumpable = 0' | sudo tee /etc/sysctl.d/99-coredump.conf && sudo sysctl -w fs.suid_dumpable=0" \
        "Core dumps are disabled" \
        "Core dumps enabled"

    fix_if_needed \
        "grep -q 'install usb-storage /bin/false' /etc/modprobe.d/hardn-blacklist.conf" \
        "echo 'install usb-storage /bin/false' | sudo tee /etc/modprobe.d/hardn-blacklist.conf" \
        "USB storage blocked via modprobe" \
        "USB storage not blocked"

    fix_if_needed \
        "grep -q 'kernel.randomize_va_space = 2' /etc/sysctl.d/hardn.conf" \
        "echo 'kernel.randomize_va_space = 2' | sudo tee -a /etc/sysctl.d/hardn.conf && sudo sysctl -w kernel.randomize_va_space=2" \
        "randomize_va_space = 2 present" \
        "Missing randomize_va_space setting"

    fix_if_needed \
        "grep -q '[SIG]}' /etc/issue" \
        "echo 'You are accessing a SIG Information System (IS)...' | sudo tee /etc/issue" \
        "Login banner exists" \
        "Missing login banner /etc/issue"

    fix_if_needed \
        "sudo systemctl status ctrl-alt-del.target | grep -q 'Masked'" \
        "sudo systemctl mask ctrl-alt-del.target" \
        "Ctrl+Alt+Del is disabled" \
        "Ctrl+Alt+Del is still active"
}

validate_boot_services() {
    echo "[*] Validating boot services..." | tee -a "$LOG_FILE"

    # Set fail2ban to start at boot
    echo "[*] Checking if Fail2Ban is enabled at boot..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "! sudo systemctl is-enabled fail2ban | grep -q 'enabled'" \
        "sudo systemctl enable fail2ban" \
        "Fail2Ban is enabled at boot" \
        "Fail2Ban is disabled at boot"

    # Set auditd to start at boot
    echo "[*] Checking if auditd is enabled at boot..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "! sudo systemctl is-enabled auditd | grep -q 'enabled'" \
        "sudo systemctl enable auditd" \
        "auditd is enabled at boot" \
        "auditd is disabled at boot"

    # Set apparmor to start at boot
    echo "[*] Checking if AppArmor is enabled at boot..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "! sudo systemctl is-enabled apparmor | grep -q 'enabled'" \
        "sudo systemctl enable apparmor" \
        "AppArmor is enabled at boot" \
        "AppArmor is disabled at boot"

    # Set sshd to start at boot
    echo "[*] Checking if sshd is enabled at boot..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "! sudo systemctl is-enabled sshd | grep -q 'enabled'" \
        "sudo systemctl enable sshd" \
        "sshd is enabled at boot" \
        "sshd is disabled at boot"
}

cron_clean() {
    echo "========================================" | sudo tee -a /etc/crontab
    echo "           CRON SETUP - CLEAN           " | sudo tee -a /etc/crontab
    echo "========================================" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get update && /usr/bin/apt-get upgrade -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get dist-upgrade -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get autoremove -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get autoclean -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get check" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get clean" | sudo tee -a /etc/crontab
}

cron_packages() {
    echo "========================================" | sudo tee -a /etc/crontab
    echo "         CRON SETUP - PACKAGES          " | sudo tee -a /etc/crontab
    echo "========================================" | sudo tee -a /etc/crontab
    echo "0 11 * * * aide --check --config /etc/aide/aide.conf" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/maldet --update" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/rkhunter --update" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/fail2ban-client -x" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apparmor_parser -r /etc/apparmor.d/*" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditctl -e 1" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditd -f" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditd -r" | sudo tee -a /etc/crontab
    
}

cron_alert() {

    ALERTS_FILE="$HOME/Desktop/HARDN_alerts.txt"
    ALERTS_DIR="$(dirname "$ALERTS_FILE")"
    [ -d "$ALERTS_DIR" ] || mkdir -p "$ALERTS_DIR"

    echo "========================================" | sudo tee -a /etc/crontab
    echo "          CRON SETUP - ALERTS           " | sudo tee -a /etc/crontab
    echo "========================================" | sudo tee -a /etc/crontab

    if command -v maldet >/dev/null || [ -x /usr/local/maldetect/maldet ]; then
        echo "[Maldet Alerts]" >> "$ALERTS_FILE"
        sudo timeout 60s maldet --report list | grep -i "alert" >> "$ALERTS_FILE" || echo "No alerts from Maldet." >> "$ALERTS_FILE"
        echo "-------------------------" >> "$ALERTS_FILE"
    fi

    if command -v fail2ban-client >/dev/null; then
        echo "[Fail2Ban Alerts]" >> "$ALERTS_FILE"
        if sudo systemctl is-active --quiet fail2ban; then
            sudo fail2ban-client status | grep -i "banned" >> "$ALERTS_FILE" || echo "No alerts from Fail2Ban." >> "$ALERTS_FILE"
        else
            echo "Fail2Ban is not running." >> "$ALERTS_FILE"
        fi
        echo "-------------------------" >> "$ALERTS_FILE"
    fi

    if command -v aa-status >/dev/null; then
        echo "[AppArmor Alerts]" >> "$ALERTS_FILE"
        sudo aa-status | grep -i "profile" >> "$ALERTS_FILE" || echo "No alerts from AppArmor." >> "$ALERTS_FILE"
        echo "-------------------------" >> "$ALERTS_FILE"
    fi

    echo "[General Security Alerts]" >> "$ALERTS_FILE"
    sudo grep -i "alert" /var/log/syslog /var/log/auth.log /var/log/kern.log 2>/dev/null >> "$ALERTS_FILE" || echo "No general security alerts found." >> "$ALERTS_FILE"
    echo "-------------------------" >> "$ALERTS_FILE"

    if [ -s "$ALERTS_FILE" ]; then
        echo "[+] Alerts have been written to $ALERTS_FILE"
    else
        echo "[+] No alerts found. Removing empty alerts file."
        rm -f "$ALERTS_FILE"
    fi
}



main() {
    printf "\033[1;31m[+] Validating configuration...\033[0m\n"
    ensure_aide_initialized
    validate_packages
    validate_stig_hardening
    validate_boot_services
    cron_clean
    cron_packages
    cron_alert

    if grep -q "[-]" "$LOG_FILE"; then
        printf "\033[1;31m[-] Validation failed. Please check the log file at %s for details.\033[0m\n" "$LOG_FILE"
        printf "\033[1;31m[-] Error Summary:\033[0m\n"
        grep "[-]" "$LOG_FILE" | nl
        return 1
    else
        printf "\033[1;32m[+] Validation successful. No errors found.\033[0m\n"
    fi

    
    sleep 3
    print_ascii_banner
    echo -e "\033[1;32m[+] ======== VALIDATION COMPLETE PLEASE REBOOT YOUR SYSTEM=========\033[0m" | tee -a "$LOG_FILE"
    
}

main