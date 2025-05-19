#!/bin/bash

########################################
#        HARDN - Auto Rice Script      #
#            main branch               #
#                                      #
#       Author:  Chris Bingham         #
#       Date:    4/5/2025              #
#       Updated: 5/16/2025             #
#                                      #
########################################


repo="https://github.com/OpenSource-For-Freedom/HARDN/"
progsfile="https://raw.githubusercontent.com/LinuxUser255/HARDN/refs/heads/main-dev/progs.csv"
repobranch="main-patch"
name=$(whoami)


############# ADD MENU HERE #############
############# ADD LOGIN BANNER FIX ######
############# IMPLIMENT MENU STATUS FOR LONG INSTALL AND SETUPS#####


# Check for root privileges
if [ "$(id -u)" -ne 0 ]; then
        echo ""
        echo "This script must be run as root."
        exit 1
fi

installpkg() {
       dpkg -s "$1" >/dev/null 2>&1 || sudo apt install -y "$1" >/dev/null 2>&1
}

# Log to stderr and exit with failure.
error() {
        printf "%s\n" "$1" >&2
        exit 1
}

welcomemsg() {
        whiptail --title "Welcome!" --backtitle "HARDN OS Security" --fb \
            --msgbox "\n\n\nWelcome to HARDN OS Security!\n\nThis script will automatically install everything you need to fully security harden your Linux machine.\n\n-Chris" 15 60

        whiptail --title "Important Note!" --backtitle "HARDN OS Security" --fb \
            --yes-button "All ready!" \
            --no-button "Return..." \
            --yesno "\n\n\nThis installer will update your system first..\n\n" 12 70
}

preinstallmsg() {
        whiptail --title "Welcome to HARDN. A Linux Security Hardening program." --yes-button "Let's go!" \
            --no-button "No, nevermind!" \
            --yesno "\n\n\nThe rest of the installation will now be totally automated, so you can sit back and relax.\n\nIt will take some time, but when done, you can enjoy your security hardened Linux OS.\n\nNow just press <Let's go!> and the system will begin installation!\n\n" 13 60 || {
            clear
            exit 1
    }
}

update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    apt update && apt upgrade -y
}

# Install package dependencies from progs.csv
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
        git clone --depth=1 "$repo_url" "$dir" >/dev/null 2>&1
        cd "$dir" || exit
        whiptail --infobox "Building and installing $description..." 7 70

        # Check and isntall build dependencies
        whiptail --infobox "Checking build dependencies for $description..." 7 70
        build_deps=$(dpkg-checkbuilddeps 2>&1 | grep -oP 'Unmet build dependencies: \K.*')
        if [ -n "$build_deps" ];  then
          whiptail --infobox "Installing build dependencies: $build_deps" 7 70
          apt install -y $build_deps >/dev/null 2>&1
        fi

        # Run dpkg-source before building
        dpkg-source --before-build . >/dev/null 2>&1

        # Build and install the package
        if sudo dpkg-buildpackage -u -uc 2>&1; then
          sudo dpkg -i ../hardn.deb
        else
          whiptail --infobox "$description Failed to build package. Please check build dependencies." 10 60
          # try to install common build dependencies
          apt install -y debhelper-compat devscripts git-buildpackage
          # Try building again
          sudo dpkg-buildpackage -us -uc 2>&1 && sudo dpkg -i  ../hardn.deb
        fi
}

build_hardn_package() {
    whiptail --infobox "Building HARDN Debian package..." 7 60

    # Create temporary directory
    temp_dir=$(mktemp -d)
    cd "$temp_dir" || exit 1

    # Clone the repository
    git clone --depth=1 -b main-patch https://github.com/OpenSource-For-Freedom/HARDN.git
    cd HARDN || exit 1

    # Build the package
    whiptail --infobox "Running dpkg-buildpackage..." 7 60
    dpkg-buildpackage -us -uc

    # Install the package
    cd .. || exit 1
    whiptail --infobox "Installing HARDN package..." 7 60
    dpkg -i hardn_*.deb

    # Handle dependencies if needed
    apt-get install -f -y

    # Clean up
    cd / || exit 1
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

enable_debsums() {
    printf "\033[1;31m[+] Enabling debsums...\033[0m\n"
    if ! dpkg -s debsums >/dev/null 2>&1; then
        whiptail --infobox "Installing debsums..." 7 60
        apt install -y debsums
    else
        whiptail --infobox "debsums is already installed." 7 60
    fi

    # Enable debsums
    sed -i 's/^#\?ENABLED=.*/ENABLED=1/' /etc/default/debsums
    debsums --generate --all

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
        printf "\033[1;31m[+] Configuring UFW...\033[0m\n"
        ufw defualt deny incoming
        ufw default allow outgoing
        ufw allow ssh proto tcp
        ufw allow out 53,80,443/tcp
        ufw allow out 53,123/udp
        ufw allow out 67,68/udp
        ufw reload
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
kernel.randomize_va_space = 2
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.default.forwarding = 0
net.ipv4.tcp_timestamps = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF

    sysctl --system || printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"
    sysctl -w kernel.randomize_va_space=2 || printf "\033[1;31m[-] Failed to set kernel.randomize_va_space.\033[0m\n"
}

stig_login_banners() {
   
    center_issue_text() {
        local text="$1"
        local width=80
        local text_len=${#text}
        if [ "$text_len" -ge "$width" ]; then
            echo "$text"
        else
            local pad=$(( (width - text_len) / 2 ))
            printf "%*s%s\n" "$pad" "" "$text"
        fi
    }

    {
        echo -e "\033[1;32m"
        center_issue_text "════════════════════════════"
        center_issue_text "   _____   _____    _____   "
        center_issue_text "  / ____| |_   _|  / ____|  "
        center_issue_text " | (___     | |   | |  __   "
        center_issue_text "  \___ \  | |   | |  | |  "
        center_issue_text "  ____) |  _| |_  | |__| |  "
        center_issue_text " |_____/  |_____|  \____|  "
        center_issue_text "                            "
        center_issue_text "════════════════════════════"
        echo -e "\033[0m"
        center_issue_text "You are accessing a SECURITY INTERNATIONAL GROUP (SIG) Information System (IS) that is provided for SIG-authorized use only."
        center_issue_text "By using this IS (which includes any device attached to this IS), you consent to the following conditions:"
        center_issue_text "- The SIG routinely intercepts and monitors communications on this IS for purposes including, but not limited to,"
        center_issue_text "  penetration testing, COMSEC monitoring, network operations and defense, personnel misconduct (PM), law enforcement (LE),"
        center_issue_text "  and counterintelligence (CI) investigations."
        center_issue_text "- At any time, the USG may inspect and seize data stored on this IS."
        center_issue_text "- Communications using, or data stored on, this IS are not private, are subject to routine monitoring, interception, and search,"
        center_issue_text "  and may be disclosed or used for any USG-authorized purpose."
        center_issue_text "- This IS includes security measures (e.g., authentication and access controls) to protect SIG interests--not for your personal"
        center_issue_text "  benefit or privacy."
        center_issue_text "- Notwithstanding the above, using this IS does not constitute consent to PM, LE or CI investigative searching or monitoring of"
        center_issue_text "  the content of privileged communications, or work product, related to personal representation or services by attorneys,"
        center_issue_text "  psychotherapists, or clergy, and their assistants. Such communications and work product are private and confidential."
        center_issue_text "  See User Agreement for details."
    } > /etc/issue

    chmod 644 /etc/issue /etc/issue.net
}

stig_harden_ssh() {
    {
        echo 10
        sleep 0.2
        printf "\033[1;31m[+] Hardening SSH configuration...\033[0m\n"

        sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        echo 30
        sleep 0.2

        sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
        echo 45
        sleep 0.2

        sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
        echo 60
        sleep 0.2

        sed -i 's/^#\?UsePAM.*/UsePAM yes/' /etc/ssh/sshd_config
        echo 70
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
    printf "\033[1;31m[+] Setting kernel.randomize_va_space...\033[0m\n"
    echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/hardn.conf
    sysctl --system || { printf "\033[1;31m[-] Failed to reload sysctl settings.\033[0m\n"; exit 1; }
    sysctl -w kernel.randomize_va_space=2 || { printf "\033[1;31m[-] Failed to set kernel.randomize_va_space.\033[0m\n"; exit 1; }
}

# Enable and start Fail2Ban and AppArmor services
enable_services() {
       printf "\033[1;31m[+] Enabling and starting Fail2Ban and AppArmor services...\033[0m\n"
       systemctl enable --now fail2ban
       systemctl enable --now apparmor
}

# Install chkrootkit, LMD, and rkhunter
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
                    whiptail --infobox "Linux Malware Detect installed successfully from GitHub."
                    printf "\033[1;31m[+] Linux Malware Detect installed successfully from GitHub\033[0m\n"
                    install_maldet_failed=false
                else
                    printf "\033[1;31m[-] Maldetect installer failed\033[0m\n"
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

    sed -i 's/^#\? *minlen *=.*/minlen = 14/' /etc/security/pwquality.conf
    sed -i 's/^#\? *dcredit *=.*/dcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *ucredit *=.*/ucredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *ocredit *=.*/ocredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *lcredit *=.*/lcredit = -1/' /etc/security/pwquality.conf
    sed -i 's/^#\? *enforcing *=.*/enforcing = 1/' /etc/security/pwquality.conf

   
    echo "PASS_MIN_DAYS 1" >> /etc/login.defs
    echo "PASS_MAX_DAYS 90" >> /etc/login.defs
    echo "PASS_WARN_AGE 7" >> /etc/login.defs

  
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

        cat > /etc/aide/aide.conf << 'EOF'
database=file:/var/lib/aide/aide.db
database_out=file:/var/lib/aide/aide.db.new

# Basic rules
NORMAL = p+i+n+u+g+s+b+m+c+md5+sha1

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

# Reload AppArmor profiles
reload_apparmor() {
  whiptail --infobox "Reloading AppArmor profiles..." 7 40
        #printf "\033[1;31m[+] Reloading AppArmor profiles...\033[0m\n"

        # Use systemd to reload AppArmor instead of manually parsing files
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
    printf "\033[1;31m[+] Disabling unnecessary and potentially vulnerable services...\033[0m\n"

    systemctl disable --now avahi-daemon
    systemctl disable --now cups
    systemctl disable --now rpcbind
    systemctl disable --now nfs-server
    systemctl disable --now smbd
    systemctl disable --now snmpd
    systemctl disable --now apache2
    systemctl disable --now mysql
    systemctl disable --now bind9

    
    apt remove -y telnet vsftpd proftpd tftpd postfix exim4

    printf "\033[1;32m[+] All unnecessary services have been disabled or removed.\033[0m\n"
}

stig_disable_core_dumps() {
    echo "* hard core 0" | tee -a /etc/security/limits.conf > /dev/null
    echo "fs.suid_dumpable = 0" | tee /etc/sysctl.d/99-coredump.conf > /dev/null
    sysctl -w fs.suid_dumpable=0
}

# Configure cron jobs
configure_cron() {
    whiptail --infobox "Configuring cron jobs... \"$name\"..." 7 50

    # Remove existing cron jobs for these tools
    (crontab -l 2>/dev/null | grep -v "lynis audit system --cronjob" | \
     grep -v "apt update && apt upgrade -y" | \
     grep -v "/opt/eset/esets/sbin/esets_update" | \
     grep -v "chkrootkit" | \
     grep -v "maldet --update" | \
     grep -v "maldet --scan-all" | \
     grep -v "rkhunter --cronjob" | \
     grep -v "debsums -s" | \
     grep -v "aide --check" | \
     crontab -) || true

    # Create new cron jobs
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
EOFCRON
    crontab mycron
    rm mycron
}

# Disable USB storage
disable_usb_storage() {
     whiptail --infobox "Disabling USB storage..." 7 50
         #printf "\033[1;31m[+] Disabling USB storage...\033[0m\n"
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
            #printf "\033[1;31m[-] System update.\033[0m\n"
        if ! update_system_packages; then
             printf "\033[1;31m[-] System update failed.\033[0m\n"
            whiptail --title "System update failed"
            exit 1
        fi
}


finalize() { # EDIT THE WORDING 
        whiptail --title "HARDN-XDR Complete" \
            --msgbox "This device is now HARDN-XDR and STIG Compliant\\n\\nPlease reboot to apply installation." 12 80
}

# Function to configure kernel hardening
configure_kernel_hardening() {
    printf "\033[1;31m[+] Configuring kernel hardening...\033[0m\n"
    cat <<EOF > /etc/sysctl.d/hardening.conf
# Disable IP forwarding
net.ipv4.ip_forward = 0
# Enable SYN cookies
net.ipv4.tcp_syncookies = 1
# Disable source routing
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
# Log martian packets
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
# Disable ICMP redirects
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
EOF
    sysctl --system
}




# Function to initialize and configure AIDE
configure_aide() {
    printf "\033[1;31m[+] Installing and configuring AIDE...\033[0m\n"
    apt install -y aide aide-common
    aideinit
    mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db
    echo "0 3 * * * root /usr/bin/aide --check" >> /etc/crontab
}

# Function to configure Fail2Ban
enhance_fail2ban() {
    printf "\033[1;31m[+] Enhancing Fail2Ban configuration...\033[0m\n"
    cat <<EOF > /etc/fail2ban/jail.local
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
EOF
    systemctl restart fail2ban
}

# Function to configure Docker hardening
configure_docker() {
    printf "\033[1;31m[+] Configuring Docker hardening...\033[0m\n"
    mkdir -p /etc/docker
    cat <<EOF > /etc/docker/daemon.json
{
  "icc": false,
  "userns-remap": "default",
  "no-new-privileges": true
}
EOF
    systemctl restart docker
}

# Function to restrict compiler access
restrict_compilers() {
    printf "\033[1;31m[+] Restricting compiler access...\033[0m\n"
    chmod o-rx /usr/bin/gcc /usr/bin/g++ /usr/bin/make
}

# Function to install and configure ClamAV
setup_clamav() {
    printf "\033[1;31m[+] Installing and configuring ClamAV...\033[0m\n"
    apt install -y clamav clamav-daemon
    systemctl stop clamav-freshclam
    freshclam
    systemctl start clamav-freshclam
    echo "0 2 * * * root /usr/bin/clamscan -r / --exclude-dir=^/sys/ --exclude-dir=^/proc/ --exclude-dir=^/dev/" >> /etc/crontab
}

# Add calls to the new functions in the main script
main() {
        welcomemsg || error "User exited."
        preinstallmsg || error "User exited."
        update_system_packages
        aptinstall
        maininstall
        gitdpkgbuild
        build_hardn_package
        installationloop
        configure_firejail
        config_selinux
        enable_debsums
        enable_aide
        check_security_tools
        configure_ufw
        enable_services
        install_additional_tools
        enable_yara
        reload_apparmor
        grub_security
        stig_harden_ssh
        stig_file_permissions
        stig_login_banners
        stig_enable_auditd
        stig_disable_ipv6
        stig_password_policy
        stig_hardn_services
        stig_lock_inactive_accounts
        stig_kernel_setup
        stig_disable_core_dumps
        stig_set_randomize_va_space
        configure_cron
        disable_usb_storage
        update_sys_pkgs
        finalize

        configure_kernel_hardening
        configure_aide
        enhance_fail2ban
        configure_docker
        restrict_compilers
        setup_clamav
}

# Run the main function
main