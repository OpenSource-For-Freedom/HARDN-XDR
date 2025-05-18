#!/bin/sh

########################################
#        HARDN - Auto Rice Script      #
#            main branch               #
#                                      #
#       Author: Chris Bingham          #
#           Date: 4/5/2025             #
#         Updated: 5/18/2025           #
#                                      #
########################################

# This script automatically starts the rice process when executed with sudo sh hardn-main.sh

# Run main() function to start the rice process automatically
auto_start() {
    echo "HARDN installation process starting automatically..."
    sleep 1
    # The main rice process will start automatically
}


# urls to be changed after merge
repo="https://github.com/OpenSource-For-Freedom/HARDN/"
progsfile="https://raw.githubusercontent.com/LinuxUser255/HARDN/refs/heads/main-dev/progs.csv"
repobranch="main-patch"
name=$(whoami)

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
        printf "\033[1;32[+] Downloading and installing files...\033[0m\n"
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
                for pkg in ufw yara fail2ban apparmor apparmor-profiles apparmor-utils firejail tcpd lynis debsums rkhunter libpam-pwquality libvirt-daemon-system libvirt-clients qemu-kvm docker.io docker-compose openssh-server; do
                        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                                whiptail --infobox "Installing $pkg..." 7 60
                                apt install -y "$pkg"
                        else
                                whiptail --infobox "$pkg is already installed." 7 60
                        fi
                done

                # Ensure yara is installed (redundant, but explicit as requested)
                if ! command -v yara >/dev/null 2>&1; then
                        whiptail --infobox "Installing yara..." 7 60
                        apt install -y yara
                else
                        whiptail --infobox "yara is already installed." 7 60
                fi
}

# UFW configuration
configure_ufw() {
        printf "\033[1;31m[+] Configuring UFW...\033[0m\n"
        ufw allow out 53,80,443/tcp
        ufw allow out 53,123/udp
        ufw allow out 67,68/udp
        ufw reload
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

          # Create a temporary directory for the installation
          # ... rest of the function


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

# Configure cron jobs
configure_cron() {
  	whiptail --infobox "Configuring cron jobs... \"$name\"..." 7 50
        #printf "\033[1;31m[+] Configuring cron jobs...\033[0m\n"

        # Remove existing cron jobs
        (crontab -l 2>/dev/null | grep -v "lynis audit system --cronjob" | \
         grep -v "apt update && apt upgrade -y" | \
         grep -v "/opt/eset/esets/sbin/esets_update" | \
         grep -v "chkrootkit" | \
         grep -v "maldet --update" | \
         grep -v "maldet --scan-all" | \
         crontab -) || true

        # Create new cron jobs
        (crontab -l 2>/dev/null || true) > mycron
        cat >> mycron << 'EOFCRON'
0 1 * * * lynis audit system --cronjob >> /var/log/lynis_cron.log 2>&1
0 3 * * * /opt/eset/esets/sbin/esets_update
0 4 * * * chkrootkit
0 5 * * * maldet --update
0 6 * * * maldet --scan-all / >> /var/log/maldet_scan.log 2>&1
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


finalize() {
        whiptail --title "All done!" \
            --msgbox "Congrats! Provided there were no hidden errors, the script completed successfully and all the programs and configuration files should be in place.\\n\\nPlease reboot to apply installation." 12 80
}

# Main function
main() {
        welcomemsg || error "User exited."
        preinstallmsg || error "User exited."
        update_system_packages
        aptinstall
        maininstall
        gitdpkgbuild
        build_hardn_package
        installationloop
        config_selinux
        check_security_tools
        configure_ufw
        enable_services
        install_additional_tools
        reload_apparmor
        configure_cron
        disable_usb_storage
        update_sys_pkgs
        finalize
}


auto_start


mkdir -p /etc/hardn
touch /etc/hardn/.first_run_complete


main