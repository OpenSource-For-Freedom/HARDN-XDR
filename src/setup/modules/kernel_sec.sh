#!/bin/bash
# Module: kernel_hardening.sh (desktop/VM aware)

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
    check_root(){ [[ $EUID -eq 0 ]]; }
    is_container_environment(){ [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -f /.dockerenv || -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
    hardn_module_exit(){ exit "${1:-0}"; }
}

# Detect desktop/VM environment
DESKTOP_VM=false
if is_systemd_available && (systemctl is-active --quiet gdm3 || systemctl is-active --quiet gdm || \
    systemctl is-active --quiet lightdm || systemctl is-active --quiet sddm); then
    DESKTOP_VM=true
elif [[ -n "$DISPLAY" || -n "$XDG_SESSION_TYPE" || "${HARDN_PROFILE,,}" =~ ^(desktop|vm)$ ]]; then
    DESKTOP_VM=true
fi

HARDN_STATUS "info" "Applying kernel security settings (desktop/VM aware)..."

declare -A kernel_params=(
    # Console / FS protections
    ["fs.protected_fifos"]="2"
    ["fs.protected_hardlinks"]="1"
    ["fs.protected_regular"]="2"
    ["fs.protected_symlinks"]="1"
    ["fs.suid_dumpable"]="0"

    # Info leak / safety
    ["kernel.core_uses_pid"]="1"
    ["kernel.ctrl-alt-del"]="0"
    ["kernel.dmesg_restrict"]="1"
    ["kernel.kptr_restrict"]="$([ "$DESKTOP_VM" = true ] && echo 1 || echo 2)"
    ["kernel.modules_disabled"]="0"
    ["kernel.yama.ptrace_scope"]="1"

    # Perf / BPF
    ["kernel.perf_event_paranoid"]="2"
    ["kernel.randomize_va_space"]="2"
    ["kernel.unprivileged_bpf_disabled"]="1"
    ["net.core.bpf_jit_harden"]="2"

    # IPv4
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
    ["net.ipv4.conf.all.rp_filter"]="$([ "$DESKTOP_VM" = true ] && echo 2 || echo 1)"
    ["net.ipv4.conf.default.rp_filter"]="$([ "$DESKTOP_VM" = true ] && echo 2 || echo 1)"
    ["net.ipv4.conf.all.send_redirects"]="0"
    ["net.ipv4.conf.default.send_redirects"]="0"
    ["net.ipv4.icmp_echo_ignore_broadcasts"]="1"
    ["net.ipv4.icmp_ignore_bogus_error_responses"]="1"
    ["net.ipv4.tcp_syncookies"]="1"
    ["net.ipv4.tcp_timestamps"]="1"

    # IPv6
    ["net.ipv6.conf.all.accept_redirects"]="0"
    ["net.ipv6.conf.default.accept_redirects"]="0"
    ["net.ipv6.conf.all.accept_source_route"]="0"
    ["net.ipv6.conf.default.accept_source_route"]="0"
)

# Only disable ldisc_autoload on servers/strict profiles
if [[ "$DESKTOP_VM" != true ]]; then
    kernel_params["dev.tty.ldisc_autoload"]="0"
fi

# Apply sysctls
for param in "${!kernel_params[@]}"; do
    safe_sysctl_set "$param" "${kernel_params[$param]}"
done

if ! is_container_environment; then
    if sysctl --system >/dev/null 2>&1; then
        HARDN_STATUS "pass" "Kernel hardening applied successfully."
    else
        HARDN_STATUS "warning" "Sysctl values set but sysctl --system failed. Settings may require reboot."
    fi
else
    HARDN_STATUS "info" "Container detected – applied what was possible."
fi

# -------- Continue section (like other modules) --------
HARDN_STATUS "pass" "Kernel hardening module completed."
return 0 2>/dev/null || hardn_module_exit 0

set -e