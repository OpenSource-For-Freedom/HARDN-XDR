#!/bin/bash
set -e

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
    echo "Warning: Could not source hardn-common.sh, using basic functions"
    HARDN_STATUS() { echo "$(date '+%Y-%m-%d %H:%M:%S') - [$1] $2"; }
    log_message() { echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"; }
    check_root() { [[ $EUID -eq 0 ]]; }
    is_installed() { command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
    hardn_yesno() { [[ "$SKIP_WHIPTAIL" == "1" ]] && return 0; echo "Auto-confirming: $1" >&2; return 0; }
    hardn_msgbox() { [[ "$SKIP_WHIPTAIL" == "1" ]] && echo "Info: $1" >&2 && return 0; echo "Info: $1" >&2; }
    is_container_environment() { [[ -n "$CI" ]] || [[ -n "$GITHUB_ACTIONS" ]] || [[ -f /.dockerenv ]] || [[ -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
    is_systemd_available() { [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1; }
    create_scheduled_task() { echo "Info: Scheduled task creation skipped in CI environment" >&2; return 0; }
    check_container_limitations() { if [[ ! -w /proc/sys ]] || [[ -f /.dockerenv ]]; then echo "Warning: Container limitations detected:" >&2; echo "  - read-only /proc/sys - kernel parameter changes limited" >&2; fi; return 0; }
    hardn_module_exit() { local exit_code="${1:-0}"; exit "$exit_code"; }
    safe_package_install() { local package="$1"; if [[ "$CI" == "true" ]] || ! check_root; then echo "Info: Package installation skipped in CI environment: $package" >&2; return 0; fi; echo "Warning: Package installation not implemented in fallback: $package" >&2; return 1; }
}

# Skip in containers
if is_container_environment; then
    HARDN_STATUS "info" "Container environment detected - skipping NTP setup (host manages time)"
    return 0 2>/dev/null || hardn_module_exit 0
fi

# --- NTP provider selection ---
if [[ "$SKIP_WHIPTAIL" == "1" ]]; then
    ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org"
    HARDN_STATUS "info" "CI mode: Using default Debian NTP pool servers."
else
    provider=$(whiptail --title "NTP Provider Selection" --menu "Choose your NTP provider:" 20 78 10 \
        "debian"   "Debian NTP Pool (default)" \
        "ntp.org"  "NTP.org global pool servers" \
        "google"   "Google Public NTP" \
        "cloudflare" "Cloudflare NTP" \
        "custom"   "Manually enter custom servers" 3>&1 1>&2 2>&3) || provider="debian"

    case "$provider" in
        debian)    ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org" ;;
        ntp.org)   ntp_servers="0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org" ;;
        google)    ntp_servers="time.google.com" ;;
        cloudflare) ntp_servers="time.cloudflare.com" ;;
        custom)    ntp_servers=$(whiptail --inputbox "Enter custom NTP server(s), space separated:" 10 78 3>&1 1>&2 2>&3) ;;
        *)         ntp_servers="0.debian.pool.ntp.org 1.debian.pool.ntp.org 2.debian.pool.ntp.org 3.debian.pool.ntp.org" ;;
    esac
fi

HARDN_STATUS "info" "Configuring NTP using: $ntp_servers"
configured=false

# --- 1. systemd-timesyncd ---
if systemctl is-active --quiet systemd-timesyncd; then
    HARDN_STATUS "info" "systemd-timesyncd detected, applying configuration..."
    conf="/etc/systemd/timesyncd.conf"
    tmp=$(mktemp)
    [[ -f "$conf" ]] || echo "[Time]" > "$conf"
    cp "$conf" "$tmp"
    if grep -qE "^\s*NTP=" "$tmp"; then
        sed -i -E "s/^\s*NTP=.*/NTP=$ntp_servers/" "$tmp"
    else
        sed -i "/\[Time\]/a NTP=$ntp_servers" "$tmp" || echo -e "\n[Time]\nNTP=$ntp_servers" >> "$tmp"
    fi
    if ! cmp -s "$tmp" "$conf"; then
        mv "$tmp" "$conf"
        HARDN_STATUS "pass" "Updated $conf. Restarting systemd-timesyncd..."
        systemctl restart systemd-timesyncd && configured=true
    else
        rm -f "$tmp"; configured=true
    fi

# --- 2. chrony ---
elif is_installed chrony || command -v chronyd >/dev/null; then
    HARDN_STATUS "info" "Chrony detected. Configuring /etc/chrony/chrony.conf..."
    conf="/etc/chrony/chrony.conf"
    [[ -f "$conf" ]] || touch "$conf"
    cp "$conf" "${conf}.bak.$(date +%F-%T)" || true
    tmp=$(mktemp)
    grep -vE "^\s*(server|pool)\s+" "$conf" > "$tmp"
    {
        echo "# HARDN-XDR configured NTP servers"
        for s in $ntp_servers; do
            echo "pool $s iburst"
        done
    } >> "$tmp"
    mv "$tmp" "$conf"
    systemctl enable --now chronyd || systemctl enable --now chrony || true
    HARDN_STATUS "pass" "Chrony configured with $ntp_servers"
    configured=true

# --- 3. ntpd ---
else
    HARDN_STATUS "info" "Falling back to classic ntpd..."
    if ! is_installed ntp; then
        HARDN_STATUS "info" "Installing ntp package..."
        if command -v apt >/dev/null; then apt-get update && apt-get install -y ntp
        elif command -v dnf >/dev/null; then dnf install -y ntp
        elif command -v yum >/dev/null; then yum install -y ntp; fi
    fi
    if is_installed ntp; then
        conf="/etc/ntp.conf"
        [[ -f "$conf" ]] || touch "$conf"
        cp "$conf" "${conf}.bak.$(date +%F-%T)" || true
        tmp=$(mktemp)
        grep -vE "^\s*(server|pool)\s+" "$conf" > "$tmp"
        {
            echo "# HARDN-XDR configured NTP servers"
            for s in $ntp_servers; do
                echo "pool $s iburst"
            done
        } >> "$tmp"
        mv "$tmp" "$conf"
        systemctl enable --now ntp || systemctl enable --now ntpd || true
        HARDN_STATUS "pass" "ntpd configured with $ntp_servers"
        configured=true
    else
        HARDN_STATUS "error" "Failed to install ntp package."
    fi
fi

# --- Validation (optional) ---
if [[ "$configured" == true ]] && command -v ntpq >/dev/null; then
    if ntpq -p 2>/dev/null | grep -q '^\*'; then
        stratum=$(timeout 3 ntpq -c rv 2>/dev/null | grep -o 'stratum=[0-9]*' | cut -d= -f2)
        if [[ -n "$stratum" && "$stratum" -gt 2 ]]; then
            HARDN_STATUS "warning" "NTP is synced but stratum=$stratum (higher than 2)."
        fi
    fi
fi


if [[ "$configured" == true ]]; then
    HARDN_STATUS "pass" "NTP configuration completed successfully."
else
    HARDN_STATUS "error" "NTP configuration failed."
fi

return 0 2>/dev/null || hardn_module_exit 0
