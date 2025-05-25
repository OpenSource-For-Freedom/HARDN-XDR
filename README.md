![GitHub release (latest by date)](https://img.shields.io/github/v/release/OpenSource-For-Freedom/HARDN?include_prereleases)

[![Auto Update Dependencies](https://github.com/OpenSource-For-Freedom/HARDN-XDR/actions/workflows/validate.yml/badge.svg)](https://github.com/OpenSource-For-Freedom/HARDN-XDR/actions/workflows/validate.yml)


<p align="center">
  <img src="https://img.shields.io/badge/OS: Debian Systems-red?style=for-the-badge&labelColor=grey" alt="OS: DEBIAN 12"><br><br>
</p>

<p align="center">
  <img src="docs/assets/HARDN(1).png" alt="HARDN Logo" width="300px" /><br><br>
  <img src="https://img.shields.io/badge/The_Linux_Security_Project-red?style=for-the-badge&labelColor=black" alt="The Linux Security Project"><br><br>
  <code>HARDN-XDR</code>
</p>



<p align="center">
  <img src="https://img.shields.io/badge/OVERVIEW-white?style=for-the-badge&labelColor=black" alt="OVERVIEW"><br><br>
</p>


### HARDN-XDR
- **Our** Goal: assist the open source community in building a Debian based **"GOLDEN IMAGE"** System.
- This Debian Package is only tested for **BARE-METAL installs of Debian based distributions and Virtual Machines**
- Is a robust and secure endpoint management solution designed to simplify and enhance the management of devices in your network. It provides advanced features for monitoring, securing, and maintaining endpoints efficiently.
- We also bring you with this release `STIG` COMPLIANCE to align with the Security Technical Information Guides provided by the DOD Cyber Exchange.

<p align="center">
  <img src="https://img.shields.io/badge/FEATURES-white?style=for-the-badge&labelColor=black" alt="FEATURES"><br><br>
</p>

- **Comprehensive Monitoring**: Real-time insights into endpoint performance and activity.
- **Enhanced Security**: Protect endpoints with advanced security protocols.
- **Scalability**: Manage endpoints across small to large-scale networks.
- **User-Friendly Interface**: Intuitive design for seamless navigation and management.
- **STIG Compliance**: This release brings the utmost, security for Debian Government based informatin systems. 

### File Structure


```bash
HARDN/
├── .gitignore
├── README.md
├── changelog.md
├── docs/
│   ├── deb_stig.md
│   ├── HARDN.md
│   ├── LICENSE
│   └── assets/
│       ├── HARDN(1).png
│       └── cybersynapse.png
├── src/
│   └── setup/
│       └── hardn-main.sh
├── debian/
│   ├── changelog
│   ├── control
│   ├── hardn.install
│   ├── postinst
│   └── rules
```

</p>


<p align="center">
  <img src="https://img.shields.io/badge/PURPOSE-white?style=for-the-badge&labelColor=black" alt="PURPOSE"><br><br>
</p>

The purpose of HARDN-XDR is to empower IT administrators and users with the tools they need to ensure endpoint security, optimize performance, and maintain compliance across their organization.

<p align="center">
  <img src="https://img.shields.io/badge/INSTALLATION-white?style=for-the-badge&labelColor=black" alt="INSTALLATION"><br><br>
</p>


## Quick Start: 

### Installation

1.  **Download the HARDN script:**
    Open your terminal and run the following command to download the main script:
    ```bash
    curl -LO https://raw.githubusercontent.com/OpenSource-For-Freedom/HARDN-XDR/main/src/setup/hardn-main.sh
    ```

2.  **Run the HARDN setup:**
    Launch the script with superuser privileges to begin the hardening process:
    ```bash
    sudo sh ./hardn-main.sh
    ```
    This will start the HARDN setup menu. Follow the on-screen prompts to configure and apply security hardening to your system. 


### Updates in Version 1.1.8
- Built and tested Debian packaging.
- Enhanced GRUB security to respect GUI changes and user-defined settings in setup.
- Improved error handling and script optimization.
- Interactive Setup
- Updated documentation and ensured cron jobs are non-intrusive.


### Installation Notes
- Ensure you have the latest version of Debian 12 or Ubuntu 24.04.
- Follow the updated installation steps in the `docs` directory.


<p align="center">
  <img src="https://img.shields.io/badge/PROJECT PARTNERS-white?style=for-the-badge&labelColor=black" alt="PROJECT PARTNERS"><br><br>
</p>


<p align="center">
  <img src="docs/assets/cybersynapse.png" alt="cybersynapse Logo" />
</p>



<p align="center">
  <img src="https://img.shields.io/badge/LICENSE-white?style=for-the-badge&labelColor=black" alt="LICENSE"><br><br>
This project is licensed under the MIT License
  
</p>


<p align="center">
  <img src="https://img.shields.io/badge/CONTACT-white?style=for-the-badge&labelColor=black" alt="CONTACT"><br><br>
office@cybersynapse.ro
</p>



