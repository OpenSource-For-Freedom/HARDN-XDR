#!/bin/bash

# HARDN-XDR - The Linux Security Hardening Sentinel
# Developed and built by chris Bingham and Tim Burns
# credit due: larbs.xyz

repo="https://github.com/OpenSource-For-Freedom/HARDN/"
progsfile="https://github.com/OpenSource-For-Freedom/HARDN/progs.csv"
repobranch="main-patch"
name=$(whoami)


############# ADD MENU HERE #############



print_ascii_banner() {
    cat << "EOF"

   ▄█    █▄            ▄████████         ▄████████      ████████▄       ███▄▄▄▄   
  ███    ███          ███    ███        ███    ███      ███   ▀███      ███▀▀▀██▄ 
  ███    ███          ███    ███        ███    ███      ███    ███      ███   ███ 
 ▄███▄▄▄▄███▄▄        ███    ███       ▄███▄▄▄▄██▀      ███    ███      ███   ███ 
▀▀███▀▀▀▀███▀       ▀███████████      ▀▀███▀▀▀▀▀        ███    ███      ███   ███ 
  ███    ███          ███    ███      ▀███████████      ███    ███      ███   ███ 
  ███    ███          ███    ███        ███    ███      ███   ▄███      ███   ███ 
  ███    █▀           ███    █▀         ███    ███      ████████▀        ▀█   █▀  
                                        ███    ███ 
                           
                            Extended Detection and Response
                            by Security International Group
                                   Version 1.1.8
EOF
}


# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
        echo ""
        echo "This script must be run as root."
        exit 1
fi

installpkg() {
       dpkg -s "$1" >/dev/null 2>&1 || sudo apt install -y "$1" >/dev/null 2>&1
}

error() {
        printf "%s\n" "$1" >&2
        exit 1
}

welcomemsg() {
        whiptail --title "HARDN-XDR" --backtitle "HARDN OS Security" --fb \
            --msgbox "\n\n Welcome to HARDN-XDR a Debian Security tool for System Hardening" 15 60

        whiptail --title "HARDN-XDR" --backtitle "HARDN OS Security" --fb \
            --yes-button "HARDN" \
            --no-button "RETURN..." \
            --yesno "\n\n\nThis installer will update your system first..\n\n" 12 70
}

preinstallmsg() {
        whiptail --title "Welcome to HARDN. A Linux Security Hardening program." --yes-button "HARDN" \
            --no-button "RETURN" \
            --yesno "\n\n\nThe Building the Debian System to ensure STIG and Security compliance\n\n" 13 60 || {
            clear
            exit 1
    }
}

update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    apt update && apt upgrade -y
    apt-get update -y
}

install_package_dependencies() {
        printf "\033[1;31[+] Installing package dependencies from progs.csv...\033[0m\n"
        progsfile="$1"
            if ! dpkg -s "$1" >/dev/null 2>&1; then
                whiptail --infobox "Installing $1... ($2)" 7 60
                sudo apt install update -qq
                sudo apt install -y "$1"
            else
                whiptail --infobox "$1 is already installed." 7 60
            fi
}

# Function to install packages with visual feedback
aptinstall() {
          package="$1"
          comment="$2"
          whiptail --title "HARDN Installation" \
              --infobox "Installing \`$package\` ($n of $total) from the repository. $comment" 9 70
          echo "$aptinstalled" | grep -q "^$package$" && return 1
          apt-get install -y "$package" >/dev/null 2>&1
          # Add to installed packages list
          aptinstalled="$aptinstalled\n$package"
  }

maininstall() {
       	# Installs all needed programs from main repo.
       	whiptail --title "HARDN Installation" --infobox "Installing \`$1\` ($n of $total). $1 $2" 9 70
       	installpkg "$1"
}

# Function to build and install from Git repo
gitdpkgbuild() {
        repo_url="$1"
        description="$2"
        dir="/tmp/$(basename "$repo_url" .git)"

        whiptail --infobox "Cloning $repo_url... ($description)" 7 70
        git clone --depth=1 "$repo_url" "$dir" >/dev/null 2>&1 || {
            whiptail --msgbox "Failed to clone $repo_url" 8 60
            return 1
        }
        cd "$dir" || { whiptail --msgbox "Failed to enter $dir" 8 60; return 1; }
        whiptail --infobox "Building and installing $description..." 7 70

        # Check and install build dependencies
        whiptail --infobox "Checking build dependencies for $description..." 7 70
        build_deps=$(dpkg-checkbuilddeps 2>&1 | grep -oP 'Unmet build dependencies: \K.*')
        if [ -n "$build_deps" ]; then
          whiptail --infobox "Installing build dependencies: $build_deps" 7 70
          apt-get install -y $build_deps >/dev/null 2>&1
        fi

        # Run dpkg-source before building (if debian/source/format exists)
        if [ -f debian/source/format ]; then
            dpkg-source --before-build . >/dev/null 2>&1
        fi

        # Build and install the package
        if dpkg-buildpackage -us -uc >/dev/null 2>&1; then
          debfile=$(ls ../*.deb | head -n1)
          if [ -n "$debfile" ]; then
            dpkg -i "$debfile"
          else
            whiptail --msgbox "No .deb file found after build." 8 60
            return 1
          fi
        else
          whiptail --infobox "$description failed to build. Installing common build dependencies and retrying..." 10 60
          apt-get install -y build-essential debhelper libpam-tmpdir apt-listbugs devscripts git-buildpackage >/dev/null 2>&1
          if dpkg-buildpackage -us -uc >/dev/null 2>&1; then
            debfile=$(ls ../*.deb | head -n1)
            if [ -n "$debfile" ]; then
              dpkg -i "$debfile"
            else
              whiptail --msgbox "No .deb file found after retry." 8 60
              return 1
            fi
          else
            whiptail --msgbox "$description failed to build after retry. Please check build dependencies." 10 60
            return 1
          fi
        fi
}

build_hardn_package() {
    set -e  

    whiptail --infobox "Building HARDN Debian package..." 7 60

    temp_dir=$(mktemp -d)
    cd "$temp_dir"

    git clone --depth=1 -b "$repobranch" "$repo"
    cd HARDN

    whiptail --infobox "Running dpkg-buildpackage..." 7 60
    dpkg-buildpackage -us -uc

    cd ..
    whiptail --infobox "Installing HARDN package..." 7 60
    dpkg -i hardn_*.deb || true  

    apt-get install -f -y

    cd /
    rm -rf "$temp_dir"

    whiptail --infobox "HARDN package installed successfully" 7 60
}


# Main loop to parse and install
installationloop() {
        [ -f "$progsfile" ] && cp "$progsfile" /tmp/progs.csv ||
                curl -Ls "$progsfile" | sed '/^#/d' >/tmp/progs.csv
        total=$(wc -l </tmp/progs.csv)
        echo "[INFO] Found $total entries to process."
        # Get list of manually installed packages (not installed as dependencies)
        aptinstalled=$(apt-mark showmanual)
        while IFS=, read -r tag program comment; do
            n=$((n + 1))
            echo "➤ Processing: $program [$tag]"

            # Strip quotes from comments
            echo "$comment" | grep -q "^\".*\"$" &&
                comment="$(echo "$comment" | sed -E "s/(^\"|\"$)//g")"

            case "$tag" in
                a) aptinstall "$program" "$comment" ;;
                G) gitdpkgbuild "$program" "$comment" ;;
                *) maininstall "$program" "$comment"
            esac
        done </tmp/progs.csv
}

putgitrepo() {
        # Downloads a gitrepo $1 and places the files in $2 only overwriting conflicts
        printf "\033[1;32m[+] Downloading and installing files...\033[0m\n"
        [ -z "$3" ] && branch="master" || branch="$repobranch"
        dir=$(mktemp -d)
        [ ! -d "$2" ] && mkdir -p "$2"
        chown "$name":wheel "$dir" "$2"
        sudo -u "$name" git -C "$repodir" clone --depth 1 \
            --single-branch --no-tags -q --recursive -b "$branch" \
            --recurse-submodules "$1" "$dir"
        sudo -u "$name" cp -rfT "$dir" "$2"
}

config_selinux() {
        printf "\033[1;31m[+] Installing and configuring SELinux...\033[0m\n"

        # Configure SELinux to enforcing mode
        setenforce 1 2>/dev/null || whiptail --msgbox "Could not set SELinux to enforcing mode immediately" 8 60

        # Configure SELinux to be enforcing at boot
        if [ -f /etc/selinux/config ]; then
            sed -i 's/SELINUX=disabled/SELINUX=enforcing/' /etc/selinux/config
            sed -i 's/SELINUX=permissive/SELINUX=enforcing/' /etc/selinux/config
            whiptail --infobox "SELinux configured to enforcing mode at boot" 7 60
        else
            whiptail --msgbox "SELinux config file not found" 8 60
        fi

        whiptail --infobox "SELinux installation and configuration completed" 7 60
}

# Install system security tools
# Check if packages are already installed before installing
check_security_tools() {
  printf "\033[1;31m[+] Checking for security packages are installed...\033[0m\n"
        for pkg in ufw fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums rkhunter libpam-pwquality libvirt-daemon-system libvirt-clients qemu-kvm docker.io docker-compose openssh-server ; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                whiptail --infobox "Installing $pkg..." 7 60
                apt install -y "$pkg"
            else
                whiptail --infobox "$pkg is already installed." 7 60
            fi
        done
}

enable_suricata() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Enabling Suricata...\033[0m\n" >&2
        if ! dpkg -s suricata >/dev/null 2>&1; then
            echo 30
            sleep 0.2
            printf "\033[1;31m[+] Installing Suricata...\033[0m\n" >&2
            apt install -y suricata
        else
            echo 30
            sleep 0.2
            printf "\033[1;31m[+] Suricata is already installed.\033[0m\n" >&2
        fi
        echo 70
        sleep 0.2
        systemctl enable --now suricata
        echo 100
        sleep 0.2
    } | whiptail --gauge "Installing and enabling Suricata..." 8 60 0
}


enable_rkhunter() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Enabling rkhunter...\033[0m\n"
        if ! dpkg -s rkhunter >/dev/null 2>&1; then
            whiptail --infobox "Installing rkhunter..." 7 60
            apt install -y rkhunter
        else
            whiptail --infobox "rkhunter is already installed." 7 60
        fi
        echo 40
        sleep 0.2

        
        sed -i 's/^#\?ENABLE_TESTS=.*/ENABLE_TESTS=all/' /etc/rkhunter.conf
        sed -i 's/^#\?MAIL-ON-WARNING=.*/MAIL-ON-WARNING="root"/' /etc/rkhunter.conf
        sed -i 's/^#\?MAIL-ON-ERROR=.*/MAIL-ON-ERROR="root"/' /etc/rkhunter.conf
        echo 60
        sleep 0.2

        
        rkhunter --update --quiet
        rkhunter --propupd --quiet
        echo 100
        sleep 0.2
    } | whiptail --gauge "Installing and configuring rkhunter..." 8 60 0

    printf "\033[1;32m[+] rkhunter installed and configured.\033[0m\n"
}

configure_firejail() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Configuring Firejail for Firefox, Chrome, Brave, and Tor Browser...\033[0m\n"

        if ! command -v firejail > /dev/null 2>&1; then
            printf "\033[1;31m[-] Firejail is not installed. Please install it first.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 20
        sleep 0.2

        if command -v firefox > /dev/null 2>&1; then
            printf "\033[1;31m[+] Setting up Firejail for Firefox...\033[0m\n"
            ln -sf /usr/bin/firejail /usr/local/bin/firefox
        else
            printf "\033[1;31m[-] Firefox is not installed. Skipping Firejail setup for Firefox.\033[0m\n"
        fi
        echo 40
        sleep 0.2

        if command -v google-chrome > /dev/null 2>&1; then
            printf "\033[1;31m[+] Setting up Firejail for Google Chrome...\033[0m\n"
            ln -sf /usr/bin/firejail /usr/local/bin/google-chrome
        else
            printf "\033[1;31m[-] Google Chrome is not installed. Skipping Firejail setup for Chrome.\033[0m\n"
        fi
        echo 60
        sleep 0.2

        if command -v brave-browser > /dev/null 2>&1; then
            printf "\033[1;31m[+] Setting up Firejail for Brave Browser...\033[0m\n"
            ln -sf /usr/bin/firejail /usr/local/bin/brave-browser
        else
            printf "\033[1;31m[-] Brave Browser is not installed. Skipping Firejail setup for Brave.\033[0m\n"
        fi
        echo 80
        sleep 0.2

        if command -v torbrowser-launcher > /dev/null 2>&1; then
            printf "\033[1;31m[+] Setting up Firejail for Tor Browser...\033[0m\n"
            ln -sf /usr/bin/firejail /usr/local/bin/torbrowser-launcher
        else
            printf "\033[1;31m[-] Tor Browser is not installed. Skipping Firejail setup for Tor Browser.\033[0m\n"
        fi
        echo 100
        sleep 0.2

        printf "\033[1;31m[+] Firejail configuration completed.\033[0m\n"
    } | whiptail --gauge "Configuring Firejail for browsers..." 8 60 0
}

# UFW configuration
configure_ufw() {
        printf "\\033[1;31m[+] Configuring UFW...\\\\033[0m\\\\n"
        
      
        if ! ufw status | grep -qw active; then
            printf "\\033[1;33m[*] UFW is not active. Enabling...\\\\033[0m\\\\n"
            yes | ufw enable 
        fi

        ufw default deny incoming
        ufw default allow outgoing
        
        
        ufw allow ssh 
        
        
        ufw allow out to any port 53 proto tcp
        ufw allow out to any port 80 proto tcp
        ufw allow out to any port 443 proto tcp
        
        
        ufw allow out to any port 53 proto udp
        ufw allow out to any port 123 proto udp
        
        
        ufw allow out to any port 67 proto udp
        ufw allow out to any port 68 proto udp

       
        if ufw status | grep -qw active; then
            printf "\\033[1;31m[+] Reloading UFW rules...\\\\033[0m\\\\n"
            ufw reload
        else
            printf "\\033[1;31m[-] UFW is not active, cannot reload. Please check UFW status manually.\\\\033[0m\\\\n"
        fi
}

enable_yara() {
    printf "\033[1;31m[+] Configuring YARA rules...\033[0m\n"
    whiptail --title "YARA Notice" --msgbox "The 'YARA' tool will be configured to scan for malware and suspicious files. You can review the logs in /var/log/yara_scan.log." 12 70

    {
        echo 5
        sleep 0.2

        if ! command -v yara >/dev/null 2>&1; then
            printf "\033[1;31m[+] Configuring YARA...\033[0m\n"
            DEBIAN_FRONTEND=noninteractive apt-get -y install yara || {
                printf "\033[1;31m[-] Failed to install YARA.\033[0m\n"
                echo 100
                sleep 0.2
                return 1
            }
        fi
        echo 15
        sleep 0.2

        yara_rules_dir="/etc/yara/rules"
        mkdir -p "$yara_rules_dir"
        echo 20
        sleep 0.2

        printf "\033[1;31m[+] Downloading YARA rules...\033[0m\n"
        yara_rules_zip="/tmp/yara-rules.zip"
        if ! wget -q "https://github.com/Yara-Rules/rules/archive/refs/heads/master.zip" -O "$yara_rules_zip"; then
            printf "\033[1;31m[-] Failed to download YARA rules.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 30
        sleep 0.2

        tmp_extract_dir="/tmp/yara-rules-extract"
        mkdir -p "$tmp_extract_dir"

        printf "\033[1;31m[+] Extracting YARA rules...\033[0m\n"
        if ! unzip -q -o "$yara_rules_zip" -d "$tmp_extract_dir"; then
            printf "\033[1;31m[-] Failed to extract YARA rules.\033[0m\n"
            rm -f "$yara_rules_zip"
            rm -rf "$tmp_extract_dir"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 40
        sleep 0.2

        rules_dir=$(find "$tmp_extract_dir" -type d -name "rules-*" | head -n 1)
        if [ -z "$rules_dir" ]; then
            printf "\033[1;31m[-] Failed to find extracted YARA rules directory.\033[0m\n"
            rm -f "$yara_rules_zip"
            rm -rf "$tmp_extract_dir"
            echo 100
            sleep 0.2
            return 1
        fi
        echo 50
        sleep 0.2

        printf "\033[1;31m[+] Copying YARA rules to $yara_rules_dir...\033[0m\n"
        cp -rf "$rules_dir"/* "$yara_rules_dir/" || {
            printf "\033[1;31m[-] Failed to copy YARA rules.\033[0m\n"
            rm -f "$yara_rules_zip"
            rm -rf "$tmp_extract_dir"
            echo 100
            sleep 0.2
            return 1
        }
        echo 60
        sleep 0.2

        printf "\033[1;31m[+] Setting proper permissions on YARA rules...\033[0m\n"
        chown -R root:root "$yara_rules_dir"
        chmod -R 644 "$yara_rules_dir"
        find "$yara_rules_dir" -type d -exec chmod 755 {} \;
        echo 65
        sleep 0.2

        if [ ! -f "$yara_rules_dir/index.yar" ]; then
            printf "\033[1;31m[+] Creating index.yar file for YARA rules...\033[0m\n"
            find "$yara_rules_dir" -name "*.yar" -not -name "index.yar" | while read -r rule_file; do
                echo "include \"${rule_file#$yara_rules_dir/}\"" >> "$yara_rules_dir/index.yar"
            done
        fi
        echo 70
        sleep 0.2

        printf "\033[1;31m[+] Testing YARA functionality...\033[0m\n"
        if ! yara -r "$yara_rules_dir/index.yar" /tmp >/dev/null 2>&1; then
            printf "\033[1;33m[!] YARA test failed. Rules might need adjustment.\033[0m\n"
            echo 'rule test_rule {strings: $test = "test" condition: $test}' > "$yara_rules_dir/test.yar"
            echo 'include "test.yar"' > "$yara_rules_dir/index.yar"
            if ! yara -r "$yara_rules_dir/index.yar" /tmp >/dev/null 2>&1; then
                printf "\033[1;31m[-] YARA installation appears to have issues.\033[0m\n"
            else
                printf "\033[1;32m[+] Basic YARA test rule works. Original rules may need fixing.\033[0m\n"
            fi
        else
            printf "\033[1;32m[+] YARA rules successfully installed and tested.\033[0m\n"
        fi
        echo 80
        sleep 0.2

        printf "\033[1;31m[+] Setting up YARA scanning in crontab...\033[0m\n"
        if grep -q "/usr/bin/yara.*index.yar" /etc/crontab; then
            sed -i '/\/usr\/bin\/yara.*index.yar/d' /etc/crontab
        fi

        touch /var/log/yara_scan.log
        chmod 640 /var/log/yara_scan.log
        chown root:adm /var/log/yara_scan.log
        echo 90
        sleep 0.2

        printf "\033[1;31m[+] Cleaning up temporary YARA files...\033[0m\n"
        rm -f "$yara_rules_zip"
        rm -rf "$tmp_extract_dir"
        echo 100
        sleep 0.2
    } | whiptail --gauge "Installing and configuring YARA..." 8 60 0

    printf "\033[1;32m[+] YARA configuration completed successfully.\033[0m\n"
}

stig_kernel_setup() {
     
    printf "\033[1;31m[+] Setting up STIG-compliant kernel parameters (login-safe)...\033[0m\n"
    tee /etc/sysctl.d/stig-kernel-safe.conf > /dev/null <<EOF

# Address Space Layout Randomization (ASLR)
kernel.randomize_va_space = 2

# Restrict kernel pointers in /proc
kernel.kptr_restrict = 2

# Restrict dmesg to root
kernel.dmesg_restrict = 1

# Protect hardlinks and symlinks
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Disable core dumps for SUID programs
fs.suid_dumpable = 0

# Disable magic SysRq key
kernel.sysrq = 0

# Use PID in core dump filenames
kernel.core_uses_pid = 1

# Restrict ptrace
kernel.yama.ptrace_scope = 1

# IPv4 network hardening
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

    sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
    sysctl -w kernel.randomize_va_space=2 || printf "\033[1;31m[-] Failed to set kernel Security Parameters.\033[0m\n"
}

#### banner removed 

stig_harden_ssh() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Hardening SSH configuration...\033[0m\n"

        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        echo 15
        sleep 0.2

        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        echo 20
        sleep 0.2

        sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
        echo 25
        sleep 0.2

        sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
        echo 30
        sleep 0.2

        # Harden SSH options as per SSH-7408
        sed -i '/^AllowTcpForwarding /d' /etc/ssh/sshd_config
        echo "AllowTcpForwarding no" >> /etc/ssh/sshd_config

        sed -i '/^ClientAliveCountMax /d' /etc/ssh/sshd_config
        echo "ClientAliveCountMax 2" >> /etc/ssh/sshd_config

        sed -i '/^Compression /d' /etc/ssh/sshd_config
        echo "Compression no" >> /etc/ssh/sshd_config

        sed -i '/^LogLevel /d' /etc/ssh/sshd_config
        echo "LogLevel VERBOSE" >> /etc/ssh/sshd_config

        sed -i '/^MaxAuthTries /d' /etc/ssh/sshd_config
        echo "MaxAuthTries 3" >> /etc/ssh/sshd_config

        sed -i '/^MaxSessions /d' /etc/ssh/sshd_config
        echo "MaxSessions 2" >> /etc/ssh/sshd_config

        sed -i '/^Port /d' /etc/ssh/sshd_config
        # Uncomment and set your custom port below (replace 22 with your port)
        # echo "Port 22" >> /etc/ssh/sshd_config

        sed -i '/^TCPKeepAlive /d' /etc/ssh/sshd_config
        echo "TCPKeepAlive no" >> /etc/ssh/sshd_config

        sed -i '/^X11Forwarding /d' /etc/ssh/sshd_config
        echo "X11Forwarding no" >> /etc/ssh/sshd_config

        sed -i '/^AllowAgentForwarding /d' /etc/ssh/sshd_config
        echo "AllowAgentForwarding no" >> /etc/ssh/sshd_config

        echo 60
        sleep 0.2

        sed -i '/^AllowUsers /d' /etc/ssh/sshd_config
        sed -i '/^Ciphers /d' /etc/ssh/sshd_config
        sed -i '/^MACs /d' /etc/ssh/sshd_config

        echo "AllowUsers your_user" >> /etc/ssh/sshd_config
        echo "Ciphers aes256-ctr,aes192-ctr,aes128-ctr" >> /etc/ssh/sshd_config
        echo "MACs hmac-sha2-512,hmac-sha2-256" >> /etc/ssh/sshd_config
        echo 85
        sleep 0.2

        systemctl restart sshd || {
            printf "\033[1;31m[-] Failed to restart SSH service. Check your configuration.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        }
        echo 100
        sleep 0.2
    } | whiptail --gauge "Hardening SSH configuration..." 8 60 0

    printf "\033[1;32m[+] SSH configuration hardened successfully.\033[0m\n"
}


stig_set_randomize_va_space() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Setting kernel.randomize_va_space...\033[0m\n"
        echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/hardn.conf
        echo 50
        sleep 0.2
        if ! sysctl --system; then
            printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
            echo 100
            sleep 0.2
            exit 1
        fi
        echo 80
        sleep 0.2
        if ! sysctl -w kernel.randomize_va_space=2; then
            printf "\033[1;31m[-] Failed to set kernel.randomize_va_space.\033[0m\n"
            echo 100
            sleep 0.2
            exit 1
        fi
        echo 100
        sleep 0.2
    } | whiptail --gauge "Setting kernel.randomize_va_space..." 8 60 0
}


enable_services() {
       printf "\033[1;31m[+] Enabling and starting Fail2Ban and AppArmor services...\033[0m\n"
       systemctl enable --now fail2ban
       systemctl enable --now apparmor
}


install_additional_tools() {
          printf "\033[1;31m[+] Installing chkrootkit...\033[0m\n"
          apt install -y chkrootkit

          # Initialize the variable
          install_maldet_failed=false


        printf "\033[1;31m[+] Installing chkrootkit...\033[0m\n"
        apt install -y chkrootkit


        # Create a temporary directory for the installation
        temp_dir=$(mktemp -d)
        cd "$temp_dir" || {
            printf "\033[1;31m[-] Failed to create temporary directory\033[0m\n"
            install_maldet_failed=true
    }

    # Try to install from GitHub
    if [ "$install_maldet_failed" != "true" ]; then
        printf "\033[1;31m[+] Cloning Linux Malware Detect from GitHub...\033[0m\n"
        if git clone https://github.com/rfxn/linux-malware-detect.git; then
            cd linux-malware-detect || {
                printf "\033[1;31m[-] Failed to change to maldetect directory\033[0m\n"
                install_maldet_failed=true
            }

            if [ "$install_maldet_failed" != "true" ]; then
                printf "\033[1;31m[+] Running maldetect installer...\033[0m\n"
                chmod +x install.sh
                if ./install.sh; then
                    # Add a small delay and ensure we are on a clean line
                    sleep 0.2
                    echo "" 

                    local msg_title="Maldet GitHub Install"
                    local msg_text="Linux Malware Detect installed successfully via GitHub."
                    local msg_height=8
                    local msg_width=70
                    
                    printf "\\033[1;34mHARDN_SCRIPT: Attempting to display maldet success message via whiptail.\\033[0m\\n"

                    if [ -z "$TERM" ] || [ "$TERM" == "dumb" ]; then
                        printf "\\033[1;33mHARDN_SCRIPT_WARNING: TERM variable is '$TERM'. Whiptail might not display. Using echo.\\033[0m\\n"
                        echo "$msg_title: $msg_text"
                    elif ! command -v whiptail > /dev/null; then
                        printf "\\033[1;31mHARDN_SCRIPT_ERROR: whiptail command not found! Cannot display message.\\033[0m\\n"
                    else
                        whiptail --title "$msg_title" --infobox "$msg_text" "$msg_height" "$msg_width"
                        local whiptail_status=$?
                        if [ $whiptail_status -ne 0 ]; then
                            printf "\\033[1;31mHARDN_SCRIPT_ERROR: Whiptail for maldet success message exited with status %s.\\033[0m\\n" "$whiptail_status"
                        else
                            printf "\\033[1;34mHARDN_SCRIPT: Whiptail maldet success message displayed.\\033[0m\\n"
                        fi
                    fi
                    
                    printf "\\033[1;32m[+] Linux Malware Detect installed successfully from GitHub\\033[0m\\n" # Original success message
                    install_maldet_failed=false # Ensure this is correctly set
                else
                    printf "\\033[1;31m[-] Maldetect installer script (./install.sh) failed.\\033[0m\\n"
                    install_maldet_failed=true
                fi
            fi
        else
            printf "\033[1;31m[-] Failed to clone maldetect repository\033[0m\n"
            install_maldet_failed=true
        fi
    fi

    # If GitHub method failed, try apt
    if [ "$install_maldet_failed" = "true" ]; then
        printf "\033[1;31m[+] Attempting to install maldetect via apt...\033[0m\n"
        if apt install -y maldetect; then
            printf "\033[1;31m[+] Maldetect installed via apt\033[0m\n"
            if command -v maldet >/dev/null 2>&1; then
                maldet -u
                whiptail --infobox "Maldetect updated successfully"
                printf "\033[1;31m[+] Maldetect updated successfully\033[0m\n"
                install_maldet_failed=false
            fi
        else
            printf "\033[1;31m[-] Apt installation failed\033[0m\n"
            install_maldet_failed=true
        fi
    fi

    # If both methods failed, provide manual instructions
    if [ "$install_maldet_failed" = "true" ]; then
        printf "\033[1;31m[-] All installation methods for maldetect failed.\033[0m\n"
        printf "\033[1;31m[-] Please install manually after setup completes using one of these methods:\033[0m\n"
        printf "\033[1;31m[-] 1. apt install maldetect\033[0m\n"
        printf "\033[1;31m[-] 2. git clone https://github.com/rfxn/linux-malware-detect.git && cd linux-malware-detect && ./install.sh\033[0m\n"
    fi

    # Clean up and return to original directory
    cd /tmp || true
    rm -rf "$temp_dir"
}


stig_password_policy() {

    # Set password quality requirements
    sed -i 's/^#\? *minlen *=.*/minlen = 14/' /etc/security/pwquality.conf
    sed -i 's/^#\? *dcredit *=.*/dcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *ucredit *=.*/ucredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *ocredit *=.*/ocredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *lcredit *=.*/lcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *enforcing *=.*/enforcing = 1/' /etc/security/pwquality.conf

    # Set password aging policy
    sed -i '/^PASS_MIN_DAYS/d' /etc/login.defs
    sed -i '/^PASS_MAX_DAYS/d' /etc/login.defs
    sed -i '/^PASS_WARN_AGE/d' /etc/login.defs
    echo "PASS_MIN_DAYS 1" >> /etc/login.defs
    echo "PASS_MAX_DAYS 90" >> /etc/login.defs
    echo "PASS_WARN_AGE 7" >> /etc/login.defs

    # Set password hashing rounds (AUTH-9230)
    sed -i '/^ENCRYPT_METHOD/d' /etc/login.defs
    sed -i '/^SHA_CRYPT_MIN_ROUNDS/d' /etc/login.defs
    sed -i '/^SHA_CRYPT_MAX_ROUNDS/d' /etc/login.defs
    echo "ENCRYPT_METHOD SHA512" >> /etc/login.defs
    echo "SHA_CRYPT_MIN_ROUNDS 5000" >> /etc/login.defs
    echo "SHA_CRYPT_MAX_ROUNDS 10000" >> /etc/login.defs

    # Set expire dates for all password protected accounts (AUTH-9282)
    awk -F: '($2 ~ /^\$/ && $1 != "root" && $1 != "nobody" && $3 >= 1000) {print $1}' /etc/shadow | while read -r user; do
        chage -M 90 -m 1 -W 7 "$user"
    done

    # Activate pam_pwquality profile
    if command -v pam-auth-update > /dev/null; then
        pam-auth-update --package
        echo "[+] pam_pwquality profile activated via pam-auth-update"
    else
        echo "[!] pam-auth-update not found. Install 'libpam-runtime' to manage PAM profiles safely."
    fi
}

enable_aide() {
    printf "\033[1;31m[+] Installing and configuring AIDE...\033[0m\n"
    {
        echo 10
        sleep 0.2

        if ! dpkg -l | grep -qw aide; then
            DEBIAN_FRONTEND=noninteractive apt-get -y install aide aide-common || {
                printf "\033[1;31m[-] Failed to install AIDE.\033[0m\n"
                echo 100
                sleep 0.2
                return 1
            }
        fi

        echo 30
        sleep 0.2

        mkdir -p /etc/aide
        chmod 750 /etc/aide
        chown root:root /etc/aide

        # Use SHA512 for checksums, and ensure config is valid
        cat > /etc/aide/aide.conf << 'EOF'
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new

# Use SHA512 for checksums (FINT-4402)
Checksums = sha512

# Basic rules
NORMAL = p+i+n+u+g+s+b+m+c+sha512
HARD = p+i+n+u+g+s+b+m+c+sha512

# Monitor only important system dirs, skip volatile/user data
/etc    HARD
/bin    NORMAL
/sbin   NORMAL
/usr    NORMAL
/lib    NORMAL
/boot   NORMAL
/var    NORMAL
/root   NORMAL
/tmp    NORMAL
/dev    NORMAL
/etc/ssh    NORMAL

!/proc
!/sys
!/dev
!/run
!/run/user         
!/mnt
!/media
!/home
!/home/user*/.cache
EOF

        chmod 640 /etc/aide/aide.conf
        chown root:root /etc/aide/aide.conf

        # Validate AIDE config (FINT-4315)
        if ! aide --config-check --config=/etc/aide/aide.conf >/dev/null 2>&1; then
            printf "\033[1;31m[-] AIDE configuration file contains errors. Please review /etc/aide/aide.conf\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi

        echo 50
        sleep 0.2

        if [ ! -f /var/lib/aide/aide.db ]; then
            aide --init --config=/etc/aide/aide.conf || {
                printf "\033[1;31m[-] Failed to initialize AIDE database.\033[0m\n"
                echo 100
                sleep 0.2
                return 1
            }
            mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
            chmod 600 /var/lib/aide/aide.db
        fi

        # Validate AIDE database (FINT-4316)
        if ! aide --check --config=/etc/aide/aide.conf >/dev/null 2>&1; then
            printf "\033[1;31m[-] AIDE database check failed. Please review the database and configuration.\033[0m\n"
            echo 100
            sleep 0.2
            return 1
        fi

        echo 70
        sleep 0.2

        cat > /etc/systemd/system/aide-check.service << 'EOF'
[Unit]
Description=AIDE Check Service
After=local-fs.target

[Service]
Type=simple
ExecStart=/usr/bin/aide --check -c /etc/aide/aide.conf
EOF

        cat > /etc/systemd/system/aide-check.timer << 'EOF'
[Unit]
Description=Daily AIDE Check Timer

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF

        chmod 644 /etc/systemd/system/aide-check.*
        systemctl daemon-reload
        systemctl enable --now aide-check.timer

        echo 100
        sleep 0.2
    } | whiptail --gauge "Installing and configuring AIDE..." 8 60 0

    printf "\033[1;32m[+] AIDE installed, enabled, and basic config applied.\033[0m\n"
}


reload_apparmor() {
  whiptail --infobox "Reloading AppArmor profiles..." 7 40
   
        if systemctl is-active --quiet apparmor; then
            printf "\033[1;31m[+] Reloading AppArmor service...\033[0m\n"
            systemctl reload apparmor
        else
            printf "\033[1;31m[+] Starting AppArmor service...\033[0m\n"
            systemctl start apparmor
        fi

        # Verify AppArmor status
        if aa-status >/dev/null 2>&1; then
            printf "\033[1;31m[+] AppArmour is running properly...\033[0m\n"
        else
            printf "\033[1;31m[-] Warning: AppArmor may not be running correctly. You may need to reboot your system.\033[0m\n"
        fi
}


stig_lock_inactive_accounts() {
    useradd -D -f 35
    awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd | while read -r user; do
        chage --inactive 35 "$user"
    done
}

stig_disable_ipv6() {
   
    if sysctl net.ipv6.conf.all.disable_ipv6 2>/dev/null | grep -q ' = 0'; then
        echo "Disabling IPv6..."
        echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
        echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.d/99-sysctl.conf
        sysctl -w net.ipv6.conf.all.disable_ipv6=1
    else
        echo "IPv6 is already disabled."
    fi
}

grub_security() {
    {
        echo 10
        sleep 0.2

        if [ -d /sys/firmware/efi ]; then
            echo "[*] UEFI system detected. Skipping GRUB configuration..."
            echo 100
            sleep 0.2
            return 0
        fi
        echo 20
        sleep 0.2

        if grep -q 'hypervisor' /proc/cpuinfo; then
            echo "[*] Virtual machine detected. Proceeding with GRUB configuration..."
        else
            echo "[+] No virtual machine detected. Proceeding with GRUB configuration..."
        fi
        echo 30
        sleep 0.2

        echo "[+] Setting GRUB password..."
        grub-mkpasswd-pbkdf2 | tee /etc/grub.d/40_custom_password
        echo 40
        sleep 0.2

       
        if [ -f /boot/grub/grub.cfg ]; then
            GRUB_CFG="/boot/grub/grub.cfg"
            GRUB_DIR="/boot/grub"
        elif [ -f /boot/grub2/grub.cfg ]; then
            GRUB_CFG="/boot/grub2/grub.cfg"
            GRUB_DIR="/boot/grub2"
        else
            echo "[-] GRUB config not found. Please verify GRUB installation."
            echo 100
            sleep 0.2
            return 1
        fi
        echo 50
        sleep 0.2

        echo "[+] Configuring GRUB security settings..."
        BACKUP_CFG="$GRUB_CFG.bak.$(date +%Y%m%d%H%M%S)"
        cp "$GRUB_CFG" "$BACKUP_CFG"
        echo "[+] Backup created at $BACKUP_CFG"
        echo 60
        sleep 0.2

        sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash security=1 /' /etc/default/grub

        if grep -q '^GRUB_TIMEOUT=' /etc/default/grub; then
            sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=5/' /etc/default/grub
        else
            echo "GRUB_TIMEOUT=5" >> /etc/default/grub
        fi
        echo 70
        sleep 0.2

      
        if command -v update-grub >/dev/null 2>&1; then
            update-grub || echo "[-] Failed to update GRUB using update-grub."
        elif command -v grub2-mkconfig >/dev/null 2>&1; then
            grub2-mkconfig -o "$GRUB_CFG" || echo "[-] Failed to update GRUB using grub2-mkconfig."
        else
            echo "[-] Neither update-grub nor grub2-mkconfig found. Please install GRUB tools."
            echo 100
            sleep 0.2
            return 1
        fi
        echo 90
        sleep 0.2

        chmod 600 "$GRUB_CFG"
        chown root:root "$GRUB_CFG"
        echo "[+] GRUB configuration secured: $GRUB_CFG"
        echo 100
        sleep 0.2
    } | whiptail --gauge "Configuring GRUB security..." 8 60 0
}

stig_enable_auditd() {
    whiptail --infobox "Configuring auditd..." 7 50
    printf "\033[1;31m[+] Configuring auditd...\033[0m\n"
    apt install -y auditd audispd-plugins
    cat > /etc/audit/rules.d/hardening.rules <<EOF
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes
-w /etc/gshadow -p wa -k gshadow_changes
-w /var/log/ -p wa -k log_changes
EOF
    systemctl restart auditd
}

stig_file_permissions() {
    whiptail --infobox "Hardening file permissions..." 7 50
    printf "\033[1;31m[+] Hardening file permissions...\033[0m\n"
    chmod 600 /etc/passwd-
    chmod 600 /etc/shadow
    chmod 600 /etc/gshadow
    chmod 600 /etc/group-
    chmod 700 /root
    chmod 600 /boot/grub/grub.cfg
}

stig_hardn_services() {
    printf "\\033[1;31m[+] Disabling unnecessary and potentially vulnerable services...\\033[0m\\n"

    disable_service_if_active() {
        local service_name="$1"
        if systemctl is-active --quiet "$service_name"; then
            printf "\033[1;31m[+] Disabling active service: %s...\033[0m\n" "$service_name"
            systemctl disable --now "$service_name" || printf "\033[1;33m[!] Failed to disable service: %s (may not be installed or already disabled).\033[0m\n" "$service_name"
        elif systemctl list-unit-files --type=service | grep -qw "^$service_name.service"; then
            printf "\033[1;31m[+] Service %s is not active, ensuring it is disabled...\033[0m\n" "$service_name"
            systemctl disable "$service_name" || printf "\033[1;33m[!] Failed to disable service: %s (may not be installed or already disabled).\033[0m\n" "$service_name"
        else
            printf "\033[1;34m[*] Service %s not found or not installed. Skipping.\033[0m\n" "$service_name"
        fi
    }

    disable_service_if_active avahi-daemon
    disable_service_if_active cups
    disable_service_if_active rpcbind
    disable_service_if_active nfs-server
    disable_service_if_active smbd
    disable_service_if_active snmpd
    disable_service_if_active apache2
    disable_service_if_active mysql
    disable_service_if_active bind9

    # Remove packages if they exist
    packages_to_remove="telnet vsftpd proftpd tftpd postfix exim4"
    for pkg in $packages_to_remove; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            printf "\033[1;31m[+] Removing package: %s...\033[0m\n" "$pkg"
            apt remove -y "$pkg"
        else
            printf "\033[1;34m[*] Package %s not installed. Skipping removal.\033[0m\n" "$pkg"
        fi
    done

    printf "\033[1;32m[+] Unnecessary services checked and disabled/removed where applicable.\033[0m\n"
}

stig_disable_core_dumps() {
    echo "* hard core 0" | tee -a /etc/security/limits.conf > /dev/null
    echo "fs.suid_dumpable = 0" | tee /etc/sysctl.d/99-coredump.conf > /dev/null
    sysctl -w fs.suid_dumpable=0
}


configure_cron() {
    whiptail --infobox "Configuring cron jobs... \"$name\"..." 7 50

    (crontab -l 2>/dev/null | grep -v "lynis audit system --cronjob" | \
     grep -v "apt update && apt upgrade -y" | \
     grep -v "/opt/eset/esets/sbin/esets_update" | \
     grep -v "chkrootkit" | \
     grep -v "maldet --update" | \
     grep -v "maldet --scan-all" | \
     grep -v "rkhunter --cronjob" | \
     grep -v "debsums -s" | \
     grep -v "aide --check" | \
     grep -v "/usr/bin/yara -r /etc/yara/rules/index.yar" | \
     crontab -) || true

    (crontab -l 2>/dev/null || true) > mycron
    cat >> mycron << 'EOFCRON'
0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1
0 2 * * * rkhunter --cronjob --report-warnings-only >> /var/log/rkhunter_cron.log 2>&1
0 2 * * * debsums -s >> /var/log/debsums_cron.log 2>&1
0 3 * * * /opt/eset/esets/sbin/esets_update
0 4 * * * chkrootkit
0 5 * * * maldet --update
0 6 * * * maldet --scan-all / >> /var/log/maldet_scan.log 2>&1
0 7 * * * aide --check -c /etc/aide/aide.conf >> /var/log/aide_check.log 2>&1
0 8 * * * /usr/bin/yara -r /etc/yara/rules/index.yar / >> /var/log/yara_scan.log 2>&1
0 9 * * * rkhunter --cronjob --report-warnings-only >> /var/log/rkhunter_cron.log 2>&1
0 10 * * * debsums -s >> /var/log/debsums_cron.log 2>&1



EOFCRON
    crontab mycron
    rm mycron
}

# Disable USB storage
disable_usb_storage() {
     whiptail --infobox "Disabling USB storage..." 7 50
         
         echo 'blacklist usb-storage' > /etc/modprobe.d/usb-storage.conf
         if modprobe -r usb-storage 2>/dev/null; then
             printf "\033[1;31m[+] USB storage successfully disabled.\033[0m\n"
         else
             printf "\033[1;31m[-] Warning: USB storage module in use, cannot unload.\033[0m\n"
         fi
}

# Update system packages again
update_sys_pkgs() {
     whiptail --infobox "Updating system packages..." 7 50
     printf "\\033[1;31m[+] System update (final pass)...\\033[0m\\n" 
     if ! (apt update && apt upgrade -y && apt-get update -y); then 
          echo "\\033[1;31m[-] System update failed.\\033[0m" 
          whiptail --title "System update failed" --msgbox "Final system update failed. Please check logs." 8 60
          
     fi
}


 update_system_packages() {
  printf "\\033[1;31m[+] Updating system packages...\\033[0m\\n"
  apt update && apt upgrade -y
  apt-get update -y
}




finalize() { 
    sleep 5
    whiptail --title "HARDN-XDR" \
        --msgbox "HARDN-XDR Setup Complete\n\nPlease reboot to apply installation." 12 80
}




# Function to configure Fail2Ban
enhance_fail2ban() {
    printf "\033[1;31m[+] Enhancing Fail2Ban configuration...\033[0m\n"
    cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 24h
findtime = 10m
maxretry = 3
ignoreip = 127.0.0.1/8 ::1
backend = systemd
destemail = root@localhost
sender = fail2ban@localhost
mta = sendmail
banaction = iptables-multiport
banaction_allports = iptables-allports
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 48h
findtime = 10m
EOF

    chmod 600 /etc/fail2ban/jail.local
    systemctl restart fail2ban
}


restrict_compilers() {
    printf "\033[1;31m[+] Restricting compiler access to root only (HRDN-7222)...\033[0m\n"

    local compilers="/usr/bin/gcc /usr/bin/g++ /usr/bin/make /usr/bin/cc /usr/bin/c++ /usr/bin/as /usr/bin/ld"
    for bin in $compilers; do
        if [ -f "$bin" ]; then
            chmod 700 "$bin"
            chown root:root "$bin"
            printf "\033[1;32m[+] Restricted $bin to root only.\033[0m\n"
        fi
    done
}

disable_binfmt_misc() {
    printf "\\033[1;31m[+] Checking/Disabling non-native binary format support (binfmt_misc)...\\033[0m\\n"
    if mount | grep -q 'binfmt_misc'; then
        printf "\\033[1;33m[*] binfmt_misc is mounted. Attempting to unmount...\033[0m\\n"
        if umount /proc/sys/fs/binfmt_misc; then
            printf "\\033[1;32m[+] binfmt_misc unmounted successfully.\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to unmount binfmt_misc. It might be busy or not a separate mount.\033[0m\\n"
        fi
    fi

    if lsmod | grep -q "^binfmt_misc"; then
        printf "\\033[1;33m[*] binfmt_misc module is loaded. Attempting to unload...\033[0m\\n"
        if rmmod binfmt_misc; then
            printf "\\033[1;32m[+] binfmt_misc module unloaded successfully.\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to unload binfmt_misc module. It might be in use or built-in.\033[0m\\n"
        fi
    else
        printf "\\033[1;32m[+] binfmt_misc module is not currently loaded.\033[0m\\n"
    fi

    # Prevent module from loading on boot
    local modprobe_conf="/etc/modprobe.d/disable-binfmt_misc.conf"
    if [ ! -f "$modprobe_conf" ]; then
        echo "install binfmt_misc /bin/true" > "$modprobe_conf"
        printf "\\033[1;32m[+] Added modprobe rule to prevent binfmt_misc from loading on boot: %s\033[0m\\n" "$modprobe_conf"
    else
        if ! grep -q "install binfmt_misc /bin/true" "$modprobe_conf"; then
            echo "install binfmt_misc /bin/true" >> "$modprobe_conf"
            printf "\\033[1;32m[+] Appended modprobe rule to prevent binfmt_misc from loading to %s\033[0m\\n" "$modprobe_conf"
        else
            printf "\\033[1;34m[*] Modprobe rule to disable binfmt_misc already exists in %s.\033[0m\\n" "$modprobe_conf"
        fi
    fi
    whiptail --infobox "Non-native binary format support (binfmt_misc) checked/disabled." 7 70
}

disable_firewire_drivers() {
    printf "\\033[1;31m[+] Checking/Disabling FireWire (IEEE 1394) drivers...\033[0m\\n"
    local firewire_modules="firewire_core firewire_ohci firewire_sbp2"
    local changed=0

    for module_name in $firewire_modules; do
        if lsmod | grep -q "^${module_name}"; then
            printf "\\033[1;33m[*] FireWire module %s is loaded. Attempting to unload...\033[0m\\n" "$module_name"
            if rmmod "$module_name"; then
                printf "\\033[1;32m[+] FireWire module %s unloaded successfully.\033[0m\\n" "$module_name"
                changed=1
            else
                printf "\\033[1;31m[-] Failed to unload FireWire module %s. It might be in use or built-in.\033[0m\\n" "$module_name"
            fi
        else
            printf "\\033[1;34m[*] FireWire module %s is not currently loaded.\033[0m\\n" "$module_name"
        fi
    done

    local blacklist_file="/etc/modprobe.d/blacklist-firewire.conf"
    if [ ! -f "$blacklist_file" ]; then
        touch "$blacklist_file"
        printf "\\033[1;32m[+] Created FireWire blacklist file: %s\033[0m\\n" "$blacklist_file"
    fi

    for module_name in $firewire_modules; do
        if ! grep -q "blacklist $module_name" "$blacklist_file"; then
            echo "blacklist $module_name" >> "$blacklist_file"
            printf "\\033[1;32m[+] Blacklisted FireWire module %s in %s\033[0m\\n" "$module_name" "$blacklist_file"
            changed=1
        else
            printf "\\033[1;34m[*] FireWire module %s already blacklisted in %s.\033[0m\\n" "$module_name" "$blacklist_file"
        fi
    done

    if [ "$changed" -eq 1 ]; then
        whiptail --infobox "FireWire drivers checked. Unloaded and/or blacklisted where applicable." 7 70
    else
        whiptail --infobox "FireWire drivers checked. No changes made (likely already disabled/not present)." 8 70
    fi
}

purge_old_packages() {
    printf "\\033[1;31m[+] Purging configuration files of old/removed packages...\033[0m\\n"
    local packages_to_purge
    packages_to_purge=$(dpkg -l | grep '^rc' | awk '{print $2}')

    if [ -n "$packages_to_purge" ]; then
        printf "\\033[1;33m[*] Found the following packages with leftover configuration files to purge:\033[0m\\n"
        echo "$packages_to_purge"
       
        if command -v whiptail >/dev/null; then
            whiptail --title "Packages to Purge" --msgbox "The following packages have leftover configuration files that will be purged:\n\n$packages_to_purge" 15 70
        fi

        for pkg in $packages_to_purge; do
            printf "\\033[1;31m[+] Purging $pkg...\033[0m\\n"
            if apt-get purge -y "$pkg"; then
                printf "\\033[1;32m[+] Successfully purged $pkg.\033[0m\\n"
            else
                printf "\\033[1;31m[-] Failed to purge $pkg. Trying dpkg --purge...\033[0m\\n"
                if dpkg --purge "$pkg"; then
                     printf "\\033[1;32m[+] Successfully purged $pkg with dpkg.\033[0m\\n"
                else
                     printf "\\033[1;31m[-] Failed to purge $pkg with dpkg as well.\033[0m\\n"
                fi
            fi
        done
        whiptail --infobox "Purged configuration files for removed packages." 7 70
    else
        printf "\\033[1;32m[+] No old/removed packages with leftover configuration files found to purge.\033[0m\\n"
        whiptail --infobox "No leftover package configurations to purge." 7 70
    fi
   
    printf "\\033[1;31m[+] Running apt-get autoremove and clean to free up space...\033[0m\\n"
    apt-get autoremove -y
    apt-get clean
    whiptail --infobox "Apt cache cleaned." 7 70
}

enable_nameservers() {
    printf "\\033[1;31m[+] Checking and configuring DNS nameservers (Quad9 primary, Google secondary)...\033[0m\\n"
    local resolv_conf="/etc/resolv.conf"
    local quad9_ns="9.9.9.9"
    local google_ns="8.8.8.8"
    local nameserver_count=0
    local configured_persistently=false
    local changes_made=false

    if [ -f "$resolv_conf" ]; then
        nameserver_count=$(grep -E "^\s*nameserver\s+" "$resolv_conf" | grep -Ev "127\.0\.0\.1|::1" | awk '{print $2}' | sort -u | wc -l)
    fi

    printf "\\033[1;34m[*] Found %s non-localhost nameserver(s) in %s.\033[0m\\n" "$nameserver_count" "$resolv_conf"

    # Always attempt to set Quad9 as primary and Google as secondary
    # Check for systemd-resolved
    if systemctl is-active --quiet systemd-resolved && \
       [ -L "$resolv_conf" ] && \
       (readlink "$resolv_conf" | grep -qE "systemd/resolve/(stub-resolv.conf|resolv.conf)"); then
        
        printf "\\033[1;34m[*] systemd-resolved is active and manages %s.\033[0m\\n" "$resolv_conf"
        local resolved_conf_systemd="/etc/systemd/resolved.conf"
        local temp_resolved_conf
        temp_resolved_conf=$(mktemp)

        if [ ! -f "$resolved_conf_systemd" ]; then
            printf "\\033[1;33m[*] Creating %s as it does not exist.\033[0m\\n" "$resolved_conf_systemd"
            echo "[Resolve]" > "$resolved_conf_systemd"
            chmod 644 "$resolved_conf_systemd"
        fi
        
        cp "$resolved_conf_systemd" "$temp_resolved_conf"

        # Set DNS= and FallbackDNS= explicitly
        if grep -qE "^\s*DNS=" "$temp_resolved_conf"; then
            sed -i -E "s/^\s*DNS=.*/DNS=$quad9_ns $google_ns/" "$temp_resolved_conf"
        else
            if grep -q "\[Resolve\]" "$temp_resolved_conf"; then
                sed -i "/\[Resolve\]/a DNS=$quad9_ns $google_ns" "$temp_resolved_conf"
            else
                echo -e "\n[Resolve]\nDNS=$quad9_ns $google_ns" >> "$temp_resolved_conf"
            fi
        fi

        # Set FallbackDNS as well (optional, for redundancy)
        if grep -qE "^\s*FallbackDNS=" "$temp_resolved_conf"; then
            sed -i -E "s/^\s*FallbackDNS=.*/FallbackDNS=$google_ns $quad9_ns/" "$temp_resolved_conf"
        else
            if grep -q "\[Resolve\]" "$temp_resolved_conf"; then
                sed -i "/\[Resolve\]/a FallbackDNS=$google_ns $quad9_ns" "$temp_resolved_conf"
            else
                echo -e "\n[Resolve]\nFallbackDNS=$google_ns $quad9_ns" >> "$temp_resolved_conf"
            fi
        fi

        if ! cmp -s "$temp_resolved_conf" "$resolved_conf_systemd"; then
            cp "$temp_resolved_conf" "$resolved_conf_systemd"
            printf "\\033[1;32m[+] Updated %s. Restarting systemd-resolved...\033[0m\\n" "$resolved_conf_systemd"
            if systemctl restart systemd-resolved; then
                printf "\\033[1;32m[+] systemd-resolved restarted successfully.\033[0m\\n"
                configured_persistently=true
                changes_made=true
            else
                printf "\\033[1;31m[-] Failed to restart systemd-resolved. Manual check required.\033[0m\\n"
            fi
        else
            printf "\\033[1;34m[*] No effective changes to %s were needed.\033[0m\\n" "$resolved_conf_systemd"
        fi
        rm -f "$temp_resolved_conf"
    fi

    # If not using systemd-resolved, try to set directly in /etc/resolv.conf
    if [ "$configured_persistently" = false ]; then
        printf "\\033[1;34m[*] Attempting direct modification of %s.\033[0m\\n" "$resolv_conf"
        if [ -f "$resolv_conf" ] && [ -w "$resolv_conf" ]; then
            # Remove existing Quad9/Google entries and add them at the top
            grep -vE "^\s*nameserver\s+($quad9_ns|$google_ns)" "$resolv_conf" > "${resolv_conf}.tmp"
            {
                echo "nameserver $quad9_ns"
                echo "nameserver $google_ns"
                cat "${resolv_conf}.tmp"
            } > "$resolv_conf"
            rm -f "${resolv_conf}.tmp"
            printf "\\033[1;32m[+] Set Quad9 as primary and Google as secondary in %s.\033[0m\\n" "$resolv_conf"
            printf "\\033[1;33m[!] Warning: Direct changes to %s might be overwritten by network management tools.\033[0m\\n" "$resolv_conf"
            changes_made=true
        else
            printf "\\033[1;31m[-] Could not modify %s (file not found or not writable).\033[0m\\n" "$resolv_conf"
        fi
    fi

    if [ "$changes_made" = true ]; then
         whiptail --infobox "DNS configured: Quad9 primary, Google secondary." 7 70
    else
         whiptail --infobox "DNS configuration checked. No changes made or needed." 8 70
    fi
}


enable_process_accounting_and_sysstat() {
    printf "\\033[1;31m[+] Enabling process accounting (acct) and system statistics (sysstat)...\033[0m\\n"
    local changed_acct=false
    local changed_sysstat=false

    # Enable Process Accounting (acct/psacct)
    printf "\\033[1;34m[*] Checking and installing acct (process accounting)...\033[0m\\n"
    if ! dpkg -s acct >/dev/null 2>&1 && ! dpkg -s psacct >/dev/null 2>&1; then
        whiptail --infobox "Installing acct (process accounting)..." 7 60
        if apt-get install -y acct; then
            printf "\\033[1;32m[+] acct installed successfully.\033[0m\\n"
            changed_acct=true
        else
            printf "\\033[1;31m[-] Failed to install acct. Please check manually.\033[0m\\n"
        fi
    else
        printf "\\033[1;34m[*] acct/psacct is already installed.\033[0m\\n"
    fi

    if dpkg -s acct >/dev/null 2>&1 || dpkg -s psacct >/dev/null 2>&1; then
        if ! systemctl is-active --quiet acct && ! systemctl is-active --quiet psacct; then
            printf "\\033[1;33m[*] Attempting to enable and start acct/psacct service...\033[0m\\n"
            if systemctl enable --now acct 2>/dev/null || systemctl enable --now psacct 2>/dev/null; then
                printf "\\033[1;32m[+] acct/psacct service enabled and started.\033[0m\\n"
                changed_acct=true
            else
                printf "\\033[1;31m[-] Failed to enable/start acct/psacct service. It might need manual configuration or a reboot.\033[0m\\n"
            fi
        else
            printf "\\033[1;32m[+] acct/psacct service is already active.\033[0m\\n"
        fi
    fi

    # Enable Sysstat
    printf "\\033[1;34m[*] Checking and installing sysstat...\033[0m\\n"
    if ! dpkg -s sysstat >/dev/null 2>&1; then
        whiptail --infobox "Installing sysstat..." 7 60
        if apt-get install -y sysstat; then
            printf "\\033[1;32m[+] sysstat installed successfully.\033[0m\\n"
            changed_sysstat=true
        else
            printf "\\033[1;31m[-] Failed to install sysstat. Please check manually.\033[0m\\n"
        fi
    else
        printf "\\033[1;34m[*] sysstat is already installed.\033[0m\\n"
    fi

    if dpkg -s sysstat >/dev/null 2>&1; then
        local sysstat_conf="/etc/default/sysstat"
        if [ -f "$sysstat_conf" ]; then
            if ! grep -qE '^\s*ENABLED="true"' "$sysstat_conf"; then
                printf "\\033[1;33m[*] Enabling sysstat data collection in %s...\033[0m\\n" "$sysstat_conf"
                sed -i 's/^\s*ENABLED="false"/ENABLED="true"/' "$sysstat_conf"
          
                if ! grep -qE '^\s*ENABLED=' "$sysstat_conf"; then
                    echo 'ENABLED="true"' >> "$sysstat_conf"
                fi
                changed_sysstat=true
                printf "\\033[1;32m[+] sysstat data collection enabled.\033[0m\\n"
            else
                printf "\\033[1;32m[+] sysstat data collection is already enabled in %s.\033[0m\\n" "$sysstat_conf"
            fi
        else
            # Fallback for systems where config might be /etc/sysstat/sysstat (e.g. RHEL based, but this is Debian focused)
            # For Debian, /etc/default/sysstat is standard.
            printf "\\033[1;33m[!] sysstat configuration file %s not found. Manual check might be needed.\033[0m\\n" "$sysstat_conf"
        fi

        if ! systemctl is-active --quiet sysstat; then
            printf "\\033[1;33m[*] Attempting to enable and start sysstat service...\033[0m\\n"
            if systemctl enable --now sysstat; then
                printf "\\033[1;32m[+] sysstat service enabled and started.\033[0m\\n"
                changed_sysstat=true
            else
                printf "\\033[1;31m[-] Failed to enable/start sysstat service.\033[0m\\n"
            fi
        else
            printf "\\033[1;32m[+] sysstat service is already active.\033[0m\\n"
        fi
    fi

    if [ "$changed_acct" = true ] || [ "$changed_sysstat" = true ]; then
        whiptail --infobox "Process accounting (acct) and sysstat configured." 7 70
    else
        whiptail --infobox "Process accounting (acct) and sysstat checked. No changes made or needed." 8 70
    fi
}




main() {
        welcomemsg || error "User exited."
        preinstallmsg || error "User exited."
        print_ascii_banner
        update_system_packages
        build_hardn_package
        installationloop
        configure_firejail
        config_selinux
        enhance_fail2ban
        restrict_compilers
        enable_aide
        check_security_tools
        configure_ufw
        enable_services
        install_additional_tools
        enable_yara
        reload_apparmor
        enable_suricata
        grub_security
        stig_harden_ssh
        stig_file_permissions
        stig_enable_auditd
        stig_disable_ipv6
        stig_password_policy
        stig_hardn_services
        stig_lock_inactive_accounts
        stig_kernel_setup
        stig_set_randomize_va_space
        stig_disable_core_dumps
        configure_cron
        disable_usb_storage
        disable_binfmt_misc
        disable_firewire_drivers
        update_sys_pkgs
        enable_nameservers
        enable_process_accounting_and_sysstat
        purge_old_packages
        finalize
}


main

