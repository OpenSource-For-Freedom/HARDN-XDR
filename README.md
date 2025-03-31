<p align="center">
        <img src="https://github.com/OpenSource-For-Freedom/HARDN/blob/Primary/Docs/HARDN.png" alt="HARDN Logo" />
</p>
 The Linux Security Project        ===================== TESTING AND DEVELOPING ====================


***A single UX based **Debian** tool to fully secure an OS using  automation, monitoring, heuristics and availability***
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

- Penetration Testing – Proactively scanning and testing for vulnerabilities to find weaknesses before attackers do.

- Automation – Reducing manual security tasks with scripts and tools that streamline system protection and performance tuning.

- OS Security – Locking down vulnerabilities while ensuring stability, speed, and reliability for Debian systems

---

## Tools

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
3. **Stay Updated** – Built-in automation via `cron` ensures **constant updates and maintenance** without user intervention.  

**The Goal** - Once installed, **HARDN runs in the background**—keeping your system tight **without slowing you down**.

> we are working on a 'headless' option to remove the gui, for server functionality. 
> We are also working on server and container compatibility.
---

## **Getting Started**  

### Clone the Repository**  
```bash
git clone https://github.com/opensource-for-freedom/HARDN.git
cd hardn
```
### Youll need Python 3 

```bash
sudo apt update && sudo apt install -y python3 python3-pip
pip install -r requirements.txt
```
### Install setup file
```bash
sudo ./setup.sh
```
### Run HARDN
```bash
chmod +x ./hardn.py
sudo ./hardn.py

```
## Check lynis output
The GUI Will show you the current system Lynis score (under development)

---
## Goals
- Replacing LMD with `Legion` – A dedicated malware scanner optimized for Linux.
> [LEGION](https://github.com/opensource-for-freedom/LEGION.git)
- Integrating Wazuh SIEM – Expanding system-wide monitoring for better incident response.
- Test and implement GRS, to help fully secure the Kernal. ( Cost associated )
- Expanding container security – Locking down VMs and containers without affecting performance and allow ssh referal. 
- Making it easier to use – Simplifying configurations for both end-users and professionals through smooth UX engagement. 
---
## Contributing
- Contact directly for access 
---

## License

- GPL License




