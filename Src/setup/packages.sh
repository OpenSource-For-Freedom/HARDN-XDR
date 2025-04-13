#!/bin/bash
# Validates setup.sh for install and configuration setups (only)

########################################
#           HARDN - Packages           #
#  Please have repo cloned beforehand  #
#       Installs + Pre-config          #
#    Must have python-3 loaded already #
#             Author(s):               #
#         - Chris Bingham              #
#           - Tim Burns                #
#        Date: 4/5-12/2025             #
########################################

LOG_FILE="/var/log/packages_validation.log"

# Initialize log file
initialize_log() {
    printf "\033[1;31m[+] Initializing log file: $LOG_FILE...\033[0m\n"
    echo "HARDN-Packages Validation Log - $(date)" > "$LOG_FILE"
    echo "=========================================" >> "$LOG_FILE"
}

# Validate package configurations
validate_packages() {
    printf "\033[1;31m[+] Validating package configurations...\033[0m\n" | tee -a "$LOG_FILE"

    # Validate SELinux
    if command -v getenforce > /dev/null 2>&1; then
        selinux_status=$(getenforce)
        if [ "$selinux_status" != "Enforcing" ]; then
            printf "\033[1;31m[-] SELinux is not in enforcing mode. Please configure it.\033[0m\n" | tee -a "$LOG_FILE"
            return 1
        fi
        printf "\033[1;31m[+] SELinux is properly configured.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] SELinux is not installed. Please install SELinux.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate Lynis
    if command -v lynis > /dev/null 2>&1; then
        printf "\033[1;31m[+] Lynis is installed.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] Lynis is not installed. Please install Lynis.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate UFW
    if ufw status | grep -q "Status: active"; then
        printf "\033[1;31m[+] UFW is active and configured.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] UFW is not active. Please enable it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate Fail2Ban
    if systemctl is-active --quiet fail2ban; then
        printf "\033[1;31m[+] Fail2Ban is running properly.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] Fail2Ban is not running. Please start it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate AppArmor
    if aa-status >/dev/null 2>&1; then
        printf "\033[1;31m[+] AppArmor is running properly.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] AppArmor is not running. Please enable it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate auditd
    if systemctl is-active --quiet auditd; then
        printf "\033[1;31m[+] auditd is running properly.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] auditd is not running. Please start it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate OpenSCAP
    if command -v oscap > /dev/null 2>&1; then
        printf "\033[1;31m[+] OpenSCAP is installed.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] OpenSCAP is not installed. Please install it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate chkrootkit
    if command -v chkrootkit > /dev/null 2>&1; then
        printf "\033[1;31m[+] chkrootkit is installed.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] chkrootkit is not installed. Please install it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate Linux Malware Detect (LMD)
    if command -v maldet > /dev/null 2>&1; then
        printf "\033[1;31m[+] Linux Malware Detect (LMD) is installed.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] Linux Malware Detect (LMD) is not installed. Please install it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate rkhunter
    if command -v rkhunter > /dev/null 2>&1; then
        printf "\033[1;31m[+] rkhunter is installed.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] rkhunter is not installed. Please install it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi

    # Validate USB storage blocking
    if grep -q "install usb-storage /bin/false" /etc/modprobe.d/usb-storage.conf; then
        printf "\033[1;31m[+] USB storage devices are blocked.\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] USB storage devices are not blocked. Please configure it.\033[0m\n" | tee -a "$LOG_FILE"
        return 1
    fi
}

# Provides an output of total configuration success or errors
validate_configuration() {
    printf "\033[1;31m[+] Validating configuration...\033[0m\n" | tee -a "$LOG_FILE"
    if validate_packages; then
        printf "\033[1;32m[+] ======== ALL CONFIGURATIONS ARE SUCCESSFUL =========\033[0m\n" | tee -a "$LOG_FILE"
    else
        printf "\033[1;31m[-] Some configurations failed. Check the log: $LOG_FILE\033[0m\n" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# Main function
main() {
    initialize_log
    validate_configuration
}

main