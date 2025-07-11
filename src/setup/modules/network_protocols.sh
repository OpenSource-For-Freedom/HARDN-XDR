#!/bin/bash

# Using built-ins for efficiency, no awk or sed required, or subshell forking.
hardn_check_promiscuous_interfaces() {
    local line interface

    # Read output line-by-line, no awk/sed No subshell forking.
    while IFS= read -r line; do
        # Match lines like: 2: eth0: <BROADCAST,...> to extract interface name.
        if [[ "$line" =~ ^[0-9]+:\ ([^:]+): ]]; then
            interface="${BASH_REMATCH[1]}"
            if /sbin/ip link show "$interface" | grep -q "PROMISC"; then
                HARDN_STATUS "warning" "Interface $interface is in promiscuous mode. Review Interface."
            fi
        fi
    done < <(/sbin/ip link show)
}


# Create blacklist configuration for rare network protocols
hardn_create_network_blacklist() {
    local blacklist_file="/etc/modprobe.d/blacklist-rare-network.conf"

    # Create blacklist file using heredoc
    cat > "$blacklist_file" << 'EOF'
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

    local count
    count=$(grep -c "^install" "$blacklist_file")
    echo "$count"
}

hardn_network_protocols() {
    HARDN_STATUS "info" "Disabling unnecessary network protocols..."

    hardn_check_promiscuous_interfaces

    local disabled_count
    disabled_count=$(hardn_create_network_blacklist)

    HARDN_STATUS "pass" "Network protocol hardening complete: Disabled $disabled_count protocols"

    sysctl -p
}
