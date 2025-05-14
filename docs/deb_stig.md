# HARDN-Debian STIG Compliance Overview

This document summarizes the DISA STIG (Security Technical Implementation Guide) controls and hardening measures implemented by the HARDN project for Debian-based systems.

---

## Account and Authentication Controls

- **Password Policy:**  
  - Minimum password length: 14 characters  
  - Password complexity: requires upper, lower, digit, and special characters  
  - Password retry and enforcement for root  
  - Inactive accounts locked after 35 days

- **Login Banners:**  
  - Custom legal banners set in `/etc/issue` and `/etc/issue.net`

---

## System and Kernel Hardening

- **Filesystem Permissions:**  
  - Secure permissions on `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`

- **Kernel Parameters (sysctl):**  
  - ASLR enabled (`kernel.randomize_va_space = 2`)
  - ExecShield enabled
  - Kernel panic on oops
  - Kernel pointer and dmesg access restricted
  - Hardlink and symlink protection
  - ICMP, TCP, and source routing protections
  - IP forwarding disabled
  - IPv6 disabled

- **Core Dumps:**  
  - Core dumps disabled for all users

- **USB Storage:**  
  - USB storage module blacklisted

- **Ctrl+Alt+Del:**  
  - Disabled to prevent accidental reboots

---

## Auditing and Logging

- **Auditd:**  
  - Installed and enabled
  - Custom rules for monitoring changes to critical files (`/etc/passwd`, `/etc/shadow`, etc.)

- **AIDE:**  
  - Installed, initialized, and scheduled for regular integrity checks

---

## Network Security

- **Firewall (UFW):**  
  - Default deny incoming, allow outgoing  
  - Only essential outbound ports allowed (HTTP, HTTPS, DNS, NTP, Debian mirrors)

- **Fail2Ban:**  
  - SSH jail enabled  
  - No ssh root login (sshd) with auditing
  - Custom ban time, find time, and max retry settings

- **AppArmor:**  
  - Installed, enabled, and profiles reset

- **Firejail:**  
  - Sandboxing for browsers (Firefox, Chrome)

---

## Malware and Rootkit Detection

- **rkhunter:**  
  - Installed, updated, and configured

- **chkrootkit:**  
  - Installed and updated

- **Linux Malware Detect (maldet):**  
  - Installed and enabled

---

## Patch Management

- **fwupd:**  
  - Firmware update tool installed and run

- **System Updates:**  
  - Automated via script and cron

---

## Monitoring and Reporting

- **Alerts and Validation:**  
  - Security alerts and validation results written to `~/Desktop/HARDN_alerts.txt`
  - Cron jobs for periodic checks

---

## References

- [DISA STIG for Debian/Ubuntu](https://public.cyber.mil/stigs/downloads/)
- [CIS Debian Linux Benchmark](https://www.cisecurity.org/benchmark/debian_linux)

---