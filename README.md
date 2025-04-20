
  ![GitHub release (latest by date)](https://img.shields.io/github/v/release/OpenSource-For-Freedom/HARDN?include_prereleases)
  ![GitHub issues](https://img.shields.io/github/issues/OpenSource-For-Freedom/HARDN)
  ![GitHub stars](https://img.shields.io/github/stars/OpenSource-For-Freedom/HARDN)

<p align="center">
  <img src="docs/assets/HARDN(1).png" alt="HARDN Logo" width="300px" /><br><br>
  <img src="https://img.shields.io/badge/The_Linux_Security_Project-red?style=for-the-badge&labelColor=black" alt="The Linux Security Project"><br><br>
  <code>HARDN-Endpoint</code>
</p>

---

<p align="center">
  <img src="https://img.shields.io/badge/OVERVIEW-white?style=for-the-badge&labelColor=black" alt="OVERVIEW"><br><br>
</p>

## Abstract  
**HARDN** is an open-source framework built to help secure Debian-based Linux systems. It’s designed with modular automation in mind—making it easier to lock down vulnerabilities without sacrificing performance. Using a combination of Python, shell scripting, and strict security policies, HARDN creates systems that are more resilient and efficient from the ground up. This document outlines where the project stands, what tools it's using, and where it's headed as it prepares for the release of a polished `.deb` package.

---

## Introduction  
With cyber threats evolving daily, securing Linux systems—especially those based on Debian—has never been more important. **HARDN** steps in as a powerful, yet user-conscious toolset that automates the hardening process without overcomplicating it. It brings together battle-tested security methods, zero-trust principles, and modern tools like Ansible, AppArmor, and Fail2Ban. Whether you’re a sysadmin, developer, or security engineer, HARDN is designed to help you take back control of your system’s security.

---
<p align="center">
  <img src="https://img.shields.io/badge/FEATURES-white?style=for-the-badge&labelColor=black" alt="FEATURES"><br><br>
</p>

---

<p align="center">
  <img src="https://img.shields.io/badge/PURPOSE-white?style=for-the-badge&labelColor=black" alt="PURPOSE"><br><br>
</p>

## Repository Structure (Current Architecture)

As we approach the `.deb` packaging milestone, the repo has been distilled down to the essentials—making it lean, maintainable, and easy to audit:

- **hardn.rs** – The main automation engine, written in Rust, responsible for executing security tasks and validations synchronized with GUI input/output.
- **setup.sh** – A bootstrap script that prepares the environment and launches the hardening process.
- **packages.sh** – A curated package installer that fetches and configures essential tools for firewalling, monitoring, and malware detection.
- **kernel.c** – A C module that handles kernel optimization and module blacklisting, improving both security and boot-time efficiency.

This minimal setup ensures a lightweight installation that’s secure right out of the gate.

---

## Key Objectives of HARDN

### 1. System Hardening Research
We’ve looked closely at what’s worked in projects like Harbian and STIG enforcement and used that insight to build custom routines tailored for Debian.

### 2. Tightening File Permissions
To reduce risk, HARDN identifies and adjusts risky `setuid` and `setgid` permissions—making privilege escalation far less likely.

### 3. User Group Cleanup
Inspired by Whonix’s lean permission model, we remove unnecessary group access to lock down privilege escalation paths.

### 4. Locking Down System Configs
We harden critical files like `/etc/security/` and `/etc/host.conf` to:
- Enforce password rotations (every 72 days).
- Set lockouts after failed login attempts.
- Limit `sudo` usage.
- Secure update tools and the bootloader.

---

## Core Orchestration
1. Validates root access  
2. Sets executable permissions for key scripts  
3. Runs setup and package hardening scripts  
4. Compiles and runs kernel hardening (`kernel.c`)  
5. Launches your Python-based GUI  
6. Monitors file system for changes  
7. Installs and manages systemd services & timers  

---

## GUI Backend Integration
8. Starts a live in-memory backend with:
   - Authentication service  
   - Network monitor  
   - Threat detection  
   - Log manager  

9. Runs async threads to monitor:
   - Active network connections  
   - Threat detection loop  

10. Starts a Unix socket IPC server at `/tmp/hardn.sock`:
   - Accepts JSON requests from the GUI  
   - Supports actions: `auth`, `network`, `threats`, `logs`  
   - Returns structured JSON responses for each service  

---

## Pre-Release Activities

### 1. Log Monitoring & Threat Detection
We’re enabling lightweight auditing across important directories and using triggers to detect unusual behavior in real-time.

### 2. Reliable Backups & Rollbacks
Every hardening action has a corresponding recovery path—just in case.

### 3. Controlled Testing Environments
All changes are run in staging first, ensuring bugs are caught before rollout.

### 4. Transparent Documentation
All steps and logic are documented in Markdown, version-controlled, and open for review.

---

## Security Tools and Integrations

- **Lynis** – For regular security audits and actionable hardening suggestions.  
- **Fail2Ban** – Helps stop brute-force attacks by banning bad actors on the fly.  
- **LMD** - Linux Malware Detect  
- **UFW** – A user-friendly firewall system built on `iptables`.  
- **AppArmor** – Mandatory access control to restrict what applications can do.  
- **Firejail** – Sandboxes individual apps, limiting the damage they can do.  
- **Modprobe** – Used to blacklist unnecessary or dangerous kernel modules like `usb_storage`:  
```bash
echo "blacklist usb_storage" >> /etc/modprobe.d/blacklist.conf
```

---

<p align="center">
  <img src="https://img.shields.io/badge/FEATURES-white?style=for-the-badge&labelColor=black" alt="FEATURES"><br><br>
</p>

- **Comprehensive Monitoring**: Real-time insights into endpoint performance and activity.  
- **Enhanced Security**: Protect endpoints with advanced security protocols.  
- **Scalability**: Manage endpoints across small to large-scale networks.  
- **User-Friendly Interface**: Intuitive design for seamless navigation and management.  

---

<p align="center">
  <img src="https://img.shields.io/badge/INSTALLATION-white?style=for-the-badge&labelColor=black" alt="INSTALLATION"><br><br>
</p>

Coming Soon..

---

<p align="center">
  <img src="https://img.shields.io/badge/CONTRIBUTION-white?style=for-the-badge&labelColor=black" alt="CONTRIBUTION"><br><br>
We welcome contributions! 
</p>

---

<p align="center">
  <img src="https://img.shields.io/badge/PROJECT PARTNERS-white?style=for-the-badge&labelColor=black" alt="PROJECT PARTNERS"><br><br>
</p>

<p align="center">
  <img src="docs/assets/cybersynapse.png" alt="cybersynapse Logo" />
</p>

---

<p align="center">
  <img src="https://img.shields.io/badge/LICENSE-white?style=for-the-badge&labelColor=black" alt="LICENSE"><br><br>
This project is licensed under the GPLicense
</p>

---

<p align="center">
  <img src="https://img.shields.io/badge/CONTACT-white?style=for-the-badge&labelColor=black" alt="CONTACT"><br><br>
office@cybersynapse.ro
</p>

---

<p align="center">
===== FILE STRUCTURE =====

```
HARDN/
├── .github/                # workflows
│   └── workflows/
│       ├── deb-build.yml
│      
├── debian/                 # packaging files
│   ├── changelog
│   ├── compat
│   ├── control
│   ├── rules
│   ├── hardn.install
│   └── ...
├── src/                    # Source code
│   ├── gui/                # GUI-related files
│   │   ├── __init__.py
│   │   ├── app.py
│   │   ├── main_window.py
│   │   ├── docs/           # Documentation 
│   │   ├── controllers/
│   │   ├── models/
│   │   ├── resources/
│   │   ├── utils/
│   │   └── views/
│   ├── setup/              # Setup 
│   │   ├── setup.sh
│   │   └── packages.sh
│   ├── kernel.c           # Kernel hardening 
│   ├── hardn.rs           # Main entry point
│   └── ...
├── build/                  # build artifacts (ignored in `.gitignore`)
├── dist/                   # Distribution packages (ignored in `.gitignore`)
├── README.md               # Project documentation
├── Makefile                # Build automation
├── hardn.toml          
```
</p>


