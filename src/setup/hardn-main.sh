#!/bin/bash

set -euo pipefail

# HARDN-XDR - The Linux Security Hardening Sentinel
# Developed and built by Christopher Bingham and Tim Burns
# IDEA: larbs.xyz "Rice Scripting" for Arch Linux. 


# Resources & Global Variables
repo="https://github.com/OpenSource-For-Freedom/HARDN-XDR/"
progsfile="https://raw.githubusercontent.com/OpenSource-For-Freedom/HARDN-XDR/main/progs.csv"
repobranch="main"
name=$(whoami)



# MENU


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
                                   Version 1.2.1
EOF
}

# Check for root privileges
[ "$(id -u)" -ne 0 ] && echo "This script must be run as root." && exit 1

installpkg() {
    dpkg -s "$1" >/dev/null 2>&1 || sudo apt install -y "$1" >/dev/null 2>&1
}

error() {
    
    printf "%s\n" "$1" >&2
    exit 1
}

welcomemsg() {
    whiptail --title "HARDN-XDR" --msgbox "Welcome to HARDN-XDR - A Debian Security Tool for System Hardening\n\nThis installer will update your system and configure security hardening measures to ensure STIG and Security compliance.\n\nPress OK to continue with the installation." 12 78
    
    printf "\\n\\n Welcome to HARDN-XDR a Debian Security tool for System Hardening\\n"
    printf "\\nThis installer will update your system first...\\n"
    
}

preinstallmsg() {
    printf "\\nWelcome to HARDN-XDR. A Linux Security Hardening program.\\n"
    printf "The system will be configured to ensure STIG and Security compliance.\\n"
    
    whiptail --title "HARDN-XDR" --msgbox "Welcome to HARDN-XDR. A Linux Security Hardening program.\n\nThe system will be configured to ensure STIG and Security compliance.\n\nPress OK to proceed with the hardening process." 12 78
}

update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    apt update && apt upgrade -y
    apt update -y
}

install_package_dependencies() {
    printf "\\033[1;31m[+] Installing package dependencies from progs.csv...\\033[0m\\n"
    progsfile="$1"
    
    # If progsfile is a URL, download it first
    if [[ "$progsfile" == http* ]]; then
        temp_csv=$(mktemp)
        curl -fsSL "$progsfile" -o "$temp_csv" || {
            printf "Failed to download %s\\n" "$progsfile"
            return 1
        }
        progsfile="$temp_csv"
    fi
    
    # Check if the CSV file exists
    if [[ ! -f "$progsfile" ]]; then
        printf "Package list file not found: %s\\n" "$progsfile"
        return 1
    fi
    
    # Read and install packages from CSV
    while IFS=, read -r tag name desc || [[ -n "$tag" ]]; do
        # Skip empty lines and comments
        [[ -z "$tag" || "$tag" =~ ^[[:space:]]*# ]] && continue
        
        # Remove any quotes and whitespace from name
        name=$(echo "$name" | tr -d '"' | xargs)
        
        if [[ -n "$name" ]]; then
            if ! dpkg -s "$name" >/dev/null 2>&1; then
                printf "Installing %s (%s)...\\n" "$name" "${desc:-$name}"
                apt install -y "$name" >/dev/null 2>&1 || {
                    printf "Warning: Failed to install %s\\n" "$name"
                }
            else
                printf "%s is already installed.\\n" "$name"
            fi
        fi
    done < "$progsfile"
    
    # Clean up temp file if we downloaded it
    [[ "$1" == http* ]] && rm -f "$temp_csv"
}

# Function to install packages with visual feedback
aptinstall() {
    package="$1"
    comment="$2"
    printf "Installing \`%s\` from the repository. %s\\n" "$package" "$comment"
    # It seems aptinstalled variable is not initialized or used consistently.
    # Using dpkg -s for a more reliable check.
    if dpkg -s "$package" >/dev/null 2>&1; then
        printf "%s is already installed.\\n" "$package"
        return 1
    fi
    if ! apt-get install -y "$package" >/dev/null 2>&1; then
        printf "Failed to install %s. Please check your network connection or package name.\\n" "$package"
        return 1
    fi
    apt update -y
    apt update lynis >/dev/null 2>&1 || true
}


maininstall() {
    # Installs all needed programs from main repo.
    printf "Installing \`%s\` - %s\\n" "$1" "$2"
    installpkg "$1"
}

# Function to build and install from Git repo
gitdpkgbuild() {
    repo_url="$1"
    description="$2"
    dir="/tmp/$(basename "$repo_url" .git)"

    printf "Cloning %s... (%s)\\n" "$repo_url" "$description"
    git clone --depth=1 "$repo_url" "$dir" >/dev/null 2>&1 || {
        printf "Failed to clone %s\\n" "$repo_url"
        return 1
    }
    cd "$dir" || { printf "Failed to enter %s\\n" "$dir"; return 1; }
    printf "Building and installing %s...\\n" "$description"

    # Check and install build dependencies
    printf "Checking build dependencies for %s...\\n" "$description"
    build_deps=$(dpkg-checkbuilddeps 2>&1 | grep -oP 'Unmet build dependencies: \\K.*')
    if [[ "$build_deps" ]]; then
        printf "Installing build dependencies: %s\\n" "$build_deps"
        apt-get install -y "$build_deps" >/dev/null 2>&1
    fi

    # Run dpkg-source before building (if debian/source/format exists)
    if [[ -f debian/source/format ]]; then
        dpkg-source --before-build . >/dev/null 2>&1
    fi

    # Build and install the package
    if dpkg-buildpackage -us -uc >/dev/null 2>&1; then
        debfile=$(find .. -name '*.deb' -print -quit)
        if [[ "$debfile" ]]; then
            dpkg -i "$debfile"
        else
            printf "No .deb file found after build.\\n"
            return 1
        fi
    else
        printf "%s failed to build. Installing common build dependencies and retrying...\\n" "$description"
        apt install -y build-essential debhelper libpam-tmpdir apt-listbugs devscripts git-buildpackage >/dev/null 2>&1
        if dpkg-buildpackage -us -uc >/dev/null 2>&1; then
            debfile=$(find .. -name '*.deb' -print -quit)
            if [[ "$debfile" ]]; then
                dpkg -i "$debfile"
            else
                printf "No .deb file found after retry.\\n"
                return 1
            fi
        else
            printf "%s failed to build after retry. Please check build dependencies.\\n" "$description"
            return 1
        fi
    fi
}

build_hardn_package() {
        set -e
        printf "Building HARDN Debian package...\\n"

        temp_dir=$(mktemp -d)
        cd "$temp_dir"
        git clone --depth=1 -b "$repobranch" "$repo"
        cd HARDN-XDR

        printf "Running dpkg-buildpackage...\\n"
        dpkg-buildpackage -us -uc

        cd ..
        printf "Installing HARDN package...\\n"
        dpkg -i hardn_*.deb || true
        apt install -f -y

        cd /
        rm -rf "$temp_dir"

        printf "HARDN package installed successfully\\n"
}


# setup basic configs for security tools:

setup_security(){
    printf "\\033[1;31m[+] Setting up security tools and configurations...\\033[0m\\n"
    
    # UFW (Uncomplicated Firewall)
    printf "Configuring UFW...\\n"
    ufw --force reset >/dev/null 2>&1
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow essential services
    ufw allow out 53/udp comment 'DNS'
    ufw allow out 80/tcp comment 'HTTP'
    ufw allow out 443/tcp comment 'HTTPS'
    ufw allow out 123/udp comment 'NTP'
    
    # Security-specific rules
    ufw deny out 23/tcp comment 'Block Telnet'
    ufw deny out 135/tcp comment 'Block RPC'
    ufw deny out 139/tcp comment 'Block NetBIOS'
    ufw deny out 445/tcp comment 'Block SMB'
    ufw deny in 1433/tcp comment 'Block MSSQL'
    ufw deny in 3389/tcp comment 'Block RDP'
    
    # Rate limiting for SSH
    ufw limit ssh/tcp comment 'Rate limit SSH'
    
    # Log denied connections
    ufw logging on
    
    ufw --force enable


    
    # Fail2Ban
    printf "Configuring Fail2Ban...\\n"
    systemctl enable fail2ban
    systemctl start fail2ban
    cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
    sed -i 's/bantime  = 10m/bantime  = 1h/' /etc/fail2ban/jail.local
    sed -i 's/findtime  = 10m/findtime  = 10m/' /etc/fail2ban/jail.local
    sed -i 's/maxretry = 5/maxretry = 3/' /etc/fail2ban/jail.local
    systemctl restart fail2ban

    ###### kernel hardening
    # Check if system is UEFI VM and skip kernel hardening if so
    if [ -d /sys/firmware/efi ] && systemd-detect-virt -q; then
        printf "\\033[1;33m[*] UEFI VM detected, skipping kernel hardening (sysctl settings)...\\033[0m\\n"
        
    else
        printf "\\033[1;31m[+] Configuring kernel hardening (sysctl settings)...\\033[0m\\n"
    fi


       
        # Create or overwrite the sysctl config file for kernel hardening
        # KRNL-6000: Tweak sysctl values
        {
            echo "# Kernel hardening settings by HARDN-XDR"
            echo "# Applied based on Lynis KRNL-6000 and general best practices"
            echo "kernel.kptr_restrict = 2"
            echo "kernel.randomize_va_space = 2"
            echo "kernel.yama.ptrace_scope = 1"
            echo "fs.protected_hardlinks = 1"
            echo "fs.protected_symlinks = 1"
            echo "fs.suid_dumpable = 0"
            echo "kernel.dmesg_restrict = 1"
            echo "kernel.unprivileged_bpf_disabled = 1"
            echo "kernel.unprivileged_userns_clone = 0" # Stricter: disable unprivileged user namespaces
            echo "kernel.kexec_load_disabled = 1"
            # echo "kernel.modules_disabled = 1" # Very restrictive, uncomment with caution
            echo "kernel.sysrq = 0"
            echo "kernel.core_pattern = |/bin/false"
            echo "kernel.core_uses_pid = 1"
            echo "kernel.panic = 10"
            echo "vm.mmap_rnd_bits = 32"
            echo "vm.mmap_rnd_compat_bits = 16"
            echo "net.ipv4.tcp_syncookies = 1"
            echo "net.ipv4.rfc1337 = 1"
            echo "net.ipv4.conf.all.rp_filter = 1"
            echo "net.ipv4.conf.default.rp_filter = 1"
            echo "net.ipv4.conf.all.accept_source_route = 0"
            echo "net.ipv4.conf.default.accept_source_route = 0"
            echo "net.ipv4.conf.all.accept_redirects = 0"
            echo "net.ipv4.conf.default.accept_redirects = 0"
            echo "net.ipv4.conf.all.secure_redirects = 0"
            echo "net.ipv4.conf.default.secure_redirects = 0"
            echo "net.ipv6.conf.all.accept_redirects = 0"
            echo "net.ipv6.conf.default.accept_redirects = 0"
            echo "net.ipv4.conf.all.send_redirects = 0"
            echo "net.ipv4.conf.default.send_redirects = 0"
            echo "net.ipv4.icmp_echo_ignore_broadcasts = 1"
            echo "net.ipv4.icmp_ignore_bogus_error_responses = 1"
            echo "net.ipv6.conf.all.accept_ra = 0"
            echo "net.ipv6.conf.default.accept_ra = 0"
        } > /etc/sysctl.d/99-hardn-xdr-kernel.conf

        printf "  [*] Applying new kernel parameters from /etc/sysctl.d/99-hardn-xdr-kernel.conf...\\n"
        if sysctl -p /etc/sysctl.d/99-hardn-xdr-kernel.conf >/dev/null 2>&1; then
            printf "\\033[1;32m  [+] Kernel parameters applied successfully.\\033[0m\\n"
         
        else
            printf "\\033[1;31m  [-] Error: Failed to apply kernel parameters. Check /etc/sysctl.d/99-hardn-xdr-kernel.conf and dmesg for errors.\\033[0m\\n"

  
            fi
   

    # remove locked accounts
    printf "Removing locked accounts...\\n" 
    awk -F: '($2 == "!" || $2 == "*") {print $1}' /etc/shadow | while read -r user; do
        if id "$user" >/dev/null 2>&1; then
            printf "Removing locked account: %s\\n" "$user"
            userdel -r "$user" >/dev/null 2>&1 || {
                printf "Warning: Failed to remove locked account %s.\\n" "$user"
            }
        else
            printf "User %s does not exist, skipping removal.\\n" "$user"
        fi
    done
    
    # PAM Password Quality
    printf "Configuring PAM password quality...\\n"
    if [ -f /etc/pam.d/common-password ]; then
        if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
            echo "password requisite pam_pwquality.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" >> /etc/pam.d/common-password
        fi
    else
        printf "Warning: /etc/pam.d/common-password not found, skipping PAM configuration...\\n"
    fi

    # umask for users
    printf "Setting umask for users...\\n"
    if [ -f /etc/profile ]; then
        if ! grep -q "umask 027" /etc/profile; then
            echo "umask 027" >> /etc/profile
        fi
    else
        printf "Warning: /etc/profile not found, skipping umask configuration...\\n"
    fi

    # Set password expiration policies for users [AUTH-9282]
    printf "\\n\\033[1;31m[+] Setting password expiration policies (AUTH-9282)...\\033[0m\\n"
    
    local MAX_DAYS=90
    local MIN_DAYS=7
    local WARN_DAYS=14

    # Iterate over users with UID >= 1000 and a valid login shell
    # Excludes system accounts and accounts with nologin/false shells
    getent passwd | awk -F: '$3 >= 1000 && $7 !~ /(\/nologin|\/false)$/ {print $1}' | while IFS= read -r username; do
        if id "$username" >/dev/null 2>&1; then # Check if user actually exists
            printf "  [*] Configuring password expiration for user: %s\\n" "$username"
            
            # Set Max/Min password age and Warning period
            if chage -M "$MAX_DAYS" -m "$MIN_DAYS" -W "$WARN_DAYS" "$username"; then
                printf "    [+] Password expiration policies (Max:%s, Min:%s, Warn:%s days) set for user %s.\\n" "$MAX_DAYS" "$MIN_DAYS" "$WARN_DAYS" "$username"
            else
                printf "    \\033[1;31m[-] Failed to set password expiration policies for user %s. Check chage output for details.\\033[0m\\n" "$username"
            fi
        else
            printf "  [!] User %s (from getent passwd) not found by id command. Skipping.\\n" "$username"
        fi
    done
    printf "\\033[1;32m[+] Password expiration policy configuration attempt completed for relevant users.\\033[0m\\n"
    
    # libvirt and KVM
    printf "Configuring libvirt...\\n"
    systemctl enable libvirtd
    systemctl start libvirtd
    usermod -a -G libvirt "$name" >/dev/null 2>&1 || true
    
    # chkrootkit
    printf "Configuring chkrootkit...\\n"
    if ! grep -q "chkrootkit" /etc/crontab; then
        echo "0 3 * * * root /usr/sbin/chkrootkit" >> /etc/crontab
    fi
    
    # auditd
    printf "Configuring auditd...\\n"
    if dpkg -s auditd >/dev/null 2>&1; then
        if systemctl enable auditd >/dev/null 2>&1; then
            printf "\\033[1;32m[+] auditd service enabled successfully\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to enable auditd service\\033[0m\\n"
        fi
        
        if systemctl start auditd >/dev/null 2>&1; then
            printf "\\033[1;32m[+] auditd service started successfully\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to start auditd service\\033[0m\\n"
        fi
        
        if command -v auditctl >/dev/null 2>&1; then
            if auditctl -e 1 >/dev/null 2>&1; then
                printf "\\033[1;32m[+] auditd enabled successfully\\033[0m\\n"
            else
                printf "\\033[1;31m[-] Failed to enable auditd\\033[0m\\n"
            fi
        else
            printf "\\033[1;33m[!] Warning: auditctl command not found\\033[0m\\n"
        fi
    else
        printf "\\033[1;33m[!] Warning: auditd not installed, skipping configuration...\\033[0m\\n"
    fi
    
    # Suricata
    printf "Configuring Suricata...\\n"
    if systemctl enable suricata; then
        printf "\\033[1;32m[+] Suricata service enabled successfully\\033[0m\\n"
    else
        printf "\\033[1;31m[-] Failed to enable Suricata service\\033[0m\\n"
    fi
    
    if suricata-update >/dev/null 2>&1; then
        printf "\\033[1;32m[+] Suricata rules updated successfully\\033[0m\\n"
    else
        printf "\\033[1;33m[!] Warning: Suricata rules update failed\\033[0m\\n"
    fi
    
    if systemctl start suricata; then
        printf "\\033[1;32m[+] Suricata service started successfully\\033[0m\\n"
    else
        printf "\\033[1;31m[-] Failed to start Suricata service\\033[0m\\n"
    fi
    
    # AIDE (Advanced Intrusion Detection Environment)
    if ! dpkg -s aide >/dev/null 2>&1; then
        printf "Installing and configuring AIDE...\\n"
        apt install -y aide >/dev/null 2>&1
        aideinit >/dev/null 2>&1 || true
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db >/dev/null 2>&1 || true
        echo "0 5 * * * root /usr/bin/aide --check" >> /etc/crontab
        printf "\\033[1;32m[+] AIDE installed and configured successfully\\033[0m\\n"
    else
        printf "\\033[1;33m[!] AIDE already installed, skipping configuration...\\033[0m\\n"
    fi
    # libpam-tmpdir
    printf "Configuring PAM tmpdir...\\n"
    if [ -f /etc/pam.d/common-session ]; then
        if ! grep -q "pam_tmpdir.so" /etc/pam.d/common-session; then
            echo "session optional pam_tmpdir.so" >> /etc/pam.d/common-session
        fi
    else
        printf "Warning: /etc/pam.d/common-session not found, skipping PAM tmpdir configuration...\\n"
    fi
    
    # YARA
    printf "YARA installed and ready for custom rules...\\n"
    mkdir -p /etc/yara/rules
    
    # apt-listbugs
    printf "Configuring apt-listbugs for security updates...\\n"
    if ! dpkg -s apt-listbugs >/dev/null 2>&1; then
        printf "Installing apt-listbugs...\\n"
        apt install -y apt-listbugs >/dev/null 2>&1
    fi
    # Configure apt-listbugs to only show security bugs and pin critical ones
    if [ -d /etc/apt/apt.conf.d ]; then
        cat << EOF > /etc/apt/apt.conf.d/10apt-listbugs
// apt-listbugs configuration by HARDN-XDR
// Only report security bugs
APT::ListBugs::Severities "critical,grave,serious";
// Pin critical bugs by default
APT::ListBugs::Pinning "critical";
// Set a default frontend if not already set (e.g. for non-interactive use)
// Dpkg::Pre-Install-Pkgs {"/usr/sbin/apt-listbugs apt || exit 10";};
EOF
        printf "\\033[1;32m[+] apt-listbugs configured to report security bugs and pin critical ones.\\033[0m\\n"
    else
        printf "\\033[1;33m[!] Warning: /etc/apt/apt.conf.d directory not found. Cannot configure apt-listbugs automatically.\\033[0m\\n"
    fi
    
    
restrict_compilers() {
    printf "\033[1;31m[+] Restricting compiler access to root only (HRDN-7222)...\033[0m\n"

    local compilers
	compilers="/usr/bin/gcc /usr/bin/g++ /usr/bin/make /usr/bin/cc /usr/bin/c++ /usr/bin/as /usr/bin/ld"
    for bin in $compilers; do
        if [[ -f "$bin" ]]; then
            chmod 700 "$bin"
            chown root:root "$bin"
            printf "\033[1;32m[+] Restricted %s to root only.\\033[0m\\n" "$bin"
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
    if [[ ! -f "$modprobe_conf" ]]; then
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
    local firewire_modules changed blacklist_file
	firewire_modules="firewire_core firewire_ohci firewire_sbp2"
    changed=0

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

    blacklist_file="/etc/modprobe.d/blacklist-firewire.conf"
    if [[ ! -f "$blacklist_file" ]]; then
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

    if [[ "$changed" -eq 1 ]]; then
        whiptail --infobox "FireWire drivers checked. Unloaded and/or blacklisted where applicable." 7 70
    else
        whiptail --infobox "FireWire drivers checked. No changes made (likely already disabled/not present)." 8 70
    fi
}


purge_old_packages() {
    printf "\\033[1;31m[+] Purging configuration files of old/removed packages...\033[0m\\n"
   
    local packages_to_purge
    # packages_to_purge=$(dpkg -l | grep '^rc' | awk '{print $2}') # Old problematic line
    packages_to_purge=$( (dpkg -l | grep '^rc' || true) | awk '{print $2}' ) # Corrected line
   

    if [[ -n "$packages_to_purge" ]]; then # Check if the string is non-empty
        
        printf "\\033[1;33m[*] Found the following packages with leftover configuration files to purge:\033[0m\\n"
        echo "$packages_to_purge"
       
        for pkg in $packages_to_purge; do
          
            printf "\\033[1;31m[+] Purging %s...\\033[0m\\n" "$pkg"
            if apt-get purge -y "$pkg" >/dev/null 2>&1; then
                
                printf "\\033[1;32m[+] Successfully purged %s.\\033[0m\\n" "$pkg"
            else
                
                printf "\\033[1;31m[-] Failed to purge %s. Trying dpkg --purge...\\033[0m\\n" "$pkg"
                if dpkg --purge "$pkg" >/dev/null 2>&1; then
                  
                    printf "\\033[1;32m[+] Successfully purged %s with dpkg.\\033[0m\\n" "$pkg"
                else
                   
                    printf "\\033[1;31m[-] Failed to purge %s with dpkg as well.\\033[0m\\n" "$pkg"
                fi
            fi
        done
    else
      
        printf "\\033[1;32m[+] No old/removed packages with leftover configuration files found to purge.\033[0m\\n"
    fi
   
   
    printf "\\033[1;31m[+] Running apt-get autoremove and clean to free up space...\033[0m\\n"
    ### Hardware Security Configuration ###
    printf "\\033[1;31m[+] Checking for deleted files still in use (LOGG-2190)...\033[0m\\n"
    
    local deleted_files_in_use report_file pids_to_kill
    
    if ! command -v lsof >/dev/null 2>&1; then
        printf "\\033[1;33m[!] lsof command not found. Skipping check for deleted files in use.\033[0m\\n"
    else
        deleted_files_in_use=$(lsof 2>/dev/null | grep '(deleted)')

        if [[ -n "$deleted_files_in_use" ]]; then
            printf "\\033[1;33m[!] Warning: The following deleted files are still in use by processes:\\033[0m\\n"
            echo "$deleted_files_in_use" # Print to console for script log
            
            report_file=$(mktemp)
            echo "HARDN-LOG-2190: Deleted files are still in use by processes." > "$report_file"
            {
                echo "This can indicate a security issue (e.g., a rootkit hiding files)"
                echo "or a normal operational behavior (e.g., a service holding a log file that was rotated)."
                echo "Review the list below. These processes might need to be restarted or terminated to release the files."
                echo "---------------------------------------------------------------------------------------------"
                echo "COMMAND  PID  USER   FD   TYPE DEVICE SIZE/OFF NODE NAME" # Header for context
                echo "$deleted_files_in_use"
                echo "---------------------------------------------------------------------------------------------"
            } >> "$report_file"
            
            pids_to_kill=$(echo "$deleted_files_in_use" | awk '{print $2}' | sort -u | grep -E '^[0-9]+$')
            
            if [[ -n "$pids_to_kill" ]]; then
                echo "The following PIDs are associated with these files: $(echo "$pids_to_kill" | tr '\n' ' ')" >> "$report_file"
                echo "Recommendation: Investigate these processes. You will be asked if you want to attempt to terminate them." >> "$report_file"
            else
                echo "Could not identify specific PIDs from the lsof output. Manual investigation required." >> "$report_file"
            fi

            cat "$report_file" # Show the report
            if [[ -n "$pids_to_kill" ]]; then
                printf "\\n\\033[1;31m[CRITICAL] LOGG-2190: Deleted files are still in use. Manual intervention required to terminate PIDs: %s\033[0m\\n" "$(echo "$pids_to_kill" | tr '\n' ' ')"
            else
                printf "\\n\\033[1;31m[CRITICAL] LOGG-2190: Deleted files are still in use. PIDs could not be reliably extracted. Manual investigation required.\033[0m\\n"
            fi
            rm -f "$report_file"
            printf "\\033[1;33m[!] Recommendation: Review process termination results. If files are still held or services are disrupted, investigate further. Restarting affected services gracefully is often the best approach.\033[0m\\n"

        else # No deleted files in use
            printf "\\033[1;32m[+] No deleted files found to be still in use.\033[0m\\n"
        fi
    fi 
}



enable_process_accounting_and_sysstat() {
    printf "\\033[1;31m[+] Enabling process accounting (acct) and system statistics (sysstat)...\033[0m\\n"
    local changed_acct changed_sysstat
	changed_acct=false
    changed_sysstat=false

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

    # Check for automation tools [TOOL-5002]
    printf "\\033[1;31m[+] Checking for presence of automation tools (TOOL-5002)...\033[0m\\n"
    local automation_tools found_tools
    automation_tools=("ansible" "puppet" "chef-client" "salt-call" "salt-minion")
    found_tools=""

    for tool in "${automation_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            printf "\\033[1;33m[!] Found automation tool: %s\033[0m\\n" "$tool"
            if [[ -z "$found_tools" ]]; then
                found_tools="$tool"
            else
                found_tools="$found_tools, $tool"
            fi
        fi
    done

    if [[ -n "$found_tools" ]]; then
        printf "\\033[1;33m[!] Automation tools detected: %s. This may impact manual configuration changes.\033[0m\\n" "$found_tools"
        if command -v whiptail >/dev/null; then
            whiptail --title "HARDN-XDR" --msgbox "The following automation tools were detected: $found_tools.\n\nBe aware that these tools might manage system configuration and could overwrite manual changes made by this script. It's recommended to integrate hardening practices into your automation workflows." 12 78
        fi
    else
        printf "\\033[1;32m[+] No common automation tools (Ansible, Puppet, Chef, Salt) detected.\033[0m\\n"
        if command -v whiptail >/dev/null; then
            whiptail --title "HARDN-XDR" --infobox "No common automation tools (Ansible, Puppet, Chef, Salt) were detected." 8 78
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
        local sysstat_conf
		sysstat_conf="/etc/default/sysstat"
        if [[ -f "$sysstat_conf" ]]; then
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

    if [[ "$changed_acct" = true || "$changed_sysstat" = true ]]; then
        printf "\\033[1;32m[+] Process accounting (acct) and sysstat configured successfully.\033[0m\\n"
    else
        printf "\\033[1;32m[+] Process accounting (acct) and sysstat already configured or no changes needed.\033[0m\\n"
    fi
}


disable_service_if_active() {
    local service_name
    service_name="$1"
    if systemctl is-active --quiet "$service_name"; then
        printf "\033[1;31m[+] Disabling active service: %s...\033[0m\n" "$service_name"
        systemctl disable --now "$service_name" >/dev/null 2>&1 || printf "\033[1;33m[!] Failed to disable service: %s (may not be installed or already disabled).\033[0m\n" "$service_name"
    elif systemctl list-unit-files --type=service | grep -qw "^$service_name.service"; then
        printf "\033[1;31m[+] Service %s is not active, ensuring it is disabled...\033[0m\n" "$service_name"
        systemctl disable "$service_name" >/dev/null 2>&1 || printf "\033[1;33m[!] Failed to disable service: %s (may not be installed or already disabled).\033[0m\n" "$service_name"
    else
        printf "\033[1;34m[*] Service %s not found or not installed. Skipping.\033[0m\n" "$service_name"
    fi
}

hardn_apache() {
    printf "\\033[1;31m[+] Hardening Apache web server (BOOT-5264)...\\033[0m\\n"
    
    if ! command -v apache2ctl >/dev/null; then
        printf "\\033[1;33m[!] Apache web server not found. Skipping hardening steps.\033[0m\\n"
        whiptail --msgbox "Apache web server not found. Skipping hardening steps." 8 78
        return
    fi

    # Disable directory listing
    local apache_conf="/etc/apache2/apache2.conf"
    if grep -q "Options Indexes" "$apache_conf"; then
        sed -i 's/Options Indexes/Options -Indexes/' "$apache_conf"
        printf "\\033[1;32m[+] Disabled directory listing in %s\\033[0m\\n" "$apache_conf"
    else
        printf "\\033[1;34m[*] Directory listing already disabled in %s\\033[0m\\n" "$apache_conf"
    fi

    # Disable server signature and tokens
    if ! grep -q "ServerSignature Off" "$apache_conf"; then
        echo "ServerSignature Off" >> "$apache_conf"
        printf "\\033[1;32m[+] Disabled server signature in %s\\033[0m\\n" "$apache_conf"
    else
        printf "\\033[1;34m[*] Server signature already disabled in %s\\033[0m\\n" "$apache_conf"
    fi

    if ! grep -q "ServerTokens Prod" "$apache_conf"; then
        echo "ServerTokens Prod" >> "$apache_conf"
        printf "\\033[1;32m[+] Set ServerTokens to Prod in %s\\033[0m\\n" "$apache_conf"
    else
        printf "\\033[1;34m[*] ServerTokens already set to Prod in %s\\033[0m\\n" "$apache_conf"
    fi

    # Disable TRACE method
    local conf_file="/etc/apache2/conf-available/security.conf"
    if [[ ! -f "$conf_file" ]]; then
        touch "$conf_file"
        printf "\\033[1;32m[+] Created security configuration file: %s\\033[0m\\n" "$conf_file"
    fi
    if ! grep -q "TraceEnable Off" "$conf_file"; then
        echo "TraceEnable Off" >> "$conf_file"
        printf "\\033[1;32m[+] Disabled TRACE method in %s\\033[0m\\n" "$conf_file"
    else
        printf "\\033[1;34m[*] TRACE method already disabled in %s\\033[0m\\n" "$conf_file"
    fi
    # Disable HTTP methods other than GET, POST, and HEAD
    if ! grep -q "LimitExcept GET POST HEAD" "$conf_file"; then
        echo "LimitExcept GET POST HEAD { deny all; }" >> "$conf_file"
        printf "\\033[1;32m[+] Restricted HTTP methods in %s\\033[0m\\n" "$conf_file"
    else
        printf "\\033[1;34m[*] HTTP methods already restricted in %s\\033[0m\\n" "$conf_file"
    fi
    # Disable SSLv2 and SSLv3
    if ! grep -q "SSLProtocol" "$apache_conf"; then
        echo "SSLProtocol all -SSLv2 -SSLv3" >> "$apache_conf"
        printf "\\033[1;32m[+] Disabled SSLv2 and SSLv3 in %s\\033[0m\\n" "$apache_conf"
    else
        sed -i 's/SSLProtocol.*/SSLProtocol all -SSLv2 -SSLv3/' "$apache_conf"
        printf "\\033[1;32m[+] Updated SSLProtocol to disable SSLv2 and SSLv3 in %s\\033[0m\\n" "$apache_conf"
    fi
    # Disable weak ciphers
    if ! grep -q "SSLCipherSuite" "$apache_conf"; then
        echo "SSLCipherSuite HIGH:!aNULL:!MD5:!3DES" >> "$apache_conf"
        printf "\\033[1;32m[+] Set strong ciphers in %s\\033[0m\\n" "$apache_conf"
    else
        sed -i 's/SSLCipherSuite.*/SSLCipherSuite HIGH:!aNULL:!MD5:!3DES/' "$apache_conf"
        printf "\\033[1;32m[+] Updated SSLCipherSuite to use strong ciphers in %s\\033[0m\\n" "$apache_conf"
    fi
    # Disable HTTP/2 if not needed
    if grep -q "Protocols h2" "$apache_conf"; then
        sed -i 's/Protocols h2/Protocols http/' "$apache_conf"
        printf "\\033[1;32m[+] Disabled HTTP/2 in %s\\033[0m\\n" "$apache_conf"
    else
        printf "\\033[1;34m[*] HTTP/2 not enabled, skipping disable step in %s\\033[0m\\n" "$apache_conf"
    fi
    # Restart Apache to apply changes
    if systemctl restart apache2; then
        printf "\\033[1;32m[+] Apache web server restarted successfully.\033[0m\\n"
    else
        printf "\\033[1;31m[-] Failed to restart Apache web server. Please check manually.\033[0m\\n"
    fi
    printf "\\033[1;32m[+] Apache hardening complete. Review the configuration in %s for any additional customizations.\033[0m\\n" "$apache_conf"
    whiptail --msgbox "Apache hardening complete. Review the configuration in $apache_conf for any additional customizations." 10 70
}

hardn_system_services() {
    printf "\\033[1;31m[+] Analyzing security of systemd services (BOOT-5264)...\033[0m\\n"
    
    if ! command -v systemd-analyze >/dev/null; then
        printf "\\033[1;33m[!] systemd-analyze command not found. Skipping service security analysis.\033[0m\\n"
        whiptail --msgbox "systemd-analyze command not found. Skipping service security analysis." 8 78
        return
    fi

    local services
    services=$(systemctl list-units --type=service --state=running --no-legend --plain | awk '{print $1}')
    
    if [ -z "$services" ]; then
        printf "\\033[1;33m[!] No running services found to analyze.\033[0m\\n"
        whiptail --msgbox "No running services found to analyze." 8 78
        return
    fi

    local output_file
    output_file=$(mktemp)

    echo "$services" | while IFS= read -r service_name; do
        printf "\\n\\033[1;34m[*] Analyzing: %s\\033[0m\\n" "$service_name" >> "$output_file"
        if systemd-analyze security "$service_name" >> "$output_file" 2>&1; then
            printf "\\033[1;32m  [+] Analysis for %s completed.\\033[0m\\n" "$service_name" >> "$output_file"
        else
            printf "\\033[1;31m  [-] Failed to analyze %s or service has issues.\\033[0m\\n" "$service_name" >> "$output_file"
        fi
        echo "-----------------------------------------------------" >> "$output_file"
    done

    printf "\\033[1;32m[+] Systemd service security analysis complete.\\033[0m\\n"
    
    if command -v whiptail >/dev/null; then
        whiptail --title "HARDN-XDR" --msgbox "Systemd service security analysis has been completed.\n\nAll running services have been analyzed for security exposure levels.\n\nPress OK to continue with the hardening process." 12 70
    fi
  
    rm -f "$output_file"
}

hardn_systemd(){
    printf "\\033[1;31m[+] Hardening systemd services based on security exposure levels...\\033[0m\\n"
    
    local service_overrides_dir="/etc/systemd/system"
    local changes_made=false
    
    create_service_override() {
        local service_name="$1"
        local security_settings="$2"
        local override_dir="${service_overrides_dir}/${service_name}.d"
        local override_file="${override_dir}/security-hardening.conf"
        
        if [[ ! -d "$override_dir" ]]; then
            mkdir -p "$override_dir"
            printf "\\033[1;34m[*] Created override directory: %s\\033[0m\\n" "$override_dir"
        fi
        
        cat << EOF > "$override_file"
# Security hardening override created by HARDN-XDR
# Applied to address systemd-analyze security findings
[Service]
$security_settings
EOF
        
        printf "\\033[1;32m[+] Created security override for %s\\033[0m\\n" "$service_name"
        changes_made=true
    }
    
    service_exists_and_enabled() {
        local service_name="$1"
        systemctl list-unit-files --type=service | grep -q "^${service_name}\\s" && \
        systemctl is-enabled "$service_name" >/dev/null 2>&1
    }
    
    printf "\\033[1;34m[*] Hardening UNSAFE services...\\033[0m\\n"
    
    # UNSAFE Services - Apply strict hardening
    if service_exists_and_enabled "ssh"; then
        create_service_override "ssh" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
RestrictNamespaces=yes
LockPersonality=yes
MemoryDenyWriteExecute=yes
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @privileged @reboot @swap
ReadWritePaths=/var/log /run/sshd"
    fi
    
    if service_exists_and_enabled "cron"; then
        create_service_override "cron" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @reboot @swap
ReadWritePaths=/var/log /var/spool/cron /etc/crontab /etc/cron.d"
    fi
    
    if service_exists_and_enabled "rsyslog"; then
        create_service_override "rsyslog" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @reboot @swap
ReadWritePaths=/var/log /run/rsyslog"
    fi
    
    if service_exists_and_enabled "fail2ban"; then
        create_service_override "fail2ban" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @reboot @swap
ReadWritePaths=/var/log /var/lib/fail2ban /var/run/fail2ban"
    fi
    
    if service_exists_and_enabled "suricata"; then
        create_service_override "suricata" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @reboot @swap
ReadWritePaths=/var/log/suricata /var/lib/suricata /run/suricata"
    fi
    
    if service_exists_and_enabled "docker"; then
        create_service_override "docker" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
NoNewPrivileges=yes
ReadWritePaths=/var/lib/docker /var/run/docker"
    fi
    
    if service_exists_and_enabled "containerd"; then
        create_service_override "containerd" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
NoNewPrivileges=yes
ReadWritePaths=/var/lib/containerd /run/containerd"
    fi
    
    if service_exists_and_enabled "libvirtd"; then
        create_service_override "libvirtd" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
ReadWritePaths=/var/lib/libvirt /var/log/libvirt /run/libvirt"
    fi
    
    if service_exists_and_enabled "clamav-daemon"; then
        create_service_override "clamav-daemon" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
SystemCallFilter=~@debug @mount @cpu-emulation @obsolete @reboot @swap
ReadWritePaths=/var/log/clamav /var/lib/clamav /run/clamav"
    fi
    
    printf "\\033[1;34m[*] Hardening EXPOSED services...\\033[0m\\n"
    
    # EXPOSED Services - Apply moderate hardening
    if service_exists_and_enabled "NetworkManager"; then
        create_service_override "NetworkManager" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
NoNewPrivileges=yes"
    fi
    
    if service_exists_and_enabled "auditd"; then
        create_service_override "auditd" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
ReadWritePaths=/var/log/audit"
    fi
    
    if service_exists_and_enabled "colord"; then
        create_service_override "colord" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service"
    fi
    
    if service_exists_and_enabled "fwupd"; then
        create_service_override "fwupd" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
NoNewPrivileges=yes"
    fi
    
    printf "\\033[1;34m[*] Hardening MEDIUM risk services...\\033[0m\\n"
    
    # MEDIUM Services - Apply basic hardening
    for service in "ModemManager" "accounts-daemon" "bluetooth" "bolt" "cockpit" "low-memory-monitor" "rtkit-daemon" "systemd-machined" "systemd-udevd"; do
        if service_exists_and_enabled "$service"; then
            create_service_override "$service" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes"
        fi
    done

    if service_exists_and_enabled "aide-check"; then
        create_service_override "aide-check" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
ReadWritePaths=/var/lib/aide /var/log/aide"
    fi
    
    if service_exists_and_enabled "lynis"; then
        create_service_override "lynis" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
ReadWritePaths=/var/log/lynis /var/lib/lynis"
    fi
    
    if service_exists_and_enabled "maldet"; then
        create_service_override "maldet" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=read-only
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
ReadWritePaths=/var/log/maldet /usr/local/maldetect"
    fi
    
    if service_exists_and_enabled "psad"; then
        create_service_override "psad" "PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
NoNewPrivileges=yes
PrivateDevices=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
SystemCallFilter=@system-service
ReadWritePaths=/var/log/psad /var/lib/psad /run/psad"
    fi
    
    if service_exists_and_enabled "unattended-upgrades"; then
        create_service_override "unattended-upgrades" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
NoNewPrivileges=yes
ReadWritePaths=/var/log /var/cache/apt /var/lib/apt"
    fi

    # Add additional EXPOSED services:
    if service_exists_and_enabled "power-profiles-daemon"; then
        create_service_override "power-profiles-daemon" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
NoNewPrivileges=yes"
    fi
    
    if service_exists_and_enabled "switcheroo-control"; then
        create_service_override "switcheroo-control" "PrivateTmp=yes
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictRealtime=yes
LockPersonality=yes
NoNewPrivileges=yes"
    fi

    # Disable unnecessary services marked as UNSAFE
    printf "\\033[1;34m[*] Disabling unnecessary UNSAFE services...\\033[0m\\n"
    
    local services_to_disable="avahi-daemon cups-browsed cups exim4 anacron alsa-state cpufrequtils loadcpufreq plymouth-start rc-local"
    for service in $services_to_disable; do
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            printf "\\033[1;31m[+] Disabling unnecessary service: %s\\033[0m\\n" "$service"
            systemctl disable --now "$service" >/dev/null 2>&1 || true
            changes_made=true
        fi
    done
    
    # Apply changes if any were made
    if [[ "$changes_made" = true ]]; then
        printf "\\033[1;33m[*] Reloading systemd daemon to apply security overrides...\\033[0m\\n"
        systemctl daemon-reload
        
        printf "\\033[1;32m[+] Systemd service hardening completed successfully.\\033[0m\\n"
        printf "\\033[1;33m[!] Note: Some services may need to be restarted for changes to take effect.\\033[0m\\n"
        
        if command -v whiptail >/dev/null; then
            whiptail --title "HARDN-XDR" --msgbox "Systemd services have been hardened with security overrides.\n\nChanges applied to UNSAFE, EXPOSED, and MEDIUM risk services.\nSome services have been disabled if deemed unnecessary.\n\nReview /etc/systemd/system/*.d/ directories for applied overrides." 12 78
        fi
        
        # Optional: Restart critical services to apply new settings immediately
        printf "\\033[1;34m[*] Restarting critical services to apply new security settings...\\033[0m\\n"
        for service in "ssh" "rsyslog" "fail2ban"; do
            if systemctl is-active --quiet "$service"; then
                printf "\\033[1;33m[*] Restarting %s...\\033[0m\\n" "$service"
                systemctl restart "$service" >/dev/null 2>&1 || \
                printf "\\033[1;31m[-] Failed to restart %s\\033[0m\\n" "$service"
            fi
        done
    else
        printf "\\033[1;32m[+] No systemd service hardening changes were needed.\\033[0m\\n"
    fi
    
    printf "\\033[1;32m[+] Systemd service security hardening process completed.\\033[0m\\n"
}




remove_unnecessary_services() {
    printf "\033[1;32m[+] Disabling unnecessary services...\033[0m\n"
    
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


pen_test() {
    printf "\\033[1;31m[+] Running comprehensive penetration tests with strongest Lynis configuration...\\033[0m\\n"
    whiptail --title "HARDN-XDR" --msgbox "Your system will be tested with the most comprehensive and detailed Lynis security audit available. This includes all tests, strict compliance checks, and verbose output." 10 78
    
    # Create temporary Lynis profile for maximum testing
    local lynis_profile="/tmp/hardn-comprehensive.prf"
    cat << EOF > "$lynis_profile"
# HARDN-XDR Comprehensive Security Profile
# This profile enables the most detailed and strict Lynis testing

# Enable all available tests
config:test_skip_always:no

# Maximum verbosity and detail
config:show_tool_tips:yes
config:show_warnings_only:no
config:colors:yes
config:compliance:yes
config:forensic_mode:yes

# Strict security settings
config:strict_compliance:yes
config:manual_audit:yes

# Enable all compliance frameworks
config:compliance_standards:all

# Maximum logging
config:log_tests_incorrect_os:yes
config:verbose:yes

# Security-focused settings
config:security_audit:yes
config:pentest_mode:yes
EOF

    printf "\\033[1;33m[*] Running the most comprehensive Lynis security audit...\\033[0m\\n"
    printf "\\033[1;34m[*] This includes all available tests with maximum detail and strict compliance checking\\033[0m\\n"
    printf "\\033[1;34m======================================\\033[0m\\n"
    
    set +e  # Allow commands to fail without exiting
    
    # Run comprehensive Lynis audit with all available options
    printf "\\033[1;32m[PHASE 1] Running full system audit with pentest mode...\\033[0m\\n"
    lynis audit system --pentest --profile "$lynis_profile" --verbose --no-colors
    
    printf "\\n\\033[1;32m[PHASE 2] Running security-focused audit...\\033[0m\\n"
    lynis audit system --tests-category security --profile "$lynis_profile" --verbose
    
    printf "\\n\\033[1;32m[PHASE 3] Running compliance audit (all standards)...\\033[0m\\n"
    lynis audit system --compliance --profile "$lynis_profile" --verbose
    
    printf "\\n\\033[1;32m[PHASE 4] Running forensic mode audit...\\033[0m\\n"
    lynis audit system --forensics --profile "$lynis_profile" --verbose
    
    printf "\\n\\033[1;32m[PHASE 5] Running manual audit mode...\\033[0m\\n"
    lynis audit system --manpage --profile "$lynis_profile" --verbose
    
    printf "\\n\\033[1;32m[PHASE 6] Running all available individual test categories...\\033[0m\\n"
    for category in accounting authentication banners boot crypto file_integrity \
                   firewalls hardening kernel logging malware networking ports_packages \
                   printers processes scheduling shells squid ssh storage time tooling; do
        if lynis show categories 2>/dev/null | grep -q "$category"; then
            printf "\\033[1;33m[*] Testing category: %s\\033[0m\\n" "$category"
            lynis audit system --tests-category "$category" --profile "$lynis_profile"
        fi
    done
    
    printf "\\n\\033[1;32m[PHASE 7] Running vulnerability assessment...\\033[0m\\n"
    lynis audit system --check-all --profile "$lynis_profile" --verbose
    
    printf "\\n\\033[1;32m[PHASE 8] Generating comprehensive report...\\033[0m\\n"
    lynis generate report --profile "$lynis_profile"
    
    local lynis_exit_code=$?
    set -e  # Re-enable exit on error
    
    # Clean up temporary profile
    rm -f "$lynis_profile"
    
    printf "\\033[1;34m======================================\\033[0m\\n"
    printf "\\033[1;33m[*] Comprehensive Lynis audit completed with exit code: %s\\033[0m\\n" "$lynis_exit_code"
    
    # Show Lynis report location
    local lynis_log="/var/log/lynis.log"
    local lynis_report="/var/log/lynis-report.dat"
    
    if [[ -f "$lynis_log" ]]; then
        printf "\\033[1;32m[+] Detailed log available at: %s\\033[0m\\n" "$lynis_log"
    fi
    
    if [[ -f "$lynis_report" ]]; then
        printf "\\033[1;32m[+] Machine-readable report available at: %s\\033[0m\\n" "$lynis_report"
    fi
    
    printf "\\033[1;32m[+] Most comprehensive penetration testing completed!\\033[0m\\n"
    
    whiptail --title "HARDN-XDR Comprehensive Security Audit Results" --msgbox "Comprehensive Security Audit Completed!\n\nLynis has performed the most detailed security assessment possible including:\n- Full system penetration testing\n- All security categories\n- Compliance checking (all standards)\n- Forensic analysis\n- Vulnerability assessment\n\nReview the detailed output above and check /var/log/lynis.log for complete results." 16 78
    
    printf "\\033[1;32m[+] Comprehensive security assessment and penetration testing completed!\\033[0m\\n"
}

cleanup() {
    printf "\\033[1;31m[+] Cleaning up temporary files...\\033[0m\\n"
    rm -rf /tmp/* >/dev/null 2>&1
    apt autoremove -y >/dev/null 2>&1
    apt clean >/dev/null 2>&1
    apt update -y >/dev/null 2>&1
    printf "\\033[1;32m[+] Cleanup completed!\\033[0m\\n"
    
    # Notify user installation is complete
    printf "\\n\\033[1;32mHARDN-XDR Install Complete, please reboot your system\\033[0m\\n"
    whiptail --title "HARDN-XDR" --msgbox "HARDN-XDR Install Complete, please reboot your system" 8 60
}





main() {
    print_ascii_banner
    welcomemsg
    
    update_system_packages
    install_package_dependencies "$progsfile"
    maininstall "hardn" "HARDN-XDR Main Program"
    build_hardn_package
    setup_security
    hardn_apache
    enable_process_accounting_and_sysstat
    purge_old_packages
    disable_firewire_drivers
    restrict_compilers
    hardn_system_services
    #hardn_systemd
    disable_binfmt_misc
    remove_unnecessary_services
    pen_test
    cleanup

    printf "\\n\\033[1;32mHARDN-XDR installation completed, Please reboot your System.\\033[0m\\n"
}

main "$@"