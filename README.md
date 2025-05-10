![GitHub release (latest by date)](https://img.shields.io/github/v/release/OpenSource-For-Freedom/HARDN?include_prereleases)


<p align="center">
  <img src="https://img.shields.io/badge/OS: DEBIAN 12-red?style=for-the-badge&labelColor=grey" alt="OS: DEBIAN 12"><br><br>
</p>

<p align="center">
  <img src="docs/assets/HARDN(1).png" alt="HARDN Logo" width="300px" /><br><br>
  <img src="https://img.shields.io/badge/The_Linux_Security_Project-red?style=for-the-badge&labelColor=black" alt="The Linux Security Project"><br><br>
  <code>HARDN-Endpoint</code>
</p>



<p align="center">
  <img src="https://img.shields.io/badge/OVERVIEW-white?style=for-the-badge&labelColor=black" alt="OVERVIEW"><br><br>
</p>


### HARDN Endpoint
- This Debian Package is only for **BARE-METAL installs of Debian 12 and Ubuntu 24.04 Bare Metal and Virtual Machines**
-  Is a robust and secure endpoint management solution designed to simplify and enhance the management of devices in your network. It provides advanced features for monitoring, securing, and maintaining endpoints efficiently.
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
│   ├── deb_grub.md
│   ├── deb_stig.md
│   ├── HARDN.md
│   ├── LICENSE
│   └── assets/
│       ├── HARDN(1).png
│       └── cybersynapse.png
├── src/
│   └── setup/
│       ├── hardn-packages.sh
│       └── hardn-setup.sh
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

The purpose of HARDN Endpoint is to empower IT administrators and users with the tools they need to ensure endpoint security, optimize performance, and maintain compliance across their organization.

<p align="center">
  <img src="https://img.shields.io/badge/INSTALLATION-white?style=for-the-badge&labelColor=black" alt="INSTALLATION"><br><br>
</p>


1. Clone the repository from GitHub:
  ```bash
  git clone https://github.com/opensource-for-freedom/HARDN.git
  ```

2. Install the generated Debian package:
  ```bash
  sudo dpkg -i ../hardn_<version>.deb
  ```

3. Run the HARDN setup:
  ```bash
  sudo hardn
  ```

6. Follow any additional setup instructions and information provided in the `docs` directory.
</p>

### Quick Start: Install and Run HARDN on Debian/Ubuntu

1. **Clone the repository:**
   ```bash
   git clone https://github.com/OpenSource-For-Freedom/HARDN.git
   cd HARDN
   ```
2. **Build the Debian package:**
   ```bash
   sudo dpkg-buildpackage -us -uc
   ```
3. **Install the package:**
   ```bash
   sudo dpkg -i ../hardn_*.deb
   ```
4. **Run the setup:**
   ```bash
   sudo hardn
   ```

After installation, you can always start the hardening setup by running `sudo hardn` from any directory.

> **Note:**
> - The package installs system-wide and is available as the `hardn` command.
> - All dependencies are handled by the package.
> - For help, run: `hardn --help`

### Updates in Version 1.1.5
- Built and tested Debian packaging.
- Enhanced GRUB security to respect GUI changes and user-defined settings in setup.
- Improved error handling and script optimization.
- Updated documentation and ensured cron jobs are non-intrusive.

### Installation Notes
- Ensure you have the latest version of Debian 12 or Ubuntu 24.04.
- Follow the updated installation steps in the `docs` directory.


<p align="center">
  <img src="https://img.shields.io/badge/CONTRIBUTION-white?style=for-the-badge&labelColor=black" alt="CONTRIBUTION"><br><br>
We welcome contributions! 

![GitHub stats](https://github-readme-stats.vercel.app/api?username=opensource-for-freedom&show_icons=true&theme=dark)
![GitHub stats](https://github-readme-stats.vercel.app/api?username=AnonVortex&show_icons=true&theme=dark)
![GitHub stats](https://github-readme-stats.vercel.app/api?username=LinuxUser255&show_icons=true&theme=dark)

</p>

<p align="center">
  <img src="https://img.shields.io/badge/PROJECT PARTNERS-white?style=for-the-badge&labelColor=black" alt="PROJECT PARTNERS"><br><br>
</p>


<p align="center">
  <img src="docs/assets/cybersynapse.png" alt="cybersynapse Logo" />
</p>



<p align="center">
  <img src="https://img.shields.io/badge/LICENSE-white?style=for-the-badge&labelColor=black" alt="LICENSE"><br><br>
This project is licensed under the GPLicense
  
</p>


<p align="center">
  <img src="https://img.shields.io/badge/CONTACT-white?style=for-the-badge&labelColor=black" alt="CONTACT"><br><br>
office@cybersynapse.ro
</p>



