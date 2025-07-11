#!/bin/bash

# Module for configuring secure network parameters
# This script is designed to be sourced by hardn-main.sh

hardn_secure_network_parameters() {
    HARDN_STATUS "info" "Configuring secure network parameters..."
    cat << EOF >> /etc/sysctl.conf
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
EOF

    # Apply changes immediately
    sysctl -p >/dev/null 2>&1 || HARDN_STATUS "warning" "Failed to apply sysctl parameters immediately"

    HARDN_STATUS "pass" "Secure network parameters configured"
    return 0
}

# Main entry point when called from hardn-main.sh
hardn_secure_network_main() {
    hardn_secure_network_parameters
    return $?
}
