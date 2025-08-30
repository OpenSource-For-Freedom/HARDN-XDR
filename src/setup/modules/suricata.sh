#!/bin/bash
# Module: suricata_light.sh — desktop/VM safe, non-blocking

# --- Common includes with graceful fallback ---
if [[ -f "/usr/lib/hardn-xdr/src/setup/hardn-common.sh" ]]; then
  source /usr/lib/hardn-xdr/src/setup/hardn-common.sh
elif [[ -f "../hardn-common.sh" ]]; then
  source ../hardn-common.sh
elif [[ -f "src/setup/hardn-common.sh" ]]; then
  source src/setup/hardn-common.sh
else
  echo "Warning: Cannot find hardn-common.sh; continuing with minimal status output"
  HARDN_STATUS(){ echo "$(date '+%F %T') - [$1] $2"; }
  is_container_environment(){ [[ -f /.dockerenv || -f /run/.containerenv ]] || grep -qa container /proc/1/environ 2>/dev/null; }
  hardn_module_exit(){ exit "${1:-0}"; }
  safe_systemctl(){ timeout 20 systemctl "$@" >/dev/null 2>&1; }
  safe_package_install(){ apt-get update -y >/dev/null 2>&1 || true; apt-get install -y "$@" >/dev/null 2>&1 || return 1; }
fi

HARDN_STATUS "info" "Installing Suricata (LIGHT mode; no service enable/restart)…"

# --- Containers: skip (non-fatal) ---
if is_container_environment; then
  HARDN_STATUS "info" "Container detected; skipping Suricata."
  return 0 2>/dev/null || hardn_module_exit 0
fi

# --- Install packages (soft-fail) ---
if ! safe_package_install suricata suricata-update 2>/dev/null; then
  # Fallback to native managers if safe_package_install is a no-op
  if command -v apt-get >/dev/null 2>&1; then
    apt-get update -y >/dev/null 2>&1 || true
    apt-get install -y suricata suricata-update >/dev/null 2>&1 || HARDN_STATUS "warning" "Install failed; continuing"
  elif command -v dnf >/dev/null 2>&1; then
    dnf -y install suricata suricata-update >/dev/null 2>&1 || HARDN_STATUS "warning" "Install failed; continuing"
  elif command -v yum >/dev/null 2>&1; then
    yum -y install suricata suricata-update >/dev/null 2>&1 || HARDN_STATUS "warning" "Install failed; continuing"
  else
    HARDN_STATUS "warning" "No supported package manager; Suricata may be missing."
  fi
fi

# --- Require a config file to proceed lightly (don’t edit it) ---
if [[ ! -f /etc/suricata/suricata.yaml ]]; then
  HARDN_STATUS "info" "No /etc/suricata/suricata.yaml yet (install may be partial). Skipping configuration."
  HARDN_STATUS "pass" "Suricata module finished (nothing to configure)."
  return 0 2>/dev/null || hardn_module_exit 0
fi

# --- Detect interface but DO NOT modify suricata.yaml or start service ---
iface="$(ip route 2>/dev/null | awk '/^default/ {print $5; exit}')" ; iface="${iface:-eth0}"
HARDN_STATUS "info" "Detected primary interface: ${iface}"

# --- Create a systemd drop-in that *would* use AF_PACKET on that interface (disabled by default) ---
install -d -m 0755 /etc/systemd/system/suricata.service.d
cat > /etc/systemd/system/suricata.service.d/10-interface.conf <<EOF
[Service]
# LIGHT MODE: This drop-in is inert until you enable/start suricata.service yourself.
# It avoids editing /etc/suricata/suricata.yaml and simply pins the capture method if/when used.
ExecStart=
ExecStart=/usr/bin/suricata -D --af-packet=${iface} -c /etc/suricata/suricata.yaml --pidfile /run/suricata.pid
EOF
HARDN_STATUS "pass" "Prepared systemd drop-in: /etc/systemd/system/suricata.service.d/10-interface.conf"

# --- Soft config test (don’t fail the build) ---
if command -v suricata >/dev/null 2>&1; then
  if timeout 30 suricata -T -c /etc/suricata/suricata.yaml >/dev/null 2>&1; then
    HARDN_STATUS "pass" "Suricata configuration test passed."
  else
    HARDN_STATUS "warning" "Suricata config test failed; service will remain disabled."
  fi
fi

# --- Optional rules update (no service restart in light mode) ---
if command -v suricata-update >/dev/null 2>&1; then
  if timeout 60 suricata-update >/dev/null 2>&1; then
    HARDN_STATUS "pass" "Suricata rules updated (no service restart in light mode)."
  else
    HARDN_STATUS "info" "suricata-update slow/failed; skipping (non-fatal)."
  fi
fi

# --- DO NOT enable or restart suricata automatically in light mode ---
HARDN_STATUS "info" "Leaving suricata.service disabled (light/desktop-safe)."
HARDN_STATUS "info" "To enable later: systemctl enable --now suricata.service"

# --- DO NOT install cron/timer that restarts the service ---
# If you want periodic updates without restarts later, create:
#   echo 'suricata-update || true' > /etc/cron.daily/suricata-update && chmod +x /etc/cron.daily/suricata-update

HARDN_STATUS "pass" "Suricata module completed (no service changes, no YAML edits)."

# --- Continue section ---
return 0 2>/dev/null || hardn_module_exit 0