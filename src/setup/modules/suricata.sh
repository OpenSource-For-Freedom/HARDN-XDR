#!/bin/bash

# Root/sudo detection
if [ "$EUID" -ne 0 ]; then
    if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
        whiptail --title "Root Privileges Required" --msgbox "This script must be run as root. Please re-run with sudo." 10 60
    else
        echo "[ERROR] This script must be run as root. Please re-run with sudo."
    fi
    return 1
fi
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

# Install and configure Suricata IDS/IPS
# This script is designed to be sourced as a module from hardn-main.sh



install_suricata() {
    local install_mode="basic"
    local rules_selected="etopen"

    if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
        # Install mode selection
        install_mode=$(whiptail --title "Suricata Install Mode" --radiolist "Choose install mode:" 12 60 2 \
            "basic" "Minimal config, default rules only" ON \
            "advanced" "Full config, custom rules, performance tuning" OFF 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 ]]; then
            HARDN_STATUS "info" "User cancelled Suricata installation."
            return 1
        fi

        # Ruleset selection (advanced)
        if [[ "$install_mode" == "advanced" ]]; then
            rules_selected=$(whiptail --title "Suricata Ruleset Selection" --checklist "Select rulesets to enable:" 14 70 3 \
                "etopen" "Emerging Threats Open (recommended)" ON \
                "etpro" "Emerging Threats Pro (requires subscription)" OFF \
                "custom" "Custom rules (upload or specify path)" OFF 3>&1 1>&2 2>&3)
            if [[ $? -ne 0 ]]; then
                HARDN_STATUS "info" "User cancelled ruleset selection."
                return 1
            fi
            rules_selected=$(echo $rules_selected | tr -d '"')
        fi
    else
        HARDN_STATUS "info" "Running in non-interactive mode, using basic Suricata installation"
    fi

    HARDN_STATUS "info" "Installing Suricata and dependencies..."

    # Try to install both packages at once
    if apt-get install -y suricata python3-suricata-update; then
        HARDN_STATUS "pass" "Installed Suricata and suricata-update successfully."
    else
        if ! apt-get install -y suricata python3-pip; then
            HARDN_STATUS "error" "Failed to install required packages."
            return 1
        fi

        HARDN_STATUS "warning" "python3-suricata-update not found in repositories, using pip instead..."

        if pip3 install suricata-update --break-system-packages; then
            if ! command -v suricata-update &> /dev/null; then
                HARDN_STATUS "error" "Failed to install suricata-update."
                return 1
            fi
        else
            HARDN_STATUS "error" "Failed to install suricata-update."
            return 1
        fi
    fi

    # After installing Suricata, update and validate the config
    local selected_interface=""
    if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
        # Gather available interfaces
        local interfaces_list
        interfaces_list=$(ip -o link show | awk -F': ' '{print $2}' | grep -v "lo" | tr '\n' ' ')
        selected_interface=$(whiptail --title "Select Network Interface" --menu "Choose the network interface for Suricata to monitor:" 15 60 4 $interfaces_list 3>&1 1>&2 2>&3)
        if [[ $? -ne 0 || -z "$selected_interface" ]]; then
            HARDN_STATUS "info" "User cancelled interface selection."
            return 1
        fi
    else
        selected_interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
        [ -z "$selected_interface" ] && selected_interface="eth0"
        HARDN_STATUS "info" "Running in non-interactive mode, auto-detected interface: $selected_interface"
    fi

    if [[ "$install_mode" == "advanced" ]]; then
        update_suricata_config "$selected_interface"
        validate_suricata_yaml
    fi

    # Ruleset logic
    if [[ "$install_mode" == "advanced" ]]; then
        if [[ "$rules_selected" == *"etopen"* ]]; then
            update_rules_with_suricata_update || download_rules_manually
        fi
        if [[ "$rules_selected" == *"etpro"* ]]; then
            HARDN_STATUS "warning" "ET Pro selected. Please ensure you have a valid subscription and configure suricata-update accordingly."
        fi
        if [[ "$rules_selected" == *"custom"* ]]; then
            HARDN_STATUS "info" "Custom rules selected. Please upload or specify your custom rules path."
            # You can add logic here to prompt for a path or handle uploads
        fi
    else
        # Basic mode: only ET Open rules
        update_rules_with_suricata_update || download_rules_manually
    fi

    return 0
}

install_suricata_update() {
        HARDN_STATUS "warning" "suricata-update command not found. Installing it now..."

        if apt-get install -y python3-suricata-update; then
            HARDN_STATUS "pass" "Successfully installed suricata-update via apt."
            return 0
        fi

        HARDN_STATUS "warning" "python3-suricata-update not found in repositories, trying alternative method..."

        if ! apt-get install -y python3-pip; then
            HARDN_STATUS "error" "Failed to install python3-pip."
            return 1
        fi

        if pip3 install suricata-update --break-system-packages; then
            HARDN_STATUS "pass" "Successfully installed suricata-update via pip."
            return 0
        fi

        HARDN_STATUS "error" "Failed to install suricata-update via pip."
        return 1
}

update_rules_with_suricata_update() {
    # Add timeout to prevent hanging
    timeout 300 suricata-update

    case $? in
        0)
            : "Suricata rules updated successfully."
        ;;
        124)
            : "Suricata update timed out after 5 minutes."
        ;;
        *)
            : "Failed to update Suricata rules."
        ;;
    esac

    # Set status message and return value based on the result
    if [ "$_" = "Suricata rules updated successfully." ]; then
        HARDN_STATUS "pass" "$_"
        return 0
    else
        HARDN_STATUS "warning" "$_"
        return 1
    fi
}

download_rules_manually() {
    HARDN_STATUS "warning" "Warning: Failed to update Suricata rules. Will try alternative method."

    # Create rules directory
    mkdir -p /var/lib/suricata/rules/

    # Download ET Open ruleset
    curl -L --connect-timeout 30 --max-time 300 https://rules.emergingthreats.net/open/suricata-6.0.0/emerging.rules.tar.gz -o /tmp/emerging.rules.tar.gz

    case $? in
        0)
            # Verify file size is reasonable (not empty or too small)
            local file_size
            file_size=$(stat -c%s "/tmp/emerging.rules.tar.gz")
            if [ "$file_size" -lt 1000 ]; then
                : "Downloaded rules file is too small (${file_size} bytes). Possible download error."
            else
                tar -xzf /tmp/emerging.rules.tar.gz -C /var/lib/suricata/rules/
                rm -f /tmp/emerging.rules.tar.gz
                : "Manually downloaded and installed Emerging Threats ruleset."
            fi
        ;;
        *)
            : "Failed to download rules manually. Continuing without rules update."
        ;;
    esac

    # Set status message and return value based on the result
    if [ "$_" = "Manually downloaded and installed Emerging Threats ruleset." ]; then
        HARDN_STATUS "pass" "$_"
        return 0
    else
        HARDN_STATUS "error" "$_"
        return 1
    fi
}

# Changes made to fix the issue with the YAML configuration

update_suricata_config() {
    local config_file="/etc/suricata/suricata.yaml"
    local selected_interface="$1"
    if command -v whiptail >/dev/null 2>&1; then
        if ! whiptail --title "Suricata Config Update" --yesno "This will update and overwrite Suricata configuration. Backup will be created. Proceed?" 10 60; then
            HARDN_STATUS "info" "User cancelled Suricata config update."
            return 1
        fi
    fi

    HARDN_STATUS "info" "Updating Suricata configuration..."

    # Create backup of original config
    cp "$config_file" "${config_file}.bak"

    # Fix HOME_NET definition - replace malformed multi-line string with proper array format
    sed -i '/HOME_NET:/c\    HOME_NET: "[10.0.2.15/24]"' "$config_file"

    # Fix interface definitions in af-packet section
    sed -i 's/^enp0s: 3$/    cluster-id: 99/' "$config_file"
    sed -i 's/^enp0s3$//' "$config_file"

    # Fix malformed interface definitions throughout the file
    # This pattern looks for lines that contain just "enp0s3" after an interface definition
    sed -i '/interface: enp0s3/{n;s/^enp0s3$//}' "$config_file"

    # Ensure proper indentation for af-packet configuration
    sed -i '/af-packet:/,/pcap:/ s/^  - interface: default$/  - interface: default/' "$config_file"

    # Fix pcap interface definitions
    sed -i '/pcap:/,/pcap-file:/ s/^  - interface: default$/  - interface: default/' "$config_file"

    # Update network interface to match the selected interface
    if [ -n "$selected_interface" ]; then
        HARDN_STATUS "info" "Setting Suricata interface to $selected_interface"
        sed -i "s/interface: enp0s3/interface: $selected_interface/g" "$config_file"
    fi

    # Validate the configuration after changes
    if ! suricata -T -c "$config_file" > /dev/null 2>&1; then
        HARDN_STATUS "error" "Failed to validate Suricata configuration after updates"
        HARDN_STATUS "info" "Restoring backup configuration"
        mv "${config_file}.bak" "$config_file"
        return 1
    else
        HARDN_STATUS "pass" "Suricata configuration updated successfully"
        rm -f "${config_file}.bak"
    fi

    return 0
}

# Changes made to fix the issue with the YAML configuration
# This function is performing a more comprehensive YAML validation and fixes
validate_suricata_yaml() {
    local config_file="/etc/suricata/suricata.yaml"
    HARDN_STATUS "info" "Performing comprehensive YAML validation..."

    # Check for common YAML syntax errors
    if ! suricata -T -c "$config_file" > /tmp/suricata_validation.log 2>&1; then
        HARDN_STATUS "warn" "Found issues in Suricata configuration"

        # Extract error information
        local error_line
        error_line=$(grep -oP "at line \K[0-9]+" /tmp/suricata_validation.log | head -1)

        local error_msg
        error_msg=$(grep "Failed to parse" /tmp/suricata_validation.log)

        if [ -n "$error_line" ]; then
            HARDN_STATUS "info" "Error detected at line $error_line: $error_msg"
            HARDN_STATUS "info" "Attempting to fix YAML syntax..."

            # Show context around the error
            sed -n "$((error_line-2)),$((error_line+2))p" "$config_file"

            # Fix missing colons (common YAML syntax error)
            sed -i "${error_line}s/\([a-zA-Z0-9_-]*\)[[:space:]]*\([^:]\)/\1: \2/" "$config_file"

            # Fix unbalanced quotes
            sed -i "${error_line}s/\"\([^\"]\)/\\\"\1/g" "$config_file"

            # Fix indentation issues
            sed -i "${error_line}s/^[[:space:]]*\([a-zA-Z]\)/  \1/" "$config_file"

            # Validate again after fixes
            if suricata -T -c "$config_file" > /dev/null 2>&1; then
                HARDN_STATUS "pass" "YAML syntax fixed successfully"
            else
                HARDN_STATUS "error" "Could not automatically fix YAML syntax"
                HARDN_STATUS "info" "Manual intervention required at line $error_line"
                return 1
            fi
        fi
    else
        HARDN_STATUS "pass" "Suricata configuration is valid"
    fi

    return 0
}


manage_suricata_service() {
    if command -v whiptail >/dev/null 2>&1; then
        if ! whiptail --title "Suricata Service" --yesno "This will enable and (re)start the Suricata service. Proceed?" 10 60; then
            HARDN_STATUS "info" "User cancelled Suricata service start/restart."
            return 1
        fi
    fi

    HARDN_STATUS "info" "Enabling and starting Suricata service..."

    systemctl enable suricata.service || true

    if systemctl is-active --quiet suricata.service; then
        HARDN_STATUS "info" "Reloading Suricata service..."
        systemctl reload-or-restart suricata.service
    else
        HARDN_STATUS "info" "Starting Suricata service..."
        systemctl start suricata.service
    fi

    case $? in
        0)
            HARDN_STATUS "pass" "Suricata service started successfully."
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

debug_suricata_config() {
    local config_file="/etc/suricata/suricata.yaml"
    local performance_file="/etc/suricata/suricata-performance.yaml"

    HARDN_STATUS "info" "Debugging Suricata configuration..."

    # Check if config files exist
    if [ ! -f "$config_file" ]; then
        HARDN_STATUS "error" "Main configuration file not found: $config_file"
        return 1
    fi

    # Check for syntax errors in main config
    if ! suricata -T -c "$config_file" 2>/tmp/suricata_config_check.log; then
        HARDN_STATUS "error" "Syntax error in Suricata configuration:"
        cat /tmp/suricata_config_check.log

        # Extract line number from error message if available
        local error_line
        error_line=$(grep -oP "at line \K[0-9]+" /tmp/suricata_config_check.log | head -1)

        if [ -n "$error_line" ]; then
            HARDN_STATUS "info" "Error detected at line $error_line, showing context:"
            # Show the problematic line and surrounding context
            sed -n "$((error_line-2)),$((error_line+2))p" "$config_file"

            # Fix specific YAML syntax issues
            HARDN_STATUS "info" "Attempting to fix YAML syntax issues..."

            # Fix missing colons (common YAML syntax error)
            sed -i "${error_line}s/\([a-zA-Z0-9_-]*\)[[:space:]]*\([^:]\)/\1: \2/" "$config_file"

            # Fix unbalanced quotes
            sed -i "${error_line}s/\"\([^\"]\)/\\\"\1/g" "$config_file"
            #sed -i "${error_line}s/\([^"]\)"/\1\"/g" "$config_file"
            sed -i "${error_line}s/"\([^"]\)/\"\1/g" "$config_file"
        fi

        # Try to fix common issues in the performance file
        if [ -f "$performance_file" ]; then
            HARDN_STATUS "info" "Checking performance configuration file..."

            # Fix potential issues with quotes in CPU arrays
            sed -i 's/\[\s*"/[ "/g' "$performance_file"
            sed -i 's/"\s*\]/" ]/g' "$performance_file"
            sed -i 's/",\s*"/", "/g' "$performance_file"

            # Fix potential YAML indentation issues
            sed -i 's/^[[:space:]]*\([a-zA-Z]\)/  \1/g' "$performance_file"

            # Ensure proper YAML formatting for key sections
            sed -i 's/^threading:/threading:/g' "$performance_file"
            sed -i 's/^af-packet:/af-packet:/g' "$performance_file"
            sed -i 's/^detect:/detect:/g' "$performance_file"

            HARDN_STATUS "info" "Fixed potential YAML syntax issues in performance file"
        fi

        # Create a minimal working configuration as fallback
        HARDN_STATUS "info" "Creating minimal working configuration..."
        cat > "$performance_file" << EOF
# Minimal Suricata performance configuration
# Generated by HARDN-XDR debug function

af-packet:
  - interface: default
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes

threading:
  set-cpu-affinity: no

detect:
  profile: medium
EOF

        # Remove include line if it exists and add it back properly formatted
        sed -i '/include: suricata-performance.yaml/d' "$config_file"
        echo "include: suricata-performance.yaml" >> "$config_file"

        # Test the configuration again
        if suricata -T -c "$config_file" 2>/tmp/suricata_config_check.log; then
            HARDN_STATUS "pass" "Configuration fixed successfully"
            return 0
        else
            HARDN_STATUS "error" "Could not fix configuration automatically. Manual intervention required."
            cat /tmp/suricata_config_check.log
            return 1
        fi
    else
        HARDN_STATUS "pass" "Suricata configuration syntax is valid"
        return 0
    fi
}


# handle_service_failure
handle_service_failure() {
    HARDN_STATUS "warning" "Failed to restart suricata.service. Checking if it's installed correctly..."

    # Check for different service files that might be used
    local service_files=(
        "/lib/systemd/system/suricata.service"
        "/etc/systemd/system/suricata.service"
        "/lib/systemd/system/suricata-ids.service"
        "/etc/systemd/system/suricata-ids.service"
    )

    local service_found=false
    local service_name="suricata.service"
    local file=""

    for ((i=0; i<${#service_files[@]}; i++)); do
        file="${service_files[i]}"

        if [ -f "$file" ]; then
            service_found=true
            service_name=$(basename "$file")
            HARDN_STATUS "info" "Found Suricata service file: $service_name"
            break
        fi
    done

    if ! $service_found; then
        HARDN_STATUS "warning" "Suricata service file not found. Attempting to reinstall..."
        apt-get purge -y suricata; apt-get install -y suricata; systemctl daemon-reload
        # Try to start service again
        systemctl enable suricata.service || true
        systemctl start suricata.service

        case $? in
            0)
                HARDN_STATUS "pass" "Suricata service started after reinstallation."
                return 0
                ;;
            *)
                HARDN_STATUS "error" "Failed to start Suricata service after reinstall."
                # Try fallback configuration
                create_fallback_performance_config
                if systemctl restart suricata.service; then
                    HARDN_STATUS "pass" "Suricata service started with fallback configuration after reinstall."
                    return 0
                fi
                return 1
                ;;
        esac
    else
        systemctl daemon-reload
        systemctl enable "$service_name" || true

        # Try with fallback configuration first
        HARDN_STATUS "info" "Trying fallback configuration without CPU affinity..."
        create_fallback_performance_config
        if systemctl restart "$service_name"; then
            HARDN_STATUS "pass" "Suricata service started with fallback configuration."
            return 0
        else
            HARDN_STATUS "error" "Service failed to start even with fallback configuration."
            # Check logs for more information
            HARDN_STATUS "info" "Last 10 lines of Suricata logs:"
            journalctl -u "$service_name" -n 10 || true

            # Debug and try to fix configuration
            HARDN_STATUS "warning" "Attempting to debug and fix configuration..."
            if debug_suricata_config; then
                if systemctl restart "$service_name"; then
                    HARDN_STATUS "pass" "Suricata service started after configuration debugging."
                    return 0
                fi
            fi

            # Try one more approach - disable performance tuning completely
            HARDN_STATUS "warning" "Trying minimal configuration..."
            sed -i '/include: suricata-performance.yaml/d' /etc/suricata/suricata.yaml
            if systemctl restart "$service_name"; then
                HARDN_STATUS "pass" "Suricata service started with minimal configuration."
                return 0
            else
                HARDN_STATUS "error" "All configuration attempts failed. Manual intervention required."
                return 1
            fi
        fi
    fi
}

create_update_cron_job() {
    cat > /etc/cron.daily/update-suricata-rules << 'EOF'
#!/bin/bash
# Daily update of Suricata rules
# Added by HARDN-XDR

# Log file for updates
LOG_FILE="/var/log/suricata/rule-updates.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "$(date): Starting Suricata rule update" >> "$LOG_FILE"

if command -v suricata-update &> /dev/null; then
    echo "Running suricata-update..." >> "$LOG_FILE"
    suricata-update >> "$LOG_FILE" 2>&1

    # Check if update was successful
    if [ $? -eq 0 ]; then
        echo "Rule update successful, restarting Suricata..." >> "$LOG_FILE"
        systemctl restart suricata.service >> "$LOG_FILE" 2>&1
    else
        echo "Rule update failed. Check logs for details." >> "$LOG_FILE"
    fi
else
    echo "suricata-update not found. Please install it." >> "$LOG_FILE"
fi

echo "$(date): Finished Suricata rule update" >> "$LOG_FILE"
return 0
EOF
    chmod +x /etc/cron.daily/update-suricata-rules
    HARDN_STATUS "pass" "Created daily cron job to update Suricata rules."
}

verify_suricata_installation() {
        HARDN_STATUS "info" "Verifying Suricata installation..."
        local verification_status=0

        # Check if binary exists
        if command -v suricata &> /dev/null; then
            : "Suricata binary found."
        else
            HARDN_STATUS "error" "Suricata binary not found after installation."
            return 1
        fi

        # Check version
        local version
        version=$(suricata --build-info 2>/dev/null | grep "Version" | awk '{print $2}')

        if [ -n "$version" ]; then
            : "Suricata version: $version"
        else
            : "Could not determine Suricata version."
        fi

        HARDN_STATUS "info" "$_"

        # Check configuration file
        if [ -f "/etc/suricata/suricata.yaml" ]; then
            : "Suricata configuration file found."
        else
            : "Suricata configuration file not found."
            verification_status=1
        fi

        # Display configuration status
        case "$_" in
            "Suricata configuration file found.")
                HARDN_STATUS "pass" "$_"
            ;;
            *)
                HARDN_STATUS "error" "$_"
            ;;
        esac

        # Check the rules dir
        if [ -d "/var/lib/suricata/rules" ] || [ -d "/etc/suricata/rules" ]; then
            : "Suricata rules directory found."
        else
            : "Suricata rules directory not found."
        fi

        # Display the rules dir status
        case "$_" in
            "Suricata rules directory found.")
                HARDN_STATUS "pass" "$_"
            ;;
            *)
                HARDN_STATUS "warning" "$_"
            ;;
        esac

        return $verification_status
}

# Determine the primary network interface
get_interface() {
        local interface
        interface=$(ip route | grep default | awk '{print $5}' | head -n 1)

        if [ -z "$interface" ]; then
            interface=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | head -n 1)
        fi

        # use case to enumerate the interface status
        case "$interface" in
            "")
                : "Could not determine primary network interface. Using 'eth0' as fallback."
                interface="eth0"
                HARDN_STATUS "warning" "$_"
            ;;

            *)
                : "Detected primary network interface: $interface"
                HARDN_STATUS "info" "$_"
            ;;
        esac

        echo "$interface"
}

get_ip_address() {
        local interface
        interface=$(get_interface)

        local ip_addr
        ip_addr=$(ip -4 addr show "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}(/\d+)?' | head -n 1)

        # If that fails, try to get any non-loopback IPv4 address
        if [ -z "$ip_addr" ]; then
            ip_addr=$(ip -4 addr show | grep -v "127.0.0.1" | grep -oP '(?<=inet\s)\d+(\.\d+){3}(/\d+)?' | head -n 1)
        fi

        # If still no IP address, then use a fallback
        if [ -z "$ip_addr" ]; then
            HARDN_STATUS "warning" "Could not determine IP address. Using '192.168.1.0/24' as fallback."
            ip_addr="192.168.1.0/24"
        else
            HARDN_STATUS "info" "Detected IP address: $ip_addr"
        fi

        echo "$ip_addr"
}

configure_firewall() {
        HARDN_STATUS "info" "Configuring firewall for Suricata..."

        # Check if UFW is installed and enabled
        if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
            # Allow traffic to be monitored by Suricata
            # This doesn't open ports but ensures traffic flows through Suricata
            HARDN_STATUS "info" "UFW detected, ensuring traffic can be monitored by Suricata"
            return 0
        fi

        # Check if firewalld is installed and running
        if command -v firewall-cmd &> /dev/null && firewall-cmd --state | grep -q "running"; then
            HARDN_STATUS "info" "firewalld detected, no specific configuration needed for Suricata monitoring"
            return 0
        fi

        HARDN_STATUS "info" "No active firewall detected, Suricata should be able to monitor traffic"
        return 0
}

# Source the module
suricata_module() {
        HARDN_STATUS "info" "Checking and configuring Suricata..."

        # Check if Suricata is installed
        if ! command -v suricata &> /dev/null; then
            install_suricata
            verify_suricata_installation
        else
            HARDN_STATUS "info" "Suricata is already installed."
        fi

        HARDN_STATUS "info" "Updating Suricata rules..."

        if command -v suricata-update &> /dev/null; then
            update_rules_with_suricata_update || download_rules_manually
        else
            install_suricata_update

            if command -v suricata-update &> /dev/null; then
                update_rules_with_suricata_update || download_rules_manually
            else
                HARDN_STATUS "error" "Error: Failed to install suricata-update."
                download_rules_manually
            fi
        fi

        # Update the Suricata config
        local interface
        interface=$(get_interface)

        local ip_addr
        ip_addr=$(get_ip_address)

        if [ -n "$interface" ] && [ -n "$ip_addr" ]; then
            update_suricata_config "$interface" "$ip_addr"
        else
            HARDN_STATUS "error" "Error: Failed to get interface or IP address."
            return 1
        fi

        configure_firewall
        tune_suricata_performance
        #manage_suricata_service || handle_service_failure

        if ! manage_suricata_service; then
            HARDN_STATUS "warning" "Initial service start failed, trying fallback configurations..."
            handle_service_failure
        fi



        verify_suricata_installation
        create_update_cron_job
        
        # Return success status
        return 0
}

tune_suricata_performance() {
        HARDN_STATUS "info" "Tuning Suricata performance..."
        # Dynamic resource detection to adapt to the host system
        local mem_total
        mem_total=$(free -m | grep Mem | awk '{print $2}')
        local cpu_count
        cpu_count=$(nproc)

        HARDN_STATUS "info" "Detected system resources: ${mem_total}MB RAM, ${cpu_count} CPU cores"

        # Tiered configuration: scales with available resources
        local mem_tier
        if [ "$mem_total" -gt 8000 ]; then
            mem_tier="high"
        elif [ "$mem_total" -gt 4000 ]; then
            mem_tier="medium"
        elif [ "$mem_total" -gt 2000 ]; then
            mem_tier="low"
        else
            mem_tier="minimal"
        fi

        # Set config vals based on memory tier
        # Bash trick with the `:` command (a no-op that sets `$_` to its argument)
        case "$mem_tier" in
            "high")
                : "65536 65536 4096"
            ;;
            "medium")
                : "32768 32768 2048"
            ;;
            "low")
                : "16384 32768 1024"
            ;;
            *)
                : "2048 32768 1024"
            ;;
        esac

        # Parse the values from $_
        read -r ring_size block_size max_pending_packets <<< "$_"

        HARDN_STATUS "info" "Using ${mem_tier} memory profile: ring_size=${ring_size}, block_size=${block_size}"

        local cpu_tier
        if [ "$cpu_count" -gt 8 ]; then
            cpu_tier="many"
        elif [ "$cpu_count" -gt 4 ]; then
            cpu_tier="several"
        else
            cpu_tier="few"
        fi

    local mgmt_cpus='[ "0" ]' # for mgmt tasks
    local recv_cpus='[ "1" ]' # packet receive tasks
    local worker_cpus         # For packet processing workers

    case "$cpu_tier" in
    "many") # <-- "many" tier (more than 8 cores)
        mgmt_cpus='[ "0" ]'
        recv_cpus='[ "1" ]'
        # Use a subset of remaining cores for workers (avoid using all cores)
        worker_cpus='[ '
        # Use at most 6 cores for workers, even on systems with many cores
        local max_workers=$((cpu_count > 8 ? 6 : cpu_count-2))
        for ((i=2; i<max_workers+2 && i<cpu_count; i++)); do
            worker_cpus+=\""$i\""
            if [ "$i" -lt $((max_workers+1)) ] && [ "$i" -lt $((cpu_count-1)) ]; then
           # if [ "$i" -lt $((max_workers+1)) ] && [ "$i" -lt $((cpu_count-1)) ]; then
                worker_cpus+=", "
            fi
        done
        worker_cpus+=' ]'
        HARDN_STATUS "info" "Using optimized CPU allocation for ${cpu_count} cores"
    ;;
    "several") # <-- "several" tier (5 to 8 cores)
        mgmt_cpus='[ "0" ]'
        recv_cpus='[ "1" ]'
        # Use only 3 cores for workers on medium systems
        worker_cpus='[ "2", "3" ]'
        HARDN_STATUS "info" "Using standard CPU allocation for ${cpu_count} cores"
    ;;
    *) # <-- Default tier (4 or fewer cores)
        # For systems with few cores, use a very conservative approach
        if [ "$cpu_count" -ge 3 ]; then
            mgmt_cpus='[ "0" ]'
            recv_cpus='[ "1" ]'
            worker_cpus='[ "2" ]'
        else
            # For 1-2 core systems, disable CPU affinity completely
            #threading_config="threading:\n  set-cpu-affinity: no"
            mgmt_cpus='[ "all" ]'
            recv_cpus='[ "all" ]'
            worker_cpus='[ "all" ]'
        fi
        HARDN_STATUS "info" "Using basic CPU allocation for ${cpu_count} cores"
    ;;
esac


        # Create performance tuning file
        local tuning_file="/etc/suricata/suricata-performance.yaml"

        cat > "$tuning_file" << EOF
# Suricata performance tuning
# Generated by HARDN-XDR
# System: ${mem_total}MB RAM (${mem_tier} profile), ${cpu_count} CPU cores (${cpu_tier} profile)

af-packet:
  - interface: default
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
    use-mmap: yes
    mmap-locked: yes
    tpacket-v3: yes
    ring-size: ${ring_size}
    block-size: ${block_size}
    max-pending-packets: ${max_pending_packets}

threading:
  set-cpu-affinity: yes
  cpu-affinity:
    - management-cpu-set:
        cpu: ${mgmt_cpus}
    - receive-cpu-set:
        cpu: ${recv_cpus}
    - worker-cpu-set:
        cpu: ${worker_cpus}
        mode: "exclusive"
        prio:
          default: "high"

detect:
  profile: medium
  custom-values:
    toclient-groups: 3
    toserver-groups: 25
  sgh-mpm-context: auto
  inspection-recursion-limit: 3000

# Memory limits tuned for ${mem_total}MB system
app-layer:
  protocols:
    http:
      request-body-limit: $((mem_total/20))mb
      response-body-limit: $((mem_total/20))mb
    smtp:
      raw-extraction-size-limit: $((mem_total/40))mb
      header-value-depth: 2000
EOF

        # Include the performance file in main config if not already included
        if ! grep -q "include: suricata-performance.yaml" /etc/suricata/suricata.yaml; then
            echo "include: suricata-performance.yaml" >> /etc/suricata/suricata.yaml
            HARDN_STATUS "pass" "Added performance tuning configuration optimized for ${mem_tier} memory and ${cpu_tier} CPU profiles"
        else
            HARDN_STATUS "info" "Performance tuning already configured, updating with system-specific values"
            HARDN_STATUS "pass" "Updated performance tuning for ${mem_tier} memory and ${cpu_tier} CPU profiles"
        fi

        return 0
}

create_fallback_performance_config() {
    HARDN_STATUS "warning" "Creating fallback performance configuration without CPU affinity..."
    local tuning_file="/etc/suricata/suricata-performance.yaml"

    cat > "$tuning_file" << EOF
# Suricata fallback performance tuning
# Generated by HARDN-XDR - FALLBACK CONFIGURATION

af-packet:
  - interface: default
    cluster-id: 99
    cluster-type: cluster_flow
    defrag: yes
    use-mmap: yes
    mmap-locked: yes
    tpacket-v3: yes
    ring-size: 32768
    block-size: 32768
    max-pending-packets: 1024

threading:
  set-cpu-affinity: no

detect:
  profile: medium
EOF

    return 0
}


# call main
suricata_module




