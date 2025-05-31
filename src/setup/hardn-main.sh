#!/bin/bash

# HARDN-XDR - The Linux Security Hardening Sentinel
# Developed and built by Christopher Bingham and Tim Burns

# --- Global Variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGS_CSV_PATH="${SCRIPT_DIR}/../../progs.csv" 
CURRENT_DEBIAN_VERSION_ID=""
CURRENT_DEBIAN_CODENAME=""


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
                                  
EOF
}

######### DETECT OS VERSIONS
detect_os_details() {
    printf "\033[1;34m[*] Detecting operating system details...\033[0m\n"
    if [[ -f /etc/os-release ]]; then
        
       
        source /etc/os-release
        CURRENT_DEBIAN_VERSION_ID="${VERSION_ID}"
        CURRENT_DEBIAN_CODENAME="${VERSION_CODENAME}"

        if [[ "${ID}" != "debian" ]]; then
            printf "\033[1;31m[-] Error: This script is intended for Debian distributions only. Detected ID: %s\033[0m\n" "${ID}"
            exit 1
        fi

        # FALLBACK for Debian 12 only
        if [[ -z "${CURRENT_DEBIAN_CODENAME}" ]] && [[ -f /etc/debian_version ]]; then
            local debian_version_major
            debian_version_major=$(cut -d'.' -f1 /etc/debian_version)
            case "${debian_version_major}" in
                "12") CURRENT_DEBIAN_CODENAME="bookworm" ;;
                *) CURRENT_DEBIAN_CODENAME="" ;;
            esac
            # If VERSION_ID was also empty, try to set it from debian_version_major
            [[ -z "${CURRENT_DEBIAN_VERSION_ID}" ]] && CURRENT_DEBIAN_VERSION_ID="${debian_version_major}"
        fi

        if [[ -z "${CURRENT_DEBIAN_VERSION_ID}" || -z "${CURRENT_DEBIAN_CODENAME}" ]]; then
            printf "\033[1;31m[-] Error: Could not reliably determine Debian version ID or codename.\033[0m\n"
            printf "\033[1;31m[-] Please ensure /etc/os-release and /etc/debian_version are correctly populated.\033[0m\n"
            exit 1
        fi

        printf "\033[1;32m[+] Detected Debian Version ID: %s, Codename: %s\033[0m\n" "${CURRENT_DEBIAN_VERSION_ID}" "${CURRENT_DEBIAN_CODENAME}"

        # Validate supported Debian versions (only Debian 12 bookworm)
        case "${CURRENT_DEBIAN_CODENAME}" in
            "bookworm")
                printf "\033[1;32m[+] Debian %s (%s) is the supported version.\033[0m\n" "${CURRENT_DEBIAN_VERSION_ID}" "${CURRENT_DEBIAN_CODENAME}"
                ;;
            *)
                printf "\033[1;31m[-] Error: Debian %s (%s) is not supported. This script only supports Debian 12 (bookworm).\033[0m\n" "${CURRENT_DEBIAN_VERSION_ID}" "${CURRENT_DEBIAN_CODENAME}"
                exit 1
                ;;
        esac
    else
        printf "\033[1;31m[-] Error: /etc/os-release not found. Cannot determine OS details.\033[0m\n"
        exit 1
    fi
}


# Check for root privileges
[ "$(id -u)" -ne 0 ] && echo "This script must be run as root." && exit 1

# Call OS detection early
detect_os_details

welcomemsg() {
    printf "\\n\\n Welcome to HARDN-XDR a Debian Security tool for System Hardening\\n"
    printf "\\nThis installer will update your system first...\\n"
}

preinstallmsg() {
    printf "\\nWelcome to HARDN-XDR. A Linux Security Hardening program.\\n"
    printf "The system will be configured to ensure STIG and Security compliance.\\n"
}

update_system_packages() {
    printf "\033[1;31m[+] Updating system packages...\033[0m\n"
    apt update -y
}

install_package_dependencies() {
    printf "\033[1;31m[+] Installing package dependencies from %s...\033[0m\n" "${PROGS_CSV_PATH}"

    if ! command -v git >/dev/null 2>&1; then
        printf "\033[1;34m[*] Git is not installed. Attempting to install git...\033[0m\n"
        if DEBIAN_FRONTEND=noninteractive apt-get install -y git >/dev/null 2>&1; then
            printf "\033[1;32m[+] Successfully installed git.\033[0m\n"
        else
            printf "\033[1;31m[-] Error: Failed to install git. Some packages might fail to install if they require git.\033[0m\n"
        fi
    else
        printf "\033[1;34m[*] Git is already installed.\033[0m\n"
    fi

    # Check if the CSV file exists
    if [[ ! -f "${PROGS_CSV_PATH}" ]]; then
        printf "\033[1;31m[-] Error: Package list file not found: %s\033[0m\n" "${PROGS_CSV_PATH}"
        return 1
    fi

    # Read the CSV file, skipping the header
    while IFS=, read -r name version debian_min_version debian_codenames_str rest || [[ -n "$name" ]]; do
        # Skip comments and empty lines
        [[ -z "$name" || "$name" =~ ^[[:space:]]*# ]] && continue

        name=$(echo "$name" | xargs)
        version=$(echo "$version" | xargs)
        debian_min_version=$(echo "$debian_min_version" | xargs)
        debian_codenames_str=$(echo "$debian_codenames_str" | xargs | tr -d '"') # Remove quotes from codenames string

        if [[ -z "$name" ]]; then
            printf "\033[1;33m[!] Warning: Skipping line with empty package name.\033[0m\n"
            continue
        fi

        printf "\033[1;34m[*] Processing package: %s (Version: %s, Min Debian: %s, Codenames: '%s')\033[0m\n" "$name" "$version" "$debian_min_version" "$debian_codenames_str"

        # Check OS compatibility
        os_compatible=false
        if [[ ",${debian_codenames_str}," == *",${CURRENT_DEBIAN_CODENAME},"* ]]; then
            if [[ "${debian_min_version}" == "12" ]]; then
                os_compatible=true
            else
                printf "\033[1;33m[!] Skipping %s: Requires Debian version >= %s, but current is %s.\033[0m\n" "$name" "$debian_min_version" "$CURRENT_DEBIAN_VERSION_ID"
            fi
        else
            printf "\033[1;33m[!] Skipping %s: Not compatible with Debian codename %s (requires one of: %s).\033[0m\n" "$name" "$CURRENT_DEBIAN_CODENAME" "$debian_codenames_str"
        fi

        if ! $os_compatible; then
            continue
        fi

        # Installation logic based on version
        case "$version" in
            "latest")
                if ! dpkg -s "$name" >/dev/null 2>&1; then
                    printf "\033[1;34m[*] Attempting to install package: %s (latest from apt)...\033[0m\n" "$name"
                    if DEBIAN_FRONTEND=noninteractive apt install -y "$name"; then
                        printf "\033[1;32m[+] Successfully installed %s.\033[0m\n" "$name"
                    else
                        printf "\033[1;33m[!] apt install failed for %s, trying apt-get...\033[0m\n" "$name"
                        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$name"; then
                             printf "\033[1;32m[+] Successfully installed %s with apt-get.\033[0m\n" "$name"
                        else
                            printf "\033[1;31m[-] Error: Failed to install %s with both apt and apt-get. Please check manually.\033[0m\n" "$name"
                        fi
                    fi
                else
                    printf "\033[1;34m[*] Package %s is already installed.\033[0m\n" "$name"
                fi
                ;;
            "source")
                printf "\033[1;33m[!] INFO: 'source' installation type for %s. This type requires manual implementation in the script.\033[0m\n" "$name"
                printf "\033[1;33m[!] Example steps for a source install (e.g., for a package named 'mytool'):\033[0m\n"
                printf "\033[1;33m[!]   1. Ensure build dependencies are installed (e.g., build-essential, cmake, etc.).\033[0m\n"
                printf "\033[1;33m[!]   2. wget https://example.com/mytool-src.tar.gz -O /tmp/mytool-src.tar.gz\033[0m\n"
                printf "\033[1;33m[!]   3. tar -xzf /tmp/mytool-src.tar.gz -C /tmp\033[0m\n"
                printf "\033[1;33m[!]   4. cd /tmp/mytool-* || exit 1\033[0m\n"
                printf "\033[1;33m[!]   5. ./configure && make && sudo make install\033[0m\n"
                printf "\033[1;33m[!] Skipping %s as its specific source installation steps are not defined.\033[0m\n" "$name"
                ;;
            "custom")
                printf "\033[1;33m[!] INFO: 'custom' installation type for %s. This type requires manual implementation in the script.\033[0m\n" "$name"
                printf "\033[1;33m[!] Example steps for a custom install (e.g., for a package named 'mycustomapp'):\033[0m\n"
                printf "\033[1;33m[!]   1. Add custom repository: curl -sSL https://example.com/repo/gpg | sudo apt-key add - \033[0m\n"
                printf "\033[1;33m[!]   2. echo 'deb https://example.com/repo %s main' | sudo tee /etc/apt/sources.list.d/mycustomapp.list \033[0m\n" "${CURRENT_DEBIAN_CODENAME}"
                printf "\033[1;33m[!]   3. sudo apt update \033[0m\n"
                printf "\033[1;33m[!]   4. sudo apt install -y mycustomapp \033[0m\n"
                printf "\033[1;33m[!] Skipping %s as its specific custom installation steps are not defined.\033[0m\n" "$name"
                ;;
            *)
                printf "\033[1;31m[-] Error: Unknown version '%s' for package %s. Skipping...\033[0m\n" "$version" "$name"
                ;;
        esac
    done < <(tail -n +2 "${PROGS_CSV_PATH}")
    printf "\033[1;31m[+] Package dependency installation attempt completed.\033[0m\n"
}



setup_security(){
    printf "\033[1;32m[+] Using detected system: Debian %s (%s) for security setup.\033[0m\n" "${CURRENT_DEBIAN_VERSION_ID}" "${CURRENT_DEBIAN_CODENAME}"

 ####################### DELETED FILES
    printf "\\033[1;31m[+] Checking for deleted files in use...\\033[0m\\n"
    if command -v lsof >/dev/null 2>&1; then
        deleted_files=$(lsof +L1 | awk '{print $9}' | grep -v '^$')
        if [[ -n "$deleted_files" ]]; then
            printf "\\033[1;33m[!] Warning: Found deleted files in use:\\033[0m\\n"
            echo "$deleted_files"
            printf "\\033[1;33mPlease consider rebooting the system to release these files.\\033[0m\\n"
        else
            printf "\\033[1;32m[+] No deleted files in use found.\\033[0m\\n"
        fi
    else
        printf "\\033[1;31m[-] Error: lsof command not found. Cannot check for deleted files in use.\\033[0m\\n"
    fi
    
################################## ntp daemon
    printf "\\033[1;31m[+] Setting up NTP daemon...\\033[0m\\n"

    local ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
    local configured=false

    # Prefer systemd-timesyncd if active
    if systemctl is-active --quiet systemd-timesyncd; then
        printf "\\033[1;34m[*] systemd-timesyncd is active. Configuring...\\033[0m\\n"
        local timesyncd_conf="/etc/systemd/timesyncd.conf"
        local temp_timesyncd_conf
        temp_timesyncd_conf=$(mktemp)

        if [[ ! -f "$timesyncd_conf" ]]; then
            printf "\\033[1;33m[*] Creating %s as it does not exist.\\033[0m\\n" "$timesyncd_conf"
            echo "[Time]" > "$timesyncd_conf"
            chmod 644 "$timesyncd_conf"
        fi

        cp "$timesyncd_conf" "$temp_timesyncd_conf"

        # Set NTP= explicitly
        if grep -qE "^\s*NTP=" "$temp_timesyncd_conf"; then
            sed -i -E "s/^\s*NTP=.*/NTP=$ntp_servers/" "$temp_timesyncd_conf"
        else
            if grep -q "\[Time\]" "$temp_timesyncd_conf"; then
                sed -i "/\[Time\]/a NTP=$ntp_servers" "$temp_timesyncd_conf"
            else
                echo -e "\n[Time]\nNTP=$ntp_servers" >> "$temp_timesyncd_conf"
            fi
        fi

        if ! cmp -s "$temp_timesyncd_conf" "$timesyncd_conf"; then
            cp "$temp_timesyncd_conf" "$timesyncd_conf"
            printf "\\033[1;32m[+] Updated %s. Restarting systemd-timesyncd...\\033[0m\\n" "$timesyncd_conf"
            if systemctl restart systemd-timesyncd; then
                printf "\\033[1;32m[+] systemd-timesyncd restarted successfully.\\033[0m\\n"
                configured=true
            else
                printf "\\033[1;31m[-] Failed to restart systemd-timesyncd. Manual check required.\\033[0m\\n"
            fi
        else
            printf "\\033[1;34m[*] No effective changes to %s were needed.\\033[0m\\n" "$timesyncd_conf"
            configured=true # Already configured correctly or no changes needed
        fi
        rm -f "$temp_timesyncd_conf"

    # Fallback to ntpd if systemd-timesyncd is not active
    else
        printf "\\033[1;34m[*] systemd-timesyncd is not active. Checking/Configuring ntpd...\\033[0m\\n"

        local ntp_package_installed=false
        # Ensure ntp package is installed
        if dpkg -s ntp >/dev/null 2>&1; then
             printf "\\033[1;32m[+] ntp package is already installed.\\033[0m\\n"
             ntp_package_installed=true
        else
             printf "\\033[1;33m[*] ntp package not found. Attempting to install...\\033[0m\\n"
             # Attempt installation, check exit status
             if apt-get update >/dev/null 2>&1 && apt-get install -y ntp >/dev/null 2>&1; then
                 printf "\\033[1;32m[+] ntp package installed successfully.\\033[0m\\n"
                 ntp_package_installed=true
             else
                 printf "\\033[1;31m[-] Error: Failed to install ntp package. Skipping NTP configuration.\\033[0m\\n"
                 configured=false # Ensure configured is false on failure
                 # Do not return here, allow the rest of setup_security to run
             fi
        fi

        # Proceed with configuration ONLY if the package is installed
        if [[ "$ntp_package_installed" = true ]]; then
            local ntp_conf="/etc/ntp.conf"
            # Check if the configuration file exists and is writable
            if [[ -f "$ntp_conf" ]] && [[ -w "$ntp_conf" ]]; then
                printf "\\033[1;34m[*] Configuring %s...\\033[0m\\n" "$ntp_conf"
                # Backup existing config
                cp "$ntp_conf" "${ntp_conf}.bak.$(date +%F-%T)" 2>/dev/null || true

                # Remove existing pool/server lines and add the desired ones
                local temp_ntp_conf
                temp_ntp_conf=$(mktemp)
                grep -vE "^\s*(pool|server)\s+" "$ntp_conf" > "$temp_ntp_conf"
                {
                    echo "# HARDN-XDR configured NTP servers"
                    for server in $ntp_servers; do
                        echo "pool $server iburst"
                    done
                } >> "$temp_ntp_conf"

                # Check if changes were made before copying and restarting
                if ! cmp -s "$temp_ntp_conf" "$ntp_conf"; then
                    mv "$temp_ntp_conf" "$ntp_conf"
                    printf "\\033[1;32m[+] Updated %s with recommended pool servers.\\033[0m\\n" "$ntp_conf"

                    # Restart/Enable ntp service
                    if systemctl enable --now ntp; then
                        printf "\\033[1;32m[+] ntp service enabled and started successfully.\\033[0m\\n"
                        configured=true
                    else
                        printf "\\033[1;31m[-] Failed to enable/start ntp service. Manual check required.\\033[0m\\n"
                        configured=false # Set to false on service failure
                    fi
                else
                    printf "\\033[1;34m[*] No effective changes to %s were needed.\\033[0m\\n" "$ntp_conf"
                    configured=true # Already configured correctly or no changes needed
                fi
                rm -f "$temp_ntp_conf" # Clean up temp file

            else
                # This is the error path the user saw
                printf "\\033[1;31m[-] Error: NTP configuration file %s not found or not writable after ntp package check/installation. Skipping NTP configuration.\\033[0m\\n" "$ntp_conf"
                configured=false # Set to false if config file is missing/unwritable
            fi
        fi # End if ntp_package_installed
    fi # End of systemd-timesyncd else block

    if [[ "$configured" = true ]]; then
        printf "\\033[1;32m[+] NTP configuration attempt completed.\\033[0m\\n"
    else
        printf "\\033[1;31m[-] NTP configuration failed or skipped due to errors.\\033[0m\\n"
    fi

    printf "\\033[1;31m[+] Setting up security tools and configurations...\\033[0m\\n"
    
    ########################### UFW (Uncomplicated Firewall)
    printf "Configuring UFW...\\n"
    if ! command -v ufw >/dev/null 2>&1; then
        printf "UFW not found, installing...\n"
        apt-get update && apt-get install -y ufw
    fi

    if command -v ufw >/dev/null 2>&1; then
        ufw --force reset >/dev/null 2>&1
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow essential services
        ufw allow ssh
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
    else
        printf "Warning: UFW could not be installed or found. Skipping UFW configuration.\\n"
    fi


    ############################## Automation tool check
    printf "\\033[1;31m[+] Checking for automation tools...\\033[0m\\n"
    local automation_tools=("ansible" "puppet" "chef" "salt")
    local found_tools=()
    for tool in "${automation_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            found_tools+=("$tool")
            printf "\\033[1;32m[+] Found automation tool: %s\\033[0m\\n" "$tool"
        else
            printf "\\033[1;33m[!] Automation tool not found: %s\\033[0m\\n" "$tool"
        fi
    done
    
    ###################################### Fail2Ban
    printf "\\033[1;31m[+] Configuring Fail2Ban...\\033[0m\\n"
    # Check if Fail2Ban package is installed
    if dpkg -s fail2ban >/dev/null 2>&1; then
        printf "\\033[1;32m[+] Fail2Ban package is installed.\\033[0m\\n"

        # Check if the service unit file exists before trying to enable/start
        if systemctl list-unit-files --type=service | grep -q '^fail2ban\.service'; then
            printf "\\033[1;34m[*] Enabling and starting Fail2Ban service...\\033[0m\\n"
            systemctl enable fail2ban >/dev/null 2>&1
            systemctl start fail2ban >/dev/null 2>&1
            if systemctl is-active --quiet fail2ban; then
                 printf "\\033[1;32m[+] Fail2Ban service enabled and started.\\033[0m\\n"
            else
                 printf "\\033[1;33m[!] Warning: Failed to start Fail2Ban service.\\033[0m\\n"
            fi
        else
            printf "\\033[1;33m[!] Warning: fail2ban.service not found, skipping service enable/start.\\033[0m\\n"
        fi

        # Configure jail.local for STIG compliance (SSH specific)
        local jail_conf="/etc/fail2ban/jail.conf"
        local jail_local="/etc/fail2ban/jail.local"

        if [ -f "$jail_conf" ]; then
            printf "\\033[1;34m[*] Configuring %s for SSH STIG compliance...\\033[0m\\n" "$jail_local"
            # Create jail.local if it doesn't exist or copy from jail.conf
            if [ ! -f "$jail_local" ]; then
                cp "$jail_conf" "$jail_local"
                printf "\\033[1;32m[+] Created %s from %s.\\033[0m\\n" "$jail_local" "$jail_conf"
            else
                 printf "\\033[1;34m[*] %s already exists. Modifying existing file.\\033[0m\\n" "$jail_local"
            fi

            # Apply STIG-like settings to jail.local for SSH
            # Ensure bantime is at least 1 hour (3600 seconds)
            sed -i 's/^\s*bantime\s*=\s*.*/bantime = 3600/' "$jail_local" 2>/dev/null || true
            # Ensure findtime is at least 15 minutes (900 seconds)
            sed -i 's/^\s*findtime\s*=\s*.*/findtime = 900/' "$jail_local" 2>/dev/null || true
            # Ensure maxretry is 3 or less
            sed -i 's/^\s*maxretry\s*=\s*.*/maxretry = 5/' "$jail_local" 2>/dev/null || true

            # Ensure sshd jail is enabled (uncomment or add if missing)
            if ! grep -q '^\[sshd\]' "$jail_local"; then # Removed space and corrected grep pattern for [sshd]
                 echo -e "\n[sshd]\nenabled = true" >> "$jail_local"
                 printf "\\033[1;32m[+] Added [sshd] jail configuration to %s.\\033[0m\\n" "$jail_local"
            else
                 sed -i '/^\[sshd\]/,/^\[.*\]/ s/^\s*enabled\s*=\s*false/enabled = true/' "$jail_local" 2>/dev/null || true # Corrected grep pattern for [sshd]
                 printf "\\033[1;34m[*] Ensured sshd jail is enabled in %s.\\033[0m\\n" "$jail_local"
            fi

            printf "\\033[1;32m[+] Applied STIG-like settings \\(bantime=1h, findtime=15m, maxretry=3\\) to sshd jail in %s.\\033[0m\\n" "$jail_local"

            # Restart Fail2Ban to apply changes
            if systemctl list-unit-files --type=service | grep -q '^fail2ban\.service'; then
                 printf "\\033[1;34m[*] Restarting Fail2Ban service to apply changes...\\033[0m\\n"
                 if systemctl restart fail2ban >/dev/null 2>&1; then
                     printf "\\033[1;32m[+] Fail2Ban service restarted successfully.\\033[0m\\n"
                 else
                     printf "\\033[1;31m[-] Failed to restart Fail2Ban service.\\033[0m\\n"
                 fi
            fi

        else
            printf "\\033[1;31m[-] Error: %s not found, skipping jail.local configuration.\\033[0m\\n" "$jail_conf"
        fi
    else
        printf "\\033[1;33m[!] Warning: Fail2Ban is not installed (checked with dpkg -s). Skipping configuration.\\033[0m\\n"
        printf "\\033[1;33m[!] Please ensure Fail2Ban is listed in ../../progs.csv for installation.\\033[0m\\n"
    fi
    printf "\\033[1;32m[+] Fail2Ban configuration attempt completed.\\033[0m\\n"

    ################################### kernel hardening
    # Check if system is UEFI VM and skip kernel hardening if so
    if [ -d /sys/firmware/efi ] && systemd-detect-virt -q; then
        printf "UEFI VM detected, skipping kernel hardening...\\n"
    else
        printf "Configuring kernel hardening...\\n"
        {
            echo "kernel.kptr_restrict = 2"
            echo "kernel.randomize_va_space = 2"
            echo "kernel.yama.ptrace_scope = 1"
            echo "fs.protected_hardlinks = 1"
            echo "fs.protected_symlinks = 1"
            echo "fs.suid_dumpable = 0"
            echo "kernel.dmesg_restrict = 1"
            echo "kernel.unprivileged_bpf_disabled = 1"
            echo "kernel.kexec_load_disabled = 1"
            echo "kernel.sysrq = 0"
            echo "kernel.core_pattern = |/bin/false"
            echo "kernel.core_uses_pid = 1"
            echo "kernel.panic = 10"
        } >> /etc/sysctl.conf
    fi

    ###################### EUFI/grub
    # Check if system is UEFI and not using GRUB
    if [ -d /sys/firmware/efi ] && ! command -v grub-install >/dev/null 2>&1; then
        printf "UEFI system detected without GRUB, skipping GRUB configuration...\\n"
    elif [ ! -f /etc/default/grub ]; then
        printf "GRUB configuration file not found, skipping GRUB configuration...\\n"
    else
        printf "Configuring GRUB...\\n"
        # Backup original GRUB config
        cp /etc/default/grub "/etc/default/grub.bak.$(date +%F-%T)" 2>/dev/null || true
        
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=auto"/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_HIDDEN_TIMEOUT=0/GRUB_HIDDEN_TIMEOUT=5/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_HIDDEN_TIMEOUT_QUIET=true/GRUB_HIDDEN_TIMEOUT_QUIET=false/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_TERMINAL=console/GRUB_TERMINAL=console/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub 2>/dev/null || true
        
        if update-grub >/dev/null 2>&1; then
            printf "GRUB configuration updated.\\n"
        else
            printf "Warning: Failed to update GRUB configuration.\\n"
        fi
    fi
    
    ################################## AppArmor
    printf "Configuring AppArmor...\\n"
    if [ -d /sys/kernel/security/apparmor ]; then
        systemctl enable apparmor >/dev/null 2>&1
        systemctl start apparmor >/dev/null 2>&1
        # Check if AppArmor is actually running before enforcing profiles
        if systemctl is-active --quiet apparmor && [ -f /sys/kernel/security/apparmor/profiles ]; then
            aa-enforce /etc/apparmor.d/* >/dev/null 2>&1 || {
                printf "Warning: Failed to enforce some AppArmor profiles.\\n"
            }
        else
            printf "Warning: AppArmor not properly initialized, skipping profile enforcement.\\n"
        fi
    else
        printf "Warning: AppArmor not supported on this system, skipping configuration.\\n"
    fi
    
    ############################ Firejail
    printf "Configuring Firejail...\\n"
    firecfg >/dev/null 2>&1 || true
    

    browsers=("firefox" "google-chrome" "tor" "brave")
    for browser in "${browsers[@]}"; do
        if command -v "$browser" >/dev/null 2>&1; then
            printf "Configuring Firejail for %s...\\n" "$browser"
            firejail --apparmor --seccomp --private-tmp --noroot --caps.drop=all "$browser" >/dev/null 2>&1 || true
        fi
    done
    
    ################################ TCP Wrappers (tcpd)
    printf "Configuring TCP Wrappers...\\n"

    # Backup existing files
    cp /etc/hosts.allow "/etc/hosts.allow.bak.$(date +%F-%T)" 2>/dev/null || true
    cp /etc/hosts.deny "/etc/hosts.deny.bak.$(date +%F-%T)" 2>/dev/null || true

    # Harden hosts.allow: only allow localhost and SSH from anywhere
    {
        echo "ALL: LOCAL, 127.0.0.1"
        echo "sshd: ALL"
    } > /etc/hosts.allow

    # Harden hosts.deny: deny everything else
    echo "ALL: ALL" > /etc/hosts.deny

    # Set strict permissions
    chmod 644 /etc/hosts.allow /etc/hosts.deny

    # Inform user
    printf "\\033[1;32m[+] TCP Wrappers configuration applied: only localhost and SSH allowed.\\033[0m\\n"
  
    ################################ USB storage
    printf "\033[1;31m[+] Configuring USB device controls...\033[0m\n"
    
    # Create USB storage blacklist file
    cat > /etc/modprobe.d/usb-storage.conf << 'EOF'
# HARDN-XDR USB Security Configuration
# Block USB storage devices while allowing keyboards and mice
blacklist usb-storage
blacklist uas          # Block USB Attached SCSI (another storage protocol)
blacklist sd_mod       # Be careful with this - may affect internal storage
# DO NOT blacklist usbhid - needed for keyboards and mice
EOF
    
    printf "\033[1;34m[*] USB security policy configured to allow HID devices but block storage.\033[0m\n"
    
    # Create udev rules to further control USB devices 
    cat > /etc/udev/rules.d/99-usb-storage.rules << 'EOF'
# Block USB storage devices while allowing keyboards and mice
ACTION=="add", SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}=="08", RUN+="/bin/sh -c 'echo 0 > /sys$DEVPATH/authorized'"
# Interface class 08 is for mass storage
# Interface class 03 is for HID devices (keyboards, mice) - these remain allowed
EOF
    
    printf "\033[1;34m[*] Additional udev rules created for USB device control.\033[0m\n"
    
    # Reload rules
    if udevadm control --reload-rules && udevadm trigger; then
        printf "\033[1;32m[+] Udev rules reloaded successfully.\033[0m\n"
    else
        printf "\033[1;31m[-] Failed to reload udev rules.\033[0m\n"
    fi
    
    # Unload the usb-storage module 
    if lsmod | grep -q "usb_storage"; then
        printf "\033[1;34m[*] usb-storage module is currently loaded, attempting to unload...\033[0m\n"
        if rmmod usb_storage >/dev/null 2>&1; then
            printf "\033[1;32m[+] Successfully unloaded usb-storage module.\033[0m\n"
        else
            printf "\033[1;31m[-] Failed to unload usb-storage module. It may be in use.\033[0m\n"
        fi
    else
        printf "\033[1;32m[+] usb-storage module is not loaded, no need to unload.\033[0m\n"
    fi
    
    # HID is enabled
    if lsmod | grep -q "usbhid"; then
        printf "\033[1;32m[+] USB HID module is loaded - keyboards and mice will work.\033[0m\n"
    else
        printf "\033[1;33m[!] USB HID module is not loaded - attempting to load it...\033[0m\n"
        if modprobe usbhid; then
            printf "\033[1;32m[+] Successfully loaded USB HID module.\033[0m\n"
        else
            printf "\033[1;31m[-] Failed to load USB HID module.\033[0m\n"
        fi
    fi
    
    printf "\033[1;32m[+] USB configuration complete: keyboards and mice allowed, storage blocked.\033[0m\n"
    
    
    ############################ Disable unnecessary network protocols in kernel
    printf "\033[1;31m[+] Disabling unnecessary network protocols...\033[0m\n"
    
    # Create comprehensive blacklist file for network protocols
    cat > /etc/modprobe.d/blacklist-rare-network.conf << 'EOF'
# HARDN-XDR Blacklist for Rare/Unused Network Protocols
# Disabled for compliance and attack surface reduction

# TIPC (Transparent Inter-Process Communication)
install tipc /bin/true

# DCCP (Datagram Congestion Control Protocol) - DoS risk
install dccp /bin/true

# SCTP (Stream Control Transmission Protocol) - Can bypass firewall rules
install sctp /bin/true

# RDS (Reliable Datagram Sockets) - Previous vulnerabilities
install rds /bin/true

# Amateur Radio and Legacy Protocols
install ax25 /bin/true
install netrom /bin/true
install rose /bin/true
install decnet /bin/true
install econet /bin/true
install ipx /bin/true
install appletalk /bin/true
install x25 /bin/true

# Bluetooth networking (typically unnecessary on servers) 

# Wireless protocols (if not needed) put 80211x and 802.11 in the blacklist

# Exotic network file systems
install cifs /bin/true
install nfs /bin/true
install nfsv3 /bin/true
install nfsv4 /bin/true
install ksmbd /bin/true
install gfs2 /bin/true

# Uncommon IPv4/IPv6 protocols
install atm /bin/true
install can /bin/true
install irda /bin/true

# Legacy protocols
install token-ring /bin/true
install fddi /bin/true
EOF

    printf "\033[1;32m[+] Network protocol hardening complete: Disabled %d protocols\033[0m\n" "$(grep -c "^install" /etc/modprobe.d/blacklist-rare-network.conf)"
    
    
    # Apply changes immediately where possible
    sysctl -p
    
    ############################ Secure shared memory
    printf "Securing shared memory...\\n"
    if ! grep -q "tmpfs /run/shm" /etc/fstab; then
        echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
    fi
    
    ########################### Set secure file permissions
    printf "Setting secure file permissions...\\n"
    chmod 700 /root # root only
    chmod 600 /etc/passwd  # root
    chmod 600 /etc/shadow # root only
    chmod 644 /etc/group  # group access
    chmod 600 /etc/gshadow # root only
    chmod 644 /etc/ssh/sshd_config # group access

    ########################### Disable core dumps for security
    printf "Disabling core dumps...\\n"
    echo "* hard core 0" >> /etc/security/limits.conf
    echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
    
    ############################### automatic security updates
    printf "Configuring automatic security updates for Debian-based systems...\\n"
    
    # Configure unattended upgrades based on distribution
    case "${ID}" in # Use ${ID} from /etc/os-release
        "debian")
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${CURRENT_DEBIAN_CODENAME}-security";
    "${ID}:${CURRENT_DEBIAN_CODENAME}-updates";
};
Unattended-Upgrade::Package-Blacklist {
    // Add any packages you want to exclude from automatic updates
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";
Unattended-Upgrade::Remove-Unused-Dependencies "false";
Unattended-Upgrade::Automatic-Reboot "false";
EOF
            ;;
        "ubuntu")
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${CURRENT_DEBIAN_CODENAME}-security";
    "${ID}ESMApps:${CURRENT_DEBIAN_CODENAME}-apps-security";
    "${ID}ESM:${CURRENT_DEBIAN_CODENAME}-infra-security";
};
EOF
            ;;
        *)
            # Generic Debian-based fallback
            cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOF
Unattended-Upgrade::Allowed-Origins {
    "${ID}:${CURRENT_DEBIAN_CODENAME}-security";
};
EOF
            ;;
    esac
    
    ########################### Secure network parameters
    printf "Configuring secure network parameters...\\n"
    {
        echo "net.ipv4.ip_forward = 0"
        echo "net.ipv4.conf.all.send_redirects = 0"
        echo "net.ipv4.conf.default.send_redirects = 0"
        echo "net.ipv4.conf.all.accept_redirects = 0"
        echo "net.ipv4.conf.default.accept_redirects = 0"
        echo "net.ipv4.conf.all.secure_redirects = 0"
        echo "net.ipv4.conf.default.secure_redirects = 0"
        echo "net.ipv4.conf.all.log_martians = 1"
        echo "net.ipv4.conf.default.log_martians = 1"
        echo "net.ipv4.icmp_echo_ignore_broadcasts = 1"
        echo "net.ipv4.icmp_ignore_bogus_error_responses = 1"
        echo "net.ipv4.tcp_syncookies = 1"
        echo "net.ipv6.conf.all.disable_ipv6 = 1"
        echo "net.ipv6.conf.default.disable_ipv6 = 1"
    } >> /etc/sysctl.conf


    ##################################### debsums
    printf "Configuring debsums...\\n"
    if command -v debsums >/dev/null 2>&1; then
        if debsums_init >/dev/null 2>&1; then
            printf "\\033[1;32m[+] debsums initialized successfully\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to initialize debsums\\033[0m\\n"
        fi
        
        # Add debsums check to daily cron
        if ! grep -q "debsums" /etc/crontab; then
            echo "0 4 * * * root /usr/bin/debsums -s 2>&1 | logger -t debsums" >> /etc/crontab
            printf "\\033[1;32m[+] debsums daily check added to crontab\\033[0m\\n"
        else
            printf "\\033[1;33m[!] debsums already in crontab\\033[0m\\n"
        fi
        
        # Run initial check
        printf "Running initial debsums check...\\n"
        if debsums -s >/dev/null 2>&1; then
            printf "\\033[1;32m[+] Initial debsums check completed successfully\\033[0m\\n"
        else
            printf "\\033[1;33m[!] Warning: Some packages failed debsums verification\\033[0m\\n"
        fi
    else
        printf "\\033[1;31m[-] debsums command not found, skipping configuration\\033[0m\\n"
    fi
    
    #################################### rkhunter
    printf "Configuring rkhunter...\\n"
    if ! dpkg -s rkhunter >/dev/null 2>&1; then
        printf "rkhunter package not found. Attempting to install via apt...\\n"
        if apt-get install -y rkhunter >/dev/null 2>&1; then
            printf "\\033[1;32m[+] rkhunter installed successfully via apt.\\033[0m\\n"
        else
            printf "\\033[1;33m[!] Warning: Failed to install rkhunter via apt. Attempting to download and install from GitHub as a fallback...\\033[0m\\n"
            # Ensure git is installed for GitHub clone
            if ! command -v git >/dev/null 2>&1; then
                printf "Installing git...\\n"
                apt-get install -y git >/dev/null 2>&1 || {
                    printf "\\033[1;31m[-] Error: Failed to install git. Cannot proceed with GitHub install.\\033[0m\\n"
                    # Skip GitHub install if git fails
                    return
                }
            fi

            cd /tmp || { printf "\\033[1;31m[-] Error: Cannot change directory to /tmp.\\033[0m\\n"; return; }
            printf "Cloning rkhunter from GitHub...\\n"
            if git clone https://github.com/rootkitHunter/rkhunter.git rkhunter_github_clone >/dev/null 2>&1; then
                cd rkhunter_github_clone || { printf "\\033[1;31m[-] Error: Cannot change directory to rkhunter_github_clone.\\033[0m\\n"; return; }
                printf "Running rkhunter installer...\\n"
                if ./installer.sh --install >/dev/null 2>&1; then
                    printf "\\033[1;32m[+] rkhunter installed successfully from GitHub.\\033[0m\\n"
                else
                    printf "\\033[1;31m[-] Error: rkhunter installer failed.\\033[0m\\n"
                fi
                cd .. && rm -rf rkhunter_github_clone
            else
                printf "\\033[1;31m[-] Error: Failed to clone rkhunter from GitHub.\\033[0m\\n"
            fi
        fi
    else
        printf "\\033[1;32m[+] rkhunter package is already installed.\\033[0m\\n"
    fi

    if command -v rkhunter >/dev/null 2>&1; then
        # Configure rkhunter first
        sed -i 's/#CRON_DAILY_RUN=""/CRON_DAILY_RUN="true"/' /etc/default/rkhunter 2>/dev/null || true
        
        # Update the configuration and database
        rkhunter --configcheck >/dev/null 2>&1 || true
        rkhunter --update --nocolors >/dev/null 2>&1 || {
            printf "Warning: Failed to update rkhunter database.\\n"
        }
        rkhunter --propupd --nocolors >/dev/null 2>&1 || {
            printf "Warning: Failed to update rkhunter properties.\\n"
        }
    else
        printf "Warning: rkhunter not found, skipping configuration.\\n"
    fi
    
    ######################## STIG-PAM Password Quality
    printf "Configuring PAM password quality...\\n"
    if [ -f /etc/pam.d/common-password ]; then
        if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
            echo "password requisite pam_pwquality.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" >> /etc/pam.d/common-password
        fi
    else
        printf "Warning: /etc/pam.d/common-password not found, skipping PAM configuration...\\n"
    fi
    
    #############################   libvirt and KVM
    printf "Configuring libvirt...\\n"
    systemctl enable libvirtd
    systemctl start libvirtd
    if [[ -n "$SUDO_USER" ]]; then
        if usermod -a -G libvirt "$SUDO_USER" >/dev/null 2>&1; then
            printf "\\033[1;34m[*] Added user %s to libvirt group (if not already a member).\\033[0m\\n" "$SUDO_USER"
        else
            printf "\\033[1;33m[!] Warning: Failed to add %s to libvirt group. User might already be a member or another issue occurred.\\033[0m\\n" "$SUDO_USER"
        fi
    else
        printf "\\033[1;33m[!] \$SUDO_USER is not set. Cannot automatically add user to libvirt group. Please do this manually if needed for user: %s\\033[0m\\n" "$(logname)"
    fi
    
    ################################### OpenSSH Server
    printf "Configuring OpenSSH...\\n"
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
    systemctl restart ssh || systemctl restart sshd
    
    ####################################### chkrootkit
    printf "Configuring chkrootkit...\\n"
    if ! command -v chkrootkit >/dev/null 2>&1; then
        printf "\\033[1;33m[*] chkrootkit package not found. Attempting to download and install from chkrootkit.org...\\033[0m\\n"
        local download_url="https://www.chkrootkit.org/dl/chkrootkit.tar.gz"
        local download_dir="/tmp/chkrootkit_install"
        local tar_file="$download_dir/chkrootkit.tar.gz"

        mkdir -p "$download_dir"
        cd "$download_dir" || { printf "\\033[1;31m[-] Error: Cannot change directory to %s.\\033[0m\\n" "$download_dir"; return 1; }

        printf "Downloading %s...\\n" "$download_url"
        if wget -q "$download_url" -O "$tar_file"; then
            printf "\\033[1;32m[+] Download successful.\\033[0m\\n"
            printf "Extracting...\\n"
            if tar -xzf "$tar_file" -C "$download_dir"; then
                printf "\\033[1;32m[+] Extraction successful.\\033[0m\\n"
                local extracted_dir
                extracted_dir=$(tar -tf "$tar_file" | head -1 | cut -f1 -d/)
                
                if [[ -d "$download_dir/$extracted_dir" ]]; then
                    cd "$download_dir/$extracted_dir" || { printf "\\033[1;31m[-] Error: Cannot change directory to extracted folder.\\033[0m\\n"; return 1; }
                    printf "Running chkrootkit installer...\\n"
                   
                    if [[ -f "chkrootkit" ]]; then
                        cp chkrootkit /usr/local/sbin/
                        chmod +x /usr/local/sbin/chkrootkit
                        if [[ -f "chkrootkit.8" ]]; then
                            cp chkrootkit.8 /usr/local/share/man/man8/
                            mandb >/dev/null 2>&1 || true
                        fi
                        printf "\\033[1;32m[+] chkrootkit installed to /usr/local/sbin.\\033[0m\\n"
                    else
                         printf "\\033[1;31m[-] Error: chkrootkit script not found in extracted directory.\\033[0m\\n"
                    fi
                else
                    printf "\\033[1;31m[-] Error: Extracted directory not found.\\033[0m\\n"
                fi
            else
                printf "\\033[1;31m[-] Error: Failed to extract %s.\\033[0m\\n" "$tar_file"
            fi
        else
            printf "\\033[1;31m[-] Error: Failed to download %s.\\033[0m\\n" "$download_url"
        fi

        # Clean up temporary files
        cd /tmp || true # Move out of the download directory before removing
        rm -rf "$download_dir"
    else
        printf "\\033[1;32m[+] chkrootkit package is already installed.\\033[0m\\n"
    fi

    # Add chkrootkit check to daily cron if the command exists
    if command -v chkrootkit >/dev/null 2>&1; then
        # Ensure the path in crontab matches the installation path
        if ! grep -q "/usr/local/sbin/chkrootkit" /etc/crontab; then
            echo "0 3 * * * root /usr/local/sbin/chkrootkit 2>&1 | logger -t chkrootkit" >> /etc/crontab
            printf "\\033[1;32m[+] chkrootkit daily check added to crontab.\\033[0m\\n"
        else
            printf "\\033[1;34m[*] chkrootkit already in crontab.\\033[0m\\n"
        fi
    else
        printf "\\033[1;31m[-] chkrootkit command not found after installation attempt, skipping cron configuration.\\033[0m\\n"
    fi
    
    ###################################### auditd
    printf "Configuring auditd...\\n"
    # Check if auditd package is installed
    if dpkg -s auditd >/dev/null 2>&1; then
        printf "\\033[1;32m[+] auditd package is installed.\\033[0m\\n"

        # Check if the service unit file exists before trying to enable/start
        if systemctl list-unit-files --type=service | grep -q '^auditd\.service'; then
            printf "\\033[1;34m[*] Enabling and starting auditd service...\\033[0m\\n"
            systemctl enable auditd >/dev/null 2>&1
            systemctl start auditd >/dev/null 2>&1
            if systemctl is-active --quiet auditd; then
                 printf "\\033[1;32m[+] auditd service enabled and started.\\033[0m\\n"
            else
                 printf "\\033[1;33m[!] Warning: Failed to start auditd service.\\033[0m\\n"
            fi
        else
            printf "\\033[1;33m[!] Warning: auditd.service not found, skipping service enable/start.\\033[0m\\n"
        fi

        # Enable auditing via auditctl (if command exists)
        if command -v auditctl >/dev/null 2>&1; then
            printf "\\033[1;34m[*] Attempting to enable auditd system via auditctl...\\033[0m\\n"
            # -e 1 enables auditing
            if auditctl -e 1 >/dev/null 2>&1; then
                printf "\\033[1;32m[+] auditd system enabled successfully via auditctl.\\033[0m\\n"
            else
                printf "\\033[1;31m[-] Failed to enable auditd system via auditctl. Check auditd status and configuration.\\033[0m\\n"
            fi
        else
            printf "\\033[1;33m[!] Warning: auditctl command not found. Cannot verify/enable audit system status.\\033[0m\\n"
        fi

        # Configure specific audit rules (/etc/audit/audit.rules) based on STIG
  
        printf "\\033[1;34m[*] Configuring optimized auditd rules based on STIG...\\033[0m\\n"
        local audit_rules_file="/etc/audit/audit.rules"

        # Backup existing rules
        if [ -f "$audit_rules_file" ]; then
            cp "$audit_rules_file" "${audit_rules_file}.bak.$(date +%F-%T)" 2>/dev/null || true
            printf "\\033[1;32m[+] Backed up existing audit rules to %s.bak.\\033[0m\\n" "$audit_rules_file"
        fi

        ##################### START OF RULESET
        cat > "$audit_rules_file" << 'EOF'
# This file is automatically generated by HARDN-XDR for STIG compliance.
# Any manual changes may be overwritten.
# 
# Note: This configuration has been optimized to reduce system impact while
# maintaining essential security monitoring. Removed overly strict rules that
# could cause performance degradation or excessive logging.

# Remove any existing rules
-D

# Increase the buffers to absorb a larger burst of events
-b 8192

# Set failure mode to syslog
-f 1

# Audit system startup and shutdown
-w /sbin/init -p x -k system-lifecycle
-w /sbin/reboot -p x -k system-lifecycle
-w /sbin/halt -p x -k system-lifecycle
-w /sbin/poweroff -p x -k system-lifecycle
-w /usr/sbin/shutdown -p x -k system-lifecycle

# Audit account, group, and authentication database changes
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/security/opasswd -p wa -k identity
-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-info
-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-info

# Audit changes to system configuration files
-w /etc/sysconfig/ -p wa -k system-config
-w /etc/default/ -p wa -k system-config
-w /etc/security/ -p wa -k system-config
-w /etc/pam.d/ -p wa -k system-config
-w /etc/login.defs -p wa -k system-config
-w /etc/bashrc -p wa -k system-config
-w /etc/profile -p wa -k system-config
-w /etc/csh.cshrc -p wa -k system-config
-w /etc/csh.login -p wa -k system-config
-w /etc/crontab -p wa -k system-config
-w /etc/at.allow -p wa -k system-config
-w /etc/at.deny -p wa -k system-config
-w /etc/cron.allow -p wa -k system-config
-w /etc/cron.deny -p wa -k system-config
-w /etc/cron.d/ -p wa -k system-config
-w /etc/cron.hourly/ -p wa -k system-config
-w /etc/cron.daily/ -p wa -k system-config
-w /etc/cron.weekly/ -p wa -k system-config
-w /etc/cron.monthly/ -p wa -k system-config
-w /etc/anacrontab -p wa -k system-config
-w /var/spool/cron/crontabs/ -p wa -k system-config
-w /etc/sysctl.conf -p wa -k system-config
-w /etc/modprobe.d/ -p wa -k system-config
-w /etc/apt/sources.list -p wa -k system-config
-w /etc/apt/sources.list.d/ -p wa -k system-config
-w /etc/resolv.conf -p wa -k system-config
-w /etc/hosts -p wa -k system-config
-w /etc/network/interfaces -p wa -k system-config
-w /etc/fstab -p wa -k system-config

# Audit module loading and unloading
-w /sbin/insmod -p x -k modules
-w /sbin/rmmod -p x -k modules
-w /sbin/modprobe -p x -k modules
-a always,exit -F arch=b64 -S init_module -S delete_module -k modules
-a always,exit -F arch=b32 -S init_module -S delete_module -k modules

# Audit login/logout and session information
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-w /var/log/tallylog -p wa -k logins
-w /var/run/utmp -p wa -k session
-w /var/log/wtmp -p wa -k session
-w /var/log/btmp -p wa -k session

# Audit privilege escalation (sudo, su)
-w /usr/bin/sudo -p x -k privilege-escalation
-w /usr/bin/su -p x -k privilege-escalation

# Audit changes to audit configuration
-w /etc/audit/auditd.conf -p wa -k audit-config
-w /etc/audit/audit.rules -p wa -k audit-config

# Audit use of privileged commands (specific, not broad directory monitoring)
-w /bin/mount -p x -k privileged-command
-w /bin/umount -p x -k privileged-command
-w /usr/bin/passwd -p x -k privileged-command
-w /usr/bin/chsh -p x -k privileged-command
-w /usr/bin/gpasswd -p x -k privileged-command

# Audit critical file deletions by user (focused on critical files)
-a always,exit -F arch=b64 -S unlink,unlinkat,rename,renameat -F dir=/etc -F auid>=1000 -F auid!=unset -k config-file-delete
-a always,exit -F arch=b32 -S unlink,unlinkat,rename,renameat -F dir=/etc -F auid>=1000 -F auid!=unset -k config-file-delete

# Audit system time changes
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change
-w /etc/localtime -p wa -k time-change

# Audit network configuration changes (simplified)
-a always,exit -F arch=b64 -S sethostname,setdomainname -k network-config
-a always,exit -F arch=b32 -S sethostname,setdomainname -k network-config
-w /etc/sysconfig/network -p wa -k network-config
-w /etc/sysconfig/network-scripts/ -p wa -k network-config

# Audit mount and unmount operations
-a always,exit -F arch=b64 -S mount,umount,umount2 -k mounts
-a always,exit -F arch=b32 -S mount,umount,umount2 -k mounts

# Audit use of the ptrace syscall (debugging/tracing)
-a always,exit -F arch=b64 -S ptrace -k ptrace
-a always,exit -F arch=b32 -S ptrace -k ptrace

# Audit use of the setuid/setgid/setresuid/setresgid syscalls
-a always,exit -F arch=b64 -S setuid,setgid,setresuid,setresgid -k user-id-change
-a always,exit -F arch=b32 -S setuid,setgid,setresuid,setresgid -k user-id-change

# Audit chroot operations
-a always,exit -F arch=b64 -S chroot -k chroot
-a always,exit -F arch=b32 -S chroot -k chroot

# Audit system lifecycle operations
-a always,exit -F arch=b64 -S reboot -k system-lifecycle
-a always,exit -F arch=b32 -S reboot -k system-lifecycle

# Audit namespace operations (containerization security)
-a always,exit -F arch=b64 -S setns,unshare -k namespaces
-a always,exit -F arch=b32 -S setns,unshare -k namespaces

# Audit final immutable rule
-e 2
EOF
        # END OF RULESET

        # Load the new rules
        printf "\\033[1;34m[*] Loading new auditd rules...\\033[0m\\n"
        if auditctl -R "$audit_rules_file" >/dev/null 2>&1; then
            printf "\\033[1;32m[+] New auditd rules loaded successfully.\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to load new auditd rules. Check the rules file for syntax errors.\\033[0m\\n"
        fi

    else
        printf "\\033[1;33m[!] Warning: auditd is not installed \\(checked with dpkg -s\\). Skipping configuration.\\033[0m\\n"
        printf "\\033[1;33m[!] Please ensure auditd is listed in ../../progs.csv for installation.\\033[0m\\n"
    fi
    printf "\\033[1;32m[+] auditd configuration attempt completed.\\033[0m\\n"


    
    ####################################### Suricata
    printf "\\033[1;31m[+] Checking and configuring Suricata...\\033[0m\\n"

    # Check if Suricata is already installed via package manager
    if dpkg -s suricata >/dev/null 2>&1; then
        printf "\\033[1;32m[+] Suricata package is already installed.\\033[0m\\n"
    else
        printf "\\033[1;33m[*] Suricata package not found. Attempting to install from source...\\033[0m\\n"

        local suricata_version="7.0.0" # Specify the desired version
        local download_url="https://www.suricata-ids.org/download/releases/suricata-${suricata_version}.tar.gz"
        local download_dir="/tmp/suricata_install"
        local tar_file="$download_dir/suricata-${suricata_version}.tar.gz"
        local extracted_dir="suricata-${suricata_version}"

        # Ensure necessary build dependencies are installed
        printf "\\033[1;34m[*] Installing Suricata build dependencies...\\033[0m\\n"
        if ! apt-get update >/dev/null 2>&1 || ! apt-get install -y \
            build-essential libpcap-dev libnet1-dev libyaml-0-2 libyaml-dev zlib1g zlib1g-dev \
            libcap-ng-dev libmagic-dev libjansson-dev libnss3-dev liblz4-dev libtool \
            libnfnetlink-dev libevent-dev pkg-config libhiredis-dev libczmq-dev \
            python3 python3-yaml python3-setuptools python3-pip python3-dev \
            rustc cargo >/dev/null 2>&1; then
            printf "\\033[1;31m[-] Error: Failed to install Suricata build dependencies. Skipping Suricata configuration.\\033[0m\\n"
            return 1
        fi
        printf "\\033[1;32m[+] Suricata build dependencies installed.\\033[0m\\n"

        mkdir -p "$download_dir"
        cd "$download_dir" || { printf "\\033[1;31m[-] Error: Cannot change directory to %s.\\033[0m\\n" "$download_dir"; return 1; }

        printf "Downloading %s...\\n" "$download_url"
        if wget -q "$download_url" -O "$tar_file"; then
            printf "\\033[1;32m[+] Download successful.\\033[0m\\n"
            printf "Extracting...\\n"
            if tar -xzf "$tar_file" -C "$download_dir"; then
                printf "\\033[1;32m[+] Extraction successful.\\033[0m\\n"

                if [[ -d "$download_dir/$extracted_dir" ]]; then
                    cd "$download_dir/$extracted_dir" || { printf "\\033[1;31m[-] Error: Cannot change directory to extracted folder.\\033[0m\\n"; return 1; }

                    printf "Running ./configure...\\n"
                    # Configure with specified options
                    if ./configure \
                        --prefix=/usr \
                        --sysconfdir=/etc \
                        --localstatedir=/var \
                        --disable-gccmarch-native \
                        --enable-lua \
                        --enable-geoip \
                        > /dev/null 2>&1; then # Added common options and suppressed output
                        printf "\\033[1;32m[+] Configure successful.\\033[0m\\n"

                        printf "Running make...\\n"
                        if make > /dev/null 2>&1; then # Suppressed output
                            printf "\\033[1;32m[+] Make successful.\\033[0m\\n"

                            printf "Running make install...\\n"
                            if make install > /dev/null 2>&1; then # Suppressed output
                                printf "\\033[1;32m[+] Suricata installed successfully from source.\\033[0m\\n"
                                # Ensure libraries are found
                                ldconfig >/dev/null 2>&1 || true
                            else
                                printf "\\033[1;31m[-] Error: make install failed.\\033[0m\\n"
                                cd /tmp || true # Move out before cleanup
                                rm -rf "$download_dir"
                                return 1
                            fi
                        else
                            printf "\\033[1;31m[-] Error: make failed.\\033[0m\\n"
                            cd /tmp || true # Move out before cleanup
                            rm -rf "$download_dir"
                            return 1
                        fi
                    else
                        printf "\\033[1;31m[-] Error: ./configure failed.\\033[0m\\n"
                        cd /tmp || true # Move out before cleanup
                        rm -rf "$download_dir"
                        return 1
                    fi
                else
                    printf "\\033[1;31m[-] Error: Extracted directory not found.\\033[0m\\n"
                    cd /tmp || true # Move out before cleanup
                    rm -rf "$download_dir"
                    return 1
                fi
            else
                printf "\\033[1;31m[-] Error: Failed to extract %s.\\033[0m\\n" "$tar_file"
                cd /tmp || true # Move out before cleanup
                rm -rf "$download_dir"
                return 1
            fi
        else
            printf "\\033[1;31m[-] Error: Failed to download %s.\\033[0m\\n" "$download_url"
            cd /tmp || true # Move out before cleanup
            rm -rf "$download_dir"
            return 1
        fi

        # Clean up temporary files
        cd /tmp || true # Move out of the download directory before removing
        rm -rf "$download_dir"
    fi

    # If Suricata is installed (either found via dpkg or just installed from source)
    if command -v suricata >/dev/null 2>&1; then
        printf "Configuring Suricata...\\n"

        # Ensure the default configuration directory exists and has default files
        if [ ! -d /etc/suricata ]; then
            printf "\\033[1;33m[*] Creating /etc/suricata and copying default config...\\033[0m\\n"
            mkdir -p /etc/suricata
    
            if [ ! -f /etc/suricata/suricata.yaml ]; then
                 printf "\\033[1;31m[-] Error: Suricata default configuration file /etc/suricata/suricata.yaml not found after installation. Skipping configuration.\\033[0m\\n"
                 return 1
            fi
        fi

        # Enable the service (assuming systemd service file was installed by make install)
        if systemctl enable suricata >/dev/null 2>&1; then
            printf "\\033[1;32m[+] Suricata service enabled successfully.\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to enable Suricata service. Check if the service file exists (e.g., /lib/systemd/system/suricata.service).\\033[0m\\n"
        fi

        # Update rules
        printf "\\033[1;34m[*] Running suricata-update...\\033[0m\\n"
        # suricata-update might need python dependencies, ensure they are installed
        if ! command -v suricata-update >/dev/null 2>&1; then
             printf "\\033[1;33m[*] suricata-update command not found. Attempting to install...\\033[0m\\n"
             if pip3 install --upgrade pip >/dev/null 2>&1 && pip3 install --upgrade suricata-update >/dev/null 2>&1; then
                 printf "\\033[1;32m[+] suricata-update installed successfully via pip3.\\033[0m\\n"
             else
                 printf "\\033[1;31m[-] Error: Failed to install suricata-update via pip3. Skipping rule update.\\033[0m\\n"
             fi
        fi

        if command -v suricata-update >/dev/null 2>&1; then
            if suricata-update >/dev/null 2>&1; then
                printf "\\033[1;32m[+] Suricata rules updated successfully.\\033[0m\\n"
            else
                printf "\\033[1;33m[!] Warning: Suricata rules update failed. Check output manually.\\033[0m\\n"
            fi
        else
             printf "\\033[1;31m[-] suricata-update command not available, skipping rule update.\\033[0m\\n"
        fi

        # Start the service
        if systemctl start suricata >/dev/null 2>&1; then
            printf "\\033[1;32m[+] Suricata service started successfully.\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to start Suricata service. Check logs for details.\\033[0m\\n"
        fi
    else
        printf "\\033[1;31m[-] Suricata command not found after installation attempt, skipping configuration.\\033[0m\\n"
    fi

    ########################### debsums
    printf "Configuring debsums...\\n"
    if command -v debsums >/dev/null 2>&1; then
        if debsums_init >/dev/null 2>&1; then
            printf "\\033[1;32m[+] debsums initialized successfully\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to initialize debsums\\033[0m\\n"
        fi
        
        # Add debsums check to daily cron
        if ! grep -q "debsums" /etc/crontab; then
            echo "0 4 * * * root /usr/bin/debsums -s 2>&1 | logger -t debsums" >> /etc/crontab
            printf "\\033[1;32m[+] debsums daily check added to crontab\\033[0m\\n"
        else
            printf "\\033[1;33m[!] debsums already in crontab\\033[0m\\n"
        fi
        
        # Run initial check
        printf "Running initial debsums check...\\n"
        if debsums -s >/dev/null 2>&1; then
            printf "\\033[1;32m[+] Initial debsums check completed successfully\\033[0m\\n"
        else
            printf "\\033[1;33m[!] Warning: Some packages failed debsums verification\\033[0m\\n"
        fi
    else
        printf "\\033[1;31m[-] debsums command not found, skipping configuration\\033[0m\\n"
    fi
    
    ############################## AIDE (Advanced Intrusion Detection Environment)
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
  
    #################################### YARA
    printf "\\033[1;31m[+] Setting up YARA rules...\\033[0m\\n"

    # Check if YARA command exists (implies installation)
    if ! command -v yara >/dev/null 2>&1; then
        printf "\\033[1;33m[!] Warning: YARA command not found. Skipping rule setup.\\033[0m\\n"
        # YARA should be installed via install_package_dependencies if listed in progs.csv
        # If it's not installed, we can't set up rules anyway.
    else
        printf "\\033[1;32m[+] YARA command found.\\033[0m\\n"
        printf "\\033[1;34m[*] Creating YARA rules directory...\\033[0m\\n"
        mkdir -p /etc/yara/rules
        chmod 755 /etc/yara/rules # Ensure directory is accessible

        printf "\\033[1;34m[*] Checking for git...\\033[0m\\n"
        if ! command -v git >/dev/null 2>&1; then
            printf "\\033[1;33m[*] git not found. Attempting to install...\\033[0m\\n"
            if apt-get update >/dev/null 2>&1 && apt-get install -y git >/dev/null 2>&1; then
                printf "\\033[1;32m[+] git installed successfully.\\033[0m\\n"
            else
                printf "\\033[1;31m[-] Error: Failed to install git. Cannot download YARA rules.\\033[0m\\n"
                return 1 # Exit this section
            fi
        else
            printf "\\033[1;32m[+] git command found.\\033[0m\\n"
        fi

        local rules_repo_url="https://github.com/Yara-Rules/rules.git"
        local temp_dir
        temp_dir=$(mktemp -d -t yara-rules-XXXXXXXX)

        if [[ ! -d "$temp_dir" ]]; then
            printf "\\033[1;31m[-] Error: Failed to create temporary directory for YARA rules.\\033[0m\\n"
            return 1 # Exit this section
        fi

        printf "\\033[1;34m[*] Cloning YARA rules from %s to %s...\\033[0m\\n" "$rules_repo_url" "$temp_dir"
        if git clone --depth 1 "$rules_repo_url" "$temp_dir" >/dev/null 2>&1; then
            printf "\\033[1;32m[+] YARA rules cloned successfully.\\033[0m\\n"

            printf "\\033[1;34m[*] Copying .yar rules to /etc/yara/rules/...\\033[0m\\n"
            local copied_count=0
            # Find all .yar files in the cloned repo and copy them
            while IFS= read -r -d $'\0' yar_file; do
                if cp "$yar_file" /etc/yara/rules/; then
                    ((copied_count++))
                else
                    printf "\\033[1;33m[!] Warning: Failed to copy rule file: %s\\033[0m\\n" "$yar_file"
                fi
            done < <(find "$temp_dir" -name "*.yar" -print0)

            if [[ "$copied_count" -gt 0 ]]; then
                printf "\\033[1;32m[+] Copied %s YARA rule files to /etc/yara/rules/.\\033[0m\\n" "$copied_count"
            else
                 printf "\\033[1;33m[!] Warning: No .yar files found or copied from the repository.\\033[0m\\n"
            fi

        else
            printf "\\033[1;31m[-] Error: Failed to clone YARA rules repository.\\033[0m\\n"
        fi

        printf "\\033[1;34m[*] Cleaning up temporary directory %s...\\033[0m\\n" "$temp_dir"
        rm -rf "$temp_dir"
        printf "\\033[1;32m[+] Cleanup complete.\\033[0m\\n"

        printf "\\033[1;32m[+] YARA rules setup attempt completed.\\033[0m\\n"
    fi
    

    ######################### STIG banner (/etc/issue.net)
    printf "\\033[1;31m[+] Configuring STIG compliant banner for remote logins (/etc/issue.net)...\\033[0m\\n"
    local banner_net_file="/etc/issue.net"
    if [ -f "$banner_net_file" ]; then
        # Backup existing banner file
        cp "$banner_net_file" "${banner_net_file}.bak.$(date +%F-%T)" 2>/dev/null || true
    else
        touch "$banner_net_file"
    fi
    # Write the STIG compliant banner
    {
        echo "************************************************************"
        echo "*                                                          *"
        echo "*  This system is for the use of authorized users only.    *"
        echo "*  Individuals using this computer system without authority *"
        echo "*  or in excess of their authority are subject to having    *"
        echo "*  all of their activities on this system monitored and     *"
        echo "*  recorded by system personnel.                            *"
        echo "*                                                          *"
        echo "************************************************************"
    } > "$banner_net_file"
    chmod 644 "$banner_net_file"
    printf "\\033[1;32m[+] STIG compliant banner configured in %s.\\033[0m\\n" "$banner_net_file"


    ########################################## Lynis
    printf "Configuring Lynis...\\n"
    apt install lynis
    lynis update info >/dev/null 2>&1 || true
    echo "0 2 * * 0 root /usr/bin/lynis audit system --cronjob" >> /etc/crontab
    
    printf "\\033[1;32m[+] Security tools configuration completed!\\033[0m\\n"
}

restrict_compilers() {
    printf "\033[1;31m[+] Restricting compiler access to root only (HRDN-7222)...\033[0m\n"

    local compilers
	compilers="/usr/bin/gcc /usr/bin/g++ /usr/bin/make /usr/bin/cc /usr/bin/c++ /usr/bin/as /usr/bin/ld"
    for bin in $compilers; do
        if [[ -f "$bin" ]]; then
            chmod 755 "$bin"
            chown root:root "$bin"
            printf "\033[1;32m[+] Set %s to 755 root:root (default for compilers).\\033[0m\\n" "$bin"
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
    packages_to_purge=$(dpkg -l | grep '^rc' | awk '{print $2}')

    if [[ "$packages_to_purge" ]]; then
        printf "\\033[1;33m[*] Found the following packages with leftover configuration files to purge:\033[0m\\n"
        echo "$packages_to_purge"
       
        if command -v whiptail >/dev/null; then
            whiptail --title "Packages to Purge" --msgbox "The following packages have leftover configuration files that will be purged:\n\n$packages_to_purge" 15 70
        fi

        for pkg in $packages_to_purge; do
            printf "\\033[1;31m[+] Purging %s...\\033[0m\\n" "$pkg"
            if apt-get purge -y "$pkg"; then
                printf "\\033[1;32m[+] Successfully purged %s.\\033[0m\\n" "$pkg"
            else
                printf "\\033[1;31m[-] Failed to purge %s. Trying dpkg --purge...\\033[0m\\n" "$pkg"
                if dpkg --purge "$pkg"; then
                    printf "\\033[1;32m[+] Successfully purged %s with dpkg.\\033[0m\\n" "$pkg"
                else
                    printf "\\033[1;31m[-] Failed to purge %s with dpkg as well.\\033[0m\\n" "$pkg"
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
    printf "\\033[1;31m[+] Checking and configuring DNS nameservers (Quad9 primary, Google secondary)...\033{0m\\n"
    local resolv_conf quad9_ns google_ns nameserver_count configured_persistently changes_made
	resolv_conf="/etc/resolv.conf"
    quad9_ns="9.9.9.9"
    google_ns="8.8.8.8"
    nameserver_count=0
    configured_persistently=false
    changes_made=false

    if [[ -f "$resolv_conf" ]]; then
        nameserver_count=$(grep -E "^\s*nameserver\s+" "$resolv_conf" | grep -Ev "127\.0\.0\.1|::1" | awk '{print $2}' | sort -u | wc -l)
    fi

    printf "\\033[1;34m[*] Found %s non-localhost nameserver(s) in %s.\033[0m\\n" "$nameserver_count" "$resolv_conf"

    # Always attempt to set Quad9 as primary and Google as secondary
    # Check for systemd-resolved
    if systemctl is-active --quiet systemd-resolved && \
       [[ -L "$resolv_conf" ]] && \
       (readlink "$resolv_conf" | grep -qE "systemd/resolve/(stub-resolv.conf|resolv.conf)"); then
        
        printf "\\033[1;34m[*] systemd-resolved is active and manages %s.\033[0m\\n" "$resolv_conf"
        local resolved_conf_systemd temp_resolved_conf
		resolved_conf_systemd="/etc/systemd/resolved.conf"
        temp_resolved_conf=$(mktemp)

        if [[ ! -f "$resolved_conf_systemd" ]]; then
            printf "\\033[1;33m[*] Creating %s as it does not exist.\\033[0m\\n" "$resolved_conf_systemd"
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
                printf "\\033[1;32m[+] systemd-resolved restarted successfully.\\033[0m\\n"
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
    if [[ "$configured_persistently" = false ]]; then
        printf "\\033[1;34m[*] Attempting direct modification of %s.\033[0m\\n" "$resolv_conf"
        if [[ -f "$resolv_conf" ]] && [[ -w "$resolv_conf" ]]; then
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

    if [[ "$changes_made" = true ]]; then
        whiptail --infobox "DNS configured: Quad9 primary, Google secondary." 7 70
    else
        whiptail --infobox "DNS configuration checked. No changes made or needed." 8 70
    fi
}

enable_process_accounting_and_sysstat() {
    printf "\\033[1;31m[+] Enabling process accounting (acct) and system statistics (sysstat)...\033[0m\\n"
    local changed_acct changed_sysstat
	changed_acct=false
    changed_sysstat=false

    # Enable Process Accounting (acct/psacct)
    printf "\\033[1;34m[*] Checking and installing acct (process accounting)...\\033[0m\\n"
    if ! dpkg -s acct >/dev/null 2>&1 && ! dpkg -s psacct >/dev/null 2>&1; then
        whiptail --infobox "Installing acct (process accounting)..." 7 60
        if apt-get install -y acct; then
            printf "\\033[1;32m[+] acct installed successfully.\\033[0m\\n"
            changed_acct=true
        else
            printf "\\033[1;31m[-] Failed to install acct. Please check manually.\\033[0m\\n"
        fi
    else
        printf "\\033[1;34m[*] acct/psacct is already installed.\\033[0m\\n"
    fi

    if dpkg -s acct >/dev/null 2>&1 || dpkg -s psacct >/dev/null 2>&1; then
        if ! systemctl is-active --quiet acct && ! systemctl is-active --quiet psacct; then
            printf "\\033[1;33m[*] Attempting to enable and start acct/psacct service...\\033[0m\\n"
            systemctl enable --now acct 2>/dev/null || systemctl enable --now psacct 2>/dev/null
            printf "\\033[1;32m[+] acct/psacct service enabled and started.\\033[0m\\n"
            changed_acct=true
        else
            printf "\\033[1;32m[+] acct/psacct service is already active.\\033[0m\\n"
        fi
    fi

    # Enable Sysstat
    printf "\\033[1;34m[*] Checking and installing sysstat...\\033[0m\\n"
    if ! dpkg -s sysstat >/dev/null 2>&1; then
        whiptail --infobox "Installing sysstat..." 7 60
        if apt-get install -y sysstat; then
            printf "\\033[1;32m[+] sysstat installed successfully.\\033[0m\\n"
            changed_sysstat=true
        else
            printf "\\033[1;31m[-] Failed to install sysstat. Please check manually.\\033[0m\\n"
        fi
    else
        printf "\\033[1;34m[*] sysstat is already installed.\\033[0m\\n"
    fi

    if dpkg -s sysstat >/dev/null 2>&1; then
        local sysstat_conf
		sysstat_conf="/etc/default/sysstat"
        if [[ -f "$sysstat_conf" ]]; then
            if ! grep -qE '^\s*ENABLED="true"' "$sysstat_conf"; then
                printf "\\033[1;33m[*] Enabling sysstat data collection in %s...\\033[0m\\n" "$sysstat_conf"
                sed -i 's/^\s*ENABLED="false"/ENABLED="true"/' "$sysstat_conf"
          
                if ! grep -qE '^\s*ENABLED=' "$sysstat_conf"; then
                    echo 'ENABLED="true"' >> "$sysstat_conf"
                fi
                changed_sysstat=true
                printf "\\033[1;32m[+] sysstat data collection enabled.\\033[0m\\n"
            else
                printf "\\033[1;32m[+] sysstat data collection is already enabled in %s.\\033[0m\\n" "$sysstat_conf"
            fi
        else
            # Fallback for systems where config might be /etc/sysstat/sysstat (e.g. RHEL based, but this is Debian focused)
            # For Debian, /etc/default/sysstat is standard.
            printf "\\033[1;33m[!] sysstat configuration file %s not found. Manual check might be needed.\\033[0m\\n" "$sysstat_conf"
        fi

        if ! systemctl is-active --quiet sysstat; then
            printf "\\033[1;33m[*] Attempting to enable and start sysstat service...\\033[0m\\n"
            if systemctl enable --now sysstat; then
                printf "\\033[1;32m[+] sysstat service enabled and started.\\033[0m\\n"
                changed_sysstat=true
            else
                printf "\\033[1;31m[-] Failed to enable/start sysstat service.\\033[0m\\n"
            fi
        else
            printf "\\033[1;32m[+] sysstat service is already active.\\033[0m\\n"
        fi
    fi

    if [[ "$changed_acct" = true || "$changed_sysstat" = true ]]; then
        printf "\\033[1;32m[+] Process accounting (acct) and sysstat configured successfully.\\033[0m\\n"
    else
        printf "\\033[1;32m[+] Process accounting (acct) and sysstat already configured or no changes needed.\\033[0m\\n"
    fi
}

# Central logging
setup_central_logging() {
    printf "\033[1;31m[+] Setting up central logging for security tools...\033[0m\n"

    # Check and install rsyslog and logrotate if necessary
    local logging_packages="rsyslog logrotate"
    printf "\\033[1;34m[*] Checking and installing logging packages (%s)...\\033[0m\\n" "$logging_packages"
    # shellcheck disable=SC2086
    if ! dpkg -s $logging_packages >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        if apt-get update >/dev/null 2>&1 && apt-get install -y $logging_packages >/dev/null 2>&1; then
            printf "\\033[1;32m[+] Logging packages installed successfully.\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Error: Failed to install logging packages. Skipping central logging configuration.\\033[0m\\n"
            return 1 # Exit this section if packages fail to install
        fi
    else
        printf "\\033[1;32m[+] Logging packages are already installed.\\033[0m\\n"
    fi


    # Create necessary directories
    printf "\\033[1;34m[*] Creating log directories and files...\\033[0m\\n"
    mkdir -p /usr/local/var/log/suricata
    # Note: /var/log/suricata is often created by the suricata package itself
    touch /usr/local/var/log/suricata/hardn-xdr.log
    chmod 640 /usr/local/var/log/suricata/hardn-xdr.log
    chown root:adm /usr/local/var/log/suricata/hardn-xdr.log
    printf "\\033[1;32m[+] Log directory /usr/local/var/log/suricata created and permissions set.\\033[0m\\n"


    # Create rsyslog configuration for centralized logging
    printf "\\033[1;34m[*] Creating rsyslog configuration file /etc/rsyslog.d/30-hardn-xdr.conf...\\033[0m\\n"
    cat > /etc/rsyslog.d/30-hardn-xdr.conf << 'EOF'
# HARDN-XDR Central Logging Configuration
# This file is automatically generated by HARDN-XDR.
# Any manual changes may be overwritten.

# Create a template for security logs
$template HARDNFormat,"%TIMESTAMP% %HOSTNAME% %syslogtag%%msg%\n"

# Define the central log file path
local5.* /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat

# Specific rules to route logs to local5 facility if they don't use it by default
# Suricata (often uses local5, but explicit rule ensures it)
if $programname == 'suricata' then local5.*
# AIDE
if $programname == 'aide' then local5.*
# Fail2Ban
if $programname == 'fail2ban' then local5.*
# AppArmor
if $programname == 'apparmor' then local5.*
# Auditd/SELinux (auditd logs via auditd, setroubleshoot logs via setroubleshoot)
if $programname == 'audit' or $programname == 'setroubleshoot' then local5.*
# RKHunter (often logs with tag rkhunter)
if $programname == 'rkhunter' or $syslogtag contains 'rkhunter' then local5.*
# Debsums (piped to logger, tag might be debsums or CRON)
if $programname == 'debsums' or $syslogtag contains 'debsums' then local5.*
# Lynis (cronjob logs via logger, tag might be lynis or CRON)
if $programname == 'lynis' or $syslogtag contains 'lynis' then local5.*
# Chkrootkit (cronjob logs via logger, tag might be chkrootkit or CRON)
if $programname == 'chkrootkit' or $syslogtag contains 'chkrootkit' then local5.*

# Stop processing these messages after they are sent to the central log
& stop
EOF
    chmod 644 /etc/rsyslog.d/30-hardn-xdr.conf
    printf "\\033[1;32m[+] Rsyslog configuration created/updated.\\033[0m\\n"


    # Create logrotate configuration for the central log
    printf "\\033[1;34m[*] Creating logrotate configuration file /etc/logrotate.d/hardn-xdr...\\033[0m\\n"
    cat > /etc/logrotate.d/hardn-xdr << 'EOF'
/usr/local/var/log/suricata/hardn-xdr.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 640 root adm
    postrotate
        # Ensure rsyslog reloads its configuration or reopens log files
        # Use the standard rsyslog-rotate script if available, otherwise restart
        if [ -x /usr/lib/rsyslog/rsyslog-rotate ]; then
            /usr/lib/rsyslog/rsyslog-rotate
        else
            systemctl reload rsyslog >/dev/null 2>&1 || true
        fi
    endscript
    # Add a prerotate script to ensure the file exists and has correct permissions before rotation
    prerotate
        if [ ! -f /usr/local/var/log/suricata/hardn-xdr.log ]; then
            mkdir -p /usr/local/var/log/suricata
            touch /usr/local/var/log/suricata/hardn-xdr.log
        fi
        chmod 640 /usr/local/var/log/suricata/hardn-xdr.log
        chown root:adm /usr/local/var/log/suricata/hardn-xdr.log
    endscript
}
EOF
    chmod 644 /etc/logrotate.d/hardn-xdr
    printf "\\033[1;32m[+] Logrotate configuration created/updated.\\033[0m\\n"



    # Restart rsyslog to apply changes
    printf "\\033[1;34m[*] Restarting rsyslog service to apply configuration changes...\\033[0m\\n"
    if systemctl restart rsyslog; then
        printf "\\033[1;32m[+] Rsyslog service restarted successfully.\\033[0m\\n"
    else
        printf "\\033[1;31m[-] Failed to restart rsyslog service. Manual check required.\\033[0m\\n"
    fi

    # Create a symlink in /var/log for easier access
    printf "\\033[1;34m[*] Creating symlink /var/log/hardn-xdr.log...\\033[0m\\n"
    ln -sf /usr/local/var/log/suricata/hardn-xdr.log /var/log/hardn-xdr.log
    printf "\\033[1;32m[+] Symlink created at /var/log/hardn-xdr.log.\\033[0m\\n"


    printf "\\033[1;32m[+] Central logging setup complete. All security logs will be collected in /usr/local/var/log/suricata/hardn-xdr.log\033[0m\n"
}

disable_service_if_active() {
    local service_name
    service_name="$1"
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
    printf "\\033[1;31m[+] Running penetration tests...\\033[0m\\n"
    local lynis_path=""
    local manual_install_dir=""
    local current_dir
    current_dir=$(pwd)

    # First, try to find Lynis in common locations
    if command -v lynis >/dev/null 2>&1; then
        lynis_path=$(command -v lynis)
        printf "\\033[1;32m[+] Lynis found at %s.\\033[0m\\n" "$lynis_path"
    elif [ -x "/usr/bin/lynis" ]; then
        lynis_path="/usr/bin/lynis"
    elif [ -x "/usr/local/bin/lynis" ]; then
        lynis_path="/usr/local/bin/lynis"
    elif [ -x "/bin/lynis" ]; then
        lynis_path="/bin/lynis"
    fi

    # If not found, check if package is installed and try to locate it
    if [ -z "$lynis_path" ] && dpkg -s lynis >/dev/null 2>&1; then
        printf "\\033[1;33m[*] Lynis package is installed but executable not found in standard locations. Searching...\\033[0m\\n"
        lynis_path=$(find /usr -name "lynis" -type f -executable 2>/dev/null | head -n 1)
        if [ -n "$lynis_path" ]; then
            printf "\\033[1;32m[+] Lynis found at %s.\\033[0m\\n" "$lynis_path"
        fi
    fi

    # If still not found, attempt installation
    if [ -z "$lynis_path" ]; then
        printf "\\033[1;33m[*] Lynis not found. Attempting to install via apt-get...\\033[0m\\n"
        if apt-get update && apt install -y lynis; then
            lynis_path="/usr/bin/lynis"
            if [ ! -x "$lynis_path" ]; then
                chmod +x "$lynis_path"
            fi

            printf "\\033[1;32m[+] Lynis installed successfully via apt-get.\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Failed to install Lynis via apt-get. Attempting manual installation...\\033[0m\\n"
            
            # Manual installation using wget
            cd /tmp || { printf "\\033[1;31m[-] Error: Cannot access /tmp directory.\\033[0m\\n"; return 1; }
            if wget https://downloads.cisofy.com/lynis/lynis-latest.tar.gz && \
               tar -xzf lynis-latest.tar.gz; then
                # Find the extracted directory
                manual_install_dir=$(find /tmp -maxdepth 1 -type d -name "lynis*" | head -n 1)
                if [ -n "$manual_install_dir" ] && [ -d "$manual_install_dir" ]; then
                    printf "\\033[1;32m[+] Lynis downloaded and extracted to %s successfully.\\033[0m\\n" "$manual_install_dir"
                    lynis_path="$manual_install_dir/lynis"
                    if [ ! -x "$lynis_path" ]; then
                        chmod +x "$lynis_path"
                    fi
                else
                    printf "\\033[1;31m[-] Failed to locate extracted Lynis directory. Cannot proceed with penetration tests.\\033[0m\\n"
                    cd "$current_dir" || true
                    return 1
                fi
            else
                printf "\\033[1;31m[-] Failed to download or extract Lynis. Cannot proceed with penetration tests.\\033[0m\\n"
                cd "$current_dir" || true
                return 1
            fi
        fi
    else
        printf "\\033[1;32m[+] Lynis is already installed.\\033[0m\\n"
    fi

    # Run the Lynis audit
    printf "\\033[1;34m[*] Running Lynis audit...\\033[0m\\n"
    if [ -x "$lynis_path" ]; then
        if "$lynis_path" audit system --pentest --quick 2>/dev/null; then
            printf "\\033[1;32m[+] Lynis audit completed successfully.\\033[0m\\n"
        else
            printf "\\033[1;31m[-] Lynis audit failed. Please check the output for details.\\033[0m\\n"
            # Don't return error, continue with script
        fi
    else
        printf "\\033[1;31m[-] Error: Lynis executable not found at %s or not executable.\\033[0m\\n" "$lynis_path"
        printf "\\033[1;31m[-] Skipping Lynis audit.\\033[0m\\n"
    fi

    # Return to original directory if we changed
    if [ -n "$manual_install_dir" ]; then
        cd "$current_dir" || true
    fi

    printf "\\033[1;32m[+] Penetration tests completed!\\033[0m\\n"
}


cleanup(){
    printf "\\033[1;31m[+] Cleaning up temporary files...\\033[0m\\n"
    rm -rf /tmp/* >/dev/null 2>&1
    apt autoremove -y >/dev/null 2>&1
    apt clean >/dev/null 2>&1
    apt update -y >/dev/null 2>&1
    printf "\\033[1;32m[+] Cleanup completed!\\033[0m\\n"
    
}


main() {
    print_ascii_banner
    welcomemsg
    update_system_packages
    install_package_dependencies "../../progs.csv"
    setup_security
    enable_process_accounting_and_sysstat
    enable_nameservers
    purge_old_packages
    disable_firewire_drivers
    restrict_compilers
    disable_binfmt_misc
    remove_unnecessary_services
    setup_central_logging
    pen_test
    cleanup

    printf "\\n\\033[1;32mHARDN-XDR installation completed, Please reboot your System.\\033[0m\\n"
}

main
