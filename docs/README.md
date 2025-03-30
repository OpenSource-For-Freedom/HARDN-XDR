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
<<<<<<< HEAD:README.md
   
===================== TESTING AND DEVELOPING ====================
=======
   ==========•=••••••••• Development ••••••••=•==========

>>>>>>> 09e83dac87335a3678a8043e704334f306637954:docs/README.md

# HARDN

## NEW UPDATE: pip install has been implimented to replace APT package install. 
---
<<<<<<< HEAD:README.md

A single UX based **Debian** tool to fully secure an OS using  automation, monitoring, heuristics and availability.
=======
A single **Debian** tool to fully secure an OS using automation, monitoring, heuristics, and keeping availability high.
>>>>>>> 09e83dac87335a3678a8043e704334f306637954:docs/README.md
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
# **Overview and Reciept of Mission**  

- Kernel Hardening – Fortifying the Linux kernel to block exploits, enforce strict access controls, and minimize attack surfaces.

<<<<<<< HEAD:README.md
- Penetration Testing – Proactively scanning and testing for vulnerabilities to find weaknesses before attackers do.
=======
We will always take suggestions and mention how to keep Linux secure and productivity high. 
>>>>>>> 09e83dac87335a3678a8043e704334f306637954:docs/README.md

- Automation – Reducing manual security tasks with scripts and tools that streamline system protection and performance tuning.

- OS Security – Locking down vulnerabilities while ensuring stability, speed, and reliability for Debian systems

---

## Tools

<<<<<<< HEAD:README.md
- Lynis,Security auditing tool for Unix-based systems.
- Fail2Ban,Protects against brute-force attacks.
- SELinux, a security feature in Linux that enforces strict access controls to protect the system from unauthorized actions, even by compromised or malicious processes.
- UFW,Easy-to-configure firewall utility.
- TCP wrappers, to bundle outbound/ inbound and predefined rules monitoring tool, host based. 
- Lynis Audit- to keep the base secure posture validated, and priovide a systems score.
- AppArmor,Mandatory Access Control (MAC) for enforcing policies.
- LMD (MALDETECT),(Soon to be replaced by Legion) Open-source antivirus software.
- Firejail,Sandboxing tool for application isolation.
- Cron, to keep it all omaintenance**
- Pex*, used for GRUB password hash automation 

1. **Secure the System** – Applies firewall rules, intrusion detection, malware protection, and access control automatically.  
2. **Monitor & Defend** – Soon to use heuristic analysis, security audits, and automated updates to **stay ahead of threats**.  (`Legion`)
=======
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
>>>>>>> 09e83dac87335a3678a8043e704334f306637954:docs/README.md
3. **Stay Updated** – Built-in automation via `cron` ensures **constant updates and maintenance** without user intervention.  

**The Goal** - Once installed, **HARDN runs in the background**—keeping your system tight **without slowing you down**.

<<<<<<< HEAD:README.md
> we are working on a 'headless' option to remove the gui, for server functionality. 
> We are also working on server and container compatibility.
=======
We are working on a 'headless' option to remove the GUI, for server functionality. 

>>>>>>> 09e83dac87335a3678a8043e704334f306637954:docs/README.md
---

## **Getting Started**  

### Clone the Repository
```bash
git clone https://github.com/opensource-for-freedom/HARDN.git
cd HARDN
```
<<<<<<< HEAD:README.md
### Youll need Python 3 

=======
### You'll need Python 3 
>>>>>>> 09e83dac87335a3678a8043e704334f306637954:docs/README.md
```bash
sudo apt update && sudo apt install -y python3 python3-pip
pip install -r requirements.txt
```
<<<<<<< HEAD:README.md
### Install setup file
=======
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
>>>>>>> 09e83dac87335a3678a8043e704334f306637954:docs/README.md
```bash
sudo ./setup.sh
```
### Run HARDN
```bash
chmod +x ./hardn.py
sudo ./hardn.py

#but if that doesn't run, then do the other one

chmod +x ./hardn_dark.py
sudo ./hardn_dark.py
```
## Check lynis output
The GUI Will show you the current system Lynis score (under development)

---
## Goals
- Replacing LMD with `Legion` – A dedicated malware scanner optimized for Linux.
<<<<<<< HEAD:README.md
> [LEGION](https://github.com/opensource-for-freedom/LEGION.git)
- Integrating Wazuh SIEM – Expanding system-wide monitoring for better incident response.
- Test and implement GRS, to help fully secure the Kernal. ( Cost associated )
- Expanding container security – Locking down VMs and containers without affecting performance and allow ssh referal. 
- Making it easier to use – Simplifying configurations for both end-users and professionals through smooth UX engagement. 
=======
- Integrating Wazuh SIEM – Expanding system-wide monitoring for better incident response.
- Expanding container security – Locking down VMs and containers without affecting performance.
- Push the file in two ways : HEADLESS systems monirot and USER role based deployments for endoints. 
- Making it easier to use – Simplifying configurations for both end-users and professionals.
- Conforming to the full CIA module for both Security and Availability. 
>>>>>>> 09e83dac87335a3678a8043e704334f306637954:docs/README.md
---
## Contributing
- Contact directly for access 
---

## License

- GPL License




