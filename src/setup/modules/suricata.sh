#!/bin/bash

# Install and configure Suricata IDS/IPS
# This script is designed to be sourced as a module from hardn-main.sh

# Code Improvements:
# - Modular design with single-purpose functions
# - Minimized nesting with early returns
# - Used case statements for cleaner flow control
# - Improved error handling and status reporting
# - Better variable scoping and naming
# - Clear execution flow in main function
# - Consistent logging throughout
# - Logical separation between utility and main functions

# Function to install Suricata and dependencies
install_suricata() {
    HARDN_STATUS "info" "Installing Suricata..."
    apt-get install -y suricata

    # Install suricata-update tool using apt instead of pip
    HARDN_STATUS "info" "Installing suricata-update tool..."
    apt-get install -y python3-suricata-update || {
        HARDN_STATUS "warning" "python3-suricata-update not found in repositories, trying alternative method..."
        # Try to install via pip with --break-system-packages flag if needed
        apt-get install -y python3-pip
        pip3 install suricata-update --break-system-packages
    }
}

# Function to install suricata-update tool
install_suricata_update() {
    HARDN_STATUS "warning" "suricata-update command not found. Installing it now..."
    apt-get install -y python3-suricata-update || {
        HARDN_STATUS "warning" "python3-suricata-update not found in repositories, trying alternative method..."
        apt-get install -y python3-pip
        pip3 install suricata-update --break-system-packages
    }
}

# Function to update Suricata rules using suricata-update
update_rules_with_suricata_update() {
    # Add timeout to prevent hanging
    timeout 300 suricata-update

    case $? in
        0)
            HARDN_STATUS "pass" "Suricata rules updated successfully."
            return 0
            ;;
        124)
            HARDN_STATUS "warning" "Suricata update timed out after 5 minutes."
            return 1
            ;;
        *)
            HARDN_STATUS "warning" "Failed to update Suricata rules."
            return 1
            ;;
    esac
}

# Function to manually download and install rules
download_rules_manually() {
    HARDN_STATUS "warning" "Warning: Failed to update Suricata rules. Will try alternative method."

    # Create rules directory if it doesn't exist
    mkdir -p /var/lib/suricata/rules/

    # Download ET Open ruleset
    curl -L --connect-timeout 30 --max-time 300 https://rules.emergingthreats.net/open/suricata-6.0.0/emerging.rules.tar.gz -o /tmp/emerging.rules.tar.gz

    case $? in
        0)
            tar -xzf /tmp/emerging.rules.tar.gz -C /var/lib/suricata/rules/
            HARDN_STATUS "pass" "Manually downloaded and installed Emerging Threats ruleset."
            rm -f /tmp/emerging.rules.tar.gz
            return 0
            ;;
        *)
            HARDN_STATUS "error" "Failed to download rules manually. Continuing without rules update."
            return 1
            ;;
    esac
}

# Function to update Suricata configuration
update_suricata_config() {
    local interface="$1"
    local ip_addr="$2"

    if [ ! -f "/etc/suricata/suricata.yaml" ]; then
        HARDN_STATUS "error" "Suricata configuration file not found."
        return 1
    fi

    HARDN_STATUS "info" "Updating Suricata configuration..."
    HARDN_STATUS "info" "  - Setting interface to: $interface"
    HARDN_STATUS "info" "  - Setting HOME_NET to: $ip_addr"

    # Backup original config
    cp /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak

    # Update interface - more robust pattern matching
    if grep -q "^  - interface:" /etc/suricata/suricata.yaml; then
        sed -i "s/^  - interface: .*$/  - interface: $interface/" /etc/suricata/suricata.yaml
    else
        # If pattern not found, try to add it in the appropriate section
        sed -i "/^af-packet:/a \  - interface: $interface" /etc/suricata/suricata.yaml
    fi

    # Update HOME_NET - more robust pattern matching
    local home_net_ip
    home_net_ip=$(echo "$ip_addr" | cut -d'/' -f1)

    local home_net_cidr
    home_net_cidr=$(echo "$ip_addr" | grep -o '/[0-9]\+' || echo "/24")

    local home_net
    home_net="${home_net_ip}${home_net_cidr}"

    if grep -q "^    HOME_NET:" /etc/suricata/suricata.yaml; then
        sed -i "s/^    HOME_NET: .*$/    HOME_NET: "${home_net}"/" /etc/suricata/suricata.yaml
    else
        # If pattern not found, try to add it in the appropriate section
        sed -i "/^vars:/a \    HOME_NET: "${home_net}"/" /etc/suricata/suricata.yaml
    fi

    return 0
}

# Function to manage Suricata service
manage_suricata_service() {
    HARDN_STATUS "info" "Enabling and starting Suricata service..."

    # Enable service
    systemctl enable suricata.service || true

    # Start/restart service
    systemctl restart suricata.service

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

# Function to handle service failure
handle_service_failure() {
    HARDN_STATUS "warning" "Failed to restart suricata.service. Checking if it's installed correctly..."

    # Check for different service names that might be used
    local service_files=(
        "/lib/systemd/system/suricata.service"
        "/etc/systemd/system/suricata.service"
        "/lib/systemd/system/suricata-ids.service"
        "/etc/systemd/system/suricata-ids.service"
    )

    local service_found=false
    local service_name="suricata.service"

    for file in "${service_files[@]}"; do
        if [ -f "$file" ]; then
            service_found=true
            service_name=$(basename "$file")
            break
        fi
    done

    if ! $service_found; then
        HARDN_STATUS "warning" "Suricata service file not found. Attempting to reinstall..."
        apt-get purge -y suricata
        apt-get install -y suricata
        systemctl daemon-reload

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
                return 1
                ;;
        esac
    else
        HARDN_STATUS "info" "Found service file: $service_name"
        systemctl daemon-reload
        systemctl enable "$service_name" || true
        systemctl start "$service_name"

        case $? in
            0)
                HARDN_STATUS "pass" "Suricata service started using $service_name."
                return 0
                ;;
            *)
                HARDN_STATUS "error" "Service file exists but service failed to start."
                # Check logs for more information
                HARDN_STATUS "info" "Last 10 lines of Suricata logs:"
                journalctl -u "$service_name" -n 10 || true
                return 1
                ;;
        esac
    fi
}

# Function to create update cron job
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
exit 0
EOF
    chmod +x /etc/cron.daily/update-suricata-rules
    HARDN_STATUS "pass" "Created daily cron job to update Suricata rules."
}

# Function to verify Suricata installation
verify_suricata_installation() {
    HARDN_STATUS "info" "Verifying Suricata installation..."

    # Check if binary exists
    if ! command -v suricata &> /dev/null; then
        HARDN_STATUS "error" "Suricata binary not found after installation."
        return 1
    fi

    # Check version
    local version
    version=$(suricata --build-info 2>/dev/null | grep "Version" | awk '{print $2}')

    if [ -n "$version" ]; then
        HARDN_STATUS "info" "Suricata version: $version"
    else
        HARDN_STATUS "warning" "Could not determine Suricata version."
    fi

    # Check configuration
    if [ -f "/etc/suricata/suricata.yaml" ]; then
        HARDN_STATUS "pass" "Suricata configuration file found."
    else
        HARDN_STATUS "error" "Suricata configuration file not found."
        return 1
    fi

    # Check rules directory
    if [ -d "/var/lib/suricata/rules" ] || [ -d "/etc/suricata/rules" ]; then
        HARDN_STATUS "pass" "Suricata rules directory found."
    else
        HARDN_STATUS "warning" "Suricata rules directory not found."
    fi

    return 0
}

# Main module function - this is what gets executed when the module is sourced
suricata_module() {
    HARDN_STATUS "info" "Checking and configuring Suricata..."

    # Check if Suricata is installed
    if ! command -v suricata &> /dev/null; then
        install_suricata
        verify_suricata_installation
    else
        HARDN_STATUS "info" "Suricata is already installed."
    fi

    # Update Suricata rules
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

    # Update Suricata configuration
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

    # Manage Suricata service
    manage_suricata_service || handle_service_failure

    # Verify installation
    verify_suricata_installation

    # Create daily update cron job
    create_update_cron_job

    return $?
}

# Execute the module function
suricata_module
