# HARDN Project Overview

## Abstract  
**HARDN** is an open-source framework built to help secure Debian-based Linux systems. It’s designed with modular automation in mind—making it easier to lock down vulnerabilities without sacrificing performance. Using a combination of Python, shell scripting, and strict security policies, HARDN creates systems that are more resilient and efficient from the ground up. This document outlines where the project stands, what tools it's using, and where it's headed as it prepares for the release of a polished `.deb` ...

## Introduction  
With cyber threats evolving daily, securing Linux systems—especially those based on Debian—has never been more important. **HARDN** steps in as a powerful, yet user-conscious toolset that automates the hardening process without overcomplicating it. It brings together battle-tested security methods, zero-trust principles, and modern tools like Ansible, AppArmor, and Fail2Ban. Whether you’re a sysadmin, developer, or security engineer, HARDN is designed to help you take back control of your system’s s...

## Repository Structure (Current Architecture)  
As we approach the `.deb` packaging milestone, the repo has been distilled down to the essentials—making it lean, maintainable, and easy to audit:

- **hardn.py** – The main automation engine, responsible for executing security tasks and validations.
- **setup.sh** – A bootstrap script that prepares the environment and launches the hardening process.
- **packages.sh** – A curated package installer that fetches and configures essential tools for firewalling, monitoring, and malware detection.
- **kernel.rs** – A Rust module that handles kernel optimization and module blacklisting, improving both security and boot-time efficiency.

This minimal setup ensures a lightweight installation that’s secure right out of the gate.

## Key Objectives of HARDN

### 1. System Hardening Research  
We’ve looked closely at what’s worked in projects like Harbian and STIG enforcement and used that insight to build custom routines tailored for Debian.

### 2. Tightening File Permissions  
To reduce risk, HARDN identifies and adjusts risky `setuid` and `setgid` permissions—making privilege escalation far less likely.  
**Example:**  
```bash
find / -mount -perm -2000 -type f -exec ls -ld {} \; > /home/user/setgid_.txt
```

### 3. User Group Cleanup  
Inspired by Whonix’s lean permission model, we remove unnecessary group access to lock down privilege escalation paths.

### 4. Locking Down System Configs  
We harden critical files like `/etc/security/` and `/etc/host.conf` to:
- Enforce password rotations (every 72 days).
- Set lockouts after failed login attempts.
- Limit `sudo` usage.
- Secure update tools and the bootloader.

## Pre-Release Activities

### 1. Log Monitoring & Threat Detection  
We’re enabling lightweight auditing across important directories and using triggers to detect unusual behavior in real-time.

### 2. Reliable Backups & Rollbacks  
Every hardening action has a corresponding recovery path—just in case.

### 3. Controlled Testing Environments  
All changes are run in staging first, ensuring bugs are caught before rollout.

### 4. Transparent Documentation  
All steps and logic are documented in Markdown, version-controlled, and open for review.

## Security Tools and Integrations

- **Lynis** – For regular security audits and actionable hardening suggestions.  
- **Fail2Ban** – Helps stop brute-force attacks by banning bad actors on the fly.  
- **UFW** – A user-friendly firewall system built on `iptables`.  
- **AppArmor** – Mandatory access control to restrict what applications can do.  
- **Firejail** – Sandboxes individual apps, limiting the damage they can do.  
- **LMD (Linux Malware Detect)** – Tailored to catch Linux-specific malware, better suited for our goals than traditional AV tools.  
- **Modprobe** – Used to blacklist unnecessary or dangerous kernel modules like `usb_storage`:
```bash
echo "blacklist usb_storage" >> /etc/modprobe.d/blacklist.conf
```

## Conclusion and Next Steps

HARDN is growing into more than just a local hardening toolkit—it’s becoming a full-stack security layer for operational Linux environments. Here’s what’s next:

### 1. Biometric Logins  
We’re working to integrate fingerprint and facial recognition for systems that support biometric authentication. It’s about adding another layer of security to local login workflows.

### 2. SIEM Integration  
Audit logs and security events will soon be exportable to platforms like Splunk, Wazuh, and Graylog. This means real-time alerts, threat correlation, and better visibility across your infrastructure.

### 3. Hardened Server Templates  
Pre-built, secure-by-default server configurations are coming—for web servers, VPN endpoints, and database nodes. These will cut down deployment time and eliminate guesswork.

### 4. STIG Compliance Mapping  
We're aligning HARDN’s configurations with DISA STIG guidelines so it can meet federal compliance standards and make audits smoother for regulated environments.

---

**HARDN** is here to prove that Linux hardening doesn’t need to be cryptic or fragile. It can be powerful, flexible, and designed with the user in mind. With a clean `.deb` installer on the way and enterprise-focused features in development, HARDN is on track to become a foundational security tool for both public and private sector deployments.