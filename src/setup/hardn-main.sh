#!/bin/bash

# HARDN-XDR - The Linux Security Hardening Sentinel
# Developed and built by Christopher Bingham and Tim Burns

# --- Global Variables ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGS_CSV_PATH="${SCRIPT_DIR}/../../progs.csv" 
CURRENT_DEBIAN_VERSION_ID=""
CURRENT_DEBIAN_CODENAME=""

# --- Standardized Status Function ---
# Usage: HARDN_STATUS "error|pass|warning|info" "message"
HARDN_STATUS() {
    local status_type="$1"
    local message="$2"
    
    case "$status_type" in
        "error")
            printf "\033[1;31m[-] %s\033[0m\n" "$message"
            ;;
        "pass")
            printf "\033[1;32m[+] %s\033[0m\n" "$message"
            ;;
        "warning")
            printf "\033[1;33m[!] %s\033[0m\n" "$message"
            ;;
        "info")
            printf "\033[1;34m[*] %s\033[0m\n" "$message"
            ;;
        *)
            printf "\033[1;37m[?] %s\033[0m\n" "$message"
            ;;
    esac
}

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
    HARDN_STATUS "info" "Detecting operating system details..."
    if [[ -f /etc/os-release ]]; then
        
       
        source /etc/os-release
        CURRENT_DEBIAN_VERSION_ID="${VERSION_ID}"
        CURRENT_DEBIAN_CODENAME="${VERSION_CODENAME}"

        if [[ "${ID}" != "debian" ]]; then
            HARDN_STATUS "error" "This script is intended for Debian distributions only. Detected ID: ${ID}"
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
            HARDN_STATUS "error" "Could not reliably determine Debian version ID or codename."
            HARDN_STATUS "error" "Please ensure /etc/os-release and /etc/debian_version are correctly populated."
            exit 1
        fi

        HARDN_STATUS "pass" "Detected Debian Version ID: ${CURRENT_DEBIAN_VERSION_ID}, Codename: ${CURRENT_DEBIAN_CODENAME}"

        # Validate supported Debian versions (only Debian 12 bookworm)
        case "${CURRENT_DEBIAN_CODENAME}" in
            "bookworm")
                HARDN_STATUS "pass" "Debian ${CURRENT_DEBIAN_VERSION_ID} (${CURRENT_DEBIAN_CODENAME}) is the supported version."
                ;;
            *)
                HARDN_STATUS "error" "Debian ${CURRENT_DEBIAN_VERSION_ID} (${CURRENT_DEBIAN_CODENAME}) is not supported. This script only supports Debian 12 (bookworm)."
                exit 1
                ;;
        esac
    else
        HARDN_STATUS "error" "/etc/os-release not found. Cannot determine OS details."
        exit 1
    fi
}


# Check for root privileges
[ "$(id -u)" -ne 0 ] && echo "This script must be run as root." && exit 1

# Call OS detection early
detect_os_details

welcomemsg() {
    echo ""
    echo ""
    whiptail --title "HARDN-XDR" --msgbox "Welcome to HARDN-XDR a Debian Security tool for System Hardening" 10 60
    echo ""
    echo "This installer will update your system first..."
    whiptail --title "HARDN-XDR" --yesno "Do you want to continue with the installation?" 10 60
    # Original yes/no whiptail did not have an explicit exit path for "no"
}

preinstallmsg() {
    echo ""
    whiptail --title "HARDN-XDR" --msgbox "Welcome to HARDN-XDR. A Linux Security Hardening program." 10 60
    echo "The system will be configured to ensure STIG and Security compliance."
    # Removed: || { clear; exit 1; }
}

update_system_packages() {

    HARDN_STATUS "pass" "Updating system packages..."
    apt update -y
}

install_package_dependencies() {
    HARDN_STATUS "pass" "Installing package dependencies from ${PROGS_CSV_PATH}..."

    if ! command -v git >/dev/null 2>&1; then
        HARDN_STATUS "info" "Git is not installed. Attempting to install git..."
        if DEBIAN_FRONTEND=noninteractive apt-get install -y git >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Successfully installed git."
        else
            HARDN_STATUS "error" "Failed to install git. Some packages might fail to install if they require git."
            # Do not exit, allow script to continue if git is not strictly needed by all packages
        fi
    else
        HARDN_STATUS "info" "Git is already installed."
    fi

    # Check if the CSV file exists
    if [[ ! -f "${PROGS_CSV_PATH}" ]]; then
        HARDN_STATUS "error" "Package list file not found: ${PROGS_CSV_PATH}"
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
            HARDN_STATUS "warning" "Skipping line with empty package name."
            continue
        fi

        HARDN_STATUS "info" "Processing package: $name (Version: $version, Min Debian: $debian_min_version, Codenames: '$debian_codenames_str')"

        # Check OS compatibility
        os_compatible=false
        if [[ ",${debian_codenames_str}," == *",${CURRENT_DEBIAN_CODENAME},"* ]]; then
            if [[ "${debian_min_version}" == "12" ]]; then
                os_compatible=true
            else
                HARDN_STATUS "warning" "Skipping $name: Requires Debian version >= $debian_min_version, but current is $CURRENT_DEBIAN_VERSION_ID."
            fi
        else
            HARDN_STATUS "warning" "Skipping $name: Not compatible with Debian codename $CURRENT_DEBIAN_CODENAME (requires one of: $debian_codenames_str)."
        fi

        if ! $os_compatible; then
            continue
        fi

        # Installation logic based on version
        case "$version" in
            "latest")
                if ! dpkg -s "$name" >/dev/null 2>&1; then
                    HARDN_STATUS "info" "Attempting to install package: $name (latest from apt)..."
                    if DEBIAN_FRONTEND=noninteractive apt install -y "$name"; then
                        HARDN_STATUS "pass" "Successfully installed $name."
                    else
                        HARDN_STATUS "warning" "apt install failed for $name, trying apt-get..."
                        if DEBIAN_FRONTEND=noninteractive apt-get install -y "$name"; then
                             HARDN_STATUS "pass" "Successfully installed $name with apt-get."
                        else
                            HARDN_STATUS "error" "Failed to install $name with both apt and apt-get. Please check manually."
                        fi
                    fi
                else
                    HARDN_STATUS "info" "Package $name is already installed."
                fi
                ;;
            "source")
                HARDN_STATUS "warning" "INFO: 'source' installation type for $name. This type requires manual implementation in the script."
                HARDN_STATUS "warning" "Example steps for a source install (e.g., for a package named 'mytool'):"
                HARDN_STATUS "warning" "  1. Ensure build dependencies are installed (e.g., build-essential, cmake, etc.)."
                HARDN_STATUS "warning" "  2. wget https://example.com/mytool-src.tar.gz -O /tmp/mytool-src.tar.gz"
                HARDN_STATUS "warning" "  3. tar -xzf /tmp/mytool-src.tar.gz -C /tmp"
                HARDN_STATUS "warning" "  4. cd /tmp/mytool-* || exit 1"
                HARDN_STATUS "warning" "  5. ./configure && make && sudo make install"
                HARDN_STATUS "warning" "Skipping $name as its specific source installation steps are not defined."
                ;;
            "custom")
                HARDN_STATUS "warning" "INFO: 'custom' installation type for $name. This type requires manual implementation in the script."
                HARDN_STATUS "warning" "Example steps for a custom install (e.g., for a package named 'mycustomapp'):"
                HARDN_STATUS "warning" "  1. Add custom repository: curl -sSL https://example.com/repo/gpg | sudo apt-key add -"
                HARDN_STATUS "warning" "  2. echo 'deb https://example.com/repo ${CURRENT_DEBIAN_CODENAME} main' | sudo tee /etc/apt/sources.list.d/mycustomapp.list"
                HARDN_STATUS "warning" "  3. sudo apt update"
                HARDN_STATUS "warning" "  4. sudo apt install -y mycustomapp"
                HARDN_STATUS "warning" "Skipping $name as its specific custom installation steps are not defined."
                ;;
            *)
                HARDN_STATUS "error" "Unknown version '$version' for package $name. Skipping..."
                ;;
        esac
    done < <(tail -n +2 "${PROGS_CSV_PATH}")
    HARDN_STATUS "pass" "Package dependency installation attempt completed."
}



setup_security(){
    # OS detection is done by detect_os_details() 
    # global variables CURRENT_DEBIAN_VERSION_ID and CURRENT_DEBIAN_CODENAME are available.
    HARDN_STATUS "pass" "Using detected system: Debian ${CURRENT_DEBIAN_VERSION_ID} (${CURRENT_DEBIAN_CODENAME}) for security setup."

 ####################### DELETED FILES
    HARDN_STATUS "info" "Checking for deleted files in use..."
    if command -v lsof >/dev/null 2>&1; then
        deleted_files=$(lsof +L1 | awk '{print $9}' | grep -v '^$')
        if [[ -n "$deleted_files" ]]; then
            HARDN_STATUS "warning" "Found deleted files in use:"
            echo "$deleted_files"
            HARDN_STATUS "warning" "Please consider rebooting the system to release these files."
        else
            HARDN_STATUS "pass" "No deleted files in use found."
        fi
    else
        HARDN_STATUS "error" "lsof command not found. Cannot check for deleted files in use."
    fi
    
################################## ntp daemon
    HARDN_STATUS "info" "Setting up NTP daemon..."

    local ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
    local configured=false

    # Prefer systemd-timesyncd if active
    if systemctl is-active --quiet systemd-timesyncd; then
        HARDN_STATUS "info" "systemd-timesyncd is active. Configuring..."
        local timesyncd_conf="/etc/systemd/timesyncd.conf"
        local temp_timesyncd_conf
        temp_timesyncd_conf=$(mktemp)

        if [[ ! -f "$timesyncd_conf" ]]; then
            HARDN_STATUS "info" "Creating $timesyncd_conf as it does not exist."
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
            HARDN_STATUS "pass" "Updated $timesyncd_conf. Restarting systemd-timesyncd..."
            if systemctl restart systemd-timesyncd; then
                HARDN_STATUS "pass" "systemd-timesyncd restarted successfully."
                configured=true
            else
                HARDN_STATUS "error" "Failed to restart systemd-timesyncd. Manual check required."
            fi
        else
            HARDN_STATUS "info" "No effective changes to $timesyncd_conf were needed."
            configured=true # Already configured correctly or no changes needed
        fi
        rm -f "$temp_timesyncd_conf"

    # Fallback to ntpd if systemd-timesyncd is not active
    else
        HARDN_STATUS "info" "systemd-timesyncd is not active. Checking/Configuring ntpd..."

        local ntp_package_installed=false
        # Ensure ntp package is installed
        if dpkg -s ntp >/dev/null 2>&1; then
             HARDN_STATUS "pass" "ntp package is already installed."
             ntp_package_installed=true
        else
             HARDN_STATUS "info" "ntp package not found. Attempting to install..."
             # Attempt installation, check exit status
             if apt-get update >/dev/null 2>&1 && apt-get install -y ntp >/dev/null 2>&1; then
                 HARDN_STATUS "pass" "ntp package installed successfully."
                 ntp_package_installed=true
             else
                 HARDN_STATUS "error" "Failed to install ntp package. Skipping NTP configuration."
                 configured=false # Ensure configured is false on failure
                 # Do not return here, allow the rest of setup_security to run
             fi
        fi

        # Proceed with configuration ONLY if the package is installed
        if [[ "$ntp_package_installed" = true ]]; then
            local ntp_conf="/etc/ntp.conf"
            # Check if the configuration file exists and is writable
            if [[ -f "$ntp_conf" ]] && [[ -w "$ntp_conf" ]]; then
                HARDN_STATUS "info" "Configuring $ntp_conf..."
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
                    HARDN_STATUS "pass" "Updated $ntp_conf with recommended pool servers."

                    # Restart/Enable ntp service
                    if systemctl enable --now ntp; then
                        HARDN_STATUS "pass" "ntp service enabled and started successfully."
                        configured=true
                    else
                        HARDN_STATUS "error" "Failed to enable/start ntp service. Manual check required."
                        configured=false # Set to false on service failure
                    fi
                else
                    HARDN_STATUS "info" "No effective changes to $ntp_conf were needed."
                    configured=true # Already configured correctly or no changes needed
                fi
                rm -f "$temp_ntp_conf" # Clean up temp file

            else
                # This is the error path the user saw
                HARDN_STATUS "error" "NTP configuration file $ntp_conf not found or not writable after ntp package check/installation. Skipping NTP configuration."
                configured=false # Set to false if config file is missing/unwritable
            fi
        fi # End if ntp_package_installed
    fi # End of systemd-timesyncd else block

    if [[ "$configured" = true ]]; then
        HARDN_STATUS "pass" "NTP configuration attempt completed."
    else
        HARDN_STATUS "error" "NTP configuration failed or skipped due to errors."
    fi

    HARDN_STATUS "info" "Setting up security tools and configurations..."
    
    ########################### UFW (Uncomplicated Firewall)
    HARDN_STATUS "info" "Configuring UFW..."
    if ! command -v ufw >/dev/null 2>&1; then
        HARDN_STATUS "info" "UFW not found, installing..."
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
        HARDN_STATUS "warning" "UFW could not be installed or found. Skipping UFW configuration."
    fi


    ############################## Automation tool check
    HARDN_STATUS "error" "Checking for automation tools..."
    local automation_tools=("ansible" "puppet" "chef" "salt")
    local found_tools=()
    for tool in "${automation_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            found_tools+=("$tool")
            HARDN_STATUS "pass" "Found automation tool: $tool"
        else
            HARDN_STATUS "warning" "Automation tool not found: $tool"
        fi
    done
    
    ###################################### Fail2Ban
    HARDN_STATUS "error" "Configuring Fail2Ban..."
    # Check if Fail2Ban package is installed
    if dpkg -s fail2ban >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Fail2Ban package is installed."

        # Check if the service unit file exists before trying to enable/start
        if systemctl list-unit-files --type=service | grep -q '^fail2ban\.service'; then
            HARDN_STATUS "info" "Enabling and starting Fail2Ban service..."
            systemctl enable fail2ban >/dev/null 2>&1
            systemctl start fail2ban >/dev/null 2>&1
            if systemctl is-active --quiet fail2ban; then
                 HARDN_STATUS "pass" "Fail2Ban service enabled and started."
            else
                 HARDN_STATUS "warning" "Warning: Failed to start Fail2Ban service."
            fi
        else
            HARDN_STATUS "warning" "Warning: fail2ban.service not found, skipping service enable/start."
        fi

        # Configure jail.local for STIG compliance (SSH specific)
        local jail_conf="/etc/fail2ban/jail.conf"
        local jail_local="/etc/fail2ban/jail.local"

        if [ -f "$jail_conf" ]; then
            HARDN_STATUS "info" "Configuring $jail_local for SSH STIG compliance..."
            # Create jail.local if it doesn't exist or copy from jail.conf
            if [ ! -f "$jail_local" ]; then
                cp "$jail_conf" "$jail_local"
                HARDN_STATUS "pass" "Created $jail_local from $jail_conf."
            else
                 HARDN_STATUS "info" "$jail_local already exists. Modifying existing file."
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
                 HARDN_STATUS "pass" "Added [sshd] jail configuration to $jail_local."
            else
                 sed -i '/^\[sshd\]/,/^\[.*\]/ s/^\s*enabled\s*=\s*false/enabled = true/' "$jail_local" 2>/dev/null || true # Corrected grep pattern for [sshd]
                 HARDN_STATUS "info" "Ensured sshd jail is enabled in $jail_local."
            fi

            HARDN_STATUS "pass" "Applied STIG-like settings (bantime=1h, findtime=15m, maxretry=3) to sshd jail in $jail_local."

            # Restart Fail2Ban to apply changes
            if systemctl list-unit-files --type=service | grep -q '^fail2ban\.service'; then
                 HARDN_STATUS "info" "Restarting Fail2Ban service to apply changes..."
                 if systemctl restart fail2ban >/dev/null 2>&1; then
                     HARDN_STATUS "pass" "Fail2Ban service restarted successfully."
                 else
                     HARDN_STATUS "error" "Failed to restart Fail2Ban service."
                 fi
            fi

        else
            HARDN_STATUS "error" "Error: $jail_conf not found, skipping jail.local configuration."
        fi
    else
        HARDN_STATUS "warning" "Warning: Fail2Ban is not installed (checked with dpkg -s). Skipping configuration."
        HARDN_STATUS "warning" "Please ensure Fail2Ban is listed in ../../progs.csv for installation."
    fi
    HARDN_STATUS "pass" "Fail2Ban configuration attempt completed."

    ################################### kernel hardening
    # Check if system is UEFI VM and skip kernel hardening if so
    if [ -d /sys/firmware/efi ] && systemd-detect-virt -q; then
        HARDN_STATUS "info" "UEFI VM detected, skipping kernel hardening..."
    else
        HARDN_STATUS "info" "Configuring kernel hardening..."
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
        HARDN_STATUS "warning" "UEFI system detected without GRUB, skipping GRUB configuration..."
    elif [ ! -f /etc/default/grub ]; then
        HARDN_STATUS "warning" "GRUB configuration file not found, skipping GRUB configuration..."
    else
        HARDN_STATUS "info" "Configuring GRUB..."
        # Backup original GRUB config
        cp /etc/default/grub "/etc/default/grub.bak.$(date +%F-%T)" 2>/dev/null || true
        
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash mitigations=auto"/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_HIDDEN_TIMEOUT=0/GRUB_HIDDEN_TIMEOUT=5/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_HIDDEN_TIMEOUT_QUIET=true/GRUB_HIDDEN_TIMEOUT_QUIET=false/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_TERMINAL=console/GRUB_TERMINAL=console/' /etc/default/grub 2>/dev/null || true
        sed -i 's/GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/' /etc/default/grub 2>/dev/null || true
        
        if update-grub >/dev/null 2>&1; then
            HARDN_STATUS "pass" "GRUB configuration updated."
        else
            HARDN_STATUS "warning" "Warning: Failed to update GRUB configuration."
        fi
    fi
    
    ################################## AppArmor
    HARDN_STATUS "info" "Configuring AppArmor..."
    if [ -d /sys/kernel/security/apparmor ]; then
        systemctl enable apparmor >/dev/null 2>&1
        systemctl start apparmor >/dev/null 2>&1
        # Check if AppArmor is actually running before enforcing profiles
        if systemctl is-active --quiet apparmor && [ -f /sys/kernel/security/apparmor/profiles ]; then
            aa-enforce /etc/apparmor.d/* >/dev/null 2>&1 || {
                HARDN_STATUS "warning" "Warning: Failed to enforce some AppArmor profiles."
            }
        else
            HARDN_STATUS "warning" "Warning: AppArmor not properly initialized, skipping profile enforcement."
        fi
    else
        HARDN_STATUS "warning" "Warning: AppArmor not supported on this system, skipping configuration."
    fi
    
    ############################ Firejail
    HARDN_STATUS "info" "Configuring Firejail..."
    firecfg >/dev/null 2>&1 || true
    

    browsers=("firefox" "google-chrome" "tor" "brave")
    for browser in "${browsers[@]}"; do
        if command -v "$browser" >/dev/null 2>&1; then
            HARDN_STATUS "info" "Configuring Firejail for $browser..."
            firejail --apparmor --seccomp --private-tmp --noroot --caps.drop=all "$browser" >/dev/null 2>&1 || true
        fi
    done
    
    ################################ TCP Wrappers (tcpd)
    HARDN_STATUS "info" "Configuring TCP Wrappers..."

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
    HARDN_STATUS "pass" "TCP Wrappers configuration applied: only localhost and SSH allowed."
  
    ################################ USB storage
    HARDN_STATUS "error" "Configuring USB device controls..."
    
    # Create USB storage blacklist file
    cat > /etc/modprobe.d/usb-storage.conf << 'EOF'
# HARDN-XDR USB Security Configuration
# Block USB storage devices while allowing keyboards and mice
blacklist usb-storage
blacklist uas          # Block USB Attached SCSI (another storage protocol)
blacklist sd_mod       # Be careful with this - may affect internal storage
# DO NOT blacklist usbhid - needed for keyboards and mice
EOF
    
    HARDN_STATUS "info" "USB security policy configured to allow HID devices but block storage."
    
    # Create udev rules to further control USB devices 
    cat > /etc/udev/rules.d/99-usb-storage.rules << 'EOF'
# Block USB storage devices while allowing keyboards and mice
ACTION=="add", SUBSYSTEMS=="usb", ATTRS{bInterfaceClass}=="08", RUN+="/bin/sh -c 'echo 0 > /sys$DEVPATH/authorized'"
# Interface class 08 is for mass storage
# Interface class 03 is for HID devices (keyboards, mice) - these remain allowed
EOF
    
    HARDN_STATUS "info" "Additional udev rules created for USB device control."
    
    # Reload rules
    if udevadm control --reload-rules && udevadm trigger; then
        HARDN_STATUS "pass" "Udev rules reloaded successfully."
    else
        HARDN_STATUS "error" "Failed to reload udev rules."
    fi
    
    # Unload the usb-storage module 
    if lsmod | grep -q "usb_storage"; then
        HARDN_STATUS "info" "usb-storage module is currently loaded, attempting to unload..."
        if rmmod usb_storage >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Successfully unloaded usb-storage module."
        else
            HARDN_STATUS "error" "Failed to unload usb-storage module. It may be in use."
        fi
    else
        HARDN_STATUS "pass" "usb-storage module is not loaded, no need to unload."
    fi
    
    # HID is enabled
    if lsmod | grep -q "usbhid"; then
        HARDN_STATUS "pass" "USB HID module is loaded - keyboards and mice will work."
    else
        HARDN_STATUS "warning" "USB HID module is not loaded - attempting to load it..."
        if modprobe usbhid; then
            HARDN_STATUS "pass" "Successfully loaded USB HID module."
        else
            HARDN_STATUS "error" "Failed to load USB HID module."
        fi
    fi
    
    HARDN_STATUS "pass" "USB configuration complete: keyboards and mice allowed, storage blocked."
    
    
    ############################ Disable unnecessary network protocols in kernel
    HARDN_STATUS "error" "Disabling unnecessary network protocols..."
    
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

    HARDN_STATUS "pass" "Network protocol hardening complete: Disabled $(grep -c "^install" /etc/modprobe.d/blacklist-rare-network.conf) protocols"
    
    
    # Apply changes immediately where possible
    sysctl -p
    
    ############################ Secure shared memory
    HARDN_STATUS "info" "Securing shared memory..."
    if ! grep -q "tmpfs /run/shm" /etc/fstab; then
        echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid,nodev 0 0" >> /etc/fstab
    fi
    
    ########################### Set secure file permissions
	HARDN_STATUS "info" "Setting secure file permissions..."
	chmod 700 /root                    # root home directory - root
	chmod 644 /etc/passwd              # user database - readable (required)
	chmod 600 /etc/shadow              # password hashes - root only
	chmod 644 /etc/group               # group database - readable
	chmod 600 /etc/gshadow             # group passwords - root   
	chmod 644 /etc/ssh/sshd_config     # SSH daemon config - readable

    ########################### Disable core dumps for security
    HARDN_STATUS "info" "Disabling core dumps..."
    echo "* hard core 0" >> /etc/security/limits.conf
    echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
    
    ############################### automatic security updates
    HARDN_STATUS "info" "Configuring automatic security updates for Debian-based systems..."

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
    HARDN_STATUS "info" "Configuring secure network parameters..."
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

    
    #################################### rkhunter
    HARDN_STATUS "info" "Configuring rkhunter..."
    if ! dpkg -s rkhunter >/dev/null 2>&1; then
        HARDN_STATUS "info" "rkhunter package not found. Attempting to install via apt..."
        if apt-get install -y rkhunter >/dev/null 2>&1; then
            HARDN_STATUS "pass" "rkhunter installed successfully via apt."
        else
            HARDN_STATUS "warning" "Warning: Failed to install rkhunter via apt. Attempting to download and install from GitHub as a fallback..."
            # Ensure git is installed for GitHub clone
            if ! command -v git >/dev/null 2>&1; then
                HARDN_STATUS "info" "Installing git..."
                apt-get install -y git >/dev/null 2>&1 || {
                    HARDN_STATUS "error" "Error: Failed to install git. Cannot proceed with GitHub install."
                    # Skip GitHub install if git fails
                    return
                }
            fi

            cd /tmp || { HARDN_STATUS "error" "Error: Cannot change directory to /tmp."; return; }
            HARDN_STATUS "info" "Cloning rkhunter from GitHub..."
            if git clone https://github.com/rootkitHunter/rkhunter.git rkhunter_github_clone >/dev/null 2>&1; then
                cd rkhunter_github_clone || { HARDN_STATUS "error" "Error: Cannot change directory to rkhunter_github_clone."; return; }
                HARDN_STATUS "info" "Running rkhunter installer..."
                if ./installer.sh --install >/dev/null 2>&1; then
                    HARDN_STATUS "pass" "rkhunter installed successfully from GitHub."
                else
                    HARDN_STATUS "error" "Error: rkhunter installer failed."
                fi
                cd .. && rm -rf rkhunter_github_clone
            else
                HARDN_STATUS "error" "Error: Failed to clone rkhunter from GitHub."
            fi
        fi
    else
        HARDN_STATUS "pass" "rkhunter package is already installed."
    fi

    if command -v rkhunter >/dev/null 2>&1; then
      
        sed -i 's/#CRON_DAILY_RUN=""/CRON_DAILY_RUN="true"/' /etc/default/rkhunter 2>/dev/null || true
        
   
        rkhunter --configcheck >/dev/null 2>&1 || true
        rkhunter --update --nocolors >/dev/null 2>&1 || {
            HARDN_STATUS "warning" "Warning: Failed to update rkhunter database."
        }
        rkhunter --propupd --nocolors >/dev/null 2>&1 || {
            HARDN_STATUS "warning" "Warning: Failed to update rkhunter properties."
        }
    else
        HARDN_STATUS "warning" "Warning: rkhunter not found, skipping configuration."
    fi
    
    ######################## STIG-PAM Password Quality
    HARDN_STATUS "info" "Configuring PAM password quality..."
    if [ -f /etc/pam.d/common-password ]; then
        if ! grep -q "pam_pwquality.so" /etc/pam.d/common-password; then
            echo "password requisite pam_pwquality.so retry=3 minlen=8 difok=3 ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1" >> /etc/pam.d/common-password
        fi
    else
        HARDN_STATUS "warning" "Warning: /etc/pam.d/common-password not found, skipping PAM configuration..."
    fi
    
    #############################   libvirt and KVM
    printf "Configuring libvirt...\n"
    systemctl enable libvirtd
    systemctl start libvirtd

if [ -n "$SUDO_USER" ]; then
    if usermod -aG libvirt "$SUDO_USER" 2>/dev/null; then
        printf "Added user %s to libvirt group\n" "$SUDO_USER"
        printf "User should log out and log back in for group change to take effect.\n"
    else
        printf "Failed to add user %s to libvirt group\n" "$SUDO_USER"
    fi
else
    printf "Warning: Could not determine user to add to libvirt group. If you ran this as root, manually add your user to the 'libvirt' group.\n"
fi

    
    ################################### OpenSSH Server
    HARDN_STATUS "info" "Configuring OpenSSH..."
    sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
    sed -i 's/#Protocol 2/Protocol 2/' /etc/ssh/sshd_config
    sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
    systemctl restart ssh || systemctl restart sshd
    
    ####################################### chkrootkit
    HARDN_STATUS "info" "Configuring chkrootkit..."
    if ! command -v chkrootkit >/dev/null 2>&1; then
        HARDN_STATUS "info" "chkrootkit package not found. Attempting to download and install from chkrootkit.org..."
        local download_url="https://www.chkrootkit.org/dl/chkrootkit.tar.gz"
        local download_dir="/tmp/chkrootkit_install"
        local tar_file="$download_dir/chkrootkit.tar.gz"

        mkdir -p "$download_dir"
        cd "$download_dir" || { HARDN_STATUS "error" "Error: Cannot change directory to $download_dir."; return 1; }

        HARDN_STATUS "info" "Downloading $download_url..."
        if wget -q "$download_url" -O "$tar_file"; then
            HARDN_STATUS "pass" "Download successful."
            HARDN_STATUS "info" "Extracting..."
            if tar -xzf "$tar_file" -C "$download_dir"; then
                HARDN_STATUS "pass" "Extraction successful."
                local extracted_dir
                extracted_dir=$(tar -tf "$tar_file" | head -1 | cut -f1 -d/)
                
                if [[ -d "$download_dir/$extracted_dir" ]]; then
                    cd "$download_dir/$extracted_dir" || { HARDN_STATUS "error" "Error: Cannot change directory to extracted folder."; return 1; }
                    HARDN_STATUS "info" "Running chkrootkit installer..."
                    
                    if [[ -f "chkrootkit" ]]; then
                        cp chkrootkit /usr/local/sbin/
                        chmod +x /usr/local/sbin/chkrootkit
                        if [[ -f "chkrootkit.8" ]]; then
                            cp chkrootkit.8 /usr/local/share/man/man8/
                            mandb >/dev/null 2>&1 || true
                        fi
                        HARDN_STATUS "pass" "chkrootkit installed to /usr/local/sbin."
                    else
                         HARDN_STATUS "error" "Error: chkrootkit script not found in extracted directory."
                    fi
                else
                    HARDN_STATUS "error" "Error: Extracted directory not found."
                fi
            else
                HARDN_STATUS "error" "Error: Failed to extract $tar_file."
            fi
        else
            HARDN_STATUS "error" "Error: Failed to download $download_url."
        fi

      
        cd /tmp || true 
        rm -rf "$download_dir"
    else
        HARDN_STATUS "pass" "chkrootkit package is already installed."
    fi

   
    if command -v chkrootkit >/dev/null 2>&1; then
       
        if ! grep -q "/usr/local/sbin/chkrootkit" /etc/crontab; then
            echo "0 3 * * * root /usr/local/sbin/chkrootkit 2>&1 | logger -t chkrootkit" >> /etc/crontab
            HARDN_STATUS "pass" "chkrootkit daily check added to crontab."
        else
            HARDN_STATUS "info" "chkrootkit already in crontab."
        fi
    else
        HARDN_STATUS "error" "chkrootkit command not found after installation attempt, skipping cron configuration."
    fi
    
    ###################################### auditd
    HARDN_STATUS "info" "Configuring auditd..."
   
    if dpkg -s auditd >/dev/null 2>&1; then
        HARDN_STATUS "pass" "auditd package is installed."

        #
        if systemctl list-unit-files --type=service | grep -q '^auditd\.service'; then
            HARDN_STATUS "info" "Enabling and starting auditd service..."
            systemctl enable auditd >/dev/null 2>&1
            systemctl start auditd >/dev/null 2>&1
            if systemctl is-active --quiet auditd; then
                 HARDN_STATUS "pass" "auditd service enabled and started."
            else
                 HARDN_STATUS "warning" "Warning: Failed to start auditd service."
            fi
        else
            HARDN_STATUS "warning" "Warning: auditd.service not found, skipping service enable/start."
        fi

        # Enable auditing via auditctl 
        if command -v auditctl >/dev/null 2>&1; then
            HARDN_STATUS "info" "Attempting to enable auditd system via auditctl..."
            # -e 1 enables auditing
            if auditctl -e 1 >/dev/null 2>&1; then
                HARDN_STATUS "pass" "auditd system enabled successfully via auditctl."
            else
                HARDN_STATUS "error" "Failed to enable auditd system via auditctl. Check auditd status and configuration."
            fi
        else
            HARDN_STATUS "warning" "Warning: auditctl command not found. Cannot verify/enable audit system status."
        fi

        # Configure specific audit rules (/etc/audit/audit.rules) based on STIG
        # Note: Rules optimized to reduce system impact while maintaining security
        HARDN_STATUS "info" "Configuring optimized auditd rules based on STIG..."
        local audit_rules_file="/etc/audit/audit.rules"

        # Backup existing rules
        if [ -f "$audit_rules_file" ]; then
            cp "$audit_rules_file" "${audit_rules_file}.bak.$(date +%F-%T)" 2>/dev/null || true
            HARDN_STATUS "pass" "Backed up existing audit rules to $audit_rules_file.bak."
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
        HARDN_STATUS "info" "Loading new auditd rules..."
        if auditctl -R "$audit_rules_file" >/dev/null 2>&1; then
            HARDN_STATUS "pass" "New auditd rules loaded successfully."
        else
            HARDN_STATUS "error" "Failed to load new auditd rules. Check the rules file for syntax errors."
        fi

    else
        HARDN_STATUS "warning" "Warning: auditd is not installed (checked with dpkg -s). Skipping configuration."
        HARDN_STATUS "warning" "Please ensure auditd is listed in ../../progs.csv for installation."
    fi
    HARDN_STATUS "pass" "auditd configuration attempt completed."


    
    ####################################### Suricata
    HARDN_STATUS "error" "Checking and configuring Suricata..."

    if dpkg -s suricata >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Suricata package is already installed."
    else
        HARDN_STATUS "info" "Suricata package not found. Attempting to install from source..."

        local suricata_version="7.0.0" 
        local download_url="https://www.suricata-ids.org/download/releases/suricata-${suricata_version}.tar.gz"
        local download_dir="/tmp/suricata_install"
        local tar_file="$download_dir/suricata-${suricata_version}.tar.gz"
        local extracted_dir="suricata-${suricata_version}"

      
        HARDN_STATUS "info" "Installing Suricata build dependencies..."
        if ! apt-get update >/dev/null 2>&1 || ! apt-get install -y \
            build-essential libpcap-dev libnet1-dev libyaml-0-2 libyaml-dev zlib1g zlib1g-dev \
            libcap-ng-dev libmagic-dev libjansson-dev libnss3-dev liblz4-dev libtool \
            libnfnetlink-dev libevent-dev pkg-config libhiredis-dev libczmq-dev \
            python3 python3-yaml python3-setuptools python3-pip python3-dev \
            rustc cargo >/dev/null 2>&1; then
            HARDN_STATUS "error" "Error: Failed to install Suricata build dependencies. Skipping Suricata configuration."
            return 1
        fi
        HARDN_STATUS "pass" "Suricata build dependencies installed."

        mkdir -p "$download_dir"
        cd "$download_dir" || { HARDN_STATUS "error" "Error: Cannot change directory to $download_dir."; return 1; }

        HARDN_STATUS "info" "Downloading %s...\\n" "$download_url"
        if wget -q "$download_url" -O "$tar_file"; then
            HARDN_STATUS "pass" "Download successful."
            HARDN_STATUS "info" "Extracting..."
            if tar -xzf "$tar_file" -C "$download_dir"; then
                HARDN_STATUS "pass" "Extraction successful."

                if [[ -d "$download_dir/$extracted_dir" ]]; then
                    cd "$download_dir/$extracted_dir" || { HARDN_STATUS "error" "Error: Cannot change directory to extracted folder."; return 1; }

                    HARDN_STATUS "info" "Running ./configure..."
                    
                    if ./configure \
                        --prefix=/usr \
                        --sysconfdir=/etc \
                        --localstatedir=/var \
                        --disable-gccmarch-native \
                        --enable-lua \
                        --enable-geoip \
                        > /dev/null 2>&1; then 
                        HARDN_STATUS "pass" "Configure successful."

                        HARDN_STATUS "info" "Running make..."
                        if make > /dev/null 2>&1; then 
                            HARDN_STATUS "pass" "Make successful."

                            HARDN_STATUS "info" "Running make install..."
                            if make install > /dev/null 2>&1; then 
                                HARDN_STATUS "pass" "Suricata installed successfully from source."
                             
                                ldconfig >/dev/null 2>&1 || true
                            else
                                HARDN_STATUS "error" "Error: make install failed."
                                cd /tmp || true 
                                rm -rf "$download_dir"
                                return 1
                            fi
                        else
                            HARDN_STATUS "error" "Error: make failed."
                            cd /tmp || true 
                            rm -rf "$download_dir"
                            return 1
                        fi
                    else
                        HARDN_STATUS "error" "Error: ./configure failed."
                        cd /tmp || true 
                        rm -rf "$download_dir"
                        return 1
                    fi
                else
                    HARDN_STATUS "error" "Error: Extracted directory not found."
                    cd /tmp || true 
                    rm -rf "$download_dir"
                    return 1
                fi
            else
                HARDN_STATUS "error" "Error: Failed to extract $tar_file."
                cd /tmp || true
                rm -rf "$download_dir"
                return 1
            fi
        else
            HARDN_STATUS "error" "Error: Failed to download $download_url."
            cd /tmp || true # Move out before cleanup
            rm -rf "$download_dir"
            return 1
        fi

        # Clean up temporary files
        cd /tmp || true # Move out of the download directory before removing
        rm -rf "$download_dir"
    fi

    # If Suricata is installed 
    if command -v suricata >/dev/null 2>&1; then
        HARDN_STATUS "info" "Configuring Suricata..."

        # Ensure the default configuration 
        if [ ! -d /etc/suricata ]; then
            HARDN_STATUS "info" "Creating /etc/suricata and copying default config..."
            mkdir -p /etc/suricata
    
            if [ ! -f /etc/suricata/suricata.yaml ]; then
                 HARDN_STATUS "error" "Error: Suricata default configuration file /etc/suricata/suricata.yaml not found after installation. Skipping configuration."
                 return 1
            fi
        fi

        # Enable the service 
        if systemctl enable suricata >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Suricata service enabled successfully."
        else
            HARDN_STATUS "error" "Failed to enable Suricata service. Check if the service file exists (e.g., /lib/systemd/system/suricata.service)."
        fi

        # Update rules
        HARDN_STATUS "info" "Running suricata-update..."
        # suricata-update might need python dependencies.....
        if ! command -v suricata-update >/dev/null 2>&1; then
             HARDN_STATUS "info" "suricata-update command not found. Attempting to install..."
             if pip3 install --upgrade pip >/dev/null 2>&1 && pip3 install --upgrade suricata-update >/dev/null 2>&1; then
                 HARDN_STATUS "pass" "suricata-update installed successfully via pip3."
             else
                 HARDN_STATUS "error" "Error: Failed to install suricata-update via pip3. Skipping rule update."
             fi
        fi

        if command -v suricata-update >/dev/null 2>&1; then
            if suricata-update >/dev/null 2>&1; then
                HARDN_STATUS "pass" "Suricata rules updated successfully."
            else
                HARDN_STATUS "warning" "Warning: Suricata rules update failed. Check output manually."
            fi
        else
             HARDN_STATUS "error" "suricata-update command not available, skipping rule update."
        fi

        # Start the service
        if systemctl start suricata >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Suricata service started successfully."
        else
            HARDN_STATUS "error" "Failed to start Suricata service. Check logs for details."
        fi
    else
        HARDN_STATUS "error" "Suricata command not found after installation attempt, skipping configuration."
    fi

    ########################### debsums 
    HARDN_STATUS "info" "Configuring debsums..."
    if command -v debsums >/dev/null 2>&1; then
        if debsums_init >/dev/null 2>&1; then
            HARDN_STATUS "pass" "debsums initialized successfully"
        else
            HARDN_STATUS "error" "Failed to initialize debsums"
        fi
        
        # Add debsums check to daily cron
        if ! grep -q "debsums" /etc/crontab; then
            echo "0 4 * * * root /usr/bin/debsums -s 2>&1 | logger -t debsums" >> /etc/crontab
            HARDN_STATUS "pass" "debsums daily check added to crontab"
        else
            HARDN_STATUS "warning" "debsums already in crontab"
        fi
        
        # Run initial check
        HARDN_STATUS "info" "Running initial debsums check..."
        if debsums -s >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Initial debsums check completed successfully"
        else
            HARDN_STATUS "warning" "Warning: Some packages failed debsums verification"
        fi
    else
        HARDN_STATUS "error" "debsums command not found, skipping configuration"
    fi
    
    ############################## AIDE (Advanced Intrusion Detection Environment)
    if ! dpkg -s aide >/dev/null 2>&1; then
        HARDN_STATUS "info" "Installing and configuring AIDE..."
        apt install -y aide >/dev/null 2>&1
        aideinit >/dev/null 2>&1 || true
        mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db >/dev/null 2>&1 || true
        echo "0 5 * * * root /usr/bin/aide --check" >> /etc/crontab
        HARDN_STATUS "pass" "AIDE installed and configured successfully"
    else
        HARDN_STATUS "warning" "AIDE already installed, skipping configuration..."
    fi
  
    #################################### YARA
    HARDN_STATUS "error" "Setting up YARA rules..."

    # Check if YARA command exists (implies installation)
    if ! command -v yara >/dev/null 2>&1; then
        HARDN_STATUS "warning" "Warning: YARA command not found. Skipping rule setup."
       
  
    else
        HARDN_STATUS "pass" "YARA command found."
        HARDN_STATUS "info" "Creating YARA rules directory..."
        mkdir -p /etc/yara/rules
        chmod 755 /etc/yara/rules # Ensure directory is accessible

        HARDN_STATUS "info" "Checking for git..."
        if ! command -v git >/dev/null 2>&1; then
            HARDN_STATUS "info" "git not found. Attempting to install..."
            if apt-get update >/dev/null 2>&1 && apt-get install -y git >/dev/null 2>&1; then
                HARDN_STATUS "pass" "git installed successfully."
            else
                HARDN_STATUS "error" "Error: Failed to install git. Cannot download YARA rules."
                return 1 # Exit this section
            fi
        else
            HARDN_STATUS "pass" "git command found."
        fi

        local rules_repo_url="https://github.com/Yara-Rules/rules.git"
        local temp_dir
        temp_dir=$(mktemp -d -t yara-rules-XXXXXXXX)

        if [[ ! -d "$temp_dir" ]]; then
            HARDN_STATUS "error" "Error: Failed to create temporary directory for YARA rules."
            return 1 # Exit this section
        fi

        HARDN_STATUS "info" "Cloning YARA rules from $rules_repo_url to $temp_dir..."
        if git clone --depth 1 "$rules_repo_url" "$temp_dir" >/dev/null 2>&1; then
            HARDN_STATUS "pass" "YARA rules cloned successfully."

            HARDN_STATUS "info" "Copying .yar rules to /etc/yara/rules/..."
            local copied_count=0
            # Find all .yar files in the cloned repo and copy them
            while IFS= read -r -d $'\0' yar_file; do
                if cp "$yar_file" /etc/yara/rules/; then
                    ((copied_count++))
                else
                    HARDN_STATUS "warning" "Warning: Failed to copy rule file: $yar_file"
                fi
            done < <(find "$temp_dir" -name "*.yar" -print0)

            if [[ "$copied_count" -gt 0 ]]; then
                HARDN_STATUS "pass" "Copied $copied_count YARA rule files to /etc/yara/rules/."
            else
                 HARDN_STATUS "warning" "Warning: No .yar files found or copied from the repository."
            fi

        else
            HARDN_STATUS "error" "Error: Failed to clone YARA rules repository."
        fi

        HARDN_STATUS "info" "Cleaning up temporary directory $temp_dir..."
        rm -rf "$temp_dir"
        HARDN_STATUS "pass" "Cleanup complete."

        HARDN_STATUS "pass" "YARA rules setup attempt completed."
    fi
    

    ######################### STIG banner (/etc/issue.net)
    HARDN_STATUS "error" "Configuring STIG compliant banner for remote logins (/etc/issue.net)..."
    local banner_net_file="/etc/issue.net"
    if [ -f "$banner_net_file" ]; then
        # Backup existing banner file
        cp "$banner_net_file" "${banner_net_file}.bak.$(date +%F-%T)" 2>/dev/null || true
    else
        touch "$banner_net_file"
    fi
    # Write the STIG compliant banner
    {
        echo "*************************************************************"
        echo "*     ############# H A R D N - X D R ##############        *"
        echo "*  This system is for the use of authorized SIG users.      *"
        echo "*  Individuals using this computer system without authority *"
        echo "*  or in excess of their authority are subject to having    *"
        echo "*  all of their activities on this system monitored and     *"
        echo "*  recorded by system personnel.                            *"
        echo "*                                                           *"
        echo "************************************************************"
    } > "$banner_net_file"
    chmod 644 "$banner_net_file"
    HARDN_STATUS "pass" "STIG compliant banner configured in $banner_net_file."    
}

restrict_compilers() {
    HARDN_STATUS "error" "Restricting compiler access to root only (HRDN-7222)..."

    local compilers
	compilers="/usr/bin/gcc /usr/bin/g++ /usr/bin/make /usr/bin/cc /usr/bin/c++ /usr/bin/as /usr/bin/ld"
    for bin in $compilers; do
        if [[ -f "$bin" ]]; then
            chmod 755 "$bin"
            chown root:root "$bin"
            HARDN_STATUS "pass" "Set $bin to 755 root:root (default for compilers)."
        fi
    done
}

disable_binfmt_misc() {
    HARDN_STATUS "error" "Checking/Disabling non-native binary format support (binfmt_misc)..."
    if mount | grep -q 'binfmt_misc'; then
        HARDN_STATUS "info" "binfmt_misc is mounted. Attempting to unmount..."
        if umount /proc/sys/fs/binfmt_misc; then
            HARDN_STATUS "pass" "binfmt_misc unmounted successfully."
        else
            HARDN_STATUS "error" "Failed to unmount binfmt_misc. It might be busy or not a separate mount."
        fi
    fi

    if lsmod | grep -q "^binfmt_misc"; then
        HARDN_STATUS "info" "binfmt_misc module is loaded. Attempting to unload..."
        if rmmod binfmt_misc; then
            HARDN_STATUS "pass" "binfmt_misc module unloaded successfully."
        else
            HARDN_STATUS "error" "Failed to unload binfmt_misc module. It might be in use or built-in."
        fi
    else
        HARDN_STATUS "pass" "binfmt_misc module is not currently loaded."
    fi

    # Prevent module from loading on boot
    local modprobe_conf="/etc/modprobe.d/disable-binfmt_misc.conf"
    if [[ ! -f "$modprobe_conf" ]]; then
        echo "install binfmt_misc /bin/true" > "$modprobe_conf"
        HARDN_STATUS "pass" "Added modprobe rule to prevent binfmt_misc from loading on boot: $modprobe_conf"
    else
        if ! grep -q "install binfmt_misc /bin/true" "$modprobe_conf"; then
            echo "install binfmt_misc /bin/true" >> "$modprobe_conf"
            HARDN_STATUS "pass" "Appended modprobe rule to prevent binfmt_misc from loading to $modprobe_conf"
        else
            HARDN_STATUS "info" "Modprobe rule to disable binfmt_misc already exists in $modprobe_conf."
        fi
    fi
    whiptail --infobox "Non-native binary format support (binfmt_misc) checked/disabled." 7 70
}

disable_firewire_drivers() {
    HARDN_STATUS "error" "Checking/Disabling FireWire (IEEE 1394) drivers..."
    local firewire_modules changed blacklist_file
	firewire_modules="firewire_core firewire_ohci firewire_sbp2"
    changed=0

    for module_name in $firewire_modules; do
        if lsmod | grep -q "^${module_name}"; then
            HARDN_STATUS "info" "FireWire module $module_name is loaded. Attempting to unload..."
            if rmmod "$module_name"; then
                HARDN_STATUS "pass" "FireWire module $module_name unloaded successfully."
                changed=1
            else
                HARDN_STATUS "error" "Failed to unload FireWire module $module_name. It might be in use or built-in."
            fi
        else
            HARDN_STATUS "info" "FireWire module $module_name is not currently loaded."
        fi
    done

    blacklist_file="/etc/modprobe.d/blacklist-firewire.conf"
    if [[ ! -f "$blacklist_file" ]]; then
        touch "$blacklist_file"
        HARDN_STATUS "pass" "Created FireWire blacklist file: $blacklist_file"
    fi

    for module_name in $firewire_modules; do
        if ! grep -q "blacklist $module_name" "$blacklist_file"; then
            echo "blacklist $module_name" >> "$blacklist_file"
            HARDN_STATUS "pass" "Blacklisted FireWire module $module_name in $blacklist_file"
            changed=1
        else
            HARDN_STATUS "info" "FireWire module $module_name already blacklisted in $blacklist_file."
        fi
    done

    if [[ "$changed" -eq 1 ]]; then
        whiptail --infobox "FireWire drivers checked. Unloaded and/or blacklisted where applicable." 7 70
    else
        whiptail --infobox "FireWire drivers checked. No changes made (likely already disabled/not present)." 8 70
    fi
}

purge_old_packages() {
    HARDN_STATUS "error" "Purging configuration files of old/removed packages..."
    local packages_to_purge
    packages_to_purge=$(dpkg -l | grep '^rc' | awk '{print $2}')

    if [[ "$packages_to_purge" ]]; then
        HARDN_STATUS "info" "Found the following packages with leftover configuration files to purge:"
        echo "$packages_to_purge"
       
        if command -v whiptail >/dev/null; then
            whiptail --title "Packages to Purge" --msgbox "The following packages have leftover configuration files that will be purged:\n\n$packages_to_purge" 15 70
        fi

        for pkg in $packages_to_purge; do
            HARDN_STATUS "error" "Purging $pkg..."
            if apt-get purge -y "$pkg"; then
                HARDN_STATUS "pass" "Successfully purged $pkg."
            else
                HARDN_STATUS "error" "Failed to purge $pkg. Trying dpkg --purge..."
                if dpkg --purge "$pkg"; then
                    HARDN_STATUS "pass" "Successfully purged $pkg with dpkg."
                else
                    HARDN_STATUS "error" "Failed to purge $pkg with dpkg as well."
                fi
            fi
        done
        whiptail --infobox "Purged configuration files for removed packages." 7 70
    else
        HARDN_STATUS "pass" "No old/removed packages with leftover configuration files found to purge."
        whiptail --infobox "No leftover package configurations to purge." 7 70
    fi
   
    HARDN_STATUS "error" "Running apt-get autoremove and clean to free up space..."
    apt-get autoremove -y
    apt-get clean
    whiptail --infobox "Apt cache cleaned." 7 70
}
### Let userdecide DNS, but place recommendaiton. ADD TO /DOCS
enable_nameservers() {
    HARDN_STATUS "error" "Checking and configuring DNS nameservers (Quad9 primary, Google secondary)..."
    local resolv_conf quad9_ns google_ns nameserver_count configured_persistently changes_made
	resolv_conf="/etc/resolv.conf"
    quad9_ns="9.9.9.9"
    google_ns="1.1.1.1"
    nameserver_count=0
    configured_persistently=false
    changes_made=false

    if [[ -f "$resolv_conf" ]]; then
        nameserver_count=$(grep -E "^\s*nameserver\s+" "$resolv_conf" | grep -Ev "127\.0\.0\.1|::1" | awk '{print $2}' | sort -u | wc -l)
    fi

    HARDN_STATUS "info" "Found $nameserver_count non-localhost nameserver(s) in $resolv_conf."

    # Always attempt to set Quad9 as primary and Google as secondary
    # Check for systemd-resolved
    if systemctl is-active --quiet systemd-resolved && \
       [[ -L "$resolv_conf" ]] && \
       (readlink "$resolv_conf" | grep -qE "systemd/resolve/(stub-resolv.conf|resolv.conf)"); then
        
        HARDN_STATUS "info" "systemd-resolved is active and manages $resolv_conf."
        local resolved_conf_systemd temp_resolved_conf
		resolved_conf_systemd="/etc/systemd/resolved.conf"
        temp_resolved_conf=$(mktemp)

        if [[ ! -f "$resolved_conf_systemd" ]]; then
            HARDN_STATUS "info" "Creating $resolved_conf_systemd as it does not exist."
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
            HARDN_STATUS "pass" "Updated $resolved_conf_systemd. Restarting systemd-resolved..."
            if systemctl restart systemd-resolved; then
                HARDN_STATUS "pass" "systemd-resolved restarted successfully."
                configured_persistently=true
                changes_made=true
            else
                HARDN_STATUS "error" "Failed to restart systemd-resolved. Manual check required."
            fi
        else
            HARDN_STATUS "info" "No effective changes to $resolved_conf_systemd were needed."
        fi
        rm -f "$temp_resolved_conf"
    fi

    # If not using systemd-resolved, try to set directly in /etc/resolv.conf
    if [[ "$configured_persistently" = false ]]; then
        HARDN_STATUS "info" "Attempting direct modification of $resolv_conf."
        if [[ -f "$resolv_conf" ]] && [[ -w "$resolv_conf" ]]; then
            # Remove existing Quad9/Google entries and add them at the top
            grep -vE "^\s*nameserver\s+($quad9_ns|$google_ns)" "$resolv_conf" > "${resolv_conf}.tmp"
            {
                echo "nameserver $quad9_ns"
                echo "nameserver $google_ns"
                cat "${resolv_conf}.tmp"
            } > "$resolv_conf"
            rm -f "${resolv_conf}.tmp"
            HARDN_STATUS "pass" "Set Quad9 as primary and Google as secondary in $resolv_conf."
            HARDN_STATUS "warning" "Warning: Direct changes to $resolv_conf might be overwritten by network management tools."
            changes_made=true
        else
            HARDN_STATUS "error" "Could not modify $resolv_conf (file not found or not writable)."
        fi
    fi

    if [[ "$changes_made" = true ]]; then
        whiptail --infobox "DNS configured: Quad9 primary, Google secondary." 7 70
    else
        whiptail --infobox "DNS configuration checked. No changes made or needed." 8 70
    fi
}

enable_process_accounting_and_sysstat() {
    HARDN_STATUS "error" "Enabling process accounting (acct) and system statistics (sysstat)..."
    local changed_acct changed_sysstat
	changed_acct=false
    changed_sysstat=false

    # Enable Process Accounting (acct/psacct)
    HARDN_STATUS "info" "Checking and installing acct (process accounting)..."
    if ! dpkg -s acct >/dev/null 2>&1 && ! dpkg -s psacct >/dev/null 2>&1; then
        whiptail --infobox "Installing acct (process accounting)..." 7 60
        if apt-get install -y acct; then
            HARDN_STATUS "pass" "acct installed successfully."
            changed_acct=true
        else
            HARDN_STATUS "error" "Failed to install acct. Please check manually."
        fi
    else
        HARDN_STATUS "info" "acct/psacct is already installed."
    fi

    if dpkg -s acct >/dev/null 2>&1 || dpkg -s psacct >/dev/null 2>&1; then
        if ! systemctl is-active --quiet acct && ! systemctl is-active --quiet psacct; then
            HARDN_STATUS "info" "Attempting to enable and start acct/psacct service..."
            systemctl enable --now acct 2>/dev/null || systemctl enable --now psacct 2>/dev/null
            HARDN_STATUS "pass" "acct/psacct service enabled and started."
            changed_acct=true
        else
            HARDN_STATUS "pass" "acct/psacct service is already active."
        fi
    fi

    # Enable Sysstat
    HARDN_STATUS "info" "Checking and installing sysstat..."
    if ! dpkg -s sysstat >/dev/null 2>&1; then
        whiptail --infobox "Installing sysstat..." 7 60
        if apt-get install -y sysstat; then
            HARDN_STATUS "pass" "sysstat installed successfully."
            changed_sysstat=true
        else
            HARDN_STATUS "error" "Failed to install sysstat. Please check manually."
        fi
    else
        HARDN_STATUS "info" "sysstat is already installed."
    fi

    if dpkg -s sysstat >/dev/null 2>&1; then
        local sysstat_conf
		sysstat_conf="/etc/default/sysstat"
        if [[ -f "$sysstat_conf" ]]; then
            if ! grep -qE '^\s*ENABLED="true"' "$sysstat_conf"; then
                HARDN_STATUS "info" "Enabling sysstat data collection in $sysstat_conf..."
                sed -i 's/^\s*ENABLED="false"/ENABLED="true"/' "$sysstat_conf"
          
                if ! grep -qE '^\s*ENABLED=' "$sysstat_conf"; then
                    echo 'ENABLED="true"' >> "$sysstat_conf"
                fi
                changed_sysstat=true
                HARDN_STATUS "pass" "sysstat data collection enabled."
            else
                HARDN_STATUS "pass" "sysstat data collection is already enabled in $sysstat_conf."
            fi
        else
            # Fallback for systems where config might be /etc/sysstat/sysstat (RHEL based, but we are Debian focused)
            # For Debian, /etc/default/sysstat is standard.
            HARDN_STATUS "warning" "sysstat configuration file $sysstat_conf not found. Manual check might be needed."
        fi

        if ! systemctl is-active --quiet sysstat; then
            HARDN_STATUS "info" "Attempting to enable and start sysstat service..."
            if systemctl enable --now sysstat; then
                HARDN_STATUS "pass" "sysstat service enabled and started."
                changed_sysstat=true
            else
                HARDN_STATUS "error" "Failed to enable/start sysstat service."
            fi
        else
            HARDN_STATUS "pass" "sysstat service is already active."
        fi
    fi

    if [[ "$changed_acct" = true || "$changed_sysstat" = true ]]; then
        HARDN_STATUS "pass" "Process accounting (acct) and sysstat configured successfully."
    else
        HARDN_STATUS "pass" "Process accounting (acct) and sysstat already configured or no changes needed."
    fi
}

# Central logging
setup_central_logging() {
    HARDN_STATUS "error" "Setting up central logging for security tools..."

    # Check and install rsyslog and logrotate if necessary
    local logging_packages="rsyslog logrotate"
    HARDN_STATUS "info" "Checking and installing logging packages ($logging_packages)..."
    # shellcheck disable=SC2086
    if ! dpkg -s $logging_packages >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        if apt-get update >/dev/null 2>&1 && apt-get install -y $logging_packages >/dev/null 2>&1; then
            HARDN_STATUS "pass" "Logging packages installed successfully."
        else
            HARDN_STATUS "error" "Error: Failed to install logging packages. Skipping central logging configuration."
            return 1 # Exit this section if packages fail to install
        fi
    else
        HARDN_STATUS "pass" "Logging packages are already installed."
    fi


    # Create necessary directories
    # ADD ALL DIR's fo monitoring
    HARDN_STATUS "info" "Creating log directories and files..."
    mkdir -p /usr/local/var/log/suricata
    # Note: /var/log/suricata is often created by the suricata package itself
    touch /usr/local/var/log/suricata/hardn-xdr.log
    chmod 640 /usr/local/var/log/suricata/hardn-xdr.log
    chown root:adm /usr/local/var/log/suricata/hardn-xdr.log
    HARDN_STATUS "pass" "Log directory /usr/local/var/log/suricata created and permissions set."


    # Create rsyslog configuration for centralized logging
    HARDN_STATUS "info" "Creating rsyslog configuration file /etc/rsyslog.d/30-hardn-xdr.conf..."
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

# Stop processing these messages after they are sent to the central log
& stop
EOF
    chmod 644 /etc/rsyslog.d/30-hardn-xdr.conf
    HARDN_STATUS "pass" "Rsyslog configuration created/updated."


    # Create logrotate configuration for the central log
    HARDN_STATUS "info" "Creating logrotate configuration file /etc/logrotate.d/hardn-xdr..."
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
    HARDN_STATUS "pass" "Logrotate configuration created/updated."



    # Restart rsyslog to apply changes
    HARDN_STATUS "info" "Restarting rsyslog service to apply configuration changes..."
    if systemctl restart rsyslog; then
        HARDN_STATUS "pass" "Rsyslog service restarted successfully."
    else
        HARDN_STATUS "error" "Failed to restart rsyslog service. Manual check required."
    fi

    # Create a symlink in /var/log for easier access
    HARDN_STATUS "info" "Creating symlink /var/log/hardn-xdr.log..."
    ln -sf /usr/local/var/log/suricata/hardn-xdr.log /var/log/hardn-xdr.log
    HARDN_STATUS "pass" "Symlink created at /var/log/hardn-xdr.log."


    HARDN_STATUS "pass" "Central logging setup complete. All security logs will be collected in /usr/local/var/log/suricata/hardn-xdr.log"
}

disable_service_if_active() {
    local service_name
    service_name="$1"
    if systemctl is-active --quiet "$service_name"; then
        HARDN_STATUS "error" "Disabling active service: $service_name..."
        systemctl disable --now "$service_name" || HARDN_STATUS "warning" "Failed to disable service: $service_name (may not be installed or already disabled)."
    elif systemctl list-unit-files --type=service | grep -qw "^$service_name.service"; then
        HARDN_STATUS "error" "Service $service_name is not active, ensuring it is disabled..."
        systemctl disable "$service_name" || HARDN_STATUS "warning" "Failed to disable service: $service_name (may not be installed or already disabled)."
    else
        HARDN_STATUS "info" "Service $service_name not found or not installed. Skipping."
    fi
}

remove_unnecessary_services() {
    HARDN_STATUS "pass" "Disabling unnecessary services..."
    
    disable_service_if_active avahi-daemon
    disable_service_if_active cups
    disable_service_if_active rpcbind
    disable_service_if_active nfs-server
    disable_service_if_active smbd
    disable_service_if_active snmpd
    disable_service_if_active apache2
    disable_service_if_active mysql
    disable_service_if_active bind9


    packages_to_remove="telnet vsftpd proftpd tftpd postfix exim4"
    for pkg in $packages_to_remove; do
        if dpkg -s "$pkg" >/dev/null 2>&1; then
            HARDN_STATUS "error" "Removing package: $pkg..."
            apt remove -y "$pkg"
        else
            HARDN_STATUS "info" "Package $pkg not installed. Skipping removal."
        fi
    done

    HARDN_STATUS "pass" "Unnecessary services checked and disabled/removed where applicable."
}

pen_test() {
    HARDN_STATUS "error" "Running penetration tests..."
    local lynis_path="/usr/bin/lynis"
    local manual_install_dir=""
    local current_dir
    current_dir=$(pwd)

    # Ensure installed
    if ! dpkg -s lynis >/dev/null 2>&1; then
        HARDN_STATUS "info" "Lynis not found. Attempting to install via apt-get..."
        if apt-get update && apt install -y lynis; then
            HARDN_STATUS "pass" "Lynis installed successfully via apt-get."
        else
            HARDN_STATUS "error" "Failed to install Lynis via apt-get. Attempting manual installation..."
            
            # Manual installation using wget
            cd /tmp || { HARDN_STATUS "error" "Error: Cannot access /tmp directory."; return 1; }
            if wget https://downloads.cisofy.com/lynis/lynis-latest.tar.gz && \
               tar -xzf lynis-latest.tar.gz; then
                # Find the extracted directory
                manual_install_dir=$(find /tmp -maxdepth 1 -type d -name "lynis*" | head -n 1)
                if [ -n "$manual_install_dir" ] && [ -d "$manual_install_dir" ]; then
                    HARDN_STATUS "pass" "Lynis downloaded and extracted to $manual_install_dir successfully."
                    lynis_path="$manual_install_dir/lynis"
                    if [ ! -x "$lynis_path" ]; then
                        chmod +x "$lynis_path"
                    fi
                else
                    HARDN_STATUS "error" "Failed to locate extracted Lynis directory. Cannot proceed with penetration tests."
                    cd "$current_dir" || true
                    return 1
                fi
            else
                HARDN_STATUS "error" "Failed to download or extract Lynis. Cannot proceed with penetration tests."
                cd "$current_dir" || true
                return 1
            fi
        fi
    else
        HARDN_STATUS "pass" "Lynis is already installed."
    fi

    # Run the Lynis audit
    HARDN_STATUS "info" "Running Lynis audit..."
    if [ -x "$lynis_path" ]; then
        if "$lynis_path" audit system --pentest --quick 2>/dev/null; then
            HARDN_STATUS "pass" "Lynis audit completed successfully."
        else
            HARDN_STATUS "error" "Lynis audit failed. Please check the output for details."
            # Don't return error, continue 
        fi
    else
        HARDN_STATUS "error" "Error: Lynis executable not found at $lynis_path or not executable."
        HARDN_STATUS "error" "Skipping Lynis audit."
    fi

    # Return to original directory if we changed
    if [ -n "$manual_install_dir" ]; then
        cd "$current_dir" || true
    fi

    HARDN_STATUS "pass" "Penetration tests completed!"
}

### Add whiptail status bar
cleanup(){
    HARDN_STATUS "error" "Cleaning up temporary files..."
    apt autoremove -y >/dev/null 2>&1
    apt clean >/dev/null 2>&1
    apt update -y >/dev/null 2>&1
    HARDN_STATUS "pass" "Cleanup completed!"

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

    HARDN_STATUS "pass" "\nHARDN-XDR installation completed, Please reboot your System."
}

main
