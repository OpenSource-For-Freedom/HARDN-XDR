#!/bin/bash

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0
        echo "Auto-confirming: $1" >&2
        return 0
    }
    hardn_msgbox() { 
        [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0
        echo "Info: $1" >&2
    }
    is_container_environment() {
        [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || \
        [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null
    }
    is_systemd_available() {
        [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1
    }
    create_scheduled_task() {
        echo "Info: Scheduled task creation skipped in CI environment" >&2
        return 0
    }
    check_container_limitations() {
        if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then
            echo "Warning: Container limitations detected:" >&2
            echo "  - read-only /proc/sys - kernel parameter changes limited" >&2
        fi
        return 0
    }
    hardn_module_exit() {
        local exit_code="${1:-0}"
        exit "$exit_code"
    }
    safe_package_install() {
        local package="$1"
        if [[ "$CI" == "true" ]] || ! check_root; then
            echo "Info: Package installation skipped in CI environment: $package" >&2
            return 0
        fi
        echo "Warning: Package installation not implemented in fallback: $package" >&2
        return 1
    }
}

HARDN_STATUS "info" "Checking network interfaces for promiscuous mode..."

if command -v ip >/dev/null 2>&1; then
    interfaces=$(ip -o link show | awk -F': ' '{print $2}')
    if [[ -n "$interfaces" ]]; then
        for interface in $interfaces; do
            if ip link show "$interface" 2>/dev/null | grep -q "PROMISC"; then
                HARDN_STATUS "warning" "Interface $interface is in promiscuous mode. Review Interface."
            fi
        done
    else
        HARDN_STATUS "info" "No network interfaces found or ip command failed"
    fi
else
    HARDN_STATUS "info" "ip command not available, skipping interface check"
fi

# --- Protocol defaults (trimmed for clarity, same as before) ---
declare -A protocols_defaults=(
    [dccp]=OFF [sctp]=OFF [rds]=OFF [tipc]=OFF
    [ax25]=OFF [netrom]=OFF [rose]=OFF [decnet]=OFF
    [econet]=OFF [ipx]=OFF [appletalk]=OFF [x25]=OFF
    [cifs]=OFF [nfs]=OFF [nfsv3]=OFF [nfsv4]=OFF [ksmbd]=OFF [gfs2]=OFF
    [bluetooth]=OFF [firewire]=OFF [slip]=OFF [ftp]=OFF [telnet]=OFF
    # Common ones default ON...
    [loopback]=ON [ethernet]=ON [bridge]=ON [bonding]=ON [vlan]=ON
    [tun]=ON [tap]=ON [veth]=ON [vxlan]=ON [wireguard]=ON
)

# Build whiptail checklist args
checklist_args=()
for proto in "${!protocols_defaults[@]}"; do
    desc="Protocol"
    checklist_args+=("$proto" "$desc" "${protocols_defaults[$proto]}")
done

if [[ "$SKIP_WHIPTAIL" != "1" ]] && command -v whiptail >/dev/null 2>&1; then
    if ! selected=$(whiptail --title "Disable Network Protocols" --checklist \
        "Select protocols to disable (recommended: disable legacy/unused):" 20 100 15 \
        "dccp" "Datagram Congestion Control Protocol" ON \
        "sctp" "Stream Control Transmission Protocol" ON \
        "rds" "Reliable Datagram Sockets" ON \
        "tipc" "Transparent Inter Process Communication" ON \
        "ax25" "Amateur Radio AX.25" ON \
        "netrom" "NET/ROM Amateur Radio" ON \
        "x25" "X.25 Protocol" ON \
        "rose" "ROSE Amateur Radio" ON \
        "decnet" "DECnet Protocol" ON \
        "econet" "Econet Protocol" ON \
        "ipx" "Internetwork Packet Exchange" ON \
        "appletalk" "AppleTalk Protocol" ON \
        "telnet" "Telnet Protocol" ON \
        "ftp" "FTP Protocol" ON 3>&1 1>&2 2>&3); then
        HARDN_STATUS "info" "No changes made to network protocol blacklist. Exiting."
        return 0 2>/dev/null || hardn_module_exit 0
    fi
    selected=$(echo "$selected" | tr -d '"')
else
    selected="tipc dccp sctp rds ax25 netrom rose decnet econet ipx appletalk x25 ftp telnet"
    HARDN_STATUS "info" "Non-interactive: disabling default vulnerable/legacy protocols: $selected"
fi

# Backup old blacklist
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

# --- NEW: Immediately unload any selected modules if already loaded ---
for proto in $selected; do
    if lsmod | grep -q "^$proto"; then
        HARDN_STATUS "info" "Unloading active kernel module: $proto"
        if modprobe -r "$proto" 2>/dev/null; then
            HARDN_STATUS "pass" "Successfully unloaded: $proto"
        else
            HARDN_STATUS "warning" "Could not unload: $proto (in use?)"
        fi
    fi
done

# Ensure blacklist is registered
depmod -a >/dev/null 2>&1 || true

HARDN_STATUS "pass" "Network protocol hardening complete: Disabled $(echo "$selected" | wc -w) protocols."

return 0 2>/dev/null || hardn_module_exit 0
set -e

