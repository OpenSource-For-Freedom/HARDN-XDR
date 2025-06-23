############################ Disable unnecessary network protocols in kernel
HARDN_STATUS "error" "Disabling unnecessary network protocols..."

# warn network interfaces in promiscuous mode
for interface in $(/sbin/ip link show | awk '$0 ~ /: / {print $2}' | sed 's/://g'); do
	if /sbin/ip link show "$interface" | grep -q "PROMISC"; then
		HARDN_STATUS "warning" "Interface $interface is in promiscuous mode. Review Interface."
	fi
done
# Create comprehensive blacklist file for network protocols
cat > /etc/modprobe.d/blacklist-rare-network.conf << 'EOF'
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

HARDN_STATUS "pass" "Network protocol hardening complete: Disabled $(grep -c "^install" /etc/modprobe.d/blacklist-rare-network.conf) protocols"


# Apply changes immediately where possible
sysctl -p
