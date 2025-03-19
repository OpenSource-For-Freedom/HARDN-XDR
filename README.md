         ██░ ██  ▄▄▄       ██▀███  ▓█████▄  ███▄    █ 
        ▓██░ ██▒▒████▄    ▓██ ▒ ██▒▒██▀ ██▌ ██ ▀█   █ 
        ▒██▀▀██░▒██  ▀█▄  ▓██ ░▄█ ▒░██   █▌▓██  ▀█ ██▒
        ░▓█ ░██ ░██▄▄▄▄██ ▒██▀▀█▄  ░▓█▄   ▌▓██▒  ▐▌██▒
        ░▓█▒░██▓ ▓█   ▓██▒░██▓ ▒██▒░▒████▓ ▒██░   ▓██░
         ▒ ░░▒░▒ ▒▒   ▓▒█░░ ▒▓ ░▒▓░ ▒▒▓  ▒ ░ ▒░   ▒ ▒ 
         ▒ ░▒░ ░  ▒   ▒▒ ░  ░▒ ░ ▒░ ░ ▒  ▒ ░ ░░   ░ ▒░
         ░  ░░ ░  ░   ▒     ░░   ░  ░ ░  ░    ░   ░ ░ 
         ░  ░  ░      ░  ░   ░        ░             ░ 
                            ░                 
                    The Linux Security Project
   ==========•=••••••••• Development ••••••••=•==========


# HARDN
---
A single **Debian** tool to fully secure an OS using automation, monitoring, heuristics, and keeping availability high.
---
# Table of Contents
## Table of Contents
- [Overview](##Overview)
- [Tools](##Tools)
- [How it works](##How_it_Works)
- [Getting Started](##Getting_Started)
- [Goals](##Goals)
- [Contributing](#contributing)
- [License](#license)
---
# **Overview**  

In the development of this repo, we aim to include all facets of **kernel hardening**, **penetration testing**, and **OS security** for Debian Linux systems, ensuring both security and stability.

We will always take suggestions and mention how to keep Linux secure and productivity high. 

This document outlines the pre-release activities that need to be completed before finalizing the project release.

These tasks are designed to reinforce security, improve performance, and streamline user management.

By following these guidelines, you will enhance system security, maintain stability, and optimize Debian-based systems for performance and resilience.

---

## Tools

- Lynis, Security auditing tool for Unix-based systems.
- Fail2Ban, Protects against brute-force attacks.
- UFW, Easy-to-configure firewall utility.
- Lynis Audit, to keep the base secure posture validated.
- AppArmor, Mandatory Access Control (MAC) for enforcing policies.
- LMD (Maldetect), (Soon to be replaced by Legion) Open-source antivirus software.
- Firejail, Sandboxing tool for application isolation.
- Cron, to keep it all automated.
- SELinux, Security-Enhanced Linux for enforcing security policies.

---

## How it works

1. **HARDN the System** – Applies firewall rules, intrusion detection, malware protection, and access control automatically.  
2. **Monitor & Defend** – Uses heuristic analysis, security audits, and automated updates to **stay ahead of threats**. (LEGION to come)
3. **Stay Updated** – Built-in automation via `cron` ensures **constant updates and maintenance** without user intervention.  

Once installed, **HARDN runs in the background**—keeping your system tight **without slowing you down**.

We are working on a 'headless' option to remove the GUI, for server functionality. 

---

## **Getting Started**  

### Clone the Repository
```bash
git clone https://github.com/opensource-for-freedom/HARDN.git
cd HARDN
```
### You'll need Python 3 
```bash
pip install -r requirements.txt
```
### Install HARDN system-wide
```bash
pip install -e .
```
### Run HARDN
```bash
hardn
```
## To update the system
rerun
```bash
sudo ./setup.sh
```
---
## Goals
- Replacing LMD with `Legion` – A dedicated malware scanner optimized for Linux.
- Integrating Wazuh SIEM – Expanding system-wide monitoring for better incident response.
- Expanding container security – Locking down VMs and containers without affecting performance.
- Push the file in two ways : HEADLESS systems monirot and USER role based deployments for endoints. 
- Making it easier to use – Simplifying configurations for both end-users and professionals.
- Conforming to the full CIA module for both Security and Availability. 
---
## Contributing
- Please do 🙂
- Contact directly for access 
---

## License

- MIT License