#!/bin/bash

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
    apt-get install -y yara python3-yara libyara-dev

    # Create directories for YARA rules
    mkdir -p /etc/yara/rules
}

# Function to download YARA rules from GitHub
download_yara_rules() {
    # Create a temporary directory for cloning rules
    local temp_dir
    temp_dir=$(mktemp -d -t yara-rules-XXXXXXXX)

    HARDN_STATUS "info" "Cloning YARA rules from GitHub to ${temp_dir}..."

    # Clone the repository with YARA rules
    if git clone --depth 1 https://github.com/Yara-Rules/rules.git "${temp_dir}"; then
        HARDN_STATUS "pass" "YARA rules cloned successfully."

        # Copy .yar files to the rules directory
        HARDN_STATUS "info" "Copying .yar rules to /etc/yara/rules/..."
        find "${temp_dir}" -type f -name "*.yar" -exec cp {} /etc/yara/rules/ \;

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
    HARDN_STATUS "warning" "Downloading some basic rules directly..."

    # Download some basic YARA rules directly
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Eicar.yar -o /etc/yara/rules/MALW_Eicar.yar
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Ransomware.yar -o /etc/yara/rules/MALW_Ransomware.yar
    curl -s https://raw.githubusercontent.com/Yara-Rules/rules/master/malware/MALW_Backdoor.yar -o /etc/yara/rules/MALW_Backdoor.yar

    if [ "$(ls -A /etc/yara/rules/)" ]; then
        HARDN_STATUS "pass" "Basic YARA rules downloaded successfully."
        return 0
    else
        HARDN_STATUS "error" "Failed to download YARA rules."
        return 1
    fi
}

# Function to create integration script with AIDE
create_aide_integration() {
    cat > /usr/local/bin/aide-with-yara.sh << 'EOF'
#!/bin/bash
# Run AIDE check
aide --check

# Run YARA scan on important directories
yara -r /etc/yara/rules/* /bin /sbin /usr/bin /usr/sbin /etc /var/www 2>/dev/null

exit 0
EOF
    chmod +x /usr/local/bin/aide-with-yara.sh
    HARDN_STATUS "info" "Created /usr/local/bin/aide-with-yara.sh to run YARA after AIDE."
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

    # Install YARA
    install_yara

    # Download YARA rules
    if ! download_yara_rules; then
        download_basic_rules
    fi

    # Create integration scripts
    create_aide_integration
    integrate_with_suricata
    create_rkhunter_integration
    create_periodic_scan_script

    HARDN_STATUS "pass" "YARA rules setup and integration scripts completed."
    return 0
}

# Execute the module function when sourced from hardn-main.sh
yara_module
