#!/bin/bash

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../hardn-common.sh" 2>/dev/null || {
    # Fallback if common file not found
    HARDN_STATUS() {
        local status="$1"
        local message="$2"
        case "$status" in
            "pass")    echo -e "\033[1;32m[PASS]\033[0m $message" ;;
            "warning") echo -e "\033[1;33m[WARNING]\033[0m $message" ;;
            "error")   echo -e "\033[1;31m[ERROR]\033[0m $message" ;;
            "info")    echo -e "\033[1;34m[INFO]\033[0m $message" ;;
            *)         echo -e "\033[1;37m[UNKNOWN]\033[0m $message" ;;
        esac
    }
}

HARDN_STATUS "info" "Configuring secure network parameters..."
{
	echo "net.ipv4.ip_forward = 0"
	echo "net.ipv4.conf.all.send_redirects = 0"
	echo "net.ipv4.conf.default.send_redirects = 0"
	echo "net.ipv4.conf.all.accept_redirects = 0"
	echo "net.ipv4.conf.default.accept_redirects = 0"
	echo "net.ipv4.conf.all.secure_redirects = 0"
	echo "net.ipv4.conf.default.secure_redirects = 0"
	echo "net.ipv4.conf.all.log_martians = 1"
	echo "net.ipv4.conf.default.log_martians = 1"
	echo "net.ipv4.icmp_echo_ignore_broadcasts = 1"
	echo "net.ipv4.icmp_ignore_bogus_error_responses = 1"
	echo "net.ipv4.tcp_syncookies = 1"
	echo "net.ipv6.conf.all.disable_ipv6 = 1"
	echo "net.ipv6.conf.default.disable_ipv6 = 1"
} >> /etc/sysctl.conf
