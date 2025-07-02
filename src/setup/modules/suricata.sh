#!/bin/bash

# Install and configure Suricata IDS/IPS
# This script is designed to be sourced as a module from hardn-main.sh

# Function to install Suricata and dependencies
install_suricata() {
        HARDN_STATUS "info" "Installing Suricata and dependencies..."

        # Try to install both packages at once
        if apt-get install -y suricata python3-suricata-update; then
            HARDN_STATUS "pass" "Installed Suricata and suricata-update successfully."
            return 0
        fi

        if ! apt-get install -y suricata python3-pip; then
            HARDN_STATUS "error" "Failed to install required packages."
            return 1
        fi

        HARDN_STATUS "warning" "python3-suricata-update not found in repositories, using pip instead..."

        if pip3 install suricata-update --break-system-packages; then
            if command -v suricata-update &> /dev/null; then
                HARDN_STATUS "pass" "Installed suricata-update via pip successfully."
                return 0
            fi
        fi

        HARDN_STATUS "error" "Failed to install suricata-update."
        return 1
}

# Function to install suricata-update tool
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

# Function to update Suricata rules using suricata-update
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
            rm -f /tmp/emerging.rules.tar.gz
            : "Manually downloaded and installed Emerging Threats ruleset."
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

# Function to update Suricata configuration
update_suricata_config() {
        local interface="$1"
        local ip_addr="$2"

        # Clean up interface and IP address values to remove any embedded log messages
        interface=$(echo "$interface" | grep -o '[a-zA-Z0-9]\+$')
        ip_addr=$(echo "$ip_addr" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+/[0-9]\+$')

        if [ ! -f "/etc/suricata/suricata.yaml" ]; then
            HARDN_STATUS "error" "Suricata configuration file not found."
            return 1
        fi

        HARDN_STATUS "info" "Updating Suricata configuration..."
        HARDN_STATUS "info" "  - Setting interface to: $interface"
        HARDN_STATUS "info" "  - Setting HOME_NET to: $ip_addr"

        # Backup original config
        cp /etc/suricata/suricata.yaml /etc/suricata/suricata.yaml.bak

        # Create a temporary file for modifications
        temp_config=$(mktemp)

        # Process the configuration file line by line
        local in_file="/etc/suricata/suricata.yaml"
        local out_file="$temp_config"

        process_config_file() {
            # Usage: process_config_file input_file output_file
            local input_file="$1"
            local output_file="$2"

            while IFS= read -r line; do
                # Check for interface line
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*interface: ]]; then
                    echo "  - interface: $interface" >> "$output_file"
                # Check for HOME_NET line
                elif [[ "$line" =~ ^[[:space:]]*HOME_NET:[[:space:]] ]]; then
                    echo "    HOME_NET: \"$ip_addr\"" >> "$output_file"
                # Keep all other lines unchanged
                else
                    echo "$line" >> "$output_file"
                fi
            done < "$input_file"

            return 0
        }

        # Process the configuration file
        process_config_file "$in_file" "$out_file"

        # Replace the original file with our modified version
        if mv "$temp_config" "/etc/suricata/suricata.yaml"; then
            # Set proper permissions
            chmod 644 /etc/suricata/suricata.yaml
            HARDN_STATUS "pass" "Successfully updated Suricata configuration."
            return 0
        else
            HARDN_STATUS "error" "Failed to update Suricata configuration."
            return 1
        fi
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
            systemctl enable suricata.service || true systemctl start suricata.service

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
            systemctl daemon-reload; systemctl enable "$service_name" || true ; systemctl start "$service_name"

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

        # Display version information
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

        # Check rules directory
        if [ -d "/var/lib/suricata/rules" ] || [ -d "/etc/suricata/rules" ]; then
            : "Suricata rules directory found."
        else
            : "Suricata rules directory not found."
        fi

        # Display rules directory status
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

# Utility function to determine the primary network interface
get_interface() {
        local interface
        interface=$(ip route | grep default | awk '{print $5}' | head -n 1)

        if [ -z "$interface" ]; then
            interface=$(ip -o link show | grep -v "lo:" | awk -F': ' '{print $2}' | head -n 1)
        fi

        # Determine interface status using case statement
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

# Utility function to get the IP address of the primary interface
get_ip_address() {
        local interface
        interface=$(get_interface)

        local ip_addr
        ip_addr=$(ip -4 addr show "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}(/\d+)?' | head -n 1)

        # If that fails, try to get any non-loopback IPv4 address
        if [ -z "$ip_addr" ]; then
            ip_addr=$(ip -4 addr show | grep -v "127.0.0.1" | grep -oP '(?<=inet\s)\d+(\.\d+){3}(/\d+)?' | head -n 1)
        fi

        # If we still don't have an IP address, use a fallback
        if [ -z "$ip_addr" ]; then
            HARDN_STATUS "warning" "Could not determine IP address. Using '192.168.1.0/24' as fallback."
            ip_addr="192.168.1.0/24"
        else
            HARDN_STATUS "info" "Detected IP address: $ip_addr"
        fi

        echo "$ip_addr"
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

        manage_suricata_service || handle_service_failure
        verify_suricata_installation
        create_update_cron_job

        return $?
}

# call the module function
suricata_module
