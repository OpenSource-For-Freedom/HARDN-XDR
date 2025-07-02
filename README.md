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


## Quick Start: 

### Installation
**Access it through the latest release**
- You will find the most recent Debian release here:
    [HARDN-XDR Debian Package](https://github.com/OpenSource-For-Freedom/HARDN-XDR/releases)
- Next:
- Automatically Detects Architecture
```bash
ARCH=$(dpkg --print-architecture)
VERSION=$(curl -s https://api.github.com/repos/OpenSource-For-Freedom/HARDN-XDR/releases/latest | grep tag_name | cut -d '"' -f4)
DEB_URL="https://github.com/OpenSource-For-Freedom/HARDN-XDR/releases/download/$VERSION/hardn_${VERSION#v}_${ARCH}.deb"

echo "Downloading: $DEB_URL"
wget "$DEB_URL" -O hardn-latest.deb
sudo apt install ./hardn-latest.deb
```

## Usage

After installation:
```bash
dpkg -l | grep hardn
sudo hardn-xdr
```
Options:
```bash
hardn-xdr --help
hardn-xdr --version
```

For detailed info and command-line options, consult the man page:
```bash
man hardn-xdr
```

### How the Interactive Menu Works
The interactive menu is the core of the `HARDN-XDR` script's flexibility, and it's powered by a standard Linux utility called `whiptail`. Here’s a breakdown of how it works inside the `setup_security` function in `hardn-main.sh`:

#### 1. Defining the Menu Items
First, a Bash array called `modules` is created. This array holds the definition for every single item that appears in the checklist menu. Each item consists of three parts:
- **The script filename**: e.g., `"ufw.sh"`
- **A user-friendly description**: e.g., `"Configure UFW Firewall"`
- **The default state**: `ON` (checked by default) or `OFF` (unchecked by default)

```bash
local modules=(
    "ufw.sh" "Configure UFW Firewall" ON
    "fail2ban.sh" "Install and configure Fail2Ban" ON
    "pentest.sh" "Install penetration testing tools" OFF
    # ... and so on
)
```

#### 2. Displaying the Menu
Next, the `whiptail` command is called with the `--checklist` option. It's given the title, the instructional text, and the `modules` array. `whiptail` then draws the interactive menu on the screen. When the user clicks "Ok", `whiptail` prints their selected choices as a string, which is captured in a variable.

```bash
choices=$(whiptail --title "HARDN-XDR Security Modules" --checklist \
    "Choose which security modules to apply:" 25 85 18 \
    "${modules[@]}" 3>&1 1>&2 2>&3)
```

#### 3. Executing the Selected Modules
Finally, the script loops through the user's choices. For each choice, it constructs the full path to the module script (e.g., `./modules/ufw.sh`), checks if the file exists, and then executes it using the `source` command.

```bash
for choice in $choices; do
    # ...
    local module_path="./modules/${choice//\"/}"
    if [ -f "$module_path" ]; then
        source "$module_path"
    fi
done
```
This approach makes the system very modular and easy to extend. To add a new hardening option, all that's needed is to create the new module script and add a corresponding entry to the `modules` array in `hardn-main.sh`.

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



<br>


## Actions

[![CI](https://github.com/OpenSource-For-Freedom/HARDN-XDR/actions/workflows/version-control.yml/badge.svg?branch=Securejump)](https://github.com/OpenSource-For-Freedom/HARDN-XDR/actions/workflows/version-control.yml)

<br>

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



