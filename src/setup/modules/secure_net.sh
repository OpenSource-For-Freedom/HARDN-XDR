#!/bin/bash
# Source common functions with fallback for development/CI environments
source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
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
}
#!/bin/bash
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
