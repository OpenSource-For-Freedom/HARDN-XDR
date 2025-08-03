#!/bin/bash
# shellcheck source=/usr/lib/hardn-xdr/src/setup/hardn-common.sh
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

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

return 0 2>/dev/null || hardn_module_exit 0
