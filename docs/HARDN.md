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

By leveraging **AIDE** and **YARA rules** together, the system provides comprehensive malware detection and response capabilities. This integrated approach enables both signature-based and heuristic detection, allowing for early identification of threats and rapid response. Regular scans and rule updates ensure that new and evolving malware patterns are recognized, supporting an effective extended detection and response (XDR) strategy.

## Monitoring & Reporting:
- Alerts and validation logs written to `/var/log/security/alerts.log` and `/var/log/security/validation.log`
- Cron setup for periodic security checks and updates

## About GRUB Security
GRUB Security is handled by the  `grub.sh`

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







