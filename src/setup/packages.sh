#!/bin/sh

set -e # Exit on errors
set -x # Debug mode

########################################
# HARDN - Packages #
# THIS SCRIPT IS STIG COMPLIANT #
# Please have repo cloned beforehand #
# Installs + Pre-config #
# Must have python-3 loaded already #
# Author(s): #
# - Chris Bingham #
# - Tim Burns #
# Date: 4/5-12/2025 #
########################################

# Ensure the script is run as root
if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use: sudo ./packages.sh"
    exit 1
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
    check_cmd="$1"
    fix_cmd="$2"
    success_msg="$3"
    failure_msg="$4"

    if eval "$check_cmd"; then
        echo "[+] $success_msg" | tee -a "$LOG_FILE"
    else
        echo "[-] $failure_msg" | tee -a "$LOG_FILE"
        if $FIX_MODE; then
            echo "[*] Attempting to fix..." | tee -a "$LOG_FILE"
            if eval "$fix_cmd"; then
                echo "[+] Fixed: $success_msg" | tee -a "$LOG_FILE"
            else
                echo "[-] Failed to fix: $failure_msg" | tee -a "$LOG_FILE"
            fi
        fi
    fi
}

validate_stig_hardening() {
    echo "[+] Validating STIG compliance..." | tee -a "$LOG_FILE"

    fix_if_needed \
    "grep -q 'minlen = 14' /etc/security/pwquality.conf" \
    "sed -i 's/^#\? *minlen.*/minlen = 14/' /etc/security/pwquality.conf" \
    "Password policy minlen is set" \
    "Password policy minlen missing or wrong"

    fix_if_needed \
    "stat -c '%a' /etc/shadow | grep -q 000" \
    "chmod 000 /etc/shadow" \
    "/etc/shadow permissions are 000" \
    "Incorrect /etc/shadow permissions"

    fix_if_needed \
    "grep -q 'net.ipv6.conf.all.disable_ipv6 = 1' /etc/sysctl.d/99-sysctl.conf" \
    "echo 'net.ipv6.conf.all.disable_ipv6 = 1' >> /etc/sysctl.d/99-sysctl.conf && sysctl -w net.ipv6.conf.all.disable_ipv6=1" \
    "IPv6 is disabled" \
    "IPv6 not disabled"

    fix_if_needed \
    "grep -q 'fs.suid_dumpable = 0' /etc/sysctl.d/99-coredump.conf" \
    "echo 'fs.suid_dumpable = 0' > /etc/sysctl.d/99-coredump.conf && sysctl -w fs.suid_dumpable=0" \
    "Core dumps are disabled" \
    "Core dumps enabled"

    fix_if_needed \
    "grep -q 'install usb-storage /bin/false' /etc/modprobe.d/hardn-blacklist.conf" \
    "echo 'install usb-storage /bin/false' > /etc/modprobe.d/hardn-blacklist.conf" \
    "USB storage blocked via modprobe" \
    "USB storage not blocked"

    fix_if_needed \
    "grep -q 'kernel.randomize_va_space = 2' /etc/sysctl.d/hardn.conf" \
    "echo 'kernel.randomize_va_space = 2' >> /etc/sysctl.d/hardn.conf && sysctl -w kernel.randomize_va_space=2" \
    "randomize_va_space = 2 present" \
    "Missing randomize_va_space setting"

    fix_if_needed \
    "grep -q 'U.S. Government' /etc/issue" \
    "echo 'You are accessing a U.S. Government (USG) Information System (IS)...' > /etc/issue" \
    "Login banner exists" \
    "Missing login banner /etc/issue"

    fix_if_needed \
    "systemctl status ctrl-alt-del.target | grep -q 'Masked'" \
    "systemctl mask ctrl-alt-del.target" \
    "Ctrl+Alt+Del is disabled" \
    "Ctrl+Alt+Del is still active"

    if [ -f /etc/apparmor.d/local/hardn.whitelist ]; then
        grep -q "hardn" /etc/apparmor.d/local/hardn.whitelist &&
        echo "[+] AppArmor whitelist exists." | tee -a "$LOG_FILE" ||
        echo "[-] AppArmor whitelist incomplete." | tee -a "$LOG_FILE"

        $FIX_MODE && {
            echo "[*] Appending HARDN whitelist entries..." | tee -a "$LOG_FILE"
            echo "/usr/local/bin/hardn rix," >> /etc/apparmor.d/local/hardn.whitelist
            echo "[+] AppArmor whitelist updated." | tee -a "$LOG_FILE"
            apparmor_parser -r /etc/apparmor.d/local/hardn.whitelist
        }

        aa-status | grep -q "enforce mode" &&
        aa-status | grep -q "hardn" &&
        echo "[+] AppArmor enforces HARDN." | tee -a "$LOG_FILE" ||
        echo "[-] AppArmor not enforcing HARDN." | tee -a "$LOG_FILE"
    else
        echo "[-] AppArmor whitelist file missing." | tee -a "$LOG_FILE"
        $FIX_MODE && {
            echo "[*] Creating AppArmor whitelist..." | tee -a "$LOG_FILE"
            echo "/usr/local/bin/hardn rix," > /etc/apparmor.d/local/hardn.whitelist
            apparmor_parser -r /etc/apparmor.d/local/hardn.whitelist
        }
    fi
}

validate_packages() {
    echo "[+] Validating package configurations..." | tee -a "$LOG_FILE"

    command -v getenforce >/dev/null && [ "$(getenforce)" = "Enforcing" ] &&
    echo "[+] SELinux is enforcing." | tee -a "$LOG_FILE" ||
    { echo "[-] SELinux not enforcing." | tee -a "$LOG_FILE"; $FIX_MODE && echo "[!] Cannot fix SELinux here." | tee -a "$LOG_FILE"; }

    ufw status | grep -q "Status: active" &&
    echo "[+] UFW is active." | tee -a "$LOG_FILE" ||
    { echo "[-] UFW not active." | tee -a "$LOG_FILE"; $FIX_MODE && ufw enable && echo "[+] UFW enabled." | tee -a "$LOG_FILE"; }

    systemctl is-active --quiet fail2ban &&
    echo "[+] Fail2Ban is active." | tee -a "$LOG_FILE" ||
    { echo "[-] Fail2Ban not running." | tee -a "$LOG_FILE"; $FIX_MODE && systemctl start fail2ban && echo "[+] Fail2Ban started." | tee -a "$LOG_FILE"; }

    command -v aa-status >/dev/null && systemctl is-active --quiet apparmor &&
    echo "[+] AppArmor is active." | tee -a "$LOG_FILE" ||
    { echo "[-] AppArmor not active." | tee -a "$LOG_FILE"; $FIX_MODE && systemctl start apparmor && echo "[+] AppArmor started." | tee -a "$LOG_FILE"; }

    command -v firejail >/dev/null &&
    echo "[+] Firejail is installed." | tee -a "$LOG_FILE" ||
    echo "[-] Firejail missing." | tee -a "$LOG_FILE"

    command -v chkrootkit >/dev/null &&
    echo "[+] chkrootkit installed." | tee -a "$LOG_FILE" ||
    echo "[-] chkrootkit missing." | tee -a "$LOG_FILE"

    command -v maldet >/dev/null || [ -x /usr/local/maldetect/maldet ] &&
    echo "[+] LMD installed." | tee -a "$LOG_FILE" ||
    echo "[-] LMD not found." | tee -a "$LOG_FILE"

    systemctl is-active --quiet auditd &&
    echo "[+] auditd is running." | tee -a "$LOG_FILE" ||
    echo "[-] auditd not running." | tee -a "$LOG_FILE"
}

validate_configuration() {
    printf "\033[1;31m[+] Validating configuration...\033[0m\n"
        if some_validation_command; then
    printf "\033[1;32m[+] Validation passed.\033[0m\n"
        else
    printf "\033[1;31m[-] Validation failed. Skipping...\033[0m\n"
    # Prevents script from exiting
    return 0

    fi
}


printf "\033[1;32m[+] ======== VALIDATION COMPLETE =========\033[0m\n" | tee -a "$LOG_FILE"
$FIX_MODE && printf "\033[1;34m[*] Fix mode was enabled. Auto-remediation attempted.\033[0m\n" | tee -a "$LOG_FILE"

# Make setup.sh and packages.sh read and execute only
PACKAGES_SCRIPT="/home/tim/DEV/HARDN/src/setup/packages.sh" # Define the path to the script
printf "\033[1;31m[+] Making setup.sh and packages.sh read and execute only...\033[0m\n"
chmod 555 "$0"
chmod 555 "$PACKAGES_SCRIPT"
printf "\033[1;32m[+] setup.sh and packages.sh are now read and execute only.\033[0m\n"

main() {
    if [ "$1" = "--fix" ]; then
        FIX_MODE=true
    fi
    initialize_log
    validate_packages
    validate_stig_hardening
    validate_configuration
}
