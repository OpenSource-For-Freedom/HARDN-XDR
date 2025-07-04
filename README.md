<p align="center">
  <img src="https://img.shields.io/badge/OS: Debian Systems-red?style=for-the-badge&labelColor=grey" alt="OS: DEBIAN 12"><br><br>
</p>

<p align="center">
  <img src="https://github.com/OpenSource-For-Freedom/HARDN-XDR/blob/main/docs/assets/HARDN%20(1).png" /><br><br>
  <img src="https://img.shields.io/badge/The_Linux_Security_Project-red?style=for-the-badge&labelColor=black" alt="The Linux Security Project"><br><br>
  <code>HARDN-XDR</code>
</p>


<p align="center">
  <img src="https://img.shields.io/endpoint?label=Views&url=https://opensource-for-freedom.github.io/HARDN-XDR/traffic-views.json" alt="Repository Views" />
  <img src="https://img.shields.io/endpoint?label=Clones&url=https://opensource-for-freedom.github.io/HARDN-XDR/traffic-clones.json" alt="Repository Clones" />
</p>


<br>
<br>
<p align="center">
  <img src="https://img.shields.io/badge/OVERVIEW-white?style=for-the-badge&labelColor=black" alt="OVERVIEW"><br><br>
</p>


## HARDN-XDR
[![ci](https://github.com/OpenSource-For-Freedom/HARDN-XDR/actions/workflows/ci.yml/badge.svg)](https://github.com/OpenSource-For-Freedom/HARDN-XDR/actions/workflows/ci.yml)
- **Our Goal**: 
  - Assist the open source community in building a Debian based **"GOLDEN IMAGE"** System.
- **Our Purpose**: 
  - To empower IT administrators and users with the tools they need to ensure endpoint security, optimize performance, and maintain compliance across their organization.
- **What we have to offer**:
  - A robust and secure endpoint management solution designed to simplify and enhance the management of devices in your network. 
  - Advanced features for monitoring, securing, and maintaining endpoints efficiently.
  - `STIG` COMPLIANCE to align with the [Security Technical Information Guides](https://public.cyber.mil/stigs/) provided by the [DOD Cyber Exchange](https://public.cyber.mil/).


<br>
<br>
<p align="center">
  <img src="https://img.shields.io/badge/FEATURES-white?style=for-the-badge&labelColor=black" alt="FEATURES"><br><br>
</p>

- **Comprehensive Monitoring**: Real-time insights into endpoint performance and activity.
- **Enhanced Security**: Protect endpoints with advanced security protocols.
- **Scalability**: Manage endpoints across small to large-scale networks.
- **User-Friendly Interface**: Intuitive design for seamless navigation and management.
- **Interactive Menu**: A user-friendly menu to select which hardening modules to apply.
- **STIG Compliance**: This release brings the utmost security for Debian Government based information systems. 


<br>
<br>
<p align="center">
  <img src="https://img.shields.io/badge/INSTALLATION-white?style=for-the-badge&labelColor=black" alt="INSTALLATION"><br><br>
</p>

## Quick Start

## HARDN-XDR Install

### Clone the Repo
```bash
git clone https://github.com/OpenSource-For-Freedom/HARDN-XDR
cd HARDN-XDR
```
### Build the Package
```bash
dpkg-buildpackage -us -uc
cd ..
sudo apt install ./hardn_*_amd64.deb
```
### Launch the Tool
```bash
sudo hardn-xdr
```

### To access the man page 

```bash
man hardn-xdr
```
---

### Installation Notes
- HARDN-XDR is currently being developed and tested for **BARE-METAL installs of Debian based distributions and Virtual Machines**.
- Ensure you have the latest version of **Debian 12**.
- By installing HARDN-XDR with the command listed in the installation, the following changes will be made to your system:
> - A collection of security focused packages will be installed.
> - Security tools and services will be enabled.
> - System hardening and STIG settings will be applied.
> - A malware and signature detection and response system will be set up.
> - A monitoring and reporting system will be activated. 
- For a detailed list of all that will be changed, please refer to [HARDN.md](docs/HARDN.md).
- For an overview of HARDN-Debian STIG Compliance, please refer to [deb_stig.md](docs/deb_stig.md).

---

## File Structure


```bash
HARDN-XDR/
├── debian/                
│   ├── changelog           
│   ├── compat              
│   ├── control             
│   ├── copyright           
│   ├── install   
│   ├── postinst  
│   └── rules               
├── docs/                 
│   ├── assets/            
│   ├── HARDN.md            
│   └── deb_stig.md        
├── install.sh              # Main installation script for the application.
├── LICENSE                 
├── man/                    
│   └── hardn-xdr.1         # Man page for the hardn-xdr command.
├── README.md               
└── src/                    
  └── setup/             
    ├── hardn-main.sh   # main script that launches the interactive menu.
    └── modules/        
```

<br>

<p align="center">
  <img src="https://img.shields.io/badge/PROJECT PARTNERS-white?style=for-the-badge&labelColor=black" alt="PROJECT PARTNERS"><br><br>
</p>


<p align="center">
  <img src="docs/assets/cybersynapse.png" alt="CyberSynapse Logo" />
</p>

<p align="center">
  <img src="docs/assets/securejump.jpg" alt="SecureJump Logo" />
</p>

<br>

<p align="center">
  <img src="https://img.shields.io/badge/LICENSE-white?style=for-the-badge&labelColor=black" alt="LICENSE"><br><br>
This project is licensed under the MIT License.
  
</p>

<br>

<p align="center">
  <img src="https://img.shields.io/badge/CONTACT-white?style=for-the-badge&labelColor=black" alt="CONTACT"><br><br>
office@cybersynapse.ro
<br>
contacto@securejump.cl
</p>



