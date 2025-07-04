#!/bin/bash

# Install and configure Suricata IDS/IPS
# This script is designed to be sourced as a module from hardn-main.sh

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

        temp_config=$(mktemp)

        # Process the configuration file line by line
        local in_file="/etc/suricata/suricata.yaml"
        local out_file="$temp_config"

        process_config_file() {
            # Usage: process_config_file input_file output_file
            local input_file="$1"
            local output_file="$2"

            while IFS= read -r line; do
                if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*interface: ]]; then
                    echo "  - interface: $interface" >> "$output_file"
                elif [[ "$line" =~ ^[[:space:]]*HOME_NET:[[:space:]] ]]; then
                    echo "    HOME_NET: \"$ip_addr\"" >> "$output_file"
                else
                    echo "$line" >> "$output_file"
                fi
            done < "$input_file"

            return 0
        }

        process_config_file "$in_file" "$out_file"

        # Replace the original file with our modified version
        # & Set proper permissions
        if mv "$temp_config" "/etc/suricata/suricata.yaml"; then
            chmod 644 /etc/suricata/suricata.yaml
            HARDN_STATUS "pass" "Successfully updated Suricata configuration."
            return 0
        else
            HARDN_STATUS "error" "Failed to update Suricata configuration."
            return 1
        fi
}

manage_suricata_service() {
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

        manage_suricata_service || handle_service_failure
        verify_suricata_installation
        create_update_cron_job

        return $?
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

        # Case Statement to allocate CPU cores based on the cpu_tier var
        case "$cpu_tier" in
            "many") # <-- "many" tier (more than 8 cores)
                mgmt_cpus='[ "0" ]'
                recv_cpus='[ "1", "2" ]'
                # Use remaining cores for workers (3 to n-1) worker cpu arrary
                worker_cpus='[ '
                for ((i=3; i<cpu_count; i++)); do
                    worker_cpus+=\""$i\""
                    if [ "$i" -lt $((cpu_count-1)) ]; then
                        worker_cpus+=", "
                    fi
                done
                worker_cpus+=' ]'
                HARDN_STATUS "info" "Using optimized CPU allocation for ${cpu_count} cores"
            ;;
            "several") # <-- "several" tier (5 to 8 cores)
                mgmt_cpus='[ "0" ]'
                recv_cpus='[ "1" ]'
                worker_cpus='[ "2", "3", "4" ]'
                HARDN_STATUS "info" "Using standard CPU allocation for ${cpu_count} cores"
            ;;
            *) # <-- Default tier (4 or fewer cores
                worker_cpus='[ "all" ]'
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


# call main
suricata_module
