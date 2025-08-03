#!/bin/bash
source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
set -e

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
	current_value=$(sysctl -n "$param" 2>/dev/null)

	if [[ -z "$current_value" ]]; then
		HARDN_STATUS "warning" "Parameter $param not available in this environment, skipping"
		continue
	fi

	if [[ "$current_value" != "$expected_value" ]]; then
		sed -i "/^$param\s*=/d" /etc/sysctl.conf 2>/dev/null || true
		echo "$param = $expected_value" >> /etc/sysctl.conf
		if sysctl -w "$param=$expected_value" >/dev/null 2>&1; then
			HARDN_STATUS "info" "Set $param = $expected_value"
		else
			HARDN_STATUS "warning" "Failed to set $param = $expected_value (may not be supported in CI environment)"
		fi
	fi
done

if sysctl --system >/dev/null 2>&1; then
	HARDN_STATUS "pass" "Kernel hardening applied successfully."
else
	HARDN_STATUS "warning" "Some sysctl parameters may not have been applied (normal in CI environment)"
fi


return 0 2>/dev/null || hardn_module_exit 0

