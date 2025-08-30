#!/bin/bash
# Module: central_logging.sh (desktop-safe, no MTA)

source "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" 2>/dev/null || \
source "$(dirname "$(dirname "$(realpath "${BASH_SOURCE[0]}")")")/hardn-common.sh" 2>/dev/null || {
  echo "Warning: Could not source hardn-common.sh, using basic functions"
  HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
  log_message(){ echo "$(date '+%F %T') - $1"; }
  check_root(){ [[ $EUID -eq 0 ]]; }
  is_installed(){ command -v "$1" >/dev/null 2>&1 || dpkg -s "$1" >/dev/null 2>&1; }
  hardn_module_exit(){ exit "${1:-0}"; }
  is_container_environment(){ [[ -n "$CI" || -n "$GITHUB_ACTIONS" || -f /.dockerenv || -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
  safe_package_install(){ apt-get update -y && apt-get install -y "$@" 2>/dev/null; }  # simple apt fallback
}

HARDN_STATUS "info" "Setting up central logging for security tools..."

install_logging_packages() {
  local need=()
  for p in rsyslog logrotate; do
    is_installed "$p" || need+=("$p")
  done
  if ((${#need[@]})); then
    HARDN_STATUS "info" "Installing: ${need[*]}"
    if ! safe_package_install "${need[@]}"; then
      HARDN_STATUS "warning" "Could not install some logging packages; continuing with what’s available"
    fi
  fi
  HARDN_STATUS "pass" "Logging package check complete."
  return 0
}

install_logging_packages || HARDN_STATUS "warning" "Package installation had issues; proceeding"

# Create log target
HARDN_STATUS "info" "Preparing log directory and file..."
install -d -m 0755 /usr/local/var/log/suricata
install -m 0640 -o root -g adm /dev/null /usr/local/var/log/suricata/hardn-xdr.log
ln -sf /usr/local/var/log/suricata/hardn-xdr.log /var/log/hardn-xdr.log
HARDN_STATUS "pass" "Log file at /usr/local/var/log/suricata/hardn-xdr.log"

# rsyslog config (classic syntax; no facility rewriting—direct file writes)
HARDN_STATUS "info" "Writing /etc/rsyslog.d/30-hardn-xdr.conf..."
cat >/etc/rsyslog.d/30-hardn-xdr.conf <<'EOF'
# HARDN-XDR Central Logging
# Collects security tool events into one file for local review/shipping.

# Template
$template HARDNFormat,"%TIMESTAMP% %HOSTNAME% %syslogtag%%msg%\n"

# Route specific programs directly to the HARDN log
if $programname == 'suricata' then /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat
& stop
if $programname == 'aide' then /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat
& stop
if $programname == 'fail2ban' then /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat
& stop
if ($programname == 'apparmor' or $syslogtag contains 'apparmor') then /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat
& stop
if ($programname == 'audit' or $syslogtag contains 'audit') then /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat
& stop
if ($programname == 'rkhunter' or $syslogtag contains 'rkhunter') then /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat
& stop
if ($programname == 'debsums' or $syslogtag contains 'debsums') then /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat
& stop
if ($programname == 'lynis' or $syslogtag contains 'lynis') then /usr/local/var/log/suricata/hardn-xdr.log;HARDNFormat
& stop
EOF
chmod 0644 /etc/rsyslog.d/30-hardn-xdr.conf
HARDN_STATUS "pass" "rsyslog rules installed."

# Enable/start rsyslog if present
if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files | grep -q '^rsyslog\.service'; then
  systemctl enable rsyslog >/dev/null 2>&1 || true
  if systemctl is-active --quiet rsyslog; then
    HARDN_STATUS "info" "Restarting rsyslog..."
    systemctl restart rsyslog >/dev/null 2>&1 || true
  else
    HARDN_STATUS "info" "Starting rsyslog..."
    systemctl start rsyslog >/dev/null 2>&1 || true
  fi
  HARDN_STATUS "pass" "rsyslog is enabled and running."
else
  HARDN_STATUS "warning" "systemd/rsyslog service not found; config will take effect when rsyslog runs."
fi

# logrotate config (portable; no shell functions)
HARDN_STATUS "info" "Writing /etc/logrotate.d/hardn-xdr..."
cat >/etc/logrotate.d/hardn-xdr <<'EOF'
/usr/local/var/log/suricata/hardn-xdr.log {
  daily
  rotate 30
  compress
  delaycompress
  missingok
  notifempty
  create 640 root adm
  prerotate
    install -d -m 0755 /usr/local/var/log/suricata
    [ -f /usr/local/var/log/suricata/hardn-xdr.log ] || touch /usr/local/var/log/suricata/hardn-xdr.log
    chown root:adm /usr/local/var/log/suricata/hardn-xdr.log
    chmod 640 /usr/local/var/log/suricata/hardn-xdr.log
  endscript
  postrotate
    # Try a polite HUP; fallback to systemctl reload if available
    pkill -HUP rsyslogd 2>/dev/null || true
    if command -v systemctl >/dev/null 2>&1; then
      systemctl reload rsyslog >/dev/null 2>&1 || true
    fi
  endscript
}
EOF
chmod 0644 /etc/logrotate.d/hardn-xdr
HARDN_STATUS "pass" "logrotate rule installed."

HARDN_STATUS "pass" "Central logging setup complete → /usr/local/var/log/suricata/hardn-xdr.log"
return 0 2>/dev/null || hardn_module_exit 0