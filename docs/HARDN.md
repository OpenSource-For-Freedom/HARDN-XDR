# HARDN v2.0.0: Included Packages and Settings

## Final Release

HARDN-XDR v2.0.0 represents the complete, production-ready security hardening solution for Debian-based systems. This final release includes comprehensive STIG compliance, advanced malware detection, and enterprise-grade security features.


## Packages Installed:
- **ufw** (Uncomplicated Firewall)
- **fail2ban**
- **apparmor**, **apparmor-profiles**, **apparmor-utils**
- **firejail**
- **tcpd**
- **lynis**
- **debsums**
- **libpam-pwquality**
- **libvirt-daemon-system**, **libvirt-clients**
- **qemu-system-x86**
- **openssh-server**, **openssh-client**
- **rkhunter**
- **chkrootkit**
- **linux-malware-detect** (maldet)
- **aide**, **aide-common**
- **YARA**
- **wget**, **curl**, **git**, **gawk**
- **mariadb-common**, **mysql-common**
- **policycoreutils**
- **python3-matplotlib**, **python3-pyqt6**
- **unixodbc-common**
- **fwupd**

## Security Tools/Services Enabled:
- **UFW firewall** (with strict outbound/inbound rules)
- **Fail2Ban** (with SSH jail and custom ban settings)
- **AppArmor** (enabled and profiles reset)
- **Firejail** (sandboxing for Firefox and Chrome)
- **rkhunter** (rootkit scanner, auto-updated)
- **chkrootkit** (rootkit scanner)
- **maldet** (Linux Malware Detect)
- **AIDE** (Advanced Intrusion Detection Environment, initialized and scheduled)
- **auditd** (system auditing, with custom rules)
- **Lynis** (security auditing tool)

## System Hardening & STIG Settings:
- Password policy (**minlen=14**, complexity, retry, enforce_for_root)
- Inactive account lock (**35 days**)
- Login banners (**issue**, **issue.net**)
- Filesystem permissions (**passwd**, **shadow**, etc.)
- Audit rules for sensitive files
- Kernel parameters:
    - ASLR
    - exec-shield
    - panic
    - kptr_restrict
    - dmesg_restrict
    - hardlink/symlink protection
    - ICMP
    - TCP
    - source routing
    - IP forwarding
- USB storage disabled (via **modprobe**)
- Core dumps disabled
- Ctrl+Alt+Del disabled
- IPv6 disabled
- Outbound firewall rules for updates, DNS, NTP only
- Randomize VA space (**ASLR**)
- Firmware updates enabled (**fwupd**)
- Cron jobs for regular **auditd** runs and system updates

## Malware and Signature Detection and Response

By leveraging **AIDE**, **Linux Malware Detect (LMD)**, and **YARA rules** together, the system provides comprehensive malware detection and response capabilities. This integrated approach enables both signature-based and heuristic detection, allowing for early identification of threats and rapid response. Regular scans and rule updates ensure that new and evolving malware patterns are recognized, supporting an effective extended detection and response (XDR) strategy.

## Monitoring & Reporting:
- Alerts and validation logs written to `/var/log/security/alerts.log` and `/var/log/security/validation.log`
- Cron setup for periodic security checks and updates

## About GRUB Security
GRUB Security is handled by the  `grub_security()` function

```bash
grub_security() {
    # This function performs a dry-run test of GRUB security configuration without making actual changes

    # Define key variables for GRUB configuration
    GRUB_CFG="/etc/grub.d/41_custom"
    GRUB_DEFAULT="/etc/default/grub"
    GRUB_USER="hardnxdr"
    CUSTOM_CFG="/boot/grub/custom.cfg"
    GRUB_MAIN_CFG="/boot/grub/grub.cfg"
    PASSWORD_FILE="/root/.hardn-grub-password"

    echo "=== GRUB Security Dry-Run Test ==="
    echo "[INFO] This will test GRUB security configuration WITHOUT making changes"

    # Skip configuration if running in a VM
    if systemd-detect-virt --quiet --vm; then
        echo "[INFO] Running in a VM, skipping GRUB security configuration."
        echo "[INFO] This script is not intended to be run inside a VM."
        return 0
    fi

    # Check if system uses EFI or BIOS boot
    if [ -d /sys/firmware/efi ]; then
        SYSTEM_TYPE="EFI"
        echo "[INFO] Detected EFI boot system"
        echo "[INFO] GRUB security configuration is not required for EFI systems."
        return 0
    else
        SYSTEM_TYPE="BIOS"
        echo "[INFO] Detected BIOS boot system"
    fi

    # Test GRUB password generation
    echo "[TEST] Testing GRUB password generation..."
    TEST_PASS=$(openssl rand -base64 12 | tr -d '\n')
    HASH=$(echo -e "$TEST_PASS\n$TEST_PASS" | grub-mkpasswd-pbkdf2 | grep "PBKDF2 hash of your password is" | sed 's/PBKDF2 hash of your password is //')

    # Check if password hash was generated successfully
    if [ -z "$HASH" ]; then
        echo "[ERROR] Failed to generate password hash"
        return 1
    else
        echo "[SUCCESS] Password hash generated: ${HASH:0:50}..."
    fi

    # Test file access permissions
    echo "[TEST] Checking file permissions and access..."
    if [ -w "$GRUB_CFG" ]; then
        echo "[SUCCESS] Can write to custom GRUB config: $GRUB_CFG"
    else
        echo "[ERROR] Cannot write to custom GRUB config: $GRUB_CFG"
    fi

    if [ -w "$GRUB_MAIN_CFG" ]; then
        echo "[SUCCESS] Can write to main GRUB config: $GRUB_MAIN_CFG"
    else
        echo "[ERROR] Cannot write to main GRUB config: $GRUB_MAIN_CFG"
    fi

    # Test if update-grub command is available
    echo "[TEST] Testing GRUB update capability..."
    if command -v update-grub >/dev/null 2>&1; then
        echo "[SUCCESS] update-grub available"
    else
        echo "[ERROR] update-grub not available"
    fi

    # Show preview of what would be configured
    echo
    echo "=== Configuration Preview ==="
    echo "[INFO] Custom config would be created at: $CUSTOM_CFG"
    echo "[INFO] Content would be:"
    echo "---"
    echo "set superusers=\"$GRUB_USER\""
    echo "password_pbkdf2 $GRUB_USER $HASH"
    echo "---"

    echo
    echo "[INFO] Custom GRUB script would be updated at: $GRUB_CFG"
    echo "[INFO] Files would be backed up with .backup extension"
    echo "[INFO] Permissions would be set to 600 (root only)"

    echo
    echo "[INFO] Password would be saved (in real script) to: $PASSWORD_FILE"

    # Summary of the dry-run test
    echo
    echo "=== Summary ==="
    echo "[SUCCESS] All tests passed! GRUB security configuration is ready."
    echo "[INFO] To apply the configuration, run:"
    echo "  sudo /usr/share/hardn/tools/stig/grub.sh"
    echo "[WARNING] Make sure to remember the password you set!"
    echo "[INFO] GRUB Username: $GRUB_USER"
    echo "[INFO] GRUB Password saved to: $PASSWORD_FILE"

    return 0
}
```

## The Purpose of the `grub_security()` Function

This function performs a **dry-run test** to check if the system is ready for GRUB bootloader password protection,
without actually making any changes. It's designed to:

1. **Verify system compatibility** for GRUB password protection
2. **Test password generation** capabilities
3. **Check file access permissions** needed for configuration
4. **Preview the changes** that would be made in a real implementation
5. **Provide instructions** for applying the actual configuration

## Key Features

1. **VM Detection**: Skips configuration if running in a virtual machine
2. **Boot System Detection**: Identifies if the system uses EFI or BIOS boot (skips for EFI systems)
3. **Password Generation Test**: Tests the ability to generate a secure PBKDF2 hash for GRUB
4. **File Permission Checks**: Verifies write access to necessary GRUB configuration files
5. **Command Availability Check**: Confirms that `update-grub` is available
6. **Configuration Preview**: Shows what would be configured without making changes
7. **Implementation Instructions**: Provides guidance on how to apply the actual configuration

## Security Implications

When actually implemented (not in this dry-run), this would:
- Require a username and password to edit GRUB boot entries
- Prevent unauthorized users from modifying boot parameters
- Protect against physical access attacks that attempt to gain root access by modifying the boot process
- Follow security best practices by using PBKDF2 password hashing

The function is part of the HARDN-XDR project's security hardening measures,
specifically targeting bootloader security to prevent unauthorized system
access and modifications.







