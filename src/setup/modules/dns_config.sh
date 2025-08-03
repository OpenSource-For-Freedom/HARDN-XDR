#!/bin/bash

source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

HARDN_STATUS "info" "Configuring DNS nameservers..."

# Define DNS providers with their primary and secondary servers
declare -A dns_providers=(
	["Quad9"]="9.9.9.9 149.112.112.112"
	["Cloudflare"]="1.1.1.1 1.0.0.1"
	["Google"]="8.8.8.8 8.8.4.4"
	["OpenDNS"]="208.67.222.222 208.67.220.220"
	["CleanBrowsing"]="185.228.168.9 185.228.169.9"
	["UncensoredDNS"]="91.239.100.100 89.233.43.71"
)

# Create menu options for whiptail

# Handle DNS provider selection - auto-select in CI mode
if [[ -n "$CI" || -n "$GITHUB_ACTIONS" || "$SKIP_WHIPTAIL" == "1" ]]; then
    # Auto-select Quad9 in CI environment
    selected_provider="Quad9"
    HARDN_STATUS "info" "CI environment detected, auto-selecting Quad9 DNS provider"
else
    # A through selection of recommended Secured DNS provider
    selected_provider=$(hardn_menu \
        "Select a DNS provider for enhanced security and privacy:" 18 78 6 \
        "Quad9" "DNSSEC, Malware Blocking, No Logging (Recommended)" \
        "Cloudflare" "DNSSEC, Privacy-First, No Logging" \
        "Google" "DNSSEC, Fast, Reliable (some logging)" \
        "OpenDNS" "DNSSEC, Custom Filtering, Logging (opt-in)" \
        "CleanBrowsing" "Family-safe, Malware Block, DNSSEC" \
        "UncensoredDNS" "DNSSEC, No Logging, Europe-based, Privacy Focus" \
        3>&1 1>&2 2>&3)
fi

# Exit if user cancels (but not in CI mode)
if [[ -z "$selected_provider" ]]; then
	HARDN_STATUS "warning" "DNS configuration cancelled by user. Using system defaults."
	return 0 2>/dev/null || hardn_module_exit 0
fi

read -r primary_dns secondary_dns <<< "${dns_providers[$selected_provider]}"
HARDN_STATUS "info" "Selected $selected_provider DNS: Primary $primary_dns, Secondary $secondary_dns"

resolv_conf="/etc/resolv.conf"
configured_persistently=false
changes_made=false

if systemctl is-active --quiet systemd-resolved && \
   [[ -L "$resolv_conf" ]] && \
   (readlink "$resolv_conf" | grep -qE "systemd/resolve/(stub-resolv.conf|resolv.conf)"); then
	HARDN_STATUS "info" "systemd-resolved is active and manages $resolv_conf."
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
		sed -i -E "s/^\s*DNS=.*/DNS=$primary_dns $secondary_dns/" "$temp_resolved_conf"
	else
		if grep -q "\[Resolve\]" "$temp_resolved_conf"; then
			sed -i "/\[Resolve\]/a DNS=$primary_dns $secondary_dns" "$temp_resolved_conf"
		else
			echo -e "\n[Resolve]\nDNS=$primary_dns $secondary_dns" >> "$temp_resolved_conf"
		fi
	fi

	# Set FallbackDNS as well (optional, for redundancy)
	if grep -qE "^\s*FallbackDNS=" "$temp_resolved_conf"; then
		sed -i -E "s/^\s*FallbackDNS=.*/FallbackDNS=$secondary_dns $primary_dns/" "$temp_resolved_conf"
	else
		if grep -q "\[Resolve\]" "$temp_resolved_conf"; then
			sed -i "/\[Resolve\]/a FallbackDNS=$secondary_dns $primary_dns" "$temp_resolved_conf"
		else
			echo -e "\n[Resolve]\nFallbackDNS=$secondary_dns $primary_dns" >> "$temp_resolved_conf"
		fi
	fi

	# Add DNSSEC support if available
	if grep -qE "^\s*DNSSEC=" "$temp_resolved_conf"; then
		sed -i -E "s/^\s*DNSSEC=.*/DNSSEC=allow-downgrade/" "$temp_resolved_conf"
	else
		if grep -q "\[Resolve\]" "$temp_resolved_conf"; then
			sed -i "/\[Resolve\]/a DNSSEC=allow-downgrade" "$temp_resolved_conf"
		else
			echo -e "\n[Resolve]\nDNSSEC=allow-downgrade" >> "$temp_resolved_conf"
		fi
	fi

	if ! cmp -s "$temp_resolved_conf" "$resolved_conf_systemd"; then
		cp "$temp_resolved_conf" "$resolved_conf_systemd"
		HARDN_STATUS "pass" "Updated $resolved_conf_systemd. Restarting systemd-resolved..."

		# Handle systemctl restart in CI environment
		if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]; then
			HARDN_STATUS "info" "CI environment detected, skipping systemd-resolved restart"
			configured_persistently=true
			changes_made=true
		elif systemctl restart systemd-resolved 2>/dev/null; then
			HARDN_STATUS "pass" "systemd-resolved restarted successfully."
			configured_persistently=true
			changes_made=true
		else
			HARDN_STATUS "warning" "Failed to restart systemd-resolved. Manual check may be required."
		fi
	else
		HARDN_STATUS "info" "No effective changes to $resolved_conf_systemd were needed."
	fi
	rm -f "$temp_resolved_conf"
fi

if [[ "$configured_persistently" = false ]] && command -v nmcli >/dev/null 2>&1; then
	HARDN_STATUS "info" "NetworkManager detected. Attempting to configure DNS via NetworkManager..."

	# Skip NetworkManager operations in CI environment
	if [[ -n "$CI" || -n "$GITHUB_ACTIONS" ]]; then
		HARDN_STATUS "info" "CI environment detected, skipping NetworkManager DNS configuration"
		configured_persistently=true
		changes_made=true
	else
		# Get the current active connection
		active_conn=$(nmcli -t -f NAME,TYPE,DEVICE,STATE c show --active 2>/dev/null | grep -E ':(ethernet|wifi):.+:activated' | head -1 | cut -d: -f1)

		if [[ -n "$active_conn" ]]; then
			HARDN_STATUS "info" "Configuring DNS for active connection: $active_conn"
			if nmcli c modify "$active_conn" ipv4.dns "$primary_dns,$secondary_dns" ipv4.ignore-auto-dns yes 2>/dev/null; then
				HARDN_STATUS "pass" "NetworkManager DNS configuration updated."

				# Restart the connection to apply changes
				if nmcli c down "$active_conn" 2>/dev/null && nmcli c up "$active_conn" 2>/dev/null; then
					HARDN_STATUS "pass" "NetworkManager connection restarted successfully."
					configured_persistently=true
					changes_made=true
				else
					HARDN_STATUS "warning" "Failed to restart NetworkManager connection. Changes may not be applied."
				fi
			else
				HARDN_STATUS "warning" "Failed to update NetworkManager DNS configuration."
			fi
		else
			HARDN_STATUS "warning" "No active NetworkManager connection found."
		fi
	fi
fi

# If not using systemd-resolved or NetworkManager, try to set directly in /etc/resolv.conf
if [[ "$configured_persistently" = false ]]; then
	HARDN_STATUS "info" "Attempting direct modification of $resolv_conf."
	if [[ -f "$resolv_conf" ]] && [[ -w "$resolv_conf" ]]; then
		# Backup the original file
		cp "$resolv_conf" "${resolv_conf}.bak.$(date +%Y%m%d%H%M%S)" || true

		# Create a new resolv.conf with our DNS servers
		{
			echo "# Generated by HARDN-XDR"
			echo "# DNS Provider: $selected_provider"
			echo "nameserver $primary_dns"
			echo "nameserver $secondary_dns"
			# Preserve any options or search domains from the original file
			grep -E "^\s*(options|search|domain)" "$resolv_conf" 2>/dev/null || true
		} > "${resolv_conf}.new"

		# Replace the original file
		if mv "${resolv_conf}.new" "$resolv_conf"; then
			chmod 644 "$resolv_conf"
			HARDN_STATUS "pass" "Set $selected_provider DNS servers in $resolv_conf."
			HARDN_STATUS "warning" "Warning: Direct changes to $resolv_conf might be overwritten by network management tools."
			changes_made=true
		else
			HARDN_STATUS "error" "Failed to update $resolv_conf"
		fi

		# Create a persistent hook for dhclient if it exists
		if command -v dhclient >/dev/null 2>&1; then
			dhclient_dir="/etc/dhcp/dhclient-enter-hooks.d"
			hook_file="$dhclient_dir/hardn-dns"

			if [[ ! -d "$dhclient_dir" ]]; then
				mkdir -p "$dhclient_dir" || true
			fi

			if mkdir -p "$dhclient_dir" 2>/dev/null; then
				cat > "$hook_file" << EOF
#!/bin/sh
# HARDN-XDR DNS configuration hook
make_resolv_conf() {
# Override the default make_resolv_conf function
cat > /etc/resolv.conf << RESOLVCONF
# Generated by HARDN-XDR dhclient hook
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
				chmod 755 "$hook_file" 2>/dev/null || true
				HARDN_STATUS "pass" "Created dhclient hook to maintain DNS settings."
			fi
		fi
	else
		HARDN_STATUS "error" "Failed to write to $resolv_conf. Manual configuration required."
	fi
fi

if [[ "$changes_made" = true ]]; then
	hardn_infobox "DNS configured: $selected_provider\nPrimary: $primary_dns\nSecondary: $secondary_dns" 8 70
else
	hardn_infobox "DNS configuration checked. No changes made or needed." 8 70
fi

return 0 2>/dev/null || hardn_module_exit 0
