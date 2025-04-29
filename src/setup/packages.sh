#!/bin/sh
set -e # Exit on errors
set -x # Debug mode




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
                        ▗▖  ▗▖     ▗▄▖     ▗▖       ▗▄▄▄▖    ▗▄▄▄       ▗▄▖     ▗▄▄▄▖    ▗▄▄▄▖
                        ▐▌  ▐▌    ▐▌ ▐▌    ▐▌         █      ▐▌  █     ▐▌ ▐▌      █      ▐▌   
                        ▐▌  ▐▌    ▐▛▀▜▌    ▐▌         █      ▐▌  █     ▐▛▀▜▌      █      ▐▛▀▀▘
                         ▝▚▞▘     ▐▌ ▐▌    ▐▙▄▄▖    ▗▄█▄▖    ▐▙▄▄▀     ▐▌ ▐▌      █      ▐▙▄▄▖
                                                                      
                                                                     
                                       
                                                    v 1.1.2               
                                    
                                                               
                                  
EOF
}

print_ascii_banner

sleep 7


if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Re-running with sudo..."
    if command -v sudo >/dev/null; then
        exec sudo "$0" "$@"
    else
        echo "Error: sudo is not installed. Please run this script as root."
        exit 1
    fi
fi

LOG_FILE="/var/log/hardn_packages.log"
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
        eval "$fix_cmd" && echo "[+] Fixed: $success_msg" | tee -a "$LOG_FILE" || { echo "[-] Failed to fix: $failure_msg" | tee -a "$LOG_FILE"; return 1; }
    else
        echo "[-] $failure_msg" | tee -a "$LOG_FILE"
        if $FIX_MODE; then
            echo "[*] Attempting to fix..." | tee -a "$LOG_FILE"
            eval "$fix_cmd" && echo "[+] Fixed: $success_msg" | tee -a "$LOG_FILE" || echo "[-] Failed to fix: $failure_msg" | tee -a "$LOG_FILE"
        fi
    fi
}

spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 "$pid" 2>/dev/null; do
        local temp=${spinstr#?}
        printf "\033[1;32m [%c]  \033[0m" "$spinstr" # Green spinner
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

validate_packages() {
    echo "[+] Validating package configurations..." | tee -a "$LOG_FILE"

    fix_if_needed \
        "command -v getenforce >/dev/null && [ \"$(getenforce)\" = \"Enforcing\" ]" \
        "echo '[!] Cannot fix SELinux enforcement automatically.'" \
        "SELinux is enforcing" \
        "SELinux not enforcing"

    fix_if_needed \
        "ufw status | grep -q 'Status: active'" \
        "sudo ufw enable" \
        "UFW is active" \
        "UFW not active"

    fix_if_needed \
        "sudo systemctl is-active --quiet fail2ban" \
        "sudo systemctl start fail2ban" \
        "Fail2Ban is active" \
        "Fail2Ban not running"

    fix_if_needed \
        "command -v aa-status >/dev/null && sudo systemctl is-active --quiet apparmor" \
        "sudo systemctl start apparmor" \
        "AppArmor is active" \
        "AppArmor not active"

    fix_if_needed \
        "command -v firejail >/dev/null" \
        "sudo apt-get install -y firejail" \
        "Firejail is installed" \
        "Firejail missing"

    fix_if_needed \
        "command -v chkrootkit >/dev/null" \
        "sudo apt-get install -y chkrootkit" \
        "chkrootkit installed" \
        "chkrootkit missing"

    fix_if_needed \
        "command -v maldet >/dev/null || [ -x /usr/local/maldetect/maldet ]" \
        "sudo apt-get install -y maldet" \
        "LMD installed" \
        "LMD not found"

    fix_if_needed \
        "sudo systemctl is-active --quiet auditd" \
        "sudo systemctl start auditd" \
        "auditd is running" \
        "auditd not running"

    fix_if_needed \
        "command -v aide >/dev/null" \
        "sudo apt-get install -y aide" \
        "AIDE is installed" \
        "AIDE not installed"

    fix_if_needed \
        "sudo aide --check >/dev/null 2>&1" \
        "sudo aideinit" \
        "AIDE database check passed" \
        "AIDE database check failed"
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
        "grep -q 'U.S. Government' /etc/issue" \
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

    # Set fail2ban to start at boot
    fix_if_needed \
        "sudo systemctl is-enabled fail2ban | grep -q 'disabled'" \
        "sudo systemctl enable fail2ban" \
        "Fail2Ban is enabled at boot" \
        "Fail2Ban is disabled at boot"

    # Set auditd to start at boot
    fix_if_needed \
        "sudo systemctl is-enabled auditd | grep -q 'disabled'" \
        "sudo systemctl enable auditd" \
        "auditd is enabled at boot" \
        "auditd is disabled at boot"

    # Set apparmor to start at boot
    fix_if_needed \
        "sudo systemctl is-enabled apparmor | grep -q 'disabled'" \
        "sudo systemctl enable apparmor" \
        "AppArmor is enabled at boot" \
        "AppArmor is disabled at boot"

    # Set sshd to start at boot
    fix_if_needed \
        "sudo systemctl is-enabled sshd | grep -q 'disabled'" \
        "sudo systemctl enable sshd" \
        "sshd is enabled at boot" \
        "sshd is disabled at boot"
}
cron_clean() {
    # setup cron to keep system updated and clean, running at midnight every 2 days
    echo "0 0 */2 * * root /usr/bin/apt-get update && /usr/bin/apt-get upgrade -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get dist-upgrade -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get autoremove -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get autoclean -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get check" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get clean" | sudo tee -a /etc/crontab
}

cron_packages() {
    # build this to validate and keep aide, lmd, apparmor, fail2ban, grub, and auditd up to date
    echo "0 0 */2 * * root /usr/bin/aide --check" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/maldet --update" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/fail2ban-client -x" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apparmor_parser -r /etc/apparmor.d/*" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditctl -e 1" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditd -f" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditd -r" | sudo tee -a /etc/crontab
}

cron_alert() {
    # build this to monitor aide and lmd for any alerts and create a text file on the user's desktop
    ALERTS_FILE="$HOME/Desktop/HARD_alerts.txt"

   
    echo "HARD Alerts - $(date)" > "$ALERTS_FILE"
    echo "=========================" >> "$ALERTS_FILE"

 
    if command -v aide >/dev/null; then
        echo "[AIDE Alerts]" >> "$ALERTS_FILE"
        sudo aide --check | grep -i "alert" >> "$ALERTS_FILE" || echo "No alerts from AIDE." >> "$ALERTS_FILE"
        echo "-------------------------" >> "$ALERTS_FILE"
    fi

    
    if command -v maldet >/dev/null || [ -x /usr/local/maldetect/maldet ]; then
        echo "[Maldet Alerts]" >> "$ALERTS_FILE"
        sudo maldet --report list | grep -i "alert" >> "$ALERTS_FILE" || echo "No alerts from Maldet." >> "$ALERTS_FILE"
        echo "-------------------------" >> "$ALERTS_FILE"
    fi

    
    if command -v fail2ban-client >/dev/null; then
        echo "[Fail2Ban Alerts]" >> "$ALERTS_FILE"
        sudo fail2ban-client status | grep -i "banned" >> "$ALERTS_FILE" || echo "No alerts from Fail2Ban." >> "$ALERTS_FILE"
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

validate_configuration() {
    printf "\033[1;31m[+] Validating configuration...\033[0m\n"

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

    echo -e "\033[1;32m[+] ======== VALIDATION COMPLETE =========\033[0m" | tee -a "$LOG_FILE"
}


print_log_file() {
    echo -e "\033[1;34m[+] Printing log file as a table...\033[0m"
    echo -e "\033[1;33mHARDN SETUP VALIDATION\033[0m" | tee /dev/stderr

    echo -e "\033[1;32m[+] Validation Results:\033[0m"
    printf "%-50s | %-10s\n" "Check" "Status"
    printf "%-50s | %-10s\n" "--------------------------------------------------" "----------"
    grep -E "\[.\]" "$LOG_FILE" | while read -r line; do
        status=$(echo "$line" | grep -oE "\[.\]")
        message=$(echo "$line" | sed -E "s/\[.\] //")
        printf "%-50s | %-10s\n" "$message" "$status"
    done

    echo -e "\n\033[1;31m[-] Errors:\033[0m"
    grep "[-]" "$LOG_FILE" | nl || echo -e "\033[1;32m[+] No errors found.\033[0m"
}

sleep 7


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
                                                                      
                                                 C O M P L E T E
                                               .....REBOOTING.....              
                                       
                                                    v 1.1.2               
                                    
                                                               
                                  
EOF


print_ascii_banner

}

echo -e "\033[1;31m[+] Rebooting system...\033[0m"
sudo reboot