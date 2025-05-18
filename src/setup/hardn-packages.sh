#!/bin/bash


set -e # Exit on errors
LOG_FILE="/var/log/hardn-packages.log"

center_text() {
    local text="$1"
    local width=$(tput cols)
    local text_width=${#text}
    local padding=$(( (width - text_width) / 2 ))
    printf "%${padding}s%s\n" "" "$text"
}

print_ascii_banner() {
    CYAN_BOLD="\033[1;36m"
    RESET="\033[0m"
    
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
        center_text "$(date +'%Y-%m-%d %H:%M:%S')"
        center_text "HARDN - Setup Validation Script"
        center_text "$(uname -s) $(uname -r) $(uname -m)"
        center_text "$BORDER"

    fi
}

print_ascii_banner

sleep 5


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
    {
        echo "========================================"
        echo " HARDN - Packages Validation Log"
        echo "========================================"
        echo "[+] Log initialized at $(date)"
    } > "$LOG_FILE"
}

fix_if_needed() {
    local check_cmd="$1"
    local fix_cmd="$2"
    local success_msg="$3"
    local failure_msg="$4"

    # Validate inputs
    if [[ -z "$check_cmd" || -z "$fix_cmd" || -z "$success_msg" || -z "$failure_msg" ]]; then
        echo "[-] Invalid arguments provided to fix_if_needed." | tee -a "$LOG_FILE"
        return 1
    fi

    if eval "$check_cmd"; then
        echo "[+] $success_msg" | tee -a "$LOG_FILE"
    else
        echo "[-] $failure_msg" | tee -a "$LOG_FILE"
        if $FIX_MODE; then
            echo "[*] Attempting to fix..." | tee -a "$LOG_FILE"
            if eval "$fix_cmd"; then
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
    # Ensure AIDE is installed
    if ! command -v aide >/dev/null 2>&1; then
        echo "[*] Installing AIDE..."
        apt-get install -y aide aide-common
    fi

    # Create and configure AIDE service and timer
    echo "[*] Creating AIDE systemd service and timer..."
    
    # Create aide.service file
    cat > /etc/systemd/system/aide.service << EOF
[Unit]
Description=AIDE (Advanced Intrusion Detection Environment) check
Documentation=man:aide(1)

[Service]
Type=oneshot
ExecStart=/usr/bin/aide --check --config=/etc/aide/aide.conf
StandardOutput=append:/var/log/aide/aide.log
StandardError=append:/var/log/aide/aide.log
EOF

    # Create aide.timer file for daily checks
    cat > /etc/systemd/system/aide.timer << EOF
[Unit]
Description=Daily AIDE check

[Timer]
OnCalendar=*-*-* 4:00:00
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # Enable the timer
    systemctl enable aide.timer
    systemctl daemon-reload

    # Ensure log directory exists
    mkdir -p /var/log/aide
    chmod 750 /var/log/aide

    # Initialize AIDE database if needed
    if [ ! -f /var/lib/aide/aide.db ]; then
        echo "[*] Initializing AIDE database..."
       
        if [ -f /etc/aide/aide.conf ]; then
            sudo aide --init --config=/etc/aide/aide.conf
            if [ -f /var/lib/aide/aide.db.new ]; then
                sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
                sudo chmod 600 /var/lib/aide/aide.db
                echo "[+] AIDE database initialized."
            else
                echo "[-] AIDE initialization failed - no new database file created."
            fi
        else
            echo "[-] AIDE configuration file not found at /etc/aide/aide.conf."
        fi
    else
        echo "[+] AIDE database already exists, skipping initialization."
    fi
}

validate_environment() {
    echo "[INFO] Validating system environment..." | tee -a "$LOG_FILE"

    if [ -d /sys/firmware/efi ]; then
        echo "[*] UEFI system detected. Ensuring UEFI configurations are applied..." | tee -a "$LOG_FILE"
        # Add UEFI-specific validation here if needed
    else
        echo "[*] Legacy BIOS system detected. Ensuring BIOS configurations are applied..." | tee -a "$LOG_FILE"
        # Add BIOS-specific validation here if needed
    fi

    if grep -q 'hypervisor' /proc/cpuinfo; then
        echo "[*] Virtual machine detected. Validating VM-specific configurations..." | tee -a "$LOG_FILE"
        # Add VM-specific validation here if needed
    else
        echo "[*] Bare metal system detected. Validating bare metal configurations..." | tee -a "$LOG_FILE"
        # Add bare metal-specific validation here if needed
    fi
}

validate_packages() {
    echo "[INFO] Validating package configurations with enhanced error handling..." | tee -a "$LOG_FILE"

    # Validate system environment
    validate_environment

    # Check and fix internet connectivity
    fix_if_needed \
        "ping -c 1 google.com >/dev/null 2>&1" \
        "sudo systemctl restart networking && sudo dhclient" \
        "Internet connectivity is restored" \
        "Internet connectivity is not available"

    # Check and fix Fail2Ban
    fix_if_needed \
        "sudo systemctl is-active --quiet fail2ban" \
        "sudo systemctl start fail2ban" \
        "Fail2Ban is active" \
        "Fail2Ban not running"

    # Check and fix AppArmor
    fix_if_needed \
        "sudo systemctl is-active --quiet apparmor" \
        "sudo systemctl enable --now apparmor" \
        "AppArmor is active" \
        "AppArmor not active"

    # Check and install maldet
    fix_if_needed \
        "command -v maldet >/dev/null 2>&1" \
        "sudo apt install -y maldet" \
        "Linux Malware Detect (maldet) is installed" \
        "Linux Malware Detect (maldet) is not installed"
        
    # Check and install YARA
    fix_if_needed \
        "command -v yara >/dev/null 2>&1" \
        "sudo apt install -y yara" \
        "YARA is installed" \
        "YARA is not installed"
    
    # Check YARA rules directory exists
    fix_if_needed \
        "[ -d /etc/yara/rules ]" \
        "mkdir -p /etc/yara/rules && wget -q \"https://github.com/Yara-Rules/rules/archive/refs/heads/master.zip\" -O /tmp/yara-rules.zip && unzip -q -o /tmp/yara-rules.zip -d /tmp/yara-extract && cp -rf /tmp/yara-extract/rules-master/* /etc/yara/rules/ && chown -R root:root /etc/yara/rules && chmod -R 644 /etc/yara/rules && find /etc/yara/rules -type d -exec chmod 755 {} \\;" \
        "YARA rules directory exists" \
        "YARA rules directory missing"
    
    # Check YARA index.yar exists
    fix_if_needed \
        "[ -f /etc/yara/rules/index.yar ]" \
        "find /etc/yara/rules -name \"*.yar\" -not -name \"index.yar\" | sed 's|^/etc/yara/rules/|include \"|; s|$|\"|' > /etc/yara/rules/index.yar" \
        "YARA index.yar exists" \
        "YARA index.yar missing"
    
    # Check YARA can execute basic test
    fix_if_needed \
        "( yara -r /etc/yara/rules/index.yar /tmp >/dev/null 2>&1 ) || ( echo 'rule test_rule {strings: $test = \"test\" condition: $test}' > /etc/yara/rules/test.yar && echo 'include \"test.yar\"' > /etc/yara/rules/index.yar && yara -r /etc/yara/rules/index.yar /tmp >/dev/null 2>&1 )" \
        "touch /var/log/yara_scan.log && chmod 640 /var/log/yara_scan.log && chown root:adm /var/log/yara_scan.log" \
        "YARA functionality verified" \
        "YARA functionality issue detected"

    # Check and reinitialize AIDE database
    fix_if_needed \
        "[ -f /var/lib/aide/aide.db ]" \
        "sudo aide --init --config=/etc/aide/aide.conf && [ -f /var/lib/aide/aide.db.new ] && sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db && sudo chmod 600 /var/lib/aide/aide.db" \
        "AIDE database is initialized" \
        "AIDE database check failed"

    # Check and fix /etc/shadow permissions
    fix_if_needed \
        "[ $(stat -c '%a' /etc/shadow) -eq 640 ] && [ $(stat -c '%U:%G' /etc/shadow) == 'root:shadow' ]" \
        "sudo chmod 640 /etc/shadow && sudo chown root:shadow /etc/shadow" \
        "/etc/shadow permissions are correct" \
        "Incorrect /etc/shadow permissions"

    # Enable Fail2Ban at boot
    fix_if_needed \
        "sudo systemctl is-enabled --quiet fail2ban" \
        "sudo systemctl enable fail2ban" \
        "Fail2Ban is enabled at boot" \
        "Fail2Ban is disabled at boot"

    # Enable auditd at boot
    fix_if_needed \
        "sudo systemctl is-enabled --quiet auditd" \
        "sudo systemctl enable auditd" \
        "auditd is enabled at boot" \
        "auditd is disabled at boot"

    # Enable AppArmor at boot
    fix_if_needed \
        "sudo systemctl is-enabled --quiet apparmor" \
        "sudo systemctl enable apparmor" \
        "AppArmor is enabled at boot" \
        "AppArmor is disabled at boot"

    echo "[INFO] Summary of changes made during validation:" | tee -a "$LOG_FILE"
    grep "[+]" "$LOG_FILE" | tee -a "$LOG_FILE"
}

validate_stig_hardening() {
    echo "[+] Validating STIG compliance..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "grep -q 'minlen = 14' /etc/security/pwquality.conf" \
        "sudo sed -i 's/^#\\? *minlen.*/minlen = 14/' /etc/security/pwquality.conf" \
        "Password policy minlen is set" \
        "Password policy minlen missing or wrong"
    fix_if_needed \
        "[[ $(stat -c '%a' /etc/shadow) -eq 600 ]]" \
        "sudo chmod 600 /etc/shadow" \
        "/etc/shadow permissions are 600" \
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
}

validate_boot_services() {
    echo "[*] Validating boot services..." | tee -a "$LOG_FILE"

    echo "[*] Checking if Fail2Ban is enabled at boot..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "! sudo systemctl is-enabled fail2ban | grep -q 'enabled'" \
        "sudo systemctl enable fail2ban" \
        "Fail2Ban is enabled at boot" \
        "Fail2Ban is disabled at boot"

    echo "[*] Checking if auditd is enabled at boot..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "! sudo systemctl is-enabled auditd | grep -q 'enabled'" \
        "sudo systemctl enable auditd" \
        "auditd is enabled at boot" \
        "auditd is disabled at boot"

    echo "[*] Checking if AppArmor is enabled at boot..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "! sudo systemctl is-enabled apparmor | grep -q 'enabled'" \
        "sudo systemctl enable apparmor" \
        "AppArmor is enabled at boot" \
        "AppArmor is disabled at boot"

    echo "[*] Checking if sshd is enabled at boot..." | tee -a "$LOG_FILE"
    fix_if_needed \
        "! sudo systemctl is-enabled sshd | grep -q 'enabled'" \
        "sudo systemctl enable sshd" \
        "sshd is enabled at boot" \
        "sshd is disabled at boot"
}

cron_clean(){
    echo "========================================" | sudo tee -a /etc/crontab
    echo "           CRON SETUP - CLEAN           " | sudo tee -a /etc/crontab
    echo "========================================" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get update && /usr/bin/apt-get upgrade -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get dist-upgrade -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get autoremove -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get autoclean -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get check" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt-get clean" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt update && apt upgrade -y" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apt full-upgrade" | sudo tee -a /etc/crontab
}

cron_packages() {
    echo "========================================" | sudo tee -a /etc/crontab
    echo "         CRON SETUP - PACKAGES          " | sudo tee -a /etc/crontab
    echo "========================================" | sudo tee -a /etc/crontab
    # Ensure AIDE log directory exists
    sudo mkdir -p /var/log/aide
    sudo chmod 750 /var/log/aide
    echo "0 11 * * * root /usr/bin/aide --check --config=/etc/aide/aide.conf >> /var/log/aide/aide.log 2>&1" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/maldet --update" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/rkhunter --update" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/fail2ban-client -x" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/bin/apparmor_parser -r /etc/apparmor.d/*" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/grub-mkconfig -o /boot/grub/grub.cfg" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditctl -e 1" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditd -f" | sudo tee -a /etc/crontab
    echo "0 0 */2 * * root /usr/sbin/auditd -r" | sudo tee -a /etc/crontab
    echo "0 3 * * * root /usr/bin/yara -r /etc/yara/rules/index.yar /home /var/www /tmp >> /var/log/yara_scan.log 2>&1" | sudo tee -a /etc/crontab
    echo "0 0 * * * root /usr/local/bin/hardn-packages.sh > /var/log/hardn-packages.log 2>&1" | sudo tee -a /etc/crontab
}

cron_alert() {
    local ALERTS_FILE="$HOME/Desktop/HARDN_alerts.txt"
    local ALERTS_DIR
    ALERTS_DIR="$(dirname "$ALERTS_FILE")"
    [ -d "$ALERTS_DIR" ] || mkdir -p "$ALERTS_DIR"
    : > "$ALERTS_FILE"

    echo "[Package Installation Alerts]" >> "$ALERTS_FILE"
    local pkgs=(
        ufw fail2ban apparmor firejail rkhunter chkrootkit maldet aide auditd lynis
    )
    for pkg in "${pkgs[@]}"; do
        if dpkg -s "$pkg" &>/dev/null; then
            printf " OK      %s\n" "$pkg" >> "$ALERTS_FILE"
        else
            printf " MISSING %s\n" "$pkg" >> "$ALERTS_FILE"
        fi
    done
    echo "-------------------------" >> "$ALERTS_FILE"

    echo "[Service Status Alerts]" >> "$ALERTS_FILE"
    local svcs=(
      ufw fail2ban apparmor firejail rkhunter chkrootkit maldet aide auditd lynis
    )
    for svc in "${svcs[@]}"; do
        if ! systemctl list-unit-files "${svc}.service" &>/dev/null; then
            printf " %s: not installed\n" "$svc" >> "$ALERTS_FILE"
            continue
        fi

        systemctl is-active --quiet "$svc" && st="active" || st="inactive"
        systemctl is-enabled --quiet "$svc" && e="enabled" || e="disabled"
        printf " %s: %s (%s)\n" "$svc" "$st" "$e" >> "$ALERTS_FILE"
    done
    echo "-------------------------" >> "$ALERTS_FILE"

    echo "[STIG Settings Alerts]" >> "$ALERTS_FILE"
    grep -q '^minlen = 14' /etc/security/pwquality.conf \
        && echo " OK      password minlen=14" >> "$ALERTS_FILE" \
        || echo " MISSING password minlen=14" >> "$ALERTS_FILE"

    sysctl -n net.ipv6.conf.all.disable_ipv6 | grep -q '^1$' \
        && echo " OK      IPv6 disabled" >> "$ALERTS_FILE" \
        || echo " MISSING IPv6 disabled" >> "$ALERTS_FILE"

    systemctl is-enabled ctrl-alt-del.target &>/dev/null \
        && echo " MISSING Ctrl+Alt+Del disabled" >> "$ALERTS_FILE" \
        || echo " OK      Ctrl+Alt+Del disabled" >> "$ALERTS_FILE"

    echo "-------------------------" >> "$ALERTS_FILE"

    echo "[Maldet Alerts]" >> "$ALERTS_FILE"
    if command -v maldet &>/dev/null; then
        local malist
        malist=$(sudo maldet --report list | awk '/alert/ {print}')
        if [ -n "$malist" ]; then
            printf "%s\n" "$malist" >> "$ALERTS_FILE"
        else
            echo " No alerts from maldet" >> "$ALERTS_FILE"
        fi
    fi
    echo "-------------------------" >> "$ALERTS_FILE"

    echo "[Fail2Ban Alerts]" >> "$ALERTS_FILE"
    if command -v fail2ban-client &>/dev/null && systemctl is-active --quiet fail2ban; then
        local flist
        flist=$(sudo fail2ban-client status sshd | awk '/Banned IP list:/ {print substr($0, index($0,$4))}')
        if [ -n "$flist" ]; then
            printf " Banned: %s\n" "$flist" >> "$ALERTS_FILE"
        else
            echo " No banned IPs" >> "$ALERTS_FILE"
        fi
    else
        echo " Fail2Ban not running" >> "$ALERTS_FILE"
    fi
    echo "-------------------------" >> "$ALERTS_FILE"

    echo "[AppArmor Alerts]" >> "$ALERTS_FILE"
    if command -v aa-status &>/dev/null; then
        local alist
        alist=$(sudo aa-status | awk '/profile/ {print}')
        if [ -n "$alist" ]; then
            printf "%s\n" "$alist" >> "$ALERTS_FILE"
        else
            echo " No AppArmor profile events" >> "$ALERTS_FILE"
        fi
    fi
    echo "-------------------------" >> "$ALERTS_FILE"

    echo "[AIDE Alerts]" >> "$ALERTS_FILE"
    if [ -f /etc/aide/aide.conf ] && [ -f /var/lib/aide/aide.db ]; then
        # First check if we have log files to analyze
        if [ -f "/var/log/aide/aide.log" ] && [ -s "/var/log/aide/aide.log" ]; then
            echo " AIDE log exists, checking for alerts..." >> "$ALERTS_FILE"
            if grep -i "found differences between database and filesystem" /var/log/aide/aide.log > /tmp/aide_alerts 2>/dev/null; then
                echo " ⚠️ AIDE detected file system changes:" >> "$ALERTS_FILE"
                grep -A 10 "found differences" /var/log/aide/aide.log | head -n 20 >> "$ALERTS_FILE"
            else
                echo " No alerts found in AIDE logs" >> "$ALERTS_FILE"
            fi
        else
            # No log file found, run an immediate check
            echo " Running AIDE check now..." >> "$ALERTS_FILE"
            if sudo aide --check --config=/etc/aide/aide.conf > /tmp/aide_check_result 2>&1; then
                echo " No deviations detected by AIDE" >> "$ALERTS_FILE"
            else 
                echo " ⚠️ Deviations detected by AIDE" >> "$ALERTS_FILE"
                echo " Last few lines from AIDE check:" >> "$ALERTS_FILE"
                tail -n 15 /tmp/aide_check_result | grep -v "^$" >> "$ALERTS_FILE"
            fi
        fi
    else
        echo " ⚠️ AIDE not properly configured. Missing configuration or database." >> "$ALERTS_FILE"
        echo " Run 'sudo apt-get install aide aide-common && sudo aide --init && sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db'" >> "$ALERTS_FILE"
    fi
    echo "-------------------------" >> "$ALERTS_FILE"
    
    echo "[YARA Alerts]" >> "$ALERTS_FILE"
    if [ ! -f /var/log/yara_scan.log ] || [ ! -s /var/log/yara_scan.log ]; then
        # If log file doesn't exist or is empty, try to run a quick scan
        echo " No previous YARA scan results found. Running a quick scan..." >> "$ALERTS_FILE"
        if command -v yara >/dev/null 2>&1 && [ -f /etc/yara/rules/index.yar ]; then
            yara -r /etc/yara/rules/index.yar /tmp > /var/log/yara_scan.log 2>&1
            if [ -s /var/log/yara_scan.log ]; then
                echo " YARA quick scan detections:" >> "$ALERTS_FILE"
                cat /var/log/yara_scan.log >> "$ALERTS_FILE"
            else
                echo " No YARA detections in quick scan" >> "$ALERTS_FILE"
            fi
        else
            echo " YARA not properly installed or configured" >> "$ALERTS_FILE"
        fi
    else
        # Use existing log file
        echo " YARA detections found:" >> "$ALERTS_FILE"
        tail -n 50 /var/log/yara_scan.log >> "$ALERTS_FILE"
    fi
    echo "-------------------------" >> "$ALERTS_FILE"

    echo "[General Alerts]" >> "$ALERTS_FILE"
    if sudo grep -i alert /var/log/syslog /var/log/auth.log /var/log/kern.log &>/dev/null; then
        sudo grep -i alert /var/log/syslog /var/log/auth.log /var/log/kern.log >> "$ALERTS_FILE"
    else
        echo " No general alerts" >> "$ALERTS_FILE"
    fi

    if [ -s "$ALERTS_FILE" ]; then
        echo "[+] Alerts written to $ALERTS_FILE"
    else
        echo "[+] No alerts found; removing empty alerts file."
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
        return 1
    else
        printf "\033[1;32m[+] Validation successful. No errors found.\033[0m\n"
    fi

    sleep 3
    print_ascii_banner
    echo -e "\033[1;32m[+] ======== VALIDATION COMPLETE PLEASE REBOOT YOUR SYSTEM=========\033[0m" | tee -a "$LOG_FILE"
}

main