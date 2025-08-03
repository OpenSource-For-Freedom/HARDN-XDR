#!/bin/bash
# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e


HARDN_STATUS "info" "Checking network interfaces for promiscuous mode..."
for interface in $(/sbin/ip link show | awk '$0 ~ /: / {print $2}' | sed 's/://g'); do
	if /sbin/ip link show "$interface" | grep -q "PROMISC"; then
		HARDN_STATUS "warning" "Interface $interface is in promiscuous mode. Review Interface."
	fi
done


# Expanded protocol list: Vulnerable/Legacy/Uncommon protocols OFF by default, common protocols ON by default
declare -A protocols_defaults=(
	# Vulnerable/Legacy/Obsolete (OFF by default)
	[tipc]=OFF
	[dccp]=OFF
	[sctp]=OFF
	[rds]=OFF
	[ax25]=OFF
	[netrom]=OFF
	[rose]=OFF
	[decnet]=OFF
	[econet]=OFF
	[ipx]=OFF
	[appletalk]=OFF
	[x25]=OFF
	[cifs]=OFF
	[nfs]=OFF
	[nfsv3]=OFF
	[nfsv4]=OFF
	[ksmbd]=OFF
	[gfs2]=OFF
	[atm]=OFF
	[can]=OFF
	[irda]=OFF
	[token-ring]=OFF
	[fddi]=OFF
	[netbeui]=OFF
	[firewire]=OFF
	[bluetooth]=OFF
	[ftp]=OFF
	[telnet]=OFF
	[wireless]=ON
	[80211]=ON
	[802_11]=ON
	[bridge]=ON
	[bonding]=ON
	[vlan]=ON
	[loopback]=ON
	[ethernet]=ON
	[ppp]=ON
	[slip]=OFF
	[usbnet]=ON
	[tun]=ON
	[tap]=ON
	[gre]=ON
	[ipip]=ON
	[sit]=ON
	[macvlan]=ON
	[vxlan]=ON
	[team]=ON
	[dummy]=ON
	[nlmon]=ON
	[ifb]=ON
	[veth]=ON
	[gretap]=ON
	[erspan]=ON
	[geneve]=ON
	[ip6_gre]=ON
	[ip6_tunnel]=ON
	[ip6_vti]=ON
	[ip6erspan]=ON
	[ip6gretap]=ON
	[ip6tnl]=ON
	[ip6_vti]=ON
	[sit]=ON
	[ipip]=ON
	[mpls]=ON
	[mpls_router]=ON
	[mpls_gso]=ON
	[mpls_iptunnel]=ON
	[vcan]=ON
	[vxcan]=ON
	[wireguard]=ON
	# Add more as needed
)

# Build whiptail checklist args
checklist_args=()

# Build whiptail checklist args with expanded descriptions
for proto in "${!protocols_defaults[@]}"; do
	case "$proto" in
		tipc|dccp|sctp|rds|ax25|netrom|rose|decnet|econet|ipx|appletalk|x25|netbeui|firewire|slip|token-ring|fddi|ftp|telnet) desc="Vulnerable/Legacy/Obsolete Protocol" ;;
		cifs|nfs|nfsv3|nfsv4|ksmbd|gfs2) desc="Network File System (disable if not needed)" ;;
		atm|can|irda) desc="Uncommon IPv4/IPv6 Protocol" ;;
		bluetooth) desc="Bluetooth (disable for servers)" ;;
		wireless|80211|802_11) desc="Wireless (disable for servers)" ;;
		bridge|bonding|vlan|loopback|ethernet|usbnet|tun|tap|gre|ipip|sit|macvlan|vxlan|team|dummy|nlmon|ifb|veth|gretap|erspan|geneve|ip6_gre|ip6_tunnel|ip6_vti|ip6erspan|ip6gretap|ip6tnl|mpls|mpls_router|mpls_gso|mpls_iptunnel|vcan|vxcan|wireguard) desc="Common Protocol (ephemeral/non-ephemeral)" ;;
		*) desc="$proto" ;;
	esac
	checklist_args+=("$proto" "$desc" "${protocols_defaults[$proto]}")
done

if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
    if ! selected=$(whiptail --title "Disable Network Protocols" --checklist "Select protocols to disable (RECOMMENDED: Keep all selected):" 20 100 15 \
        "dccp" "Datagram Congestion Control Protocol" ON \
        "sctp" "Stream Control Transmission Protocol" ON \
        "rds" "Reliable Datagram Sockets" ON \
        "tipc" "Transparent Inter Process Communication" ON \
        "n-hdlc" "New High-level Data Link Control" ON \
        "ax25" "Amateur Radio AX.25" ON \
        "netrom" "NET/ROM Amateur Radio" ON \
        "x25" "X.25 Protocol" ON \
        "rose" "ROSE Amateur Radio" ON \
        "decnet" "DECnet Protocol" ON \
        "econet" "Econet Protocol" ON \
        "af_802154" "IEEE 802.15.4" ON \
        "ipx" "Internetwork Packet Exchange" ON \
        "appletalk" "AppleTalk Protocol" ON \
        "psnap" "SubNetwork Access Protocol" ON 3>&1 1>&2 2>&3); then
        HARDN_STATUS "info" "No changes made to network protocol blacklist. Exiting."
        return 0 2>/dev/null || hardn_module_exit 0
    fi

    # Remove quotes from whiptail output
    selected=$(echo "$selected" | tr -d '"')
else
    # Default selection for non-interactive mode - disable vulnerable/legacy protocols
    selected="tipc dccp sctp rds ax25 netrom rose decnet econet ipx appletalk x25 netbeui firewire slip ftp telnet"
    HARDN_STATUS "info" "Running in non-interactive mode, disabling vulnerable/legacy protocols: $selected"
fi

# Backup existing blacklist file
if [[ -f /etc/modprobe.d/blacklist-rare-network.conf ]]; then
	cp /etc/modprobe.d/blacklist-rare-network.conf "/etc/modprobe.d/blacklist-rare-network.conf.bak.$(date +%Y%m%d%H%M%S)"
fi

# Write new blacklist file
{
	echo "# HARDN-XDR Blacklist for Rare/Unused Network Protocols"
	echo "# Disabled for compliance and attack surface reduction"
	for proto in $selected; do
		echo "install $proto /bin/true"
	done
} > /etc/modprobe.d/blacklist-rare-network.conf

HARDN_STATUS "pass" "Network protocol hardening complete: Disabled $(echo "$selected" | wc -w) protocols."

return 0 2>/dev/null || hardn_module_exit 0
