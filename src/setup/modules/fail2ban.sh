#!/bin/bash
# Module: fail2ban_light.sh (desktop/VM friendly)

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
  echo "Warning: Could not source hardn-common.sh, using basic functions"
  HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
  log_message(){ echo "$(date '+%F %T') - $1"; }
  check_root(){ [[ $EUID -eq 0 ]]; }
  is_installed(){ command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
  is_systemd_available(){ [[ -d /run/systemd/system ]] && systemctl --version >/dev/null 2>&1; }
  is_container_environment(){ [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -f /.dockerenv || -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
  hardn_module_exit(){ exit "${1:-0}"; }
}
type safe_systemctl >/dev/null 2>&1 || safe_systemctl(){ timeout 20 systemctl "$@" >/dev/null 2>&1; }

# -------- Skip containers --------
if is_container_environment; then
  HARDN_STATUS "info" "Container detected; skipping Fail2ban."
  return 0 2>/dev/null || hardn_module_exit 0
fi

HARDN_STATUS "info" "Installing Fail2ban (light desktop/VM mode)..."

install_fail2ban() {
  if command -v apt >/dev/null 2>&1; then
    apt update -y && apt install -y --no-install-recommends fail2ban
  elif command -v dnf >/dev/null 2>&1; then
    # Many desktops already have EPEL; don’t force it if unavailable
    dnf install -y fail2ban || {
      dnf install -y epel-release && dnf install -y fail2ban
    }
  elif command -v yum >/dev/null 2>&1; then
    yum install -y fail2ban || { yum install -y epel-release && yum install -y fail2ban; }
  else
    HARDN_STATUS "error" "No supported package manager found."
    return 1
  fi
  HARDN_STATUS "pass" "Fail2ban installed."
  return 0
}

# -------- Banaction autodetect (don’t break laptops) --------
detect_banaction() {
  if command -v ufw >/dev/null 2>&1 && safe_systemctl is-active ufw --quiet; then
    echo "ufw"; return
  fi
  if command -v firewall-cmd >/dev/null 2>&1 && safe_systemctl is-active firewalld --quiet; then
    echo "firewallcmd-rich-rules"; return
  fi
  if command -v iptables-nft >/dev/null 2>&1 || command -v iptables >/dev/null 2>&1; then
    echo "iptables-multiport"; return
  fi
  echo "none" # log-only; safest on desktops/VMs without firewall
}

# -------- Configure defaults (systemd backend, safe thresholds) --------
configure_defaults() {
  install -d -m 0755 /etc/fail2ban
  local jail_local="/etc/fail2ban/jail.local"
  local banaction; banaction="$(detect_banaction)"

  # ignore localhost and RFC1918; systemd backend avoids heavy file tailing
  cat > "$jail_local" <<EOF
[DEFAULT]
backend = systemd
ignoreip = 127.0.0.1/8 ::1 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16
banaction = ${banaction}
findtime = 1h
maxretry = 10
bantime = 1h
EOF

  HARDN_STATUS "pass" "Fail2ban defaults set (backend=systemd, banaction=${banaction})."
}

# -------- Only enable sshd jail if SSH actually exists --------
configure_sshd_jail_if_present() {
  # Debian/Ubuntu service name is "ssh"; unit file provides "sshd" binary
  local has_ssh=false
  if command -v sshd >/dev/null 2>&1; then
    has_ssh=true
  elif systemctl list-unit-files | grep -qE '^ssh\.service'; then
    has_ssh=true
  fi

  if [[ "$has_ssh" == "true" ]]; then
    install -d -m 0755 /etc/fail2ban/jail.d
    cat > /etc/fail2ban/jail.d/10-sshd.conf <<'EOF'
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
maxretry = 6
findtime = 30m
bantime  = 1h
EOF
    HARDN_STATUS "pass" "Enabled sshd jail."
  else
    HARDN_STATUS "info" "No SSH service detected; leaving sshd jail disabled."
  fi
}

# -------- Minimal systemd hardening (safe for desktops) --------
harden_fail2ban_service() {
  install -d -m 0755 /etc/systemd/system/fail2ban.service.d
  cat > /etc/systemd/system/fail2ban.service.d/override.conf <<'EOF'
[Service]
PrivateTmp=true
ProtectSystem=full
ProtectHome=true
NoNewPrivileges=true
# Keep it modest; fail2ban often needs to call firewall tools
# CapabilityBoundingSet= cap_net_admin cap_net_raw
EOF
  safe_systemctl daemon-reload
  HARDN_STATUS "pass" "Applied minimal systemd hardening to fail2ban."
}

# -------- Start/enable only if useful --------
enable_and_start_fail2ban() {
  safe_systemctl enable fail2ban
  safe_systemctl restart fail2ban
  safe_systemctl is-active fail2ban --quiet && \
    HARDN_STATUS "pass" "Fail2ban is running." || \
    HARDN_STATUS "warning" "Fail2ban not active (no jails?) — this is okay on desktops."
}

# -------- Summary --------
summary_message() {
  HARDN_STATUS "info"  "Check status: fail2ban-client status"
  HARDN_STATUS "info"  "Logs: /var/log/fail2ban.log"
  HARDN_STATUS "info"  "Config: /etc/fail2ban/jail.local, /etc/fail2ban/jail.d/*.conf"
  HARDN_STATUS "pass"  "Fail2ban setup (light) complete."
}

main() {
  install_fail2ban || { HARDN_STATUS "warning" "Install failed; skipping configuration"; return 0; }
  configure_defaults
  configure_sshd_jail_if_present
  harden_fail2ban_service
  enable_and_start_fail2ban
  summary_message
  return 0
}

main

# -------- Continue section (like your other modules) --------
return 0 2>/dev/null || hardn_module_exit 0
# no 'set -e' at end — we want the chain to continue