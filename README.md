
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
- This installation is only for **BARE-METAL INSTALLS of DEBIAN 12 and Ubunut 24.04 Bare Metal and Virtual Machines**
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
├── docs/*
│   ├── LICENSE
│   └── assets/
│       ├── HARDN(1).png
│       └── cybersynapse.png
├── src/
│   └── setup/
|       |__ hardn-grub.sh
│       ├── hardn-packages.sh
│       └── hardn-setup.sh
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
2. Navigate to the `src` directory:
 ```bash
  cd HARDN/src/setup
  sudo chmod +x hardn-setup.sh
  sudo ./hardn-setup.sh

  ```
  This will kick off the full setup of HARDN with `STIG` principles. 
  ### NOTE: 

  
  #### AIDE will 20-60 minutes to fully establish the "ADVANCED INTRUSION DETECTION SYSTEM" however, this runs in the background. 
  - This script will run syncronously and reboot your system when complete. 
  - DO-NOT turn your system off: We have established an update routine with reboots using CRON. 
  - HARDN in itself once executed, will keep your Debian system secure and up to date. 

6. Follow any additional setup instructions and information provided in the `docs` directory.
</p>

### MAINTAINERS

* Building a debian package
```bash
debuild -us -uc
```
* Clean the repo after building a debian package
```bash
debuild -- clean
```

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



