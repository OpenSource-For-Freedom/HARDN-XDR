#!/bin/bash
# Source common functions with fallback for development/CI environments
# Source common functions with fallback for development/CI environments
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
#!/bin/bash

# Check for container environment
if is_container_environment; then
    check_container_limitations || true  # Don't exit on warnings
    HARDN_STATUS "info" "Container environment detected - kernel security parameter modifications may be limited"
fi

HARDN_STATUS "info" "Applying kernel security settings..."

declare -A kernel_params=(
	# === Console and Memory Protections ===
	["dev.tty.ldisc_autoload"]="0"
	["fs.protected_fifos"]="2"
	["fs.protected_hardlinks"]="1"
	["fs.protected_regular"]="2"
	["fs.protected_symlinks"]="1"
	["fs.suid_dumpable"]="0"

	# === Kernel Info Leak Prevention ===
	["kernel.core_uses_pid"]="1"
	["kernel.ctrl-alt-del"]="0"
	["kernel.dmesg_restrict"]="1"
	["kernel.kptr_restrict"]="2"
	["kernel.modules_disabled"]="0" #changed from 1, 1 could break login.
	["kernel.yama.ptrace_scope"]="1"

	# === Performance & BPF ===
	["kernel.perf_event_paranoid"]="2"
	["kernel.randomize_va_space"]="2"
	["kernel.unprivileged_bpf_disabled"]="1"

	# === BPF JIT Hardening ===
	["net.core.bpf_jit_harden"]="2"

	# === IPv4 Hardening ===
	["net.ipv4.conf.all.accept_redirects"]="0"
	["net.ipv4.conf.default.accept_redirects"]="0"
	["net.ipv4.conf.all.accept_source_route"]="0"
	["net.ipv4.conf.default.accept_source_route"]="0"
	["net.ipv4.conf.all.bootp_relay"]="0"
	["net.ipv4.conf.all.forwarding"]="0"
	["net.ipv4.conf.all.log_martians"]="1"
	["net.ipv4.conf.default.log_martians"]="1"
	["net.ipv4.conf.all.mc_forwarding"]="0"
	["net.ipv4.conf.all.proxy_arp"]="0"
	["net.ipv4.conf.all.rp_filter"]="1"
	["net.ipv4.conf.all.send_redirects"]="0"
	["net.ipv4.conf.default.send_redirects"]="0"
	["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
	["net.ipv4.icmp_ignore_bogus_error_responses"]="1"
	["net.ipv4.tcp_syncookies"]="1"
	["net.ipv4.tcp_timestamps"]="1"

	# === IPv6 Hardening ===
	["net.ipv6.conf.all.accept_redirects"]="0"
	["net.ipv6.conf.default.accept_redirects"]="0"
	["net.ipv6.conf.all.accept_source_route"]="0"
	["net.ipv6.conf.default.accept_source_route"]="0"
)

for param in "${!kernel_params[@]}"; do
	expected_value="${kernel_params[$param]}"
	safe_sysctl_set "$param" "$expected_value"
done

if ! is_container_environment; then
	if sysctl --system >/dev/null 2>&1; then
		HARDN_STATUS "pass" "Kernel hardening applied successfully."
	else
		HARDN_STATUS "warning" "Kernel parameters configured but sysctl --system failed. Settings may require reboot."
	fi
else
	HARDN_STATUS "info" "Kernel security parameters configured (some limitations may apply in containers)"
fi


return 0 2>/dev/null || hardn_module_exit 0

set -e
