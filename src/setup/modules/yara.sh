#!/bin/bash
# Source common functions with fallback for development/CI environments
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}
#!/bin/bash

# shellcheck disable=SC1091

# Install and configure YARA for malware detection
# This script is designed to be sourced as a module from hardn-main.sh

# Refactored version:
#--------------------
# 1.Organizes the code into logical functions
# 2.Avoids nested functions
# 3.Uses proper return values for error handling
# 4.Follows a clear flow of execution
# 5.Includes a main yara_module() function that orchestrates the entire process
# 6.Includes proper comments and documentation
# 7.Maintains the same functionality as the original script
# 8.Is designed to be sourced as a module from hardn-main.sh



# Function to install YARA and dependencies
install_yara() {
    HARDN_STATUS "info" "Installing YARA and related packages..."
    
    # Use safe package installation
    if ! safe_package_install yara python3-yara libyara-dev; then
        HARDN_STATUS "warning" "Failed to install some YARA packages (normal in minimal containers)"
        # Check if any YARA tools were installed
        if ! command -v yara >/dev/null 2>&1; then
            HARDN_STATUS "warning" "YARA not available, skipping YARA configuration"
            return 1
        fi
    fi

    # Create directories for YARA rules
    mkdir -p /etc/yara/rules
    exit 0
}


# Function to download YARA rules from GitHub
download_yara_rules() {
    # Check if git is available first
    if ! command -v git >/dev/null 2>&1; then
        HARDN_STATUS "warning" "git not available, skipping GitHub rules download"
        return 1
    fi

    # Create a temporary directory for cloning rules
    local temp_dir
    temp_dir=$(mktemp -d -t yara-rules-XXXXXXXX)

    HARDN_STATUS "info" "Cloning YARA rules from GitHub to ${temp_dir}..."

    # Clone the repository with YARA rules
    if git clone --depth 1 https://github.com/Yara-Rules/rules "${temp_dir}" 2>/dev/null; then
        HARDN_STATUS "pass" "YARA rules cloned successfully."

        # Copy .yar files to the rules directory
        HARDN_STATUS "info" "Copying .yar rules to /etc/yara/rules/..."
        find "${temp_dir}" -type f -name "*.yar" -exec cp {} /etc/yara/rules/ \; 2>/dev/null || true

        # Check if any rules were copied
        if [ "$(ls -A /etc/yara/rules/)" ]; then
            HARDN_STATUS "pass" "YARA rules copied successfully."
            local result=0
        else
            HARDN_STATUS "warning" "No rules found in git repository."
            local result=1
        fi
    else
        HARDN_STATUS "error" "Failed to clone YARA rules repository."
        local result=1
    fi

    # Clean up
    HARDN_STATUS "info" "Cleaning up temporary directory ${temp_dir}..."
    rm -rf "${temp_dir}"

    return $result
}

# Function to download basic YARA rules directly
download_basic_rules() {
    # Check if curl is available first
    if ! command -v curl >/dev/null 2>&1; then
        HARDN_STATUS "warning" "curl not available, skipping basic rules download"
        return 1
    fi

    HARDN_STATUS "warning" "Downloading some basic rules directly..."

    # basic YARA rules directly
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Eicar.yar -o /etc/yara/rules/MALW_Eicar.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Ransomware.yar -o /etc/yara/rules/MALW_Ransomware.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Backdoor.yar -o /etc/yara/rules/MALW_Backdoor.yar 2>/dev/null || true

    # Debian specific rules
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_LinuxHelios.yar -o /etc/yara/rules/MALW_LinuxHelios.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Linux_Multiarch.yar -o /etc/yara/rules/MALW_Linux_Multiarch.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_ROOTKIT_Linux.yar -o /etc/yara/rules/MALW_ROOTKIT_Linux.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Mirai_Okiru_ELF.yar -o /etc/yara/rules/MALW_Mirai_Okiru_ELF.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Torte_ELF.yar -o /etc/yara/rules/MALW_Torte_ELF.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Furtim.yar -o /etc/yara/rules/MALW_Furtim.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_LXC_Webshell.yar -o /etc/yara/rules/MALW_LXC_Webshell.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Linux_Xor_Ddos.yar -o /etc/yara/rules/MALW_Linux_Xor_Ddos.yar 2>/dev/null || true

    # Government/FedRAMP/FIPS
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/apt/APT_APT29_Grizzly_Steppe.yar -o /etc/yara/rules/APT_APT29_Grizzly_Steppe.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/apt/APT_Sofacy.yar -o /etc/yara/rules/APT_Sofacy.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/apt/APT_EQUATIONGRP.yar -o /etc/yara/rules/APT_EQUATIONGRP.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/apt/APT_FIN7.yar -o /etc/yara/rules/APT_FIN7.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/apt/APT_HackingTeam.yar -o /etc/yara/rules/APT_HackingTeam.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Credential_Stealer.yar -o /etc/yara/rules/MALW_Credential_Stealer.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Lateral_Movement.yar -o /etc/yara/rules/MALW_Lateral_Movement.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Neo23x0/signature-base/master/yara/apt_apt41.yar -o /etc/yara/rules/apt_apt41.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Neo23x0/signature-base/master/yara/expl_log4j_cve_2021_44228.yar -o /etc/yara/rules/expl_log4j_cve_2021_44228.yar 2>/dev/null || true
    curl -s https://raw.githubusercontent.com/Neo23x0/signature-base/master/yara/gen_crypto_signatures.yar -o /etc/yara/rules/gen_crypto_signatures.yar 2>/dev/null || true

    if [ "$(ls -A /etc/yara/rules/)" ]; then
        HARDN_STATUS "pass" "Basic YARA rules downloaded successfully."
        return 0
    fi
}


# Function to integrate YARA with Suricata
integrate_with_suricata() {
    if [ -f "/etc/suricata/suricata.yaml" ]; then
        if ! grep -q "yara-rules" /etc/suricata/suricata.yaml; then
            echo "
# YARA rules
rule-files:
  - /etc/yara/rules/*.yar" >> /etc/suricata/suricata.yaml
        fi
        HARDN_STATUS "info" "Added YARA rules directory to Suricata config."
    fi
}

# Function to create integration script with RKHunter
create_rkhunter_integration() {
    cat > /usr/local/bin/rkhunter-with-yara.sh << 'EOF'
#!/bin/bash
# Run rkhunter
rkhunter --check --skip-keypress

# Run YARA scan on important directories
yara -r /etc/yara/rules/* /bin /sbin /usr/bin /usr/sbin /etc /var/www 2>/dev/null

exit 0
EOF
    chmod +x /usr/local/bin/rkhunter-with-yara.sh
    HARDN_STATUS "info" "Created /usr/local/bin/rkhunter-with-yara.sh to run YARA after RKHunter."
}

# Function to create script for periodic YARA scans
create_periodic_scan_script() {
    cat > /usr/local/bin/auditd-yara-scan.sh << 'EOF'
#!/bin/bash
# Find files modified in the last 24 hours
find /bin /sbin /usr/bin /usr/sbin /etc /var/www -type f -mtime -1 > /tmp/recent_files.txt

# Run YARA scan on these files
if [ -s /tmp/recent_files.txt ]; then
    yara -r /etc/yara/rules/* -f /tmp/recent_files.txt 2>/dev/null
fi

# Clean up
rm -f /tmp/recent_files.txt
exit 0
EOF
    chmod +x /usr/local/bin/auditd-yara-scan.sh
    HARDN_STATUS "info" "Created /usr/local/bin/auditd-yara-scan.sh for periodic YARA scans on recent changes."
}

# Main module function

yara_module() {
    HARDN_STATUS "info" "Installing and configuring YARA..."

    # Install YARA - exit gracefully if it fails
    if ! install_yara; then
        HARDN_STATUS "warning" "YARA installation failed, skipping YARA configuration"
        return 0
    fi

    # Use basic and github rules by default for comprehensive coverage
    local ruleset_choice="basic github"
    HARDN_STATUS "info" "YARA configured for automated deployment: downloading basic and GitHub rules"

    # Download selected rulesets
    if [[ "$ruleset_choice" == *"github"* ]]; then
        download_yara_rules || true
    fi
    if [[ "$ruleset_choice" == *"basic"* ]]; then
        download_basic_rules || true
    fi

    if [[ "$ruleset_choice" == *"yararoth"* ]]; then
        local roth_temp
        roth_temp=$(mktemp -d -t yararoth-XXXXXXXX)
        if git clone --depth 1 git://github.com/Neo23x0/yararules "$roth_temp" && \
           find "$roth_temp" -type f -name "*.yar" -exec cp {} /etc/yara/rules/ \; && \
           rm -rf "$roth_temp"; then
            HARDN_STATUS "pass" "Florian Roth's yararules downloaded."
        else
            HARDN_STATUS "error" "Failed to download yararules."
        fi
    fi
    if [[ "$ruleset_choice" == *"malwarebazaar"* ]]; then
        if curl -s https://bazaar.abuse.ch/api/v1/yara | grep -E '^rule ' > /etc/yara/rules/malwarebazaar.yar; then
            HARDN_STATUS "pass" "MalwareBazaar YARA rules downloaded."
        else
            HARDN_STATUS "error" "Failed to download MalwareBazaar rules."
        fi
    fi
    if [[ "$ruleset_choice" == *"apt"* ]]; then
        if curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/apt/apt.yar -o /etc/yara/rules/apt.yar; then
            HARDN_STATUS "pass" "APT & targeted attack rules downloaded."
        else
            HARDN_STATUS "error" "Failed to download APT rules."
        fi
    fi
    if [[ "$ruleset_choice" == *"custom"* ]]; then
        # Skip custom URLs for automated deployment
        HARDN_STATUS "info" "Custom YARA rules skipped for automated deployment (can be added manually later)"
    fi

    # Create integration scripts
    create_aide_integration
    integrate_with_suricata
    create_rkhunter_integration
    create_periodic_scan_script

    HARDN_STATUS "pass" "YARA rules setup and integration scripts completed."
    exit 0
}
# Execute the module function when sourced from hardn-main.sh
yara_module

# shellcheck disable=SC2317
return 0 2>/dev/null || hardn_module_exit 0
set -e
