# HARDN: Included Packages and Settings


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
