#!/bin/bash

# DNS configuration module for HARDN-XDR
# This script is meant to be sourced by hardn-main.sh

hardn_select_dns_provider() {
    local -A dns_providers=(
        ["Quad9"]="9.9.9.9 149.112.112.112"
        ["Cloudflare"]="1.1.1.1 1.0.0.1"
        ["Google"]="8.8.8.8 8.8.4.4"
        ["OpenDNS"]="208.67.222.222 208.67.220.220"
        ["CleanBrowsing"]="185.228.168.9 185.228.169.9"
        ["UncensoredDNS"]="91.239.100.100 89.233.43.71"
    )

    local selected_provider
    selected_provider=$(whiptail --title "DNS Provider Selection" --menu \
        "Select a DNS provider for enhanced security and privacy:" 18 78 6 \
        "Quad9" "DNSSEC, Malware Blocking, No Logging (Recommended)" \
        "Cloudflare" "DNSSEC, Privacy-First, No Logging" \
        "Google" "DNSSEC, Fast, Reliable (some logging)" \
        "OpenDNS" "DNSSEC, Custom Filtering, Logging (opt-in)" \
        "CleanBrowsing" "Family-safe, Malware Block, DNSSEC" \
        "UncensoredDNS" "DNSSEC, No Logging, Europe-based, Privacy Focus" \
        3>&1 1>&2 2>&3)

    # Exit if user cancels
    if [[ -z "$selected_provider" ]]; then
        HARDN_STATUS "warning" "DNS configuration cancelled by user. Using system defaults."
        return 1
    fi

    # Return the selected provider and its DNS servers
    echo "$selected_provider ${dns_providers[$selected_provider]}"
    return 0
}

hardn_configure_networkmanager_dns() {
        local primary_dns="$1"
        local secondary_dns="$2"
        local configured_persistently="$3"
        local result=1
        local active_conn

        [[ "$configured_persistently" == "true" ]] || ! command -v nmcli >/dev/null 2>&1 && return "$result"

        HARDN_STATUS "info" "NetworkManager detected. Attempting to configure DNS via NetworkManager..."

        # Get the current active connection - minimize forks with single pipeline
        active_conn=$(nmcli -t -f NAME,TYPE,DEVICE,STATE c show --active | grep -E ':(ethernet|wifi):.+:activated' | head -1 | cut -d: -f1)

        # Early return if no active connection
        [[ -z "$active_conn" ]] && {
            HARDN_STATUS "warning" "No active NetworkManager connection found."
            return "$result"
        }

        HARDN_STATUS "info" "Configuring DNS for active connection: $active_conn"

        # Combine operations with && to fail fast
        if nmcli c modify "$active_conn" ipv4.dns "$primary_dns,$secondary_dns" ipv4.ignore-auto-dns yes &&
           nmcli c down "$active_conn" &&
           nmcli c up "$active_conn"; then
            HARDN_STATUS "pass" "NetworkManager connection configured and restarted successfully."
            return 0
        else
            HARDN_STATUS "error" "Failed to configure or restart NetworkManager connection."
            return "$result"
        fi
}

hardn_configure_systemd_resolved() {
    local primary_dns="$1"
    local secondary_dns="$2"
    local resolv_conf="$3"
    local configured_persistently=false
    local changes_made=false

    # Fast-fail if systemd-resolved isn't managing DNS
    # Combined conditions with single subprocess call for efficiency
    if ! { systemctl is-active --quiet systemd-resolved &&
           [[ -L "$resolv_conf" ]] &&
           readlink "$resolv_conf" | grep -qE "systemd/resolve/(stub-resolv.conf|resolv.conf)"; }; then
        return 1
    fi

    HARDN_STATUS "info" "systemd-resolved is active and manages $resolv_conf."

    # Define config paths and create temp file with error handling
    local resolved_conf_systemd="/etc/systemd/resolved.conf"
    local temp_resolved_conf
    temp_resolved_conf=$(mktemp) || {
        HARDN_STATUS "error" "Failed to create temporary file for resolved.conf"
            return 1
        }

    if ! { printf "[Resolve]\n" > "$resolved_conf_systemd" && chmod 644 "$resolved_conf_systemd"; }; then
        HARDN_STATUS "error" "Failed to create $resolved_conf_systemd"
        rm -f "$temp_resolved_conf"
        return 1
    fi

    # Copy existing config to temp file
    cp "$resolved_conf_systemd" "$temp_resolved_conf" || {
        HARDN_STATUS "error" "Failed to copy resolved.conf to temp file"
            rm -f "$temp_resolved_conf"
            return 1
        }

    # Nested function for updating settings - more efficient than repeating code
    hardn_update_resolved_setting() {
        local setting="$1"
        local value="$2"
        local file="$3"

        if grep -qE "^\s*$setting=" "$file"; then
            sed -i -E "s/^\s*$setting=.*/$setting=$value/" "$file"
        elif grep -q "\[Resolve\]" "$file"; then
            sed -i "/\[Resolve\]/a $setting=$value" "$file"
        else
            printf "\n[Resolve]\n%s=%s\n" "$setting" "$value" >> "$file"
        fi
    }

    # Update all settings in a batch
    hardn_update_resolved_setting "DNS" "$primary_dns $secondary_dns" "$temp_resolved_conf"
    hardn_update_resolved_setting "FallbackDNS" "$secondary_dns $primary_dns" "$temp_resolved_conf"
    hardn_update_resolved_setting "DNSSEC" "allow-downgrade" "$temp_resolved_conf"

    # Apply changes only if needed (avoid unnecessary service restarts)
    if ! cmp -s "$temp_resolved_conf" "$resolved_conf_systemd"; then
        cp "$temp_resolved_conf" "$resolved_conf_systemd" || {
            HARDN_STATUS "error" "Failed to update $resolved_conf_systemd"
            rm -f "$temp_resolved_conf"
            return 1
        }

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

    # Clean up temp file
    rm -f "$temp_resolved_conf"

    # Return success if configured persistently
    [[ "$configured_persistently" = true ]] && return 0 || return 1
}

hardn_create_dhclient_hook() {
    local selected_provider="$1"
    local primary_dns="$2"
    local secondary_dns="$3"

    # Check if dhclient is available
    if ! command -v dhclient >/dev/null 2>&1; then
        return 1
    fi

    local dhclient_dir="/etc/dhcp/dhclient-enter-hooks.d"
    local hook_file="$dhclient_dir/hardn-dns"

    # Create directory if it doesn't exist
    if [[ ! -d "$dhclient_dir" ]]; then
        mkdir -p "$dhclient_dir"
    fi

    cat > "$hook_file" << EOF
#!/bin/sh
# HARDN-XDR DNS configuration hook
# DNS Provider: $selected_provider

make_resolv_conf() {
# Override the default make_resolv_conf function
cat > /etc/resolv.conf << RESOLVCONF
# Generated by HARDN-XDR dhclient hook
# DNS Provider: $selected_provider
nameserver $primary_dns
nameserver $secondary_dns
RESOLVCONF

# Preserve any search domains from DHCP
if [ -n "\$new_domain_search" ]; then
    echo "search \$new_domain_search" >> /etc/resolv.conf
elif [ -n "\$new_domain_name" ]; then
    echo "search \$new_domain_name" >> /etc/resolv.conf
fi

return 0
}
EOF
    chmod 755 "$hook_file"
    HARDN_STATUS "pass" "Created dhclient hook to maintain DNS settings."
    return 0
}

hardn_modify_resolv_conf() {
        local resolv_conf="$1"
        local selected_provider="$2"
        local primary_dns="$3"
        local secondary_dns="$4"
        local changes_made=false

        HARDN_STATUS "info" "Attempting direct modification of $resolv_conf."

        if [[ -f "$resolv_conf" ]] && [[ -w "$resolv_conf" ]]; then
            # Backup the original file
            cp "$resolv_conf" "${resolv_conf}.bak.$(date +%Y%m%d%H%M%S)"

            # Create a new resolv.conf with our DNS servers
            {
                echo "# Generated by HARDN-XDR"
                echo "# DNS Provider: $selected_provider"
                echo "nameserver $primary_dns"
                echo "nameserver $secondary_dns"
                # Preserve any options or search domains from the original file
                grep -E "^\s*(options|search|domain)" "$resolv_conf" || true
            } > "${resolv_conf}.new"

            # Replace the original file
            mv "${resolv_conf}.new" "$resolv_conf"
            chmod 644 "$resolv_conf"

            HARDN_STATUS "pass" "Set $selected_provider DNS servers in $resolv_conf."
            HARDN_STATUS "warning" "Warning: Direct changes to $resolv_conf might be overwritten by network management tools."
            changes_made=true

            # Create a persistent hook for dhclient if it exists
            hardn_create_dhclient_hook "$selected_provider" "$primary_dns" "$secondary_dns"

            return 0
        else
            HARDN_STATUS "error" "Failed to write to $resolv_conf. Manual configuration required."
            return 1
        fi
}

hardn_configure_dns() {
        # Declare all local variables at the beginning of the function
        local resolv_conf="/etc/resolv.conf"
        local configured_persistently=false
        local changes_made=false
        local dns_selection
        local selected_provider
        local primary_dns
        local secondary_dns

        HARDN_STATUS "info" "Configuring DNS nameservers..."

        # Get DNS provider selection
        if ! dns_selection=$(hardn_select_dns_provider); then
            return 0
        fi

        read -r selected_provider primary_dns secondary_dns <<< "$dns_selection"
        HARDN_STATUS "info" "Selected $selected_provider DNS: Primary $primary_dns, Secondary $secondary_dns"

        if hardn_configure_systemd_resolved "$primary_dns" "$secondary_dns" "$resolv_conf"; then
            configured_persistently=true
            changes_made=true
        fi

        if ! $configured_persistently && hardn_configure_networkmanager_dns "$primary_dns" "$secondary_dns" "$configured_persistently"; then
            configured_persistently=true
            changes_made=true
        fi

        if ! $configured_persistently && hardn_modify_resolv_conf "$resolv_conf" "$selected_provider" "$primary_dns" "$secondary_dns"; then
            changes_made=true
        fi

        if [[ "$changes_made" = true ]]; then
            whiptail --infobox "DNS configured: $selected_provider\nPrimary: $primary_dns\nSecondary: $secondary_dns" 8 70
        else
            whiptail --infobox "DNS configuration checked. No changes made or needed." 8 70
        fi
}

# SOURCE THIS SCRIPT ONLY!
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    printf "Error: This script should be sourced by hardn-main.sh, not executed directly.\n" >&2
    exit 1
fi
