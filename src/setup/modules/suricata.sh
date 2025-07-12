#!/bin/bash

# Suricata IDS/IPS installation and configuration module
# Designed to be sourced by hardn-main.sh

# Main module function - entry point
hardn_suricata_module() {
    HARDN_STATUS "info" "Checking and configuring Suricata..."

    # Check if Suricata is installed
    if ! command -v suricata &> /dev/null; then
        hardn_suricata_install
        hardn_suricata_verify_installation
    else
        HARDN_STATUS "info" "Suricata is already installed."
    fi

    HARDN_STATUS "info" "Updating Suricata rules..."

    if command -v suricata-update &> /dev/null; then
        hardn_suricata_update_rules || hardn_suricata_download_rules_manually
    else
        hardn_suricata_install_update

        if command -v suricata-update &> /dev/null; then
            hardn_suricata_update_rules || hardn_suricata_download_rules_manually
        else
            HARDN_STATUS "error" "Failed to install suricata-update."
            hardn_suricata_download_rules_manually
        fi
    fi

    # Update the Suricata config
    local interface ip_addr
    interface=$(hardn_suricata_get_interface)
    ip_addr=$(hardn_suricata_get_ip_address)

    if [[ -n "$interface" && -n "$ip_addr" ]]; then
        hardn_suricata_update_config "$interface" "$ip_addr"
    else
        HARDN_STATUS "error" "Failed to get interface or IP address."
        return 1
    fi

    hardn_suricata_configure_firewall
    hardn_suricata_tune_performance

    if ! hardn_suricata_manage_service; then
        HARDN_STATUS "warning" "Initial service start failed, trying fallback configurations..."
        hardn_suricata_handle_service_failure
    fi

    hardn_suricata_verify_installation
    hardn_suricata_create_update_cron_job

    return $?
}

hardn_suricata_install() {
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

        if pip3 install suricata-update --break-system-packages && command -v suricata-update &> /dev/null; then
            HARDN_STATUS "pass" "Installed suricata-update via pip."
        else
            HARDN_STATUS "error" "Failed to install suricata-update."
            return 1
        fi
    fi

    # After installing Suricata, update and validate the config
    hardn_suricata_configure

    return 0
}

hardn_suricata_configure() {
    hardn_suricata_update_config
    hardn_suricata_validate_yaml
}

hardn_suricata_install_update() {
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

hardn_suricata_update_rules() {
    # Add timeout to prevent hanging
    timeout 300 suricata-update
    local result=$?

    case $result in
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

hardn_suricata_download_rules_manually() {
    HARDN_STATUS "warning" "Failed to update Suricata rules. Will try alternative method."

    # Create rules directory
    mkdir -p /var/lib/suricata/rules/

    # Download ET Open ruleset
    local temp_file
    temp_file=$(mktemp)

    if curl -L --connect-timeout 30 --max-time 300 \
        https://rules.emergingthreats.net/open/suricata-6.0.0/emerging.rules.tar.gz \
        -o "$temp_file"; then

        # Verify file size is reasonable (not empty or too small)
        local file_size
        file_size=$(stat -c%s "$temp_file")

        if [[ "$file_size" -lt 1000 ]]; then
            HARDN_STATUS "error" "Downloaded rules file is too small (${file_size} bytes). Possible download error."
        else
            tar -xzf "$temp_file" -C /var/lib/suricata/rules/
            HARDN_STATUS "pass" "Manually downloaded and installed Emerging Threats ruleset."
            rm -f "$temp_file"
            return 0
        fi
    else
        HARDN_STATUS "error" "Failed to download rules manually. Continuing without rules update."
    fi

    rm -f "$temp_file"
    return 1
}

hardn_suricata_update_config() {
    local config_file="/etc/suricata/suricata.yaml"
    HARDN_STATUS "info" "Updating Suricata configuration..."

    # Create backup of original config
    cp "$config_file" "${config_file}.bak"

    # Fix HOME_NET definition
    sed -i '/HOME_NET:/c\    HOME_NET: "[10.0.2.15/24]"' "$config_file"

    # Fix interface definitions in af-packet section
    sed -i 's/^enp0s: 3$/    cluster-id: 99/' "$config_file"
    sed -i 's/^enp0s3$//' "$config_file"
    sed -i '/interface: enp0s3/{n;s/^enp0s3$//}' "$config_file"
    sed -i '/af-packet:/,/pcap:/ s/^  - interface: default$/  - interface: default/' "$config_file"
    sed -i '/pcap:/,/pcap-file:/ s/^  - interface: default$/  - interface: default/' "$config_file"

    # Update network interface to match the system's primary interface
    local primary_interface
    primary_interface=$(ip route | grep default | awk '{print $5}' | head -n 1)
    if [[ -n "$primary_interface" ]]; then
        HARDN_STATUS "info" "Setting primary interface to $primary_interface"
        sed -i "s/interface: enp0s3/interface: $primary_interface/g" "$config_file"
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

hardn_suricata_validate_yaml() {
    local config_file="/etc/suricata/suricata.yaml"
    local temp_log
    temp_log=$(mktemp)
    local validation_status=0

    HARDN_STATUS "info" "Performing comprehensive YAML validation..."

    # Check for common YAML syntax errors
    suricata -T -c "$config_file" > "$temp_log" 2>&1
    validation_status=$?

    case $validation_status in
        0)
            HARDN_STATUS "pass" "Suricata configuration is valid"
            rm -f "$temp_log"
            return 0
            ;;
        *)
            HARDN_STATUS "warn" "Found issues in Suricata configuration"
            ;;
    esac

    # Extract error information using a single read loop
    local error_line=""
    local error_msg=""
    while IFS= read -r line; do
        [[ "$line" =~ at\ line\ ([0-9]+) ]] && error_line="${BASH_REMATCH[1]}" && continue
        [[ "$line" =~ Failed\ to\ parse ]] && error_msg="$line" && continue
    done < "$temp_log"

    # If no error line found, we can't fix it automatically
    if [[ -z "$error_line" ]]; then
        HARDN_STATUS "error" "Could not determine error location in configuration"
        rm -f "$temp_log"
        return 1
    fi

    HARDN_STATUS "info" "Error detected at line $error_line: $error_msg"
    HARDN_STATUS "info" "Attempting to fix YAML syntax..."

    # Show context around the error
    sed -n "$((error_line-2)),$((error_line+2))p" "$config_file"

    # Get problematic line content
    local line_content
    line_content=$(sed -n "${error_line}p" "$config_file")
    HARDN_STATUS "info" "Original line: $line_content"

    # Apply fixes in sequence, checking after each one
    fix_yaml_and_validate() {
        # 1. Fix missing colons (common YAML syntax error)
        sed -i "${error_line}s/\([a-zA-Z0-9_-]*\)[[:space:]]*\([^:]\)/\1: \2/" "$config_file"
        suricata -T -c "$config_file" > /dev/null 2>&1 && return 0

        # 2. Fix indentation issues
        sed -i "${error_line}s/^[[:space:]]*\([a-zA-Z]\)/  \1/" "$config_file"
        suricata -T -c "$config_file" > /dev/null 2>&1 && return 0

        # 3. Handle unbalanced quotes - simpler approach
        line_content=$(sed -n "${error_line}p" "$config_file")

        # Count quotes in the line
        quote_count=$(grep -o '"' <<< "$line_content" | wc -l)

        # If odd number of quotes, fix by commenting out the line
        if (( quote_count % 2 != 0 )); then
            HARDN_STATUS "info" "Line $error_line has unbalanced quotes, commenting it out"
            sed -i "${error_line}s/^/#QUOTE_ERROR: /" "$config_file"
        fi

        # Check if the fix worked
        if suricata -T -c "$config_file" > /dev/null 2>&1; then
            return 0
        fi

        # 4. Last resort - comment out the line completely
        HARDN_STATUS "info" "Trying last resort fix - commenting out the line"
        line_content=$(sed -n "${error_line}p" "$config_file")
        printf -v escaped_line "%q" "$line_content"
        sed -i "${error_line}c\\    # DISABLED DUE TO SYNTAX ERROR: ${escaped_line}" "$config_file"

        # Check if the fix worked
        if suricata -T -c "$config_file" > /dev/null 2>&1; then
            return 0
        fi

        # If we get here, all fixes failed
        return 1
    }

    # Try to fix the YAML and validate
    if fix_yaml_and_validate; then
        HARDN_STATUS "pass" "YAML syntax fixed successfully"
        validation_status=0
    else
        HARDN_STATUS "error" "Could not automatically fix YAML syntax"
        HARDN_STATUS "info" "Manual intervention required at line $error_line"
        validation_status=1
    fi

    rm -f "$temp_log"
    return $validation_status
}

hardn_suricata_configure_firewall() {
    HARDN_STATUS "info" "Configuring firewall for Suricata..."

    # Check if UFW is installed and enabled
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
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

hardn_suricata_tune_performance() {
    HARDN_STATUS "info" "Tuning Suricata performance..."
    # Dynamic resource detection to adapt to the host system
    local mem_total
    mem_total=$(free -m | grep Mem | awk '{print $2}')
    local cpu_count
    cpu_count=$(nproc)

    HARDN_STATUS "info" "Detected system resources: ${mem_total}MB RAM, ${cpu_count} CPU cores"

    # Tiered configuration: scales with available resources
    local mem_tier
    if (( mem_total > 8000 )); then
        mem_tier="high"
    elif (( mem_total > 4000 )); then
        mem_tier="medium"
    elif (( mem_total > 2000 )); then
        mem_tier="low"
    else
        mem_tier="minimal"
    fi

    # Set config vals based on memory tier
    local ring_size block_size max_pending_packets
    case "$mem_tier" in
        "high")
            ring_size=65536
            block_size=65536
            max_pending_packets=4096
            ;;
        "medium")
            ring_size=32768
            block_size=32768
            max_pending_packets=2048
            ;;
        "low")
            ring_size=16384
            block_size=32768
            max_pending_packets=1024
            ;;
        *)
            ring_size=2048
            block_size=32768
            max_pending_packets=1024
            ;;
    esac

    HARDN_STATUS "info" "Using ${mem_tier} memory profile: ring_size=${ring_size}, block_size=${block_size}"

    local cpu_tier
    if (( cpu_count > 8 )); then
        cpu_tier="many"
    elif (( cpu_count > 4 )); then
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
                worker_cpus+=""$i""
                if (( i < max_workers+1 )) && (( i < cpu_count-1 )); then
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
            if (( cpu_count >= 3 )); then
                mgmt_cpus='[ "0" ]'
                recv_cpus='[ "1" ]'
                worker_cpus='[ "2" ]'
            else
                # For 1-2 core systems, disable CPU affinity completely
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

hardn_suricata_create_update_cron_job() {
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

hardn_suricata_verify_installation() {
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

    if [[ -n "$version" ]]; then
        : "Suricata version: $version"
    else
        : "Could not determine Suricata version."
    fi

    HARDN_STATUS "info" "$_"

    # Check configuration file
    if [[ -f "/etc/suricata/suricata.yaml" ]]; then
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
    if [[ -d "/var/lib/suricata/rules" || -d "/etc/suricata/rules" ]]; then
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
hardn_suricata_get_interface() {
    local interface
    interface=$(ip route | grep default | awk '{print $5}' | head -n 1)

    if [[ -z "$interface" ]]; then
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

hardn_suricata_get_ip_address() {
    local interface
    interface=$(hardn_suricata_get_interface)

    local ip_addr
    ip_addr=$(ip -4 addr show "$interface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}(/\d+)?' | head -n 1)

    # If that fails, try to get any non-loopback IPv4 address
    if [[ -z "$ip_addr" ]]; then
        ip_addr=$(ip -4 addr show | grep -v "127.0.0.1" | grep -oP '(?<=inet\s)\d+(\.\d+){3}(/\d+)?' | head -n 1)
    fi

    # If still no IP address, then use a fallback
    if [[ -z "$ip_addr" ]]; then
        HARDN_STATUS "warning" "Could not determine IP address. Using '192.168.1.0/24' as fallback."
        ip_addr="192.168.1.0/24"
    else
        HARDN_STATUS "info" "Detected IP address: $ip_addr"
    fi

    echo "$ip_addr"
}

hardn_suricata_manage_service() {
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

hardn_suricata_handle_service_failure() {
    # Placeholder for handling service failure
    # Implement specific actions here if needed
    HARDN_STATUS "warning" "Service failure handling not implemented."
}

hardn_suricata_debug_config() {
    local config_file="/etc/suricata/suricata.yaml"
    local performance_file="/etc/suricata/suricata-performance.yaml"
    local temp_log

    HARDN_STATUS "info" "Debugging Suricata configuration..."

    # Check if config files exist
    if [[ ! -f "$config_file" ]]; then
        HARDN_STATUS "error" "Main configuration file not found: $config_file"
        return 1
    fi

    # Use process substitution instead of temp file
    if ! suricata -T -c "$config_file" 2> >(tee /tmp/suricata_config_check.log >/dev/null); then
        HARDN_STATUS "error" "Syntax error in Suricata configuration:"

        # Extract error line with one command
        local error_line
        error_line=$(grep -oP "at line \K[0-9]+" /tmp/suricata_config_check.log 2>/dev/null | head -1)

        if [[ -n "$error_line" ]]; then
            HARDN_STATUS "info" "Error detected at line $error_line, showing context:"
            # Show context around error
            sed -n "$((error_line-2)),$((error_line+2))p" "$config_file"

            HARDN_STATUS "info" "Attempting to fix YAML syntax issues..."

            # Fix missing colons (common YAML syntax error)
            sed -i "${error_line}s/\([a-zA-Z0-9_-]*\)[[:space:]]*\([^:]\)/\1: \2/" "$config_file"

            # Fix unbalanced quotes - properly escaped
            sed -i "${error_line}s/"\([^"]*\)/"\1/g" "$config_file"
            sed -i "${error_line}s/\([^"]*\)"/\1"/g" "$config_file"
        fi

        # Fix performance file if it exists
        if [[ -f "$performance_file" ]]; then
            HARDN_STATUS "info" "Checking performance configuration file..."

            # Batch all sed operations into one command with multiple expressions
            sed -i -e 's/\[\s*"/[ "/g' \
                   -e 's/"\s*\]/" ]/g' \
                   -e 's/",\s*"/", "/g' \
                   -e 's/^threading:/threading:/g' \
                   -e 's/^af-packet:/af-packet:/g' \
                   -e 's/^detect:/detect:/g' "$performance_file"

            HARDN_STATUS "info" "Fixed potential YAML syntax issues in performance file"
        fi

        # Create minimal working configuration
        HARDN_STATUS "info" "Creating minimal working configuration..."
        cat > "$performance_file" << 'EOF'
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

        # Update include directive
        sed -i '/include: suricata-performance.yaml/d' "$config_file"
        echo "include: suricata-performance.yaml" >> "$config_file"

        # Test configuration again
        if suricata -T -c "$config_file" &>/dev/null; then
            HARDN_STATUS "pass" "Configuration fixed successfully"
            rm -f /tmp/suricata_config_check.log
            return 0
        else
            HARDN_STATUS "error" "Could not fix configuration automatically. Manual intervention required."
            cat /tmp/suricata_config_check.log
            rm -f /tmp/suricata_config_check.log
            return 1
        fi
    else
        HARDN_STATUS "pass" "Suricata configuration syntax is valid"
        rm -f /tmp/suricata_config_check.log
        return 0
    fi
}
